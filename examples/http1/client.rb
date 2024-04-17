#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)

require 'async'
require 'async/io/stream'
require 'async/http/endpoint'
require 'protocol/http1/connection'

# class IO
# 	def readable?
# 		if self.wait_readable(0).nil?
# 			# timeout means it is not eof
# 			return true
# 		else
# 			!self.eof?
# 		end
# 	rescue Errno::EPIPE, Errno::ECONNRESET
# 		false
# 	end
# end

class IO
	def readable?
		!self.closed?
	end
end

class BasicSocket
	# Is it likely that the socket is still connected?
	# May return false positive, but won't return false negative.
	def readable?
		return false unless super
		
		# If we can wait for the socket to become readable, we know that the socket may still be open.
		result = self.recv_nonblock(1, Socket::MSG_PEEK, exception: false)
		
		# No data was available - newer Ruby can return nil instead of empty string:
		return false if result.nil?
		
		# Either there was some data available, or we can wait to see if there is data avaialble.
		return !result.empty? || result == :wait_readable
		
	rescue Errno::ECONNRESET
		# This might be thrown by recv_nonblock.
		return false
	end
end

def connect(endpoint)
	peer = endpoint.connect.to_io
	
	puts "Connected to #{peer} #{peer.remote_address.inspect}"
	
	return Protocol::HTTP1::Connection.new(peer)
end

Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:8080")
	
	client = connect(endpoint)
	
	10.times do
		puts "Writing request..."
		# How do we know here whether the client is still good?
		unless client.stream.readable?
			puts "Client is not readable, closing..."
			client.close
			
			puts "Reconnecting..."
			client = connect(endpoint)
		end
		
		client.write_request("localhost", "GET", "/", "HTTP/1.1", [["Accept", "*/*"]])
		client.write_body("HTTP/1.1", nil)
	
		puts "Reading response..."
		response = client.read_response("GET")
		version, status, reason, headers, body = response
		
		puts "Got response: #{response.inspect}"
		puts body&.read
	rescue Errno::ECONNRESET, Errno::EPIPE, EOFError
		puts "Connection reset by peer."
		
		# Reconnect and try again:
		client = connect(endpoint)
	end
	
	puts "Closing client..."
	client.close
end

puts "Exiting."
