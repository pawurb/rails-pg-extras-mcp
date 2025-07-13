# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rails_pg_extras_mcp/version"

Gem::Specification.new do |s|
  s.name = "rails-pg-extras-mcp"
  s.version = RailsPgExtrasMcp::VERSION
  s.authors = ["pawurb"]
  s.email = ["contact@pawelurbanek.com"]
  s.summary = %q{ MCP interface for rails-pg-extras }
  s.description = %q{ MCP interface for rails-pg-extras. It enables LLMs to analyze the PostgreSQL metadata and performance metrics. }
  s.homepage = "http://github.com/pawurb/rails-pg-extras-mcp"
  s.files = `git ls-files`.split("\n")
  s.test_files = s.files.grep(%r{^(spec)/})
  s.require_paths = ["lib"]
  s.license = "MIT"
  s.add_dependency "rails-pg-extras", "~> 5.6.12"
  s.add_dependency "rails"
  s.add_dependency "fast-mcp"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rufo"

  if s.respond_to?(:metadata=)
    s.metadata = { "rubygems_mfa_required" => "true" }
  end
end
