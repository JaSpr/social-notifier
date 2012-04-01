#! /usr/bin/ruby -wW2d

require 'nokogiri'

module SocialNotifier
  class GoogleVoiceMessageHTML #< SocialNotifier::Request

    def type
      "Google Voice"
    end

    attr_accessor :message_data

    attr_reader :type, :id, :contact, :time, :messages, :message_text

    #
    # Initialize the object
    #
    # @param params [Hash]
    # @return [Void]
    #
    def initialize(type, html)

      @type = type
      @html = html

      @message_data = nil

      process_html

    end

    def process_html
      @id      = @html.attr('id')
      @contact = @html.css('.gc-message-name a').text.strip
      @time    = @html.css('.gc-message-relative').text.strip

      if @type == :sms
        @messages = @html.css('.gc-message-sms-row').map do |sms|
          [
              sms.css('.gc-message-sms-from').text.strip.upcase,
              sms.css('.gc-message-sms-text').text.strip,
              '(' + sms.css('.gc-message-sms-time').text.strip + ') ',
          ].join("  ")
        end

        @message_text = @messages.join("\n----\n")
      elsif type == :vm
        @message_text = "NEW VOICEMAIL: #{@html.css('.gc-edited-trans-text').text.strip}"
      end

    end

  end
end