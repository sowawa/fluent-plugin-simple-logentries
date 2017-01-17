require 'socket'
require 'json'
require 'openssl'
require 'securerandom'

class Fluent::SimpleLogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  Fluent::Plugin.register_output('simple-logentries', self)

  config_param :use_ssl,        :bool,    :default => true
  config_param :port,           :integer, :default => 20000
  config_param :protocol,       :string,  :default => 'tcp'
  config_param :max_retries,    :integer, :default => 3
  config_param :append_tag,     :bool,    :default => true
  config_param :token,          :string
  SSL_HOST    = "api.logentries.com"
  NO_SSL_HOST = "data.logentries.com"
  MAX_ENTRY_SIZE = 8192
  SPLITED_ENTRY_SIZE = MAX_ENTRY_SIZE - 256

  def configure(conf)
    super
  end

  def start
    super
  end

  def shutdown
    super
  end

  def client
    @_socket ||= if @use_ssl
      context    = OpenSSL::SSL::SSLContext.new
      socket     = TCPSocket.new SSL_HOST, @port
      ssl_client = OpenSSL::SSL::SSLSocket.new socket, context

      ssl_client.connect
    else
      if @protocol == 'tcp'
        TCPSocket.new NO_SSL_HOST, @port
      else
        udp_client = UDPSocket.new
        udp_client.connect NO_SSL_HOST, @port

        udp_client
      end
    end
  end

  def format(tag, time, record)
    return [tag, record].to_msgpack
  end

  def write(chunk)
    chunk.msgpack_each do |tag, record|
      if record.is_a? Hash
        send_logentries(tag, record)
      end
    end
  end

  def send_logentries(tag, record)
    data = if @append_tag
             record.merge({tag: tag})
           else
             record
           end
    jsonfied = JSON.generate(data)
    if (data.member?(:messages) || data.member?('messages')) && jsonfied.length > MAX_ENTRY_SIZE
      identifyer = SecureRandom.uuid
      messages = if data.member?(:messages)
                   data[:messages]
                 elsif data.member?('messages')
                   data['messages']
                 end
      data.delete(:messages)
      data.delete('messages')
      ([data] + split_messages(messages).map{|i| {messages: i}} ).each_with_index { |item, idx|
        push(JSON.generate({sequence: idx, identifyer: identifyer}.merge(item)))
      }
    else
      push(jsonfied)
    end
  rescue => e
    log.warn "Could not push logs to Logentries. #{e.message}"
    if retries < @max_retries
      retries += 1
      @_socket = nil
      log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
      sleep 5**retries
      retry
    end
    raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
  end

  def push(data)
    retries = 0
    begin
      client.write("#{@token} #{data} \n")
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      if retries < @max_retries
        retries += 1
        @_socket = nil
        log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
        sleep 5**retries
        retry
      end
      raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
    rescue Errno::EMSGSIZE => e
      log.warn "Could not push logs to Logentries. #{e.message}"
    end
  end

  def split_messages(messages)
    if messages.is_a? String
      str_length = messages.length
      return [messages] if SPLITED_ENTRY_SIZE > str_length
      return split_messages(messages[0..str_length/2-1]) +
        split_messages(messages[(str_length/2)..str_length])
    elsif messages.is_a? Array
      arr_length = messages.length
      jsonfied = JSON.generate(messages)
      str_length = jsonfied.length
      return [messages] if SPLITED_ENTRY_SIZE > str_length
      if arr_length == 1
        split_messages(messages[0])
      else
        return split_messages(messages[0..arr_length/2-1]) +
          split_messages(messages[(arr_length/2)..arr_length])
      end
    elsif messages.is_a? Hash
      return split_messages(JSON.generate(messages))
    else
      raise TypeError, "Can't split unknown data type."
    end
  end
end
