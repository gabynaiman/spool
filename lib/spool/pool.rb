module Spool
  class Pool

    SIGNALS = {
      INT:  :stop!,
      TERM: :stop!,
      QUIT: :stop,
      HUP:  :reload,
      USR2: :restart,
      TTIN: :incr,
      TTOU: :decr
    }

    attr_reader :configuration, :runner, :processes
    
    def initialize(configuration=nil, &block)
      @configuration = configuration || DSL.configure(&block)
      @processes = []
      @started = false
    end

    def started?
      @started
    end

    def stopped?
      !started?
    end

    def start
      @started = true

      handle_signals

      File.write configuration.pid_file, Process.pid if configuration.pid_file

      configuration.processes.times.map do
        processes << Spawner.spawn(configuration)
      end
      logger.info(self.class) { "SPOOL START childrens: #{processes.map(&:pid)}" }

      while @started
        check_status
        sleep 0.05
      end
    end

    def stop(timeout=0)
      logger.info(self.class) { "SPOOL STOP" }
      stop_processes processes
      Timeout.timeout(timeout) { wait_for_stopped processes }
    rescue Timeout::Error
      logger.error(self.class) { "ERROR IN SPOOL STOP. Timeout error" }
    ensure
      stop!
    end

    def stop!
      @started = false
      logger.info(self.class) { "SPOOL STOP! kill this children (#{processes.map(&:pid)})" }
      processes.each { |p| p.send_signal configuration.kill_signal}
      wait_for_stopped processes
      processes.clear
      File.delete configuration.pid_file if File.exists? configuration.pid_file
    end

    def incr(count=1)
      configuration.processes += count
    end

    def decr(count=1)
      configuration.processes -= count
    end

    def reload
      @configuration = DSL.configure configuration.source_file if configuration.source_file
    end

    def restart
      logger.info(self.class) { "RESTART" }
      stop_processes processes
    end

    private

    def handle_signals
      SIGNALS.each do |signal, event|
        Signal.trap(signal) { send event }
      end
    end

    def check_status 
      return if stopped?

      stop_processes processes.select(&configuration.restart_condition)
      processes.delete_if { |p| !p.alive? }

      return if stopped?
      if configuration.processes > processes.count
        logger.info(self.class) { "Initialize new children: #{processes.map(&:pid)}" }

        (configuration.processes - processes.count).times do
          processes << Spawner.spawn(configuration)
        end

        logger.info(self.class) { "new children: #{processes.map(&:pid)}" }
      
      elsif configuration.processes < processes.count
        logger.info(self.class) { "Kill childrens: #{processes.map(&:pid)}" }

        list = processes.take(processes.count - configuration.processes)
        stop_processes list
        wait_for_stopped list
        list.each { |p| processes.delete p }

        logger.info(self.class) { "After kill childrens: #{processes.map(&:pid)}" }
      end

    rescue
      retry
    end

    def stop_processes(processes_list)
      processes_list.each { |p| p.send_signal configuration.stop_signal }
    end

    def wait_for_stopped(processes)
      while processes.any?(&:alive?)
        sleep 0.01
      end
    end

    def logger
      configuration.logger
    end

  end

end