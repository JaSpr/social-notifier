require 'uuid'

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

      @uuid             = UUID.new
      @notifier_engine     = notifier_engine

      listen if is_listener
    end

    def unload
      unlock_file request_file
      unlock_file response_file
    end

    #
    # Sends a message to the listener instance
    #
    # @param message [Array<String>]
    # @return [String] The response from the listener instance
    #
    def send_message(message)

      message_uuid = @uuid.generate
      message      = "#{message_uuid}\t" + message.join("\t")
      message_sent = false

      until message_sent

        unless is_locked? request_file

          lock_file request_file

          open(request_file, "a") do |file|
            file.write("#{message}\n")
          end

          unlock_file request_file

          message_sent = true

        end

        break if message_sent
        sleep (0.06)

      end

      response = false

      until response
        response = retrieve_response message_uuid
        break if response
        sleep (0.06)
      end

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
      Thread.new do
        while true
          retrieve_messages
          sleep (0.1)
        end
      end
    end

    #
    # Parses a request retrieved via retrieve_messages() and sends the response back to the requester instance
    #
    # @param request [Array<String>]
    # @return [Void]
    #
    def parse_request request

      request_uuid   = request.shift
      request_method = request.shift

      begin
        request_response = @notifier_engine.process_input request_method.to_sym, request
      rescue => exc
        request_response = "#{exc.class}: #{exc.message}"
      end

      send_response request_uuid, request_response

    end

    #
    # Checks the requests file to see if any requests have been sent to the listener
    #
    # @return [Void]
    #
    def retrieve_messages
      if FileTest::file? request_file and not is_locked? request_file

        lock_file request_file

        requests = File.read(request_file).split("\n")
        requests.each do |request|
          @notifier_engine.log "New request: #{request}"
          parse_request request.split("\t")
        end

        open(request_file, 'w') {}

        unlock_file request_file
      end
    end

    #
    # Sends the response back to the requester instance
    #
    # @param uuid [String]
    # @param message [String]
    # @return [Void]
    #
    def send_response(uuid, message)
      while true
        unless is_locked? response_file

          lock_file response_file

          open(response_file, "a") do |file|
            file.write("#{uuid}>>\n")
          end

          open(response_file, "a") do |file|
            file.write("#{message}\n")
          end

          open(response_file, "a") do |file|
            file.write("<<#{uuid}\n")
          end

          unlock_file response_file

          return

        end
        sleep(0.1)
      end
    end

    #
    # Retrieves a response from the listener via the response file
    #
    # @param uuid [String] The unique ID of the message for which the messenger is waiting
    # @return [String]
    #
    def retrieve_response(uuid)

      response = false
      remaining_file_contents = []

      message_has_begun = false
      message_has_ended = false

      if FileTest::file? response_file and not is_locked? response_file

        lock_file response_file

        open(response_file, "r") do |file|
          while (line = file.gets)

            if (line == "#{uuid}>>" or line == "#{uuid}>>\n") and not message_has_begun
              message_has_begun = true
              response = []
              next
            elsif (line == "<<#{uuid}" or line == "<<#{uuid}\n") and message_has_begun
              message_has_ended = true
              next
            end

            if message_has_begun and not message_has_ended
              response.push line
            else
              remaining_file_contents.push line
            end

          end
        end

        if response and remaining_file_contents.first
          open(response_file, "w") do |file|
            file.write(remaining_file_contents.join() + "\n")
          end
        elsif response
          open(response_file, "w") {}
        end

        unlock_file response_file

      end

      response

    end

    #
    # Returns the path to the request file
    #
    # @return [String]
    #
    def request_file
      @notifier_engine.request_file
    end


    #
    # Returns the path to the response file
    #
    # @return [String]
    #
    def response_file
      @notifier_engine.response_file
    end

    #
    # Adds a lock file to mark the given file as locked
    #
    # @param file [String] Full path to the file
    # @return [Void]
    #
    def lock_file file
      file_lock =  file + ".lock"
      open(file_lock, "w") {}
    end

    #
    # Deletes a lock file to mark the given file as unlocked
    #
    # @param file [String] Full path to the file
    # @return [Void]
    #
    def unlock_file file
      file_lock = file + ".lock"
      File.delete(file_lock) if FileTest::file? file_lock
    end

    #
    # Checks for a lock file to see if the given file is marked as locked
    #
    # @param file [String] Full path to the file
    # @return [Void]
    #
    def is_locked? file
      file_lock = file + ".lock"
      FileTest::file? file_lock
    end

  end
end