module Spool
  class Spawner

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    def spawn
      base_file = File.join Dir.tmpdir, SecureRandom.uuid
      out_file = "#{base_file}.out"
      command = configuration.command.strip

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
      File.delete out_file if File.exist? out_file
    end

    def self.spawn(configuration)
      new(configuration).spawn
    end

  end
end