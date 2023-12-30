#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)

require 'socket'
require 'protocol/http1/connection'
require 'protocol/http/body/buffered'

# Test with: curl http://localhost:8080/

Addrinfo.tcp("0.0.0.0", 8080).listen do |server|
	loop do
		client, address = server.accept
		connection = Protocol::HTTP1::Connection.new(client)
		
		# Read request:
		while request = connection.read_request
			headers, method, path, version, headers, body = request
			
			# Write response:
			connection.write_response(version, 200, [["Content-Type", "text/plain"]])
			connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(["Hello World"]))
			
			break unless connection.persistent
		end
	end
end
