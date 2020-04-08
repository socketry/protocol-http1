
require_relative 'lib/protocol/http1/version'

Gem::Specification.new do |spec|
	spec.name          = "protocol-http1"
	spec.version       = Protocol::HTTP1::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	
	spec.summary       = "A low level implementation of the HTTP/1 protocol."
	spec.homepage      = "https://github.com/socketry/protocol-http1"
	spec.license       = "MIT"
	
	spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
		`git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
	end
	
	spec.required_ruby_version = "~> 2.4"
	
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.require_paths = ["lib"]
	
	spec.add_dependency "protocol-http", "~> 0.18"
	
	spec.add_development_dependency "covered"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "bake-bundler"
	spec.add_development_dependency "rspec", "~> 3.0"
	spec.add_development_dependency "rspec-memory", "~> 1.0"
	spec.add_development_dependency "rspec-files", "~> 1.0"
end
