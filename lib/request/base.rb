#! /usr/bin/ruby -wW2d
module SocialNotifier
  module Request
    class Base
      attr_accessor :type

      #
      # Initialize the object
      #
      # @param params [Hash]
      # @return [Void]
      #
      def initialize(params)

        if params and params.length
          params.each do |key, value|
            instance_variable_set("@#{key}".to_sym, value)
          end
        end

      end

      #
      # Runs the request
      #
      # @return [Array, Exception]
      #
      def send

        response = nil

        response || []

      end

      #
      # Custom inspect method
      #
      # @return [String]
      #
      def inspect
        "#{type}: #{@method}: #{@params.inspect}"
      end

      private

      #
      # Throws exception on invalid request.
      #
      # @raise [ArgumentError]
      # @return [Void]
      #
      def validate_parameters

        raise ArgumentError, "Request method is not set" unless @method

      end


      #
      # returns the request method
      #
      # @return [Symbol]
      #
      def method
        @method
      end

      #
      # Directly sets the request method
      #
      # @param method [String, Symbol]
      # @raise [ArgumentError]
      # @return [symbol]
      #
      def method=(method)
        raise ArgumentError, "#{method} is not a valid request method" unless valid_methods.member? method.to_sym
        @method = method.to_sym
      end
    end
  end
end