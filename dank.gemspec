# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dank/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mike Kendall"]
  gem.email         = ["kendall@okcupidlabs.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "dank"
  gem.require_paths = ["lib"]
  gem.version       = Dank::VERSION

  gem.add_dependency 'redis'

  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'ruby-prof'
end
