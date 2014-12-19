module Spool
  class Configuration
  
    attr_accessor :processes, 
                  :env,
                  :dir, 
                  :command, 
                  :pidfile, 
                  :restart_condition,
                  :source_file

    def env
      @env ||= {}
    end

    def dir
      @dir ||= source_file ? File.dirname(source_file) : Dir.pwd
    end

    def pidfile
      @pidfile ||= File.join(dir, (source_file ? "#{File.basename(source_file, '.*')}.pid" : 'pool.pid'))
    end

  end
end