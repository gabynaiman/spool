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
      @dir ||= Dir.pwd
    end

  end
end