$app_config = {}

#
# Configuration settings for Twitter API
#
require 'twitter'
Twitter.configure do |config|
  config.consumer_key = 'hFsJVbvGYVeJdDsLkkRtqQ'
  config.consumer_secret = '6F7s4pTNKQtHn3Ss96RaJH9yw9g7LBtJj99JVSwD5b0'
  config.oauth_token = '16170243-LnabVZfVSImOZQXGxidf17hM3DBlDlrbHApXuO2Ss'
  config.oauth_token_secret = 'ucRJp703HapQBEgZ3rzYpFMpBGjFcsDVCPyhfozrjE'
end

#
# Configuration for Facebook API
#
require 'fb_graph'
$app_config = {
    facebook: {
        access_token: 'AAAFIusHgiVQBAE4XzuI6tRmFxUq682MZCGw8uNaNlkAUOhpdC3KwNZCo2TE9AfZCLFC3imZAdx6Xb1XZB0aZCoxPKEOZB06OCZCzWP6O2diqkgZDZD'
    }
}



