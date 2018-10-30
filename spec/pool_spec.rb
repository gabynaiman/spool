require 'minitest_helper'

describe Spool::Pool do

  SLEEP_TIME = 0.01

  after do
    @pool.stop! if @pool
    machine = Datacenter::Machine.new
    begin
      machine.processes('ruby -e').each {|p| p.send_signal :KILL}
    rescue
      # All processes dead. I hope
    end
  end

  def start_pool(&block)
    @pool = Spool::Pool.new(&block).tap do |pool|
      t = Thread.new { pool.start }
      t.abort_on_exception = true
      while pool.processes.count < pool.configuration.processes
        sleep 0.01
      end
    end
  end

  def assert_with_timeout(timeout, &block)
    Timeout.timeout(timeout) do
      until block.call
        sleep 0.01
      end
    end
  end

  it 'Start and stop' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
      stop_signal :TERM
    end

    pool.must_be :running?
    pool.processes.count.must_equal 1
    pool.processes[0].must_be :alive?

    process = pool.processes[0]
    pool.stop

    while pool.running?
      sleep SLEEP_TIME
    end 

    pool.must_be :stopped?
    pool.processes.must_be_empty
    process.wont_be :alive?
  end

  it 'Start and force stop' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
    end

    pool.must_be :running?
    pool.processes.count.must_equal 1
    pool.processes[0].must_be :alive?

    process = pool.processes[0]

    pool.stop!

    while pool.running?
      sleep SLEEP_TIME
    end 

    pool.must_be :stopped?
    pool.processes.must_be_empty
    process.wont_be :alive?
  end

  it 'Recover killed process' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
    end

    original_process = pool.processes[0]
    original_process.send_signal :KILL

    begin
      sleep SLEEP_TIME
      new_pid = pool.processes.any? ? pool.processes[0].pid : original_process.pid
    end while original_process.pid == new_pid
    
    original_process.wont_be :alive?

    pool.processes.count.must_equal 1
    pool.processes[0].must_be :alive?
  end

  it 'Restart processes' do
    pool = start_pool do
      processes 2
      command 'ruby -e "loop do; sleep 1; end"'
      stop_signal :TERM
    end

    pool.processes.count.must_equal 2

    original_pids = pool.processes.map(&:pid)
    
    pool.restart
    
    begin
      sleep SLEEP_TIME
      new_pids = (pool.processes.count == 2) ? pool.processes.map(&:pid) : original_pids
    end until (original_pids & new_pids).empty?

    pool.processes.each { |p| p.must_be :alive?}
  end

  it 'Stop with timeout' do
    pool = start_pool do
      processes 1
      command 'ruby -e "Signal.trap(:QUIT) { puts :quit; sleep 5; exit 0 }; loop { sleep 1 }"'
      stop_signal :QUIT
    end

    process = pool.processes[0]

    Benchmark.realtime do 
      pool.stop 0.1
      while pool.running?
        sleep SLEEP_TIME
      end 
    end.must_be :<, 1

    pool.must_be :stopped?
    pool.processes.must_be_empty    
    process.wont_be :alive?
  end

  it 'Increase processes' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
    end

    pool.processes.count.must_equal 1

    pool.incr 2

    assert_with_timeout(1) { pool.processes.count == 3 }
  end

  it 'Decrease processes' do
    pool = start_pool do
      processes 3
      command 'ruby -e "loop do; sleep 1; end"'
      stop_signal :TERM
    end

    pool.processes.count.must_equal 3

    pool.decr 2

    assert_with_timeout(1) { pool.processes.count == 1 }
  end

  it 'Change process when satisfied stop condition' do
    file_name = File.expand_path 'used_memory.log'
    ruby_command = %Q{
      require 'datacenter'
      Signal.trap(:TERM) do
        File.write('#{file_name}', 'Finished')
        exit 0 
      end 
      a = 50_000_000.times.to_a
      loop do 
      end
    }

    pool = start_pool do
      processes 1
      command "ruby -e \"#{ruby_command}\""
      restart_when { |p| p.memory > 300 }
      stop_signal :TERM
    end

    original_process = pool.processes[0]

    begin
      sleep SLEEP_TIME
      new_pid = pool.processes.any? ? pool.processes[0].pid : original_process.pid
    end while original_process.pid == new_pid

    text_file = File.read(file_name)
    File.delete(file_name) 

    text_file.must_equal 'Finished'
    pool.processes.count.must_equal 1
  end

  it 'Reload config' do
    config_file = File.expand_path('../loop_pool_config.rb', __FILE__)
    config = Spool::DSL.configure config_file

    pool = Spool::Pool.new(config).tap do |pool|
      t = Thread.new { pool.start }
      t.abort_on_exception = true
      while pool.processes.count < pool.configuration.processes
      end
    end

    pool.processes.count.must_equal 1

    pool.incr 1

    assert_with_timeout(1) { pool.processes.count == 2 }
    
    pool.reload

    assert_with_timeout(1) { pool.processes.count == 1 }

    pool.stop!
  end

end