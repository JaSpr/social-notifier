#! /usr/bin/ruby -wW2d

require 'simple-rss'
require 'net/http'
require 'open-uri'

require_relative 'base'

module SocialNotifier
  module Request
    class Rss < SocialNotifier::Request::Base

      attr_accessor :url, :username, :password

      def type
        "RSS"
      end

      #
      # Initialize the object
      #
      # @param params [Hash]
      # @return [Void]
      #
      def initialize(notifier_engine, params=nil)

        # We use the notifier engine object to write to the log file.
        raise ArgumentError, "Notifier engine must be instance of SocialNotifier::Engine" unless notifier_engine.is_a? SocialNotifier::Engine

        # Turn the parameters into instance variables so that we can reference them any time.
        if params and params.is_a? Enumerable
          params.each do |key, value|
            if key == :method
              @url = value
            else
              instance_variable_set("@#{key}".to_sym, value)
            end
          end
        end

        if @params
          @username = @params.shift if @params.first
          @password = @params.shift if @params.first
        end

        @past_entries    = []
        @notifier_engine = notifier_engine

      end

      #
      # Runs the request
      #
      # @return [Array, Exception]
      #
      def send
        validate_parameters

        response = get_rss_contents

        process_response response
      end

      def inspect
        "#{type.upcase}: #{@url}"
      end

  ###########################################################################
      private
  ###########################################################################

      def get_rss_contents
        begin
          if @username and @password
            rss_response = SimpleRSS.parse open(@url, :http_basic_authentication => [@username, @password])
          else
            rss_response = SimpleRSS.parse open(@url)
          end
        rescue => exc
          return exc
        end

        @feed_title = rss_response.instance_variable_get("@title")

        rss_response.items[0..2] || []

      end

      #
      # Processes the responses from the API and returns them properly
      # @return [Hash|Exception|Array<Void>]
      #
      def process_response(response)
        if response and response.is_a? Array
          response.map do |entry|

            body = []
            body.push entry.title
            body.push "by #{entry.author}" if entry.author
            body.push (entry.summary ? entry.summary[0..150] : nil) || (entry.description ? entry.description[0..150] : nil)
            body.push Time.parse(entry.modified) if entry.modifie

            {
                id:        entry.id || entry.guid || entry.uuid || entry.link,
                title:     @feed_title,
                body:      body.compact.join("\n--\n"),
                icon_path: File.realpath("#{APPLICATION_PATH}/assets/rss.png"),
                object:    entry
            }

          end
        elsif response and response.is_a? Exception
          response
        else
          []
        end
      end

      #
      # Throws exception on invalid request.
      #
      # @raise [ArgumentError]
      # @return [Void]
      #
      def validate_parameters

        raise ArgumentError, "URL is required" unless @url
        raise ArgumentError, "URL must be absolute" unless URI.parse(@url).absolute?

      end

    end

  end
end