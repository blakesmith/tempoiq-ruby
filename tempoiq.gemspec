$:.push File.expand_path("../lib", __FILE__)

require "tempoiq/constants"

Gem::Specification.new do |s|
  s.name        = "tempoiq"
  s.version     = TempoIQ::Constants::VERSION
  s.authors     = ["TempoIQ, Inc."]
  s.email       = ["software@tempoiq.com"]
  s.homepage    = "http://tempoiq.com"
  s.summary     = %q{TempoIQ http client}
  s.description = %q{TempoIQ http client}

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "json"
  s.add_runtime_dependency "httpclient"
  s.add_runtime_dependency "httpclient_link_header"
end
