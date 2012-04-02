module SocialNotifier
  module Notifier
    class Base

     def send(message_title, message_body, options={})
       puts "#{message_title}: #{message_body}: #{options.inspect}"
     end

    end
  end
end
