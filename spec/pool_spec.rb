require 'minitest_helper'

describe Spool::Pool do

  after do
    @pool.stop! if @pool
    machine = Datacenter::Machine.new
    machine.processes('ruby -e').each {|p| p.send_signal :KILL}
  end

  def start_pool(&block)
    @pool = Spool::Pool.new(&block).tap do |pool|
      t = Thread.new { pool.start }
      t.abort_on_exception = true
      while pool.processes.count < pool.configuration.processes
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

    pool.must_be :started?
    pool.processes.count.must_equal 1
    pool.processes[0].must_be :alive?

    process = pool.processes[0]

    pool.stop

    pool.must_be :stopped?
    pool.processes.must_be_empty
    process.wont_be :alive?
  end

  it 'Start and force stop' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
    end

    pool.must_be :started?
    pool.processes.count.must_equal 1
    pool.processes[0].must_be :alive?

    process = pool.processes[0]

    pool.stop!

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

    original_process.wont_be :alive?

    until pool.processes[0] && pool.processes[0].pid != original_process.pid; end

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

    until pool.processes.count == 2 && pool.processes[0].pid != original_pids[0] && pool.processes[1].pid != original_pids[1]; end

    pool.processes.count.must_equal 2
    pool.processes.each { |p| p.must_be :alive?}
  end

  it 'Stop with timeout' do
    pool = start_pool do
      processes 1
      command 'ruby -e "Signal.trap(:QUIT) { puts :quit; sleep 5; exit 0 }; loop { sleep 1 }"'
      stop_signal :QUIT
    end

    process = pool.processes[0]

    Benchmark.realtime { pool.stop 0.1 }.must_be :<, 1

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
    ruby_command = "require 'datacenter'; Signal.trap(:TERM) { File.write('#{file_name}', Datacenter::Process.new(Process.pid).memory); exit 0 }; a = 50_000_000.times.to_a; loop do; end"

    pool = start_pool do
      processes 1
      command "ruby -e \"#{ruby_command}\""
      restart_when { |p| p.memory > 300 }
      stop_signal :TERM
    end

    memory = 0
    process = pool.processes[0]
    while !File.exists?(file_name)
      sleep 0.5  
    end

    memory = File.read(file_name).to_i
    File.delete(file_name) 

    memory.must_be :>=, 300
    pool.processes.count.must_equal 1
    pool.processes[0].pid.wont_equal process.pid
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