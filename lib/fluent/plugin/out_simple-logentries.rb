require 'socket'
require 'json'
require 'openssl'

class Fluent::SimpleLogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  Fluent::Plugin.register_output('simple-logentries', self)

  config_param :use_ssl,        :bool,    :default => true
  config_param :port,           :integer, :default => 20000
  config_param :protocol,       :string,  :default => 'tcp'
  config_param :max_retries,    :integer, :default => 3
  config_param :token,          :string
  SSL_HOST    = "api.logentries.com"
  NO_SSL_HOST = "data.logentries.com"

  def configure(conf)
    super
    @last_edit = Time.at(0)
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
    generate_tokens_list()
    return unless @tokens.is_a? Hash

    chunk.msgpack_each do |tag, record|
      if record.is_a? Hash
        send_logentries(@token, JSON.generate(record))
      end
    end
  end

  def send_logentries(token, data)
    retries = 0
    begin
      client.write("#{token} #{data} \n")
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      if retries < @max_retries
        retries += 1
        @_socket = nil
        log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
        sleep 5**retries
        retry
      end
      raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
    rescue Errno::EMSGSIZE
      log.warn "Could not push logs to Logentries. #{e.message}"
    end
  end

end
