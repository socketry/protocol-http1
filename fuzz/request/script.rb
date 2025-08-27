#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require "socket"
require_relative "../../lib/protocol/http1"

def test
	# input, output = Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)
	
	server = Protocol::HTTP1::Connection.new($stdin)
	
	# input.write($stdin.read)
	# input.close
	
	begin
		host, method, path, version, headers, body = server.read_request
		
		body = server.read_request_body(method, headers)
	rescue Protocol::HTTP1::InvalidRequest
		# Ignore.
	end
end

if ENV["_"] =~ /afl/
	require "kisaten"
	Kisaten.crash_at [], [], Signal.list["USR1"]
	
	while Kisaten.loop 10000
		test
	end
else
	test
end
