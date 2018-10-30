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

    attr_reader :configuration, :processes
    
    def initialize(configuration=nil, &block)
      @configuration = configuration || DSL.configure(&block)
      @processes = []
      @running = false
      @actions_queue = []
    end

    def running?
      @running
    end

    def stopped?
      !running?
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
        processes << Spawner.spawn(configuration)
      end

      logger.info(self.class) { "SPOOL START childrens: #{processes.map(&:pid)}" }

      while running?
        action = actions_queue.pop
        
        if action
          logger.info(self.class) { "Starting action #{action[:name]} with params: [#{action[:args].join(', ')}]" }
          send action[:name], *action[:args] 
        end

        if running?
          check_status
          sleep CHECK_TIMEOUT
        end
      end

      logger.info(self.class) { "Spool finished successfully!" }
    end

    private

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
      processes.delete_if { |p| !p.alive? }
      
      to_restart = processes.select(&configuration.restart_condition)
      logger.info(self.class) {"Restart condition successful in child processes: #{to_restart.map(&:pid)}"} if to_restart.any?
      stop_processes to_restart

      if configuration.processes > processes.count
        logger.info(self.class) { "Initialize new children: #{processes.map(&:pid)}" }

        (configuration.processes - processes.count).times do
          processes << Spawner.spawn(configuration)
        end

        logger.info(self.class) { "New children: #{processes.map(&:pid)}" }
      elsif configuration.processes < processes.count
        logger.info(self.class) { "Kill childrens: #{processes.map(&:pid)}" }

        list = processes.take(processes.count - configuration.processes)
        stop_processes list
        wait_for_stopped list
        list.each { |p| processes.delete p }

        logger.info(self.class) { "After kill childrens: #{processes.map(&:pid)}" }
      end

    rescue Exception => e
      log_error e
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
      stop_processes processes
    end

    def _stop(timeout=0)
      logger.info(self.class) { "SPOOL STOP" }

      stop_processes processes
      Timeout.timeout(timeout) { wait_for_stopped processes }
    rescue Timeout::Error
      logger.error(self.class) { "ERROR IN SPOOL STOP. Timeout error" }
    ensure
      _stop! 
      @running = false
    end

    def _stop!
      logger.info(self.class) { "SPOOL STOP! kill this children (#{processes.map(&:pid)})" }

      processes.each do |p| 
        begin
          p.send_signal(configuration.kill_signal) if p.alive?
        rescue Datacenter::Shell::CommandError => e
          if p.alive?
            log_error e
          else
            logger.info(self.class) { "Signal KILL was sent to #{p.pid} but process was already dead" }
          end
        end
      end

      wait_for_stopped processes
      
      processes.clear
      
      File.delete configuration.pid_file if File.exist? configuration.pid_file
      @running = false
    end

    def stop_processes(processes_list)
      processes_list.each do |p| 
        begin
          logger.info(self.class) {"Going to kill process #{p.pid}, alive? => #{p.alive?}"}
          p.send_signal configuration.stop_signal
        rescue Exception => e
          log_error e
        end
      end
    end

    def wait_for_stopped(processes)
      while processes.any?(&:alive?)
        sleep 0.01
      end
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
        "#{index+1} => #{a[:name]}"
      end.join("\n")
    end

  end

end