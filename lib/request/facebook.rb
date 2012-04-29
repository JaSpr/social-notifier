#! /usr/bin/ruby -wW2d

require_relative 'base'

module SocialNotifier
  module Request
    class Facebook < SocialNotifier::Request::Base

      def type
        "Facebook"
      end

      #
      # Initialize the object
      #
      # @param params [Hash]
      # @return [Void]
      #
      def initialize(notifier_engine, params=nil)

        raise ArgumentError, "Notifier engine must be instance of SocialNotifier::Engine" unless notifier_engine.is_a? SocialNotifier::Engine

        if params and params.is_a? Enumerable
          params.each do |key, value|
            instance_variable_set("@#{key}".to_sym, value)
          end
        end

        @response = nil
        @feed     = nil
        @last_status_id = nil
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

        if @method.to_sym == :home
          @response = get_home_feed
        else
          @notifier_engine.log "method: #{@method.inspect}"
        end

        @feed = @response if valid_response? @response

        process_response

      end

      ##
      # Checks whether the twitter response is a valid twitter response
      #
      # @param response [Array, Exception]
      #
      # @return [Boolean]
      ##
      def valid_response?(response)
        (response.is_a? Enumerable and response.first and response.first.is_a? FbGraph::Post)
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

  ###########################################################################
      private
  ###########################################################################

      #
      # Processes the responses from the API and returns them properly
      #
      def process_response
        if @response and @response.is_a? Enumerable
          response = @response.map do |post|
            if post.from.respond_to? :category  # dump posts by pages
              nil
            else
              body = []
              body.push post.story if post.respond_to? :story and post.story
              body.push post.message if post.respond_to? :message and post.message
              body.push post.name if post.respond_to? :name and post.name
              body.push post.link if post.respond_to? :link and post.link

              title = ['fb:']

              title.push "#{post.type}" if post.type
              title.push post.from.name if post.from

              {
                  id: post.identifier,
                  title: title.join(" "),
                  body: body.join("\n"),
                  icon_path: get_image(post.from.picture, post.from.identifier),
                  object: post
              }
            end
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
        [:home]
      end

      #
      # Retrieve the latest tweets
      #
      # @return [Array, Exception]
      #
      def get_home_feed

        begin
          @notifier_engine.log "Fetching status updates"
          if @feed
            response = @feed.previous
          else
            unless @me
              @me = FbGraph::User.new('me', :access_token => $app_config[:facebook][:access_token])
            end
            response = @me.home(:limit => 15)
          end
        rescue => exc
          return exc
        end

        response || []

      end



      def icon_dir
        DATA_PATH + '/facebook-images'
      end

      def initialize_data_storage
        Dir::mkdir icon_dir unless FileTest::directory? icon_dir or not FileTest::directory? DATA_PATH
      end

      #
      # Retrieves the full path to local image, and the image file, if necessary
      #
      # @param base_path [String] Base path to the images folder
      # @return [String]
      #
      def get_image(image_url, image_id)
        image_path = get_image_path(image_url, image_id)

        if FileTest::file? image_path and (FileTest::size image_path).to_i > 0
          # if image exists, download asynchronously
          Thread.new {store_image(image_url, image_id)}
        else
          # synchronously
          store_image(image_url, image_id)
        end

        image_path

      end

      #
      # returns the full image path
      #
      # @return [String]
      #
      def get_image_path(image_url, image_id)
        uri_path  = URI(image_url).path
        extension = File.extname(uri_path)
        "#{icon_dir}/#{image_id}#{extension}"
      end

      #
      # Downloads and saves the user's profile image.
      #
      # @return [Void]
      #
      def store_image(image_url, image_id)
        uri = URI.parse(URI.encode(image_url))
        image_storage_path = get_image_path(image_url, image_id)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        http_response = http.request_get(uri.path)

        redirect_uri = URI.parse(URI.encode(http_response['location']))

        http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
        http.use_ssl = true

        http.start do |h|
          resp = h.get(redirect_uri.path)
          open(image_storage_path, "wb") do |file|
            file.write(resp.body)
          end
        end
      end

    end

  end
end

