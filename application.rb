#!/usr/bin/ruby

# set the present working directory
Dir.chdir File.dirname File.expand_path __FILE__

require_relative 'engine'
require_relative 'config'

# require any request classes you'd like to use
require_relative 'lib/request/twitter'
require_relative 'lib/request/facebook'
require_relative 'lib/request/gmail'
require_relative 'lib/request/google-voice'
require_relative 'lib/request/svn'
require_relative 'lib/request/github'


# require the messenger class you'd like to use
require_relative 'lib/messenger/tcp'
# require the notifier class you'd like to use
require_relative 'lib/notifier/libnotify'

notifier_method = ARGV.first ? ARGV.shift.to_sym : nil
params = ARGV
debug  = false

SocialNotifier::Engine.new(notifier_method, params, debug)

#sleep

