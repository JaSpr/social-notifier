
# Skeleton (abstract) class
module Social_Notifier
  class Messenger

    #
    # Initialize the Class
    #
    # @param notifier_engine [Social_Notifier::Engine]
    # @param is_listener [Boolean]
    # @raise [ArgumentError]
    # @return [Void]
    #
    def initialize(notifier_engine, is_listener)

      raise ArgumentError, "Notifier Engine must be instance of Social_Notifier::Engine" unless notifier_engine.is_a? Social_Notifier::Engine

      @notifier_engine = notifier_engine

      listen if is_listener
    end

    #
    # Anything that needs to be unloaded
    #
    def unload
    end

    #
    # Sends a message to the listener instance
    #
    # @param message [Array<String>]
    # @return [String] The response from the listener instance
    #
    def send_message(message)

      raise Exception, "No messenger interface selected." if self.class === Messenger
      raise Exception, "No send_message method implemented in class #{self.class}"

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
      raise Exception, "No messenger interface selected." if self.class === Messenger
      raise Exception, "No listen method implemented in class #{self.class}"

    end

    #
    # Parses a request retrieved via retrieve_messages() and sends the response back to the requester instance
    #
    # @param request [Array<String>]
    # @return [Void]
    #
    def handle_request(request)
      raise Exception, "No messenger interface selected." if self.class === Messenger
      raise Exception, "No listen method implemented in class #{self.class}"
    end


    #
    # Sends the response back to the requester instance
    #
    # @param uuid [String]
    # @param message [String]
    # @return [Void]
    #
    def send_response(arguments)
      raise Exception, "No messenger interface selected." if self.class === Messenger
      raise Exception, "No listen method implemented in class #{self.class}"
    end


  end
end