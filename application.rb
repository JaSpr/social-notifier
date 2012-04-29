#!/usr/bin/ruby

require 'etc'

# set the application path and data path
APPLICATION_PATH = File.dirname File.expand_path __FILE__
DATA_PATH        = Etc.getpwuid.dir + "/.social-notifier"

require_relative 'engine'
require_relative 'config'

notifier_method = ARGV.first ? ARGV.shift.to_sym : nil
params = ARGV
debug  = false

SocialNotifier::Engine.new(notifier_method, params, debug)

#sleep

