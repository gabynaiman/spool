module Spool
  class Pool

    CHECK_TIMEOUT = 0.01

    SIGNALS = {
      INT:  :stop!,
      TERM: :stop!,
      QUIT: :stop,
      HUP:  :reload,
      USR2: :restart,
      TTIN: :incr,
      TTOU: :decr
    }

    attr_reader :configuration, :working_processes, :zombie_processes
    
    def initialize(configuration=nil, &block)
      @configuration = configuration || DSL.configure(&block)
      @working_processes = []
      @zombie_processes = Set.new
      @running = false
      @actions_queue = []
    end

    def running?
      @running
    end

    def stopped?
      !running?
    end

    def all_processes
      working_processes + zombie_processes.to_a
    end

    [:incr, :decr, :reload, :restart, :stop, :stop!].each do |method|
      define_method method do |*args|
        actions_queue.push(name: "_#{method}".to_sym, args: args)
        nil
      end
    end

    def start
      @running = true

      handle_signals

      File.write configuration.pid_file, Process.pid if configuration.pid_file

      configuration.processes.times.map do
        working_processes << Spawner.spawn(configuration)
      end

      logger.info(self.class) { "SPOOL START => #{format_processes}" }

      while running?
        begin
          action = actions_queue.pop
          
          if action
            logger.info(self.class) { "Starting action #{action[:name]} with params: [#{action[:args].join(', ')}]" }
            send action[:name], *action[:args] 
          end

          if running?
            check_status
            sleep CHECK_TIMEOUT
          end
        rescue Exception => e
          log_error e
        end
      end

      logger.info(self.class) { "Spool finished successfully!" }
    end

    private

    attr_writer :working_processes, :zombie_processes
    attr_reader :actions_queue

    def handle_signals
      SIGNALS.each do |signal, event|
        Signal.trap(signal) do
          logger.info(self.class) { "Signal #{signal} received. Current state of actions queue is:\n#{format_actions_queue}" }
          send event
        end
      end
    end

    def check_status
      clear_dead_processes

      check_processes_to_restart
      
      if configuration.processes > all_processes_count
        logger.info(self.class) { "Initializing new children. Current State => #{format_processes}" }

        (configuration.processes - all_processes_count).times do
          working_processes << Spawner.spawn(configuration)
        end

        logger.info(self.class) { "Status after new childrens => #{format_processes}" }
      elsif configuration.processes < working_processes.count
        count_to_kill = working_processes.count - configuration.processes
        logger.info(self.class) { "Killing #{count_to_kill} children. Current state => #{format_processes}" }

        stop_processes working_processes.take(count_to_kill)

        logger.info(self.class) { "After killing childers. Current State => #{format_processes}" }
      end
    end

    def _incr(count=1)
      configuration.processes += count
    end

    def _decr(count=1)
      configuration.processes -= count
      configuration.processes = 0 if configuration.processes < 0
    end

    def _reload
      @configuration = DSL.configure configuration.source_file if configuration.source_file
    end

    def _restart
      logger.info(self.class) { "RESTART" }
      stop_processes working_processes
    end

    def _stop
      logger.info(self.class) { "SPOOL STOP" }

      stop_processes working_processes
      wait_for_stopped all_processes

      @running = false
    end

    def _stop!
      logger.info(self.class) { "SPOOL STOP! Going to kill => #{format_processes}" }

      all_processes.each do |p| 
        begin
          send_signal_to(p, configuration.kill_signal) if p.alive?
        rescue Datacenter::Shell::CommandError => e
          log_error e
        end
      end

      wait_for_stopped all_processes

      File.delete configuration.pid_file if File.exist? configuration.pid_file

      @running = false
    end

    def stop_processes(processes_list)
      processes_list.each do |p| 
        begin
          send_signal_to p, configuration.stop_signal
          zombie_processes << p
        rescue Exception => e
          log_error e
        end
      end

      working_processes.delete_if{ |p| zombie_processes.include? p }
    end

    def wait_for_stopped(processes_list)
      while processes_list.any?(&:alive?)
        sleep 0.01
      end

      clear_dead_processes
    end

    def check_processes_to_restart
      to_restart = working_processes.select(&configuration.restart_condition)

      if to_restart.any?
        logger.info(self.class) {"Restart condition successful in child processes: #{to_restart.map(&:pid)}"}
        stop_processes to_restart
      end
    end

    def send_signal_to(process, signal)
      logger.info(self.class) { "Going to send signal #{signal} to process #{process.pid}" }
      process.send_signal signal
    end

    def clear_dead_processes
      working_processes.delete_if { |p| !p.alive? }
      zombie_processes.delete_if { |p| !p.alive? }
    end

    def all_processes_count
      working_processes.count + zombie_processes.count
    end

    def logger
      configuration.logger
    end

    def log_error(error)
      logger.error(self.class) { "#{error.message}\n#{error.backtrace.join("\n")}" }
    end

    def format_actions_queue
      return "EMPTY" if actions_queue.empty?
      
      actions_queue.map.with_index do |action, index| 
        "#{index+1} => #{action[:name]}"
      end.join("\n")
    end

    def format_processes
      "Working Processes: #{working_processes.map(&:pid)}, Zombie Processes: #{zombie_processes.map(&:pid)}"
    end

  end

end
