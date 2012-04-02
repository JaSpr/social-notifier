#! /usr/bin/ruby -wW2d

require 'nokogiri'
require_relative 'rss'

module SocialNotifier
  class GithubRequest < SocialNotifier::RssRequest

    attr_accessor :url, :username, :password

    def type
      "Git"
    end

###########################################################################
    private
###########################################################################


    def get_rss_contents
      begin
        if @username and @password
          xml = Nokogiri::XML open(@url, :http_basic_authentication => [@username, @password])
        else
          xml = Nokogiri::XML open(@url)
        end
      rescue => exc
        return exc
      end

      xml
    end

    # Processes the responses from the API and returns them properly
    # @return [Array<Hash>|Exception|Array<Void>]
    def process_response(response)

      if response and response.is_a? Exception
        response
      elsif response and response.is_a? Nokogiri::XML::Document

        feed_title = response.css('feed > title').text.gsub('Recent Commits to ', '')
        entries    = response.css('entry')[0..3]

        final_response = entries.map do |entry|

          entry_id = entry.css('id').text.strip
          # Don't return the same entry on subsequent calls
          if @past_entries.member? entry_id
            nil
          else
            @past_entries.push entry_id

            data = process_content_message entry.css('content').text

            body = []
            body.push data[:files]
            body.push "#{entry.css('author > name').text.upcase}: #{data[:message].gsub(/\n/, " | ")}"
            body.push entry.css('updated').text.to_time

            {
                id:        entry_id,
                title:     "GitHub: #{feed_title}",
                body:      body.compact.join("\n----\n"),
                icon_path: File.realpath("#{Dir.pwd}/assets/github.png"),
                object:    entry
            }
          end
        end

        # Return the processed response, removing nil entries.
        final_response.compact

      elsif response and response.is_a? Exception
        response
      else
        []
      end
    end

    # Processes the embedded HTML in the <content> tag and return
    # correct values as a Hash
    # @param message [String]
    # @return [Hash]
    def process_content_message message

      xml = Nokogiri.XML("<xml>" + message.strip + "</xml>")

      {
          :files   => xml.css('pre').first.text.strip,
          :message => xml.css('pre').last.text.strip,
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
      raise ArgumentError, "URL must be a GitHub URL" unless URI.parse(@url).host === "github.com"

    end

  end
end
