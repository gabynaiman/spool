require 'minitest_helper'

describe Spool::DSL do

  MockProcess = Struct.new :memory
  
  it 'Configure from block' do
    config = Spool::DSL.configure do
      processes 10
      env VAR_1: 1, VAR_2: 2
      dir '/tmp'
      command 'tailf file.log'
      pidfile '/tailf.pid'
      restart_when { |p| p.memory > 512 }
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
    config.processes.must_equal 10
    config.env.must_equal VAR_1: 1, VAR_2: 2
    config.dir.must_equal '/tmp'
    config.command.must_equal 'tailf file.log'
    config.restart_condition.call(MockProcess.new(600)).must_equal true
    config.restart_condition.call(MockProcess.new(100)).must_equal false
  end

end