#! /usr/bin/ruby -wW2d

require 'nokogiri'
require 'net/http'
require 'net/https'
require 'open-uri'

require_relative 'base'
require_relative 'google-voice/message-html'

module SocialNotifier
  class GvoiceRequest < SocialNotifier::Request

    attr_accessor :username, :password
    attr_reader :response, :messages

    def type
      "Google Voice"
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

      @params = {}

      @params[:method] = params[:method].to_sym if params[:method]

      if params[:params] and params[:params].is_a? Array
        @params[:username] = params[:params].shift if params[:params].first
        @params[:password] = params[:params].shift if params[:params].first
      end

      #validate_parameters

      @messages        = []
      @past_entries    = []
      @notifier_engine = notifier_engine

    end

    # send the request
    def send
      begin
        # delete any previous messages
        @messages = []

        types = {
            :sms    => 'sms',
            :vm     => 'voicemail',
            :missed => 'missed',
        }

        url  = 'https://www.google.com/voice/inbox/recent/'
        data = "_rnr_se=#{rnr_se}"

        response  = send_get(url + types[method], header)

        document = parse_response response

        # find DIVs with a class of "gc-message-unread" and convert to messages
        document.css('.gc-message-unread').each do |message|
          @messages.push SocialNotifier::GoogleVoiceMessageHTML.new(method, message)
        end
      rescue => exc
        response = exc
      end

      process_response response
    end


    # returns the request method
    # @return [Symbol]
    def method
      @params[:method]
    end

    # Directly sets the request method
    #
    # @param method [String, Symbol]
    # @raise [ArgumentError]
    # @return [Symbol]
    def method=(method)
      raise ArgumentError, "#{method} is not a valid request method" unless valid_methods.member? method.to_sym
      @params[:method] = method.to_sym
    end

    def inspect
      "#{type}: #{method.upcase}: #{@params[:username]}"
    end

###########################################################################
    private
###########################################################################

    # Processes the responses from the API and returns them properly
    # @return [Array<Hash>|Exception|Array<Void>]
    def process_response response

      if response and response.is_a? Exception
        response
      elsif @messages.length

        final_response = @messages.map do |entry|

          # Don't return the same entry on subsequent calls
          if @past_entries.member? entry.id
            nil
          else
            @past_entries.push entry.id
            {
              id:        entry.id,
              title:     "#{entry.type.upcase}: #{entry.contact}  (#{entry.time})",
              body:      entry.message_text,
              icon_path: File.realpath("#{Dir.pwd}/assets/gvoice.png"),
              object:    entry
            }
          end

        end
        @messages = nil
        # Remove any invalid entries that were marked as nil
        final_response.compact

      else
        []
      end
    end

    # Throws exception on invalid request.
    # @raise [ArgumentError]
    # @return [Void]
    def validate_parameters

      raise ArgumentError, "Request method is not set" unless method
      raise ArgumentError, "#{method} is not a valid request method" unless valid_methods.member? method.to_sym

      raise ArgumentError, "Username is not set" unless @params[:username] and @params[:username] != "" and @params[:username].is_a? String
      raise ArgumentError, "Password is not set" unless @params[:password] and @params[:password] != "" and @params[:password].is_a? String

    end

    # list of valid request methods
    # @return [Array<Symbol>]
    def valid_methods
      [:sms, :missed, :vm]
    end


    # defines a post request
    # @param uri_str [String]  The URI as a string
    # @param data [Hash] The data to send as post data
    # @param header [Hash] The header data
    # @param limit [Integer] The number of redirects to follow
    # @return [Net::HTTPResponse]
    #
    def send_post(uri_str, data, header = nil, limit = 3)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      url = URI.parse(uri_str)
      http = Net::HTTP.new(url.host,443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response,content = http.post(url.path,data,header)
      case response
        when Net::HTTPSuccess     then content
        when Net::HTTPRedirection then send_post(response['location'],data,header, limit - 1)
        else
          puts response.inspect
          response.error!
      end
    end

    # defines a get request
    # @param uri_str [String]  The URI as a string
    # @param header [Hash] The header data
    # @param limit [Integer] The number of redirects to follow
    # @raise [Exception]
    # @return [Net::HTTPResponse]
    #
    def send_get(uri_str, header, limit = 3)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      url = URI.parse(uri_str)
      http = Net::HTTP.new(url.host,url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response,content = http.get(url.path,header)
      case response
        when Net::HTTPSuccess     then content
        when Net::HTTPRedirection then send_get(response['location'],header, limit - 1)
        else
          response.error!
      end
    end

    # Retrieves the auth code
    # @raise [Exception]
    # @return [String]
    def auth_code
      unless @auth_code
        data = "accountType=GOOGLE&Email=#{@params[:username]}&Passwd=#{@params[:password]}&service=grandcentral&source=jaspr-socialnotifierCLI-1.0"
        res  = send_post('https://www.google.com/accounts/ClientLogin', data)
        if res
          @auth_code = res.match(/Auth=(.+)/)[1]
        else
          res.error!
        end
      end

      @auth_code

    end

    # Build the http header with the auth_code previously retrieved
    # @return [Net::HTTPResponse]
    def header
      {'Authorization ' => "GoogleLogin auth=#{auth_code.strip}",'Content-Length' => '0'}
    end

    # retrieve a new response, based on the header data,
    # which includes the auth content from the previous response
    # @return Http
    def new_res
      unless @new_res
        @new_res = send_get('https://www.google.com/voice', header)
      end
      @new_res
    end

    # Retrieve the _rnr_se value from the new response
    # @return [String]
    def rnr_se
      unless @rnr_se
        if new_res
          @rnr_se = new_res.match(/'_rnr_se': '([^']+)'/)[1]
        else
          new_res.error!
        end
      end

      @rnr_se
    end

    # filter out invalid html content
    # @return []
    def parse_response response
      # parse response as XML
      document = Nokogiri.XML(response)

      # Hacky
      # clear out CDATA tags, leaving their inner content, because otherwise nokogiri can't handle it
      document = document.css('response').inner_html.gsub(/<\!\[CDATA\[(.*)\]\]>/m, '\1')

      #remove <json></json> content, because nokogiri will report it as the only element
      document = document.gsub(/.*<html>/m, '<html>')

      # re-parse resulting html
      Nokogiri.XML(document)
    end

  end
end