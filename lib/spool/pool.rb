module Spool
  class Pool

    attr_reader :configuration, :runner, :processes
    
    def initialize(configuration=nil, &block)
      @configuration = configuration || DSL.configure(&block)
      @processes = []
      @started = false
      @mutex = Mutex.new
    end

    def started?
      @started
    end

    def stopped?
      !started?
    end

    def start
      @started = true

      configuration.processes.times.map do
        processes << Spawner.spawn(configuration)
      end

      while @started
        check_status
        sleep 0.05
      end
    end

    def stop(timeout=nil)
      processes.each(&:stop)
      
      if timeout
        kill_on timeout
      else
        wait_for_stopped
      end

      processes.clear
      
      @started = false
    end

    def incr(count=1)
      configuration.processes += count
      check_status
    end

    def decr(count=1)
      configuration.processes -= count
      check_status
    end

    private

    def check_status
      @mutex.synchronize do
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
      end
    end

    def wait_for_stopped(list=nil)
      list ||= processes
      while list.any?(&:alive?)
        sleep 0.01
      end
    end

    def kill_on(timeout)
      Timeout.timeout(timeout) { wait_for_stopped }
    rescue Timeout::Error
      processes.each(&:kill)
    end

  end

end