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

      File.write configuration.pidfile, Process.pid if configuration.pidfile

      configuration.processes.times.map do
        processes << Spawner.spawn(configuration)
      end

      while @started
        check_status
        sleep 0.05
      end
    end

    def stop(timeout=0)
      processes.each(&:stop)
      Timeout.timeout(timeout) { wait_for_stopped processes }
    rescue Timeout::Error
    ensure
      stop!
    end

    def stop!
      processes.each(&:kill)
      processes.clear
      File.delete configuration.pidfile if File.exists? configuration.pidfile
      @started = false
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
      processes.each(&:stop)
    end

    private

    def handle_signals
      SIGNALS.each do |signal, event|
        Signal.trap(signal) { send event }
      end
    end

    def check_status 
      return if stopped?

      processes.select(&configuration.restart_condition).each(&:stop) if configuration.restart_condition
      processes.delete_if { |p| !p.alive? }

      if configuration.processes > processes.count
        (configuration.processes - processes.count).times do
          processes << Spawner.spawn(configuration)
        end

      elsif configuration.processes < processes.count
        list = processes.take(processes.count - configuration.processes)
        list.each(&:stop)
        wait_for_stopped list
        list.each { |p| processes.delete p }

      end

    rescue
      retry
    end

    def wait_for_stopped(processes)
      while processes.any?(&:alive?)
        sleep 0.01
      end
    end

  end

end