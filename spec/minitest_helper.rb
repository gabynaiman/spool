require 'coverage_helper'
require 'minitest/autorun'
require 'turn'
require 'spool'
require 'pry-nav'
require 'benchmark'

Turn.config do |c|
  c.format = :pretty
  c.natural = true
  c.ansi = true
end