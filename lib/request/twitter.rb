#! /usr/bin/ruby -wW2d

require_relative '../request'

module SocialNotifier
  class TwitterRequest < SocialNotifier::Request

    attr_accessor :keyword, :list_owner, :list_slug

    def type
      "Twitter"
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
          instance_variable_set("@#{key}".to_sym, value)
        end
      end

      @response        = nil
      @last_tweet_id   = nil
      @notifier_engine = notifier_engine

      initialize_data_storage

    end

    #
    # Runs the request
    #
    # @return [Array, Exception]
    #
    def send
      validate_parameters

      if @method.to_sym    == :list
        @response = get_list_timeline_tweets @params[0], @params[1]
      elsif @method.to_sym == :search
        @response = get_search_timeline_tweets @params[0]
      elsif @method.to_sym == :home
        @response = get_home_timeline_tweets
      else
        @notifier_engine.log "method: #{@method.inspect}"
      end

      @last_tweet_id = @response.first.id if valid_twitter_response? @response

      process_response

    end

    ##
    # Checks whether the twitter response is a valid twitter response
    #
    # @param response [Array, Exception]
    #
    # @return [Boolean]
    ##
    def valid_twitter_response?(response)
      (response.is_a? Array and response.first and response.first.is_a? Twitter::Status)
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
    private
###########################################################################

    #
    # Processes the responses from the API and returns them properly
    # @return [Hash|Exception|Array<Void>]
    #
    def process_response
      if @response and @response.is_a? Array
        @response.map do |entry|

          begin
            user = entry.user || Twitter.user(entry.from_user)
          rescue Twitter::Error::ServiceUnavailable => exc
            # when twitter returns service unavailable while calling for the user, TRY AGAIN
            @notifier_engine.log "method: #{exc.message}"
            sleep 2
            retry
          end

          {
            id:        entry.id,
            title:     "Twitter: @#{user.screen_name}",
            body:      "#{entry.text}\n#{entry.created_at.to_time}",
            icon_path: user.get_image(icon_dir),
            object:    entry
          }

        end
      elsif @response and @response.is_a? Exception
        @response
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
      [:home, :list, :search]
    end

    #
    # Retrieve the latest tweets
    #
    # @return [Array, Exception]
    #
    def get_home_timeline_tweets

      begin
        if @last_tweet_id
          response = Twitter.home_timeline(:since_id => @last_tweet_id)
        else
          response = Twitter.home_timeline(:count => 3)
        end
      rescue => exc
        return exc
      end

      response || []

    end

    ##
    # Retrieve the latest tweets
    #
    # @return [Array, Exception]
    ##
    def get_list_timeline_tweets(user_screen_name, list_slug)

      begin
        if @last_tweet_id
          response = Twitter.list_timeline(user_screen_name, list_slug, :since_id => @last_tweet_id)
        else
          response = Twitter.list_timeline(user_screen_name, list_slug, :page => 1, :per_page => 3)
        end

      rescue => exc
        return exc
      end

      response || []

    end

    #
    # Retrieve the latest tweets
    #
    # @return [Array, Exception]
    #
    def get_search_timeline_tweets(search_term)

      begin
        if @last_tweet_id
          response = Twitter.search(search_term, :since_id => @last_tweet_id)
        else
          response = Twitter.search(search_term, :result_type => "recent", :rpp => 3, :page => 1)
        end

      rescue => exc
        return exc
      end

      response || []

    end

    #
    # @return [String]]
    def icon_dir
      @notifier_engine.data_dir + '/twitter-images'
    end

    #
    # Initializes the data storage directory
    # @return [Void]
    def initialize_data_storage
      Dir::mkdir icon_dir unless FileTest::directory? icon_dir or not FileTest::directory? @notifier_engine.data_dir
    end

  end
end



module Twitter
  #
  # Modifications to [Twitter::User]
  #
  class User

    #
    # Retrieves the full path to local image, and the image file, if necessary
    #
    # @param base_path [String] Base path to the images folder
    # @return [String]
    #
    def get_image(base_path)
      @base_path = base_path if base_path

      begin
        if FileTest::file? image_path and (FileTest::size image_path).to_i > 0
          # if image exists, download asynchronously
          Thread.new {store_image}
        else
          # synchronously
          store_image
      end
      rescue
        #
      end

      image_path

    end

    #
    # returns the full image path
    #
    # @return [String]
    #
    def image_path
      uri_path  = URI(profile_image_url).path
      extension = File.extname(uri_path)
      "#{@base_path}/#{screen_name}#{extension}"
    end

    private

    #
    # Downloads and saves the user's profile image.
    #
    # @return [Void]
    #
    def store_image
      uri = URI.parse(profile_image_url)
      Net::HTTP.start(uri.host, uri.port) do |http|
        resp = http.get(uri.path)
        open(image_path, "wb") do |file|
          file.write(resp.body)
        end
      end
    end

  end
end