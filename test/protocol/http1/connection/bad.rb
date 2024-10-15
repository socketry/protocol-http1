# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "protocol/http1/connection"
require "connection_context"

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	before do
		# We use a thread here, as writing to the stream may block, e.g. if the input is big enough.
		@writer = Thread.new do
			client.stream.write(input)
			client.stream.close
		end
	end
	
	after do
		@writer.join
	end
	
	with "invalid hexadecimal content-length" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			Content-Length: 0x10
			Connection: close
			
			0123456789abcdef
			HTTP
		end
		
		it "should fail to parse the request body" do
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::BadRequest)
		end
	end
	
	with "invalid +integer content-length" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			Content-Length: +16
			Connection: close
			
			0123456789abcdef
			HTTP
		end
		
		it "should fail to parse the request body" do
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::BadRequest)
		end
	end
	
	with "invalid -integer content-length" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			Content-Length: -16
			Connection: close
			
			0123456789abcdef
			HTTP
		end
		
		it "should fail to parse the request body" do
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::BadRequest)
		end
	end
	
	with "invalid hexidecimal chunk size" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			Transfer-Encoding: chunked
			Connection: close
			
			0x10
			0123456789abcdef
			0
			HTTP
		end
		
		it "should fail to parse the request body" do
			authority, method, target, version, headers, body = server.read_request
			
			expect(body).to be_a(Protocol::HTTP1::Body::Chunked)
			
			expect do
				body.read
			end.to raise_exception(Protocol::HTTP1::BadRequest)
		end
	end
	
	with "invalid +integer chunk size" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			Transfer-Encoding: chunked
			Connection: close
			
			+10
			0123456789abcdef
			0
			HTTP
		end
		
		it "should fail to parse the request body" do
			authority, method, target, version, headers, body = server.read_request
			
			expect(body).to be_a(Protocol::HTTP1::Body::Chunked)
			
			expect do
				body.read
			end.to raise_exception(Protocol::HTTP1::BadRequest)
		end
	end
	
	with "line length exceeding the limit" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			Connection: close
			Long-Header: #{'a' * 8192}
			
			HTTP
		end
		
		it "should fail to parse the request" do
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::LineLengthError)
		end
	end
	
	with "incomplete headers" do
		def input
			<<~HTTP.gsub("\n", "\r\n")
			POST / HTTP/1.1
			Host: a.com
			HTTP
		end
		
		it "should fail to parse the request" do
			expect do
				server.read_request
			end.to raise_exception(EOFError)
		end
	end
end
