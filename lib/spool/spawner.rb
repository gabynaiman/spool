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

      File.write script_file, %Q{
        #!/usr/bin/env bash
        #{configuration.command.strip} &
        echo $! > #{pid_file}
      }

      ::Process.spawn configuration.env, 
                      "sh #{script_file}", 
                      chdir: configuration.dir, 
                      out: out_file, 
                      err: out_file

      pid = wait_for_pid pid_file

      Datacenter::Process.new(pid).tap do |process|
        raise "Invalid command: #{configuration.command}\n#{IO.read(out_file)}" unless process.alive?
      end

    ensure
      [script_file, out_file, pid_file].each do |filename|
        File.delete filename if File.exists? filename
      end
    end

    def self.spawn(configuration)
      new(configuration).spawn
    end

    private

    def wait_for_pid(pid_file)
      Timeout.timeout(60) do
        until File.exists?(pid_file); end
        IO.read(pid_file).to_i
      end
    rescue Timeout::Error
      nil
    end

  end
end