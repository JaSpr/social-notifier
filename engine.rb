#!/usr/bin/ruby
require 'etc'
require 'net/http'

module SocialNotifier
  class Engine

    # Initialize
    #
    # @return [Void]
    #
    def initialize(method, params, debug)

      @debug = debug

      if method
        params = [] unless params
      else
        method = :add
        params = [:home]
      end

      init_data_storage

      $DEBUG = true

      $stderr.reopen(debug_log_file, "a")
      $stderr.sync = true

      if method === :start
        pid = fork do
          Signal.trap('HUP', 'IGNORE')
          init_master
          sleep
        end
      else
        init_child method, params
      end

    end

    #
    # Initialization for the master process
    #
    # @param method [Symbol]
    # @param params [Array<String>]
    # @return [Void]
    #
    def init_master

      $stdout.reopen(application_log_file, "a")
      $stdout.sync = true

      @messenger = load_messenger true
      @notifier  = load_notifier

      log ""
      log "****************************"
      log "Starting Social Notifier..."
      log "****************************"
      log ""

      @statuses        = []
      @requests        = {}
      @past_status_ids = []

      @notifier.send(
          "Social Notifier",
          "Starting Social Notifier",
          :timeout => 2
      )

      Signal.trap("TERM") {unload}
      Signal.trap("KILL") {unload}
      Signal.trap("SIGINT") {unload}

      start

    end


    # Dynamically loads the messenger object
    #
    # @param whether or not this is the messaging server
    # @raise [ArgumentError]
    # @return [SocialNotifier::Messenger::[Mixed]]
    #
    def load_messenger(is_master=false)
      messenger_service = $app_config[:messenger_class].downcase
      file_path = "#{Dir.pwd}/lib/messenger/#{messenger_service}.rb"

      raise ArgumentError, "Invalid messenger type #{messenger_service}" unless File.file? file_path
      require(File.realpath(file_path))

      class_name = messenger_service.split(/[^\w]/).map { |word| word.capitalize }.join
      SocialNotifier::Messenger.const_get(class_name).new self, is_master
    end

    # Dynamically loads the notifier object
    #
    # @raise [ArgumentError]
    # @return [SocialNotifier::Messenger::[Mixed]]
    #
    def load_notifier
      notifier_service = $app_config[:notifier_class].downcase
      file_path = "#{Dir.pwd}/lib/notifier/#{notifier_service}.rb"

      raise ArgumentError, "Invalid notifier type #{notifier_service}" unless File.file? file_path
      require(File.realpath(file_path))

      class_name = notifier_service.split(/[^\w]/).map { |word| word.capitalize }.join
      SocialNotifier::Notifier.const_get(class_name).new
    end

    #
    # Initialization for subsidiary processes
    #
    # @param method [Symbol]
    # @param params [Array<String>]
    # @return [Void]
    #
    def init_child(method, params)

      @messenger = load_messenger

      params.unshift method

      response = @messenger.send_message(params)

      puts response

    end

    #
    # Begin the listener thread
    #
    # @return [Void]
    #
    def start

      # Thread to show statuses
      Thread.new do
        while true

          while @statuses.length > 0
            status = @statuses.pop

            # skip showing this status if it has already been viewed.
            next if @past_status_ids.member? status[:id]


            @notifier.send(
                status[:title],
                status[:body],
                :icon_path => status[:icon_path],
                :timeout   => 5
            )

            # store statuses id as viewed
            @past_status_ids.push status[:id]

            # drop the oldest stored status id after 100 stored IDs
            @past_status_ids.shift if @past_status_ids.length > 100

            log "#{status[:title]}: #{status[:body]}"
            sleep 2
          end
          sleep 2

        end
      end

    end

    #
    # Start a new thread to periodically receive a certain type of requests.
    # @param type [Symbol]
    # @raise [ArgumentError]
    # @return [Void]
    #
    def start_request_thread(type)
      raise ArgumentError, "type must be a symbol" unless type.is_a? Symbol

      begin
        Thread.new do
          while true

            # loop through requests
            @requests[type].each do |request|

              # if request has been deleted, skip with no wait
              next unless request

              response = request.send

              if response.is_a? Exception
                log "#{request.type}: API Exception: #{response.class}: #{response.message}"
              elsif response.is_a? Array and response.first
                log "Retrieved #{response.length} new #{request.type} update(s)."
                @statuses = response + @statuses
              end

              sleep 15
            end
            sleep 15
          end
        end
      rescue => exc
        log exc.message
      end
    end

    #
    # Return a list of valid request methods
    # @return [Array<Symbol>]
    #
    def valid_notifier_methods
      [:add, :delete, :list, :start, :stop]
    end

    #
    # Processes command line input
    #
    # @param method [symbol]
    # @param params [Array<String>]
    # @raise [ArgumentError]
    # @return [String]
    #
    def process_input(method, params)

      raise ArgumentError, "Invalid notifier method called: '#{method.inspect}'." unless valid_notifier_methods.member? method

      case method
        when :add
          request_service = params.shift.downcase
          request_params = {
              method: params.shift,
              params: params
          }

          unless @requests[request_service.to_sym] and @requests[request_service.to_sym].is_a? Array
            @requests[request_service.to_sym] = []
            start_request_thread request_service.to_sym
          end

          file_path = "#{Dir.pwd}/lib/request/#{request_service}.rb"

          raise ArgumentError, "Invalid request type #{request_service}" unless File.file? file_path

          require(File.realpath(file_path))

          class_name = request_service.split(/[^\w]/).map { |word| word.capitalize }.join

          request = SocialNotifier::Request.const_get(class_name).new self, request_params

          @requests[request_service.to_sym].push request

        when :delete
           if params.first
             request_group, request_index = params.first.split(':')
             if @requests[request_group.to_sym] and @requests[request_group.to_sym][request_index.to_i]
               @requests[request_group.to_sym][request_index.to_i] = nil
             end
           end

        when :stop
          Thread.new do
            log "Shutting down..."
            sleep 0.5
            @messenger.unload
            unload
            exit
          end

        else

      end

      response = ""
      @requests.each do |type, group|
        group.each_with_index do |request, index|
          if request
            response += "[#{type}:#{index}] #{request.inspect}\n"
          end
        end
      end

      response
    end

    #
    # Logs a message to the application log and the cli output
    #
    # @param message [String] Message to be logged
    # @return [Void]
    #
    def log(message)
      log_message = "[#{Time.parse(Time.now.to_s)}]: " + message + "\n"

      puts log_message if @debug

      File.open(application_log_file, 'a') {|f| f.write(log_message)}
    end

    #
    # Returns the path to the Log File
    #
    # @return [String]
    # @raise [ArgumentError]
    #
    def response_file
      data_dir + "/responses"
    end

    #
    # Returns the path to the Log File
    #
    # @return [String]
    # @raise [ArgumentError]
    #
    def request_file
      data_dir + "/requests"
    end

    #
    # Returns the data directory
    # @return [String]
    #
    def data_dir
      raise ArgumentError, "Data directory is not set" unless @data_dir
      @data_dir
    end

    private

    #
    # Initialize data storage directories and related instance variables
    #
    # @return [Void]
    #
    def init_data_storage
      @data_dir = Etc.getpwuid.dir + "/.social-notifier"

      Dir::mkdir @data_dir unless FileTest::directory? @data_dir
      Dir::mkdir log_dir   unless FileTest::directory? log_dir or not FileTest::directory? @data_dir
    end


    #
    # Returns the path to the Log Directory
    #
    # @return [String]
    # @raise [ArgumentError]
    #
    def log_dir
      data_dir + "/log"
    end

    #
    # Returns the path to the application log file
    #
    # @return [String]
    # @raise [ArgumentError]
    #
    def application_log_file
      log_dir + "/activity.log"
    end

    #
    # Returns the path to the debug log file
    #
    # @return [String]
    # @raise [ArgumentError]
    #
    def debug_log_file
      log_dir + "/debug.log"
    end

    #
    # Shutdown functionality
    #
    # @return [Void]
    #
    def unload
      log ""
      log "****************************"
      log "STOPPING Social Notifier..."
      log "****************************"
      log ""
      exit
    end

  end

end
