require 'libnotify'

require_relative 'base'

module SocialNotifier
  module Notifier
    class Libnotify < SocialNotifier::Notifier::Base

      # Sends a notification to libnotify
      # @param message_title [String] Message title to send to libnotify
      # @param message_body  [String] Message body to send to libnotify
      # @param options       [Hash]   Additional (optional) libnotify options
      # @return [Void]
      def send(message_title, message_body, options={})

        notification = {
            :body    => message_body,
            :summary => message_title,
        }.merge(options)

        ::Libnotify.show(notification)

      end

    end
  end
end