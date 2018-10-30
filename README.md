# Spool

[![Gem Version](https://badge.fury.io/rb/spool.svg)](https://rubygems.org/gems/spool)
[![Build Status](https://travis-ci.org/gabynaiman/spool.svg?branch=master)](https://travis-ci.org/gabynaiman/spool)
[![Coverage Status](https://coveralls.io/repos/gabynaiman/spool/badge.svg?branch=master)](https://coveralls.io/r/gabynaiman/spool?branch=master)
[![Code Climate](https://codeclimate.com/github/gabynaiman/spool.svg)](https://codeclimate.com/github/gabynaiman/spool)
[![Dependency Status](https://gemnasium.com/gabynaiman/spool.svg)](https://gemnasium.com/gabynaiman/spool)

Manage and keep alive pool of processes

## Installation

Add this line to your application's Gemfile:

    gem 'spool'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install spool

## Usage

#### Setup

*Worker*

    loop do
      puts "#{Process.pid} - #{Time.now}"
      sleep 1
    end

*Pool config*

    processes 4
    command 'ruby worker.rb'
    # optional
    dir File.dirname(__FILE__)
    env VAR1: 'foo', VAR2: 'bar'
    pidfile 'pool.pid'
    restart_when { |p| p.memory > 512 }

#### Start

    console:~$ spool pool_config.rb

#### Signals

- **INT/TERM:** quick shutdown, kills all processes immediately
- **QUIT:** graceful shutdown, waits for processes to finish
- **HUP:** reloads config file and gracefully restart all processes
- **USR2:** gracefully restart all processes with current configuration
- **TTIN:** increment the number of processes by one
- **TTOU:** decrement the number of processes by one

## Contributing

1. Fork it ( https://github.com/gabynaiman/spool/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
