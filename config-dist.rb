$app_config = {
    :messenger_class => 'Tcp',
    :notifier_class  => 'Libnotify',
}
#
# Configuration settings for Twitter API
#
# Go to https://dev.twitter.com/apps/new, login, create a new application.  Consumer
# Key and Consumer Secret will be available on the first page.
#
# Click "Create my access token" button near bottom of page, page will refresh and
# give oAuth Token and oAuth Token Secret on the same part of the page as the bottom,
# near the bottom.
#
# Copy the consumer and authorization keys and secrets and put them here.  Rename file
# as config.rb
#
# UNCOMMENT BELOW TO USE TWITTER

#require 'twitter'
#Twitter.configure do |config|
#  config.consumer_key = ''
#  config.consumer_secret = ''
#  config.oauth_token = ''
#  config.oauth_token_secret = ''
#end

#
# Configuration for Facebook API
#
# Go to developers.facebook.com/apps, make sure you're approved as an FB developer.  Create app,
# figure out how to authorize yourself on that app and give yourself offline access, then get that
# access token and uncomment and paste below
#
# UNCOMMENT BELOW TO USE FACEBOOK
#

#require 'fb_graph'
#$app_config = {
#    facebook: {
#                  access_token: ''
#              }
#}