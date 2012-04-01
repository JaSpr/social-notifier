#! /usr/bin/ruby -wW2d

require 'cgi'
require 'json'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'open-uri'

require_relative '../request'
require_relative 'google-voice/message'
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
      #raise ArgumentError, "Notifier engine must be instance of SocialNotifier::Engine" unless notifier_engine.is_a? SocialNotifier::Engine

      # Turn the parameters into instance variables so that we can reference them any time.
      if params and params.is_a? Enumerable
        params.each do |key, value|
          instance_variable_set("@#{key}".to_sym, value)
          @method = value.to_sym if key == :method
        end
      end

      if params
        @username = @params.shift if @params.first
        @password = @params.shift if @params.first
      end

      #validate_parameters

      @past_entries    = []
      @response        = nil
      @notifier_engine = notifier_engine
      @messages = []

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

###########################################################################
    #private
###########################################################################

    #
    # Processes the responses from the API and returns them properly
    # @return [Hash|Exception|Array<Void>]
    #
    def process_response

      if @response and @response.is_a? Exception
        @response
      elsif @messages.length

        response = @messages.map do |entry|

            {
              id:        entry.id,
              title:     "#{entry.type.upcase}: #{entry.contact}  (#{entry.time})",
              body:      entry.message_text,
              icon_path: File.realpath("#{Dir.pwd}/assets/gvoice.png"),
              object:    entry
            }

        end

        response.compact

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

      raise ArgumentError, "Request method is not set" unless @method
      raise ArgumentError, "#{@method} is not a valid request method" unless valid_methods.member? @method.to_sym

      if @method == 'search'
        raise ArgumentError, "Search keyword is not set" unless @params.first
      elsif @method == 'list'
        raise ArgumentError, "List owner is not set" unless @params.first and @params.first != "" and @params.first != 0
        raise ArgumentError, "No list selected" unless @params[1] and @params[1] != "" and @params[1] != 0
      end

    end

    #
    # list of valid request methods
    #
    # @return [Array<Symbol>]
    #
    def valid_methods
      [:sms, :missed, :vm]
    end

    #
    # Retrieve the latest tweets
    #
    # @return [Array, Exception]
    #
    def get_inbox

      begin
        response = send
      rescue => exc
        return exc
      end

      response || []

    end


    #
    # @return [String]]
    def contact_dir
      @notifier_engine.data_dir + '/google-contacts'
    end

    #
    # Initializes the data storage directory
    # @return [Void]
    def initialize_data_storage
      Dir::mkdir contact_dir unless FileTest::directory? contact_dir or not FileTest::directory? @notifier_engine.data_dir
    end

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

    def auth_code
      unless @auth_code
        data = "accountType=GOOGLE&Email=#{@username}&Passwd=#{@password}&service=grandcentral&source=jaspr-socialnotifierCLI-1.0"
        res = send_post('https://www.google.com/accounts/ClientLogin', data)
        if res
          @auth_code = res.match(/Auth=(.+)/)[1]
        else
          res.error!
        end
      end

      @auth_code

    end

    def header
      {'Authorization ' => "GoogleLogin auth=#{auth_code.strip}",'Content-Length' => '0'}
    end

    def new_res
      unless @new_res
        @new_res = send_get('https://www.google.com/voice',header)
      end
      @new_res
    end

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


    def send
      begin
        @messages = []
        data = "_rnr_se=#{rnr_se}"

        types = {
          :sms => 'sms',
          :vm  => 'voicemail',
          :missed => 'missed',
        }

        url = 'https://www.google.com/voice/inbox/recent/'

        @response  = send_get(url + types[method], header)

        document = Nokogiri.XML(@response)

        # MASSIVE hack
        html_document =  Nokogiri.XML(document.css('response').inner_html.gsub(/<\!\[CDATA\[(.*)\]\]>/m, '\1').gsub(/.*<html>/m, '<html>'))

        html_document.css('.gc-message-unread').each do |message|
          @messages.push SocialNotifier::GoogleVoiceMessageHTML.new(method, message)
        end
      rescue => exc
        @response = exc
      end

      process_response
    end

  end
end