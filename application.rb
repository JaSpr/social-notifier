#!/usr/bin/ruby

# set the present working directory
Dir.chdir File.dirname File.expand_path __FILE__

require_relative 'engine'
require_relative 'config'

notifier_method = ARGV.first ? ARGV.shift.to_sym : nil
params = ARGV
debug  = false

SocialNotifier::Engine.new(notifier_method, params, debug)

#sleep

