#!/usr/bin/env ruby

require 'socket'
require_relative '../../lib/protocol/http1/connection'
require 'protocol/http/body/buffered'

# Test with: curl http://localhost:8080/

Addrinfo.tcp("0.0.0.0", 8080).listen do |server|
	loop do
		client, address = server.accept
		connection = Protocol::HTTP1::Connection.new(client)
		
		# Read request:
		headers, method, path, version, headers, body = connection.read_request
		
		# Write response:
		connection.write_response(version, 200, [["Content-Type", "text/plain"]])
		connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(["Hello World"]))
	end
end
