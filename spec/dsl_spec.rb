require 'minitest_helper'

describe Spool::DSL do

  MockProcess = Struct.new :memory
  
  it 'Configure from block' do
    config = Spool::DSL.configure do
      name 'Process pool'
      processes 10
      env VAR_1: 1, VAR_2: 2
      dir '/tmp'
      command 'tailf file.log'
      pid_file '/tailf.pid'
      restart_when { |p| p.memory > 512 }
      stop_signal :TERM
      kill_signal :INT
      log_file 'test.log'
      log_level :INFO
      log_formatter { |s,d,p,m| "#{s},#{d},#{p},#{m}" }
    end

    assert_configuration config
    config.source_file.must_equal nil
  end

  it 'Configure from file' do
    config_file = File.expand_path('../sample_config.rb', __FILE__)
    config = Spool::DSL.configure config_file
    assert_configuration config
    config.source_file.must_equal config_file
  end

  def assert_configuration(config)
    config.name.must_equal 'Process pool'
    config.processes.must_equal 10
    config.env.must_equal VAR_1: 1, VAR_2: 2
    config.dir.must_equal '/tmp'
    config.command.must_equal 'tailf file.log'
    config.restart_condition.call(MockProcess.new(600)).must_equal true
    config.restart_condition.call(MockProcess.new(100)).must_equal false
    config.stop_signal.must_equal :TERM
    config.kill_signal.must_equal :INT
    config.log_file.must_equal 'test.log'
    config.log_level.must_equal 'INFO'
    config.log_formatter.call('1','2','3','4').must_equal '1,2,3,4'
  end

end