#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)

require "async"
require "async/http/endpoint"
require "protocol/http1/connection"

Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:8080")
	
	peer = endpoint.connect
	
	puts "Connected to #{peer} #{peer.remote_address.inspect}"
	
	# IO Buffering...
	client = Protocol::HTTP1::Connection.new(peer)
	
	puts "Writing request..."
	3.times do
		client.write_request("localhost", "GET", "/", "HTTP/1.1", [["Accept", "*/*"]])
		client.write_body("HTTP/1.1", nil)
		
		puts "Reading response..."
		response = client.read_response("GET")
		version, status, reason, headers, body = response
		
		puts "Got response: #{response.inspect}"
		puts body&.read
	end
	
	puts "Closing client..."
	client.close
end

puts "Exiting."
