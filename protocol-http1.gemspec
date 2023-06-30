# frozen_string_literal: true

require_relative "lib/protocol/http1/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-http1"
	spec.version = Protocol::HTTP1::VERSION
	
	spec.summary = "A low level implementation of the HTTP/1 protocol."
	spec.authors = ["Samuel Williams", "Brian Morearty", "Bruno Sutic", "Olle Jonsson"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/protocol-http1"
	
	spec.files = Dir.glob(['{lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.7.6b"
	
	spec.add_dependency "protocol-http", "~> 0.22"
end
