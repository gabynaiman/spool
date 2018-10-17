module Spool
  class Spawner

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    def spawn
      base_file = File.join Dir.tmpdir, SecureRandom.uuid
      pid_file = "#{base_file}.pid"
      out_file = "#{base_file}.out"
      script_file = "#{base_file}.sh"
      command = configuration.command.strip

      File.write script_file, %Q{
        #!/usr/bin/env bash
        #{command} &
        echo $! > #{pid_file}
      }

      pid = Process.spawn configuration.env, 
                          "exec #{command}", 
                          chdir: configuration.dir, 
                          out: out_file, 
                          err: out_file

      Process.detach pid

      Datacenter::Process.new(pid).tap do |process|
        raise "Invalid command: #{command}\n#{IO.read(out_file)}" unless process.alive?
      end

    ensure
      [script_file, out_file, pid_file].each do |filename|
        File.delete filename if File.exist? filename
      end
    end

    def self.spawn(configuration)
      new(configuration).spawn
    end

  end
end