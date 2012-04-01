#! /usr/bin/ruby -wW2d

require 'nokogiri'

module SocialNotifier
  class GoogleVoiceMessage #< SocialNotifier::Request

    def type
      "Google Voice"
    end

    attr_accessor :message_data

    attr_reader :id, :phoneNumber, :displayNumber, :startTime,
        :displayStartTime, :relativeStartTime, :note, :isRead, :isSpam, :isTrash,
        :star, :messageText, :labels, :type, :children

    #
    # Initialize the object
    #
    # @param params [Hash]
    # @return [Void]
    #
    def initialize(parent, data)

      @parent = parent

      @message_data = nil

      if data and data.is_a? Array
        @id  = data.shift
        @message_data = data.shift
      end

      if @message_data and @message_data.is_a? Enumerable
        @message_data.each do |key, value|
          instance_variable_set("@#{key}".to_sym, value)
        end
      end

    end

  end
end