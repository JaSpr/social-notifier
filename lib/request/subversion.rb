#! /usr/bin/ruby -wW2d

require 'open3'
require 'nokogiri'

require_relative 'base'

module SocialNotifier
  module Request
    class Subversion < SocialNotifier::Request::Base

      def type
        "SVN"
      end

      #
      # Initialize the object
      #
      # @param params [Hash]
      # @return [Void]
      #
      def initialize(notifier_engine, params=nil)

        # We use the notifier engine object to write to the log file.
        #raise ArgumentError, "Notifier engine must be instance of SocialNotifier::Engine" unless notifier_engine.is_a? SocialNotifier::Engine

        @params = {}
        #@params[:method] = params[:method] if params[:method]
        @params[:url]    = params[:method] if params[:method]

        if params[:params] and params[:params].length > 0
          @params[:username] = params[:params].shift if params[:params].first
          @params[:password] = params[:params].shift if params[:params].first
        end

        @last_revision   = nil
        @notifier_engine = notifier_engine

      end

      #
      # Runs the request
      #
      # @return [Array, Exception]
      #
      def send
        #validate_parameters

        response = get_log_entries

        #@last_revision_id = response.first.id if valid_svn_response? response

        #[]

        process_response response
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
      # @return [Symbol]
      #
      def method=(method)
        raise ArgumentError, "#{method} is not a valid request method" unless valid_methods.member? method.to_sym
        @method = method.to_sym
      end


      def inspect
        "#{type}: #{@params[:url]}"
      end

  ###########################################################################
      private
  ###########################################################################

      #
      # Processes the responses from the API and returns them properly
      # @return [Hash|Exception|Array<Void>]
      #
      def process_response(response)

        if response and response.is_a? Nokogiri::XML::NodeSet and response.length > 0
          @last_revision = response.first.attr('revision')
          response.map do |entry|

            body = []
            entry.css('path').each do |path|
              body.push "#{path.attr('action')}  #{path.text.gsub(/^\//, '')}"
            end

            body = [body.join("\n")]

            message = entry.css('msg').text.gsub(/\n/, ' | ')

            body.push "#{entry.css('author').text.upcase}: #{message}" if entry.css('msg').length > 0
            body.push Time.parse(entry.css('date').text)

            {
              id:        "#{@url}|#{entry.attr('revision')}",
              title:     "#{entry.css('author').text} | Rev. #{entry.attr('revision')}",
              body:      body.join("\n----\n"),
              icon_path: File.realpath("#{Dir.pwd}/assets/svn.png"),
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

        raise ArgumentError, "URL is required" unless @params[:url]
        raise ArgumentError, "URL must be absolute" unless URI.parse(@params[:url]).absolute?

      end

      #
      # Retrieve the latest tweets
      #
      # @return [Array, Exception]
      #
      def get_log_entries
        command = "svn log  -v --xml #{@params[:url]}"
        command += " -r HEAD:#{@last_revision.to_i + 1}" if @last_revision
        command += " -l3" unless @last_revision
        command += " --username=#{@params[:username]}" if @params[:username]
        command += " --password=#{@params[:password]}" if @params[:password]
        command += " &"

        cli_response = Open3.popen3(command)

        stdout = cli_response[1]
        stderr = cli_response[2]

        stderr.readlines.each do |line|
          @notifier_engine.log line.strip
        end

        doc = Nokogiri::XML(stdout.read)

        doc.css("logentry")

      end

    end
  end
end
