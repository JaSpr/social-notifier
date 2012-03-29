#!/usr/bin/ruby
require 'etc'
require 'net/http'

module Social_Notifier
  class Engine

    #
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
          init_master method, params
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
    def init_master(method, params)

      $stdout.reopen(application_log_file, "a")
      $stdout.sync = true

      @messenger = Social_Notifier::Messenger.new self, true
      @notifier  = Social_Notifier::Notifier.new

      log ""
      log "****************************"
      log "Starting Social Notifier..."
      log "****************************"
      log ""

      @statuses          = []
      @requests        = []
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

    #
    # Initialization for subsidiary processes
    #
    # @param method [Symbol]
    # @param params [Array<String>]
    # @return [Void]
    #
    def init_child(method, params)

      @messenger = Social_Notifier::Messenger.new self, false

      params.unshift method

      response = @messenger.send_message(params)

      puts response

    end

    #
    # Begin the listener threads
    #
    # @return [Void]
    #
    def start

      # Thread to periodically retrieve statuses
      begin
        Thread.new do
          while true

            # loop through requests
            @requests.each do |request|

              # if request has been deleted, skip with no wait
              next unless request

              response = request.send

              if response.is_a? Exception
                log "API Exception: #{response.class}: #{response.message}"
              elsif response.is_a? Array and response.first
                log "Retrieved #{response.length} new status update(s)."
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
    def process_input method, params

      raise ArgumentError, "Invalid notifier method called: '#{method.inspect}'." unless valid_notifier_methods.member? method

      case method
        when :add
          request_service = params.shift
          request_params = {
              method: params.shift,
              params: params
          }

          @requests.push eval("Social_Notifier::#{request_service.capitalize}Request").new self, request_params
          #@requests.push Social_Notifier::FacebookRequest.new self, request_params

        when :delete
           if params.first and @requests[params.first.to_i]
             @requests[params.first.to_i] = nil
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
      @requests.each_with_index do |value, index|
        if value
          response += "[#{index}] #{value.inspect}\n"
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
