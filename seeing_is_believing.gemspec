# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "seeing_is_believing/version"

Gem::Specification.new do |s|
  s.name        = "seeing_is_believing"
  s.version     = SeeingIsBelieving::VERSION
  s.authors     = ["Josh Cheek"]
  s.email       = ["josh.cheek@gmail.com"]
  s.homepage    = "https://github.com/JoshCheek/seeing_is_believing"
  s.summary     = %q{Records results of every line of code in your file}
  s.description = %q{Records the results of every line of code in your file (intended to be like xmpfilter), inspired by Brett Victor's JavaScript example in his talk "Inventing on Principle"}

  s.rubyforge_project = "seeing_is_believing"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec",    "~> 2.12.0"
  s.add_development_dependency "cucumber", "~> 1.2.1"
end