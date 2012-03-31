#! /usr/bin/ruby -wW2d

require 'simple-rss'
require 'open-uri'

require_relative 'rss'

module SocialNotifier
  class GmailRequest < SocialNotifier::RssRequest

    def type
      "Gmail"
    end

    attr_accessor :url, :username, :password, :label

    def initialize(notifier_engine, params=nil)

      # We use the notifier engine object to write to the log file.
      raise ArgumentError, "Notifier engine must be instance of SocialNotifier::Engine" unless notifier_engine.is_a? SocialNotifier::Engine

      # Turn the parameters into instance variables so that we can reference them any time.
      if params and params.is_a? Enumerable
        params.each do |key, value|
          instance_variable_set("@#{key}".to_sym, value)
          @label = value if key == :method
        end
      end

      @url = "https://mail.google.com/mail/feed/atom/#{@label}"

      if @params
        @username = @params.shift if @params.first
        @password = @params.shift if @params.first
      end

      validate_parameters

      @response        = nil
      @notifier_engine = notifier_engine

      SimpleRSS.item_tags << ":feedburner:origLink"

    end

    def inspect

      uname = (username.match(/@/) ? username : username + "@gmail.com")

      "#{type}: #{uname}, Label: \"#{@method.capitalize}\""
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

          author = parse_author_tag entry.author

          body = []
          body.push author[:email]
          body.push entry.summary != "" ? entry.summary : "[no message]"
          body.push entry.modified.to_time

          {
            id:        entry.id,
            title:     "#{author[:name]} | #{entry.title}",
            body:      body.compact.join("\n---\n"),
            icon_path: File.realpath("#{Dir.pwd}/assets/gmail.png"),
            object:    entry
          }

        end
      elsif @response and @response.is_a? Exception
        @response
      else
        []
      end
    end

    def parse_author_tag author
      author_dup = author.dump.split('\\')
      author_dup.first[0] = ""
      author_dup.last[author_dup.last.length - 1] = ""

      {
          :name => author_dup.first,
          :email => author_dup.last,
      }

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

      raise ArgumentError, "Username is required for access to the Gmail Atom feed" unless @username and @username != ""
      raise ArgumentError, "Password is required for access to the Gmail Atom feed" unless @password and @password != ""

    end

  end
end