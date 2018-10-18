# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spool/version'

Gem::Specification.new do |spec|
  spec.name          = 'spool'
  spec.version       = Spool::VERSION
  spec.authors       = ['Gabriel Naiman']
  spec.email         = ['gnaiman@keepcon.com']
  spec.summary       = 'Manage and keep alive pool of processes'
  spec.description   = ''
  spec.homepage      = 'https://github.com/gabynaiman/spool'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'datacenter', '~> 0.4', '>= 0.4.4'
  spec.add_dependency 'mono_logger'

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 11.0'
  spec.add_development_dependency 'minitest', '~> 5.0', '< 5.11'
  spec.add_development_dependency 'minitest-colorin', '~> 0.1'
  spec.add_development_dependency 'minitest-line', '~> 0.6'
  spec.add_development_dependency 'simplecov', '~> 0.12'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'pry-nav', '~> 0.2'
end
