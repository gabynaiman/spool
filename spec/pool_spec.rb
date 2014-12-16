require 'minitest_helper'

describe Spool::Pool do

  after do
    @pool.stop if @pool
    machine = Datacenter::Machine.new
    machine.processes('ruby -e').each(&:kill)
  end

  def start_pool(&block)
    @pool = Spool::Pool.new(&block).tap do |pool|
      t = Thread.new { pool.start }
      t.abort_on_exception = true
      while pool.processes.count < pool.configuration.processes
      end
    end
  end

  it 'Start and stop' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
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

  it 'Recover killed process' do
    pool = start_pool do
      processes 1
      command 'ruby -e "loop do; sleep 1; end"'
    end

    original_process = pool.processes[0]
    original_process.kill

    original_process.wont_be :alive?

    until pool.processes[0] && pool.processes[0].pid != original_process.pid; end

    pool.processes.count.must_equal 1
    pool.processes[0].must_be :alive?
  end

  it 'Stop with timeout' do
    pool = start_pool do
      processes 1
      command 'ruby -e "Signal.trap(:TERM) { sleep 5; exit 0 }; loop { sleep 1 }"'
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

    pool.processes.count.must_equal 3
  end

  it 'Decrease processes' do
    pool = start_pool do
      processes 3
      command 'ruby -e "loop do; sleep 1; end"'
    end

    pool.processes.count.must_equal 3

    pool.decr 2

    pool.processes.count.must_equal 1
  end

  it 'Change process when satisfied stop condition' do
    pool = start_pool do
      processes 1
      command 'ruby -e "a = 50_000_000.times.to_a; loop do; end"'
      restart_when { |p| p.memory > 300 }
    end

    memory = 0
    process = pool.processes[0]
    while pool.processes.empty? || pool.processes[0].pid == process.pid
      memory = process.memory
    end

    memory.must_be :>, 100
    pool.processes.count.must_equal 1
    pool.processes[0].pid.wont_equal process.pid
  end

end