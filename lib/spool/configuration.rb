module Spool
  class Configuration
  
    attr_accessor :name,
                  :processes, 
                  :env,
                  :dir, 
                  :command, 
                  :pid_file, 
                  :restart_condition,
                  :source_file,
                  :stop_signal, 
                  :kill_signal,
                  :log_file,
                  :log_level,
                  :log_formatter
                  
    def name
      @name ||= 'SPOOL'
    end

    def env
      @env ||= {}
    end

    def dir
      @dir ||= source_file ? File.dirname(source_file) : Dir.pwd
    end

    def pid_file
      @pid_file ||= File.join(dir, (source_file ? "#{File.basename(source_file, '.*')}.pid" : 'pool.pid'))
    end

    def restart_condition
      @restart_condition ||= Proc.new do |p|
        false
      end
    end

    def stop_signal
      @stop_signal ||= :QUIT
    end

    def kill_signal
      @kill_signal ||= :KILL
    end

    def log_file
      @log_file ||= '/dev/null'
    end

    def log_formatter
      @log_formatter ||= Proc.new do |s,d,p,m|
        "#{d} - #{name} - #{s.to_s.ljust(5,' ')} - #{p.to_s.upcase} ##{::Process.pid} - #{m}\n"
      end
    end

    def log_level
      @log_level ||= 'INFO'
    end

    def logger
      @logger ||= MonoLogger.new(log_file).tap do |logger|
        logger.level = MonoLogger.const_get log_level
        logger.formatter = log_formatter
      end
    end

  end
end