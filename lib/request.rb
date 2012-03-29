#! /usr/bin/ruby -wW2d
module Social_Notifier
  class Request

    attr_accessor :keyword, :list_owner, :list_slug

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

      @last_tweet_id = nil

    end

    #
    # Runs the request
    #
    # @return [Array, Exception]
    #
    def send
      validate_parameters

      response = nil

      if @method == 'list'
        response = get_list_timeline_tweets @params[0], @params[1]
      elsif @method == 'search'
        response = get_search_timeline_tweets @params[0]
      elsif @method == 'home'
        response = get_home_timeline_tweets
      end

      @last_tweet_id = response.first.id if valid_twitter_response? response

      response || []

    end

    ##
    # Checks whether the twitter response is a valid twitter response
    #
    # @param response [Array, Exception]
    #
    # @return [Boolean]
    ##
    def valid_twitter_response?(response)
      (response.is_a? Enumerable and response.first and response.first.is_a? Twitter::Status)
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