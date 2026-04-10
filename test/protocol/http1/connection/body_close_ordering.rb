# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http1/connection"
require "protocol/http/body/buffered"
require "protocol/http/body/wrapper"

require "connection_context"

# A body wrapper whose close callback reads the client side of the socket to verify
# that the response framing is already complete at close time.
class StreamCheckingBody < Protocol::HTTP::Body::Wrapper
	attr_reader :client_data_at_close
	
	def initialize(body, client_socket)
		super(body)
		@client_socket = client_socket
		@client_data_at_close = nil
	end
	
	def close(error = nil)
		# Non-blocking read of everything available on the client socket right now.
		# If the response was fully flushed before close, all framing bytes are here.
		@client_data_at_close = +""
		
		loop do
			@client_data_at_close << @client_socket.read_nonblock(65536)
		rescue IO::WaitReadable, EOFError
			break
		end
		
		super
	end
end

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	before do
		server.open!
		client.open!
	end
	
	with "#write_body_and_close" do
		it "flushes all data to the stream before closing body" do
			body = StreamCheckingBody.new(
				Protocol::HTTP::Body::Buffered.new(["Hello", " ", "World"]),
				sockets.first,
			)
			
			server.write_body_and_close(body, false)
			
			expect(body.client_data_at_close).not.to be_nil
			expect(body.client_data_at_close).to be(:include?, "Hello")
			expect(body.client_data_at_close).to be(:include?, "World")
		end
	end
	
	with "#write_chunked_body" do
		it "writes terminal chunk before closing body" do
			body = StreamCheckingBody.new(
				Protocol::HTTP::Body::Buffered.new(["Hello", " ", "World"]),
				sockets.first,
			)
			
			server.write_chunked_body(body, false)
			
			expect(body.client_data_at_close).not.to be_nil
			# Terminal chunk should already be on the wire:
			expect(body.client_data_at_close).to be(:include?, "\r\n0\r\n\r\n")
		end
	end
	
	with "#write_fixed_length_body" do
		it "writes all data before closing body" do
			body = StreamCheckingBody.new(
				Protocol::HTTP::Body::Buffered.new(["Hello", " ", "World"]),
				sockets.first,
			)
			
			server.write_fixed_length_body(body, 11, false)
			
			expect(body.client_data_at_close).not.to be_nil
			expect(body.client_data_at_close).to be(:include?, "Hello World")
		end
	end
end
