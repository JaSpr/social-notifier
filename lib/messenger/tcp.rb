require 'socket'

require_relative 'base'

module SocialNotifier
  class Messenger

    #
    # Initialize the Class
    #
    # @param notifier_engine [SocialNotifier::Engine]
    # @param is_listener [Boolean]
    # @raise [ArgumentError]
    # @return [Void]
    #
    def initialize(notifier_engine, is_listener)

      raise ArgumentError, "Notifier Object must be instance of SocialNotifier::Engine" unless notifier_engine.is_a? SocialNotifier::Engine

      @notifier_engine = notifier_engine

      listen if is_listener
    end

    #
    # Unload anything that needs to be unload
    # @return [Void]
    def unload

    end

    #
    # Sends a message to the listener instance
    #
    # @param message [Array<String>]
    # @return [String] The response from the listener instance
    #
    def send_message(message)

      message = message.join("\t")
      begin
        server  = TCPSocket.open('localhost', 3456)
      rescue Exception => e
        @notifier_engine.log "Could not connect to SocialNotifier server process"
        @notifier_engine.log "Message Sender Exception: #{e.class}: #{e.message}"
      end

      # send message
      server.puts message

      # get response (ALL LINES (until connection closed by other side))
      response = server.read

      #close the connection
      server.close

      #return the response
      response

    end

####################################################################################
    private
####################################################################################

    #
    # Starts the listener thread
    #
    # @return [Void]
    #
    def listen
      @message_queue = Thread.new do
        begin

          server = TCPServer.open(3456)

          done = false

          until done
            sleep 0.001
            Thread.start(server.accept) do |client|
              # retrieve ONE LINE message (don't wait for connection close)
              message = client.gets.chomp
              @notifier_engine.log "MESSAGE RECEIVED BY SERVER: #{message}"
              client.puts handle_request message
              client.close
              done = true if message.chomp === 'quit'
            end
          end
          @notifier_engine.log 'Finished Message Queue'

        rescue Exception => e
          @notifier_engine.log "Message Listener Exception: #{e.class}: #{e.message}"
        end
      end

    end

    #
    # Parses a request retrieved via retrieve_messages() and sends the response back to the requester instance
    #
    # @param request [String]
    # @return [Void]
    #
    def handle_request(request)

      request = request.split("\t")

      request_method = request.shift

      begin
        request_response = @notifier_engine.process_input request_method.to_sym, request
      rescue => exc
        request_response = "Messenger: Error handling input: #{exc.class}: #{exc.message}"
      end

      request_response

    end

  end
end