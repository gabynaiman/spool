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

    def pidfile(pidfile)
      configuration.pidfile = pidfile
    end

    def restart_when(&block)
      configuration.restart_condition = block
    end

  end
end