module Spool
  class DSL

    def self.configure(filename=nil, &block)
      dsl = new filename, &block
      dsl.configuration
    end
    
    attr_reader :configuration
    
    private

    def initialize(filename=nil, &block)
      @configuration = Configuration.new
      if filename
        configuration.source_file = File.expand_path filename
        instance_eval IO.read(filename), filename
      else
        instance_eval &block
      end
    end

    def name(name)
      configuration.name = name
    end

    def processes(count)
      configuration.processes = count
    end

    def env(env)
      configuration.env = env
    end

    def dir(dir)
      configuration.dir = File.expand_path dir
    end

    def command(command)
      configuration.command = command
    end

    def pid_file(pid_file)
      configuration.pid_file = pid_file
    end

    def restart_when(&block)
      configuration.restart_condition = block
    end

    def stop_signal(signal)
      configuration.stop_signal = signal.to_sym
    end

    def kill_signal(signal)
      configuration.kill_signal = signal.to_sym
    end

    def log_file(filename)
      configuration.log_file = filename
    end

    def log_level(level)
      configuration.log_level = level.to_s.upcase
    end

    def log_formatter(&block)
      configuration.log_formatter = block
    end

  end
end