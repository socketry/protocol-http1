# frozen_string_literal: true

# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'protocol/http1/connection'
require 'protocol/http/body/buffered'

require_relative 'connection_context'

RSpec.describe Protocol::HTTP1::Connection do
	include_context Protocol::HTTP1::Connection
	
	describe '#read_request' do
		it "reads request without body" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n"
			client.stream.close
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(authority).to be == 'localhost'
			expect(method).to be == 'GET'
			expect(target).to be == '/'
			expect(version).to be == 'HTTP/1.1'
			expect(headers).to be == {}
			expect(body).to be_nil
		end
		
		it "reads request without body after closing connection" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nAccept: */*\r\nHeader-0: value 1\r\n\r\n"
			client.stream.close
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(authority).to be == 'localhost'
			expect(method).to be == 'GET'
			expect(target).to be == '/'
			expect(version).to be == 'HTTP/1.1'
			expect(headers).to be == {'accept' => ['*/*'], 'header-0' => ["value 1"]}
			expect(body).to be_nil
		end
		
		it "reads request with fixed body" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 11\r\n\r\nHello World"
			client.stream.close
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(authority).to be == 'localhost'
			expect(method).to be == 'GET'
			expect(target).to be == '/'
			expect(version).to be == 'HTTP/1.1'
			expect(headers).to be == {}
			expect(body.join).to be == "Hello World"
		end
		
		it "reads request with chunked body" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\nb\r\nHello World\r\n0\r\n\r\n"
			client.stream.close
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(authority).to be == 'localhost'
			expect(method).to be == 'GET'
			expect(target).to be == '/'
			expect(version).to be == 'HTTP/1.1'
			expect(headers).to be == {}
			expect(body.join).to be == "Hello World"
			expect(server).to be_persistent(version, method, headers)
		end
		
		it "fails with broken request" do
			client.stream.write "Accept: */*\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(Protocol::HTTP1::InvalidRequest)
		end
		
		it "fails with missing version" do
			client.stream.write "GET foo\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(Protocol::HTTP1::InvalidRequest)
		end
	end

	describe '#persistent?' do
		describe "HTTP 1.0" do
			it "should not be persistent by default" do
				expect(server).not_to be_persistent("HTTP/1.0", "GET", {})
			end

			it "should be persistent if connection: keep-alive is set" do
				headers = Protocol::HTTP::Headers[
					"connection" => "keep-alive"
				]
				
				expect(server).to be_persistent("HTTP/1.0", "GET", headers)
			end

			it "should allow case-insensitive 'connection' value" do
				headers = Protocol::HTTP::Headers[
					"connection" => "Keep-Alive"
				]
				
				expect(server).to be_persistent("HTTP/1.0", "GET", headers)
			end
		end

		describe "HTTP 1.1" do
			it "should be persistent by default" do
				expect(server).to be_persistent("HTTP/1.1", "GET", {})
			end

			it "should not be persistent if connection: close is set" do
				headers = Protocol::HTTP::Headers[
					"connection" => "close"
				]
				
				expect(server).not_to be_persistent("HTTP/1.1", "GET", headers)
			end

			it "should allow case-insensitive 'connection' value" do
				headers = Protocol::HTTP::Headers[
					"connection" => "Close"
				]
				
				expect(server).not_to be_persistent("HTTP/1.1", "GET", headers)
			end
		end
	end
	
	describe '#read_response' do
		it "should read successful response" do
			server.stream.write("HTTP/1.1 200 Hello\r\nContent-Length: 0\r\n\r\n")
			server.stream.close
			
			version, status, reason, headers, body = client.read_response("GET")
			
			expect(version).to be == 'HTTP/1.1'
			expect(status).to be == 200
			expect(reason).to be == "Hello"
			expect(headers).to be == {}
			expect(body).to be_nil
		end
	end
	
	describe '#read_response_body' do
		context "with GET" do
			it "should ignore body for informational responses" do
				expect(client.read_response_body("GET", 100, {'content-length' => '10'})).to be_nil
			end
		end
		
		context "with HEAD" do
			it "can read length of head response" do
				body = client.read_response_body("HEAD", 200, {'content-length' => 3773})
				
				expect(body).to be_kind_of ::Protocol::HTTP::Body::Head
				expect(body.length).to be == 3773
				expect(body.read).to be nil
			end
			
			it "ignores zero length body" do
				body = client.read_response_body("HEAD", 200, {'content-length' => 0})
				
				expect(body).to be_nil
			end
		end
	end
	
	describe '#write_chunked_body' do
		let(:chunks) {["Hello", "World"]}
		let(:body) {::Protocol::HTTP::Body::Buffered.wrap(chunks)}
		
		it "can generate and read chunked response" do
			server.write_chunked_body(body, false)
			server.close
			
			headers = client.read_headers
			expect(headers).to be == [['transfer-encoding', 'chunked']]
			
			body = client.read_body(headers, false)
			expect(body.join).to be == chunks.join
		end
		
		it "can generate and read trailer" do
			chunks = ["Hello", "World"]
			
			server.write_headers({'trailer' => 'etag'})
			server.write_chunked_body(body, false, {'etag' => 'abcd'})
			server.close
			
			headers = client.read_headers
			expect(headers).to be == [['trailer', 'etag'], ['transfer-encoding', 'chunked']]
			
			body = client.read_body(headers, false)
			expect(body.join).to be == chunks.join
			
			expect(headers).to include('etag')
		end
	end
	
	describe '#write_fixed_length_body' do
		let(:chunks) {["Hello", "World"]}
		let(:body) {::Protocol::HTTP::Body::Buffered.wrap(chunks)}
		
		it "can generate and read chunked response" do
			server.write_fixed_length_body(body, 10, false)
			server.close
			
			headers = client.read_headers
			expect(headers).to be == [['content-length', '10']]
			
			body = client.read_body(headers, false)
			expect(body.join).to be == chunks.join
		end
	end
	
	describe '#write_body' do
		let(:body) {double}
		
		it "can write empty body" do
			expect(body).to receive(:empty?).and_return(true)
			expect(body).to receive(:length).and_return(false)
			
			expect(server).to receive(:write_empty_body)
			server.write_body("HTTP/1.0", body)
		end
		
		it "can write fixed length body" do
			expect(body).to receive(:length).and_return(1024)
			
			expect(server).to receive(:write_fixed_length_body)
			server.write_body("HTTP/1.0", body)
		end
		
		it "can write chunked body" do
			expect(server.persistent).to be true
			
			expect(body).to receive(:empty?).and_return(false)
			expect(body).to receive(:length).and_return(nil)
			
			expect(server).to receive(:write_chunked_body)
			server.write_body("HTTP/1.1", body)
		end
		
		it "can write fixed length body for HTTP/1.1" do
			expect(body).to receive(:length).and_return(1024)
			
			expect(server).to receive(:write_fixed_length_body)
			server.write_body("HTTP/1.1", body)
		end
		
		it "can write closed body" do
			expect(server.persistent).to be true
			
			expect(body).to receive(:empty?).and_return(false)
			expect(body).to receive(:length).and_return(nil)
			
			expect(server).to receive(:write_body_and_close)
			server.write_body("HTTP/1.0", body)
		end
	end
	
	context 'bad requests' do
		it "should fail with negative content length" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: -1\r\n\r\nHello World"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(Protocol::HTTP1::BadRequest)
		end
		
		it "should fail with invalid headers" do
			client.stream.write "GET / HTTP/1.1\r\nHost: \000localhost\r\n\r\nHello World"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(Protocol::HTTP1::BadHeader)
		end
	end
	
	context 'bad responses' do
		it 'should fail if headers contain \r characters' do
			expect do
				server.write_headers(
					[["id", "5\rSet-Cookie: foo-bar"]]
				)
			end.to raise_error(Protocol::HTTP1::BadHeader)
		end
		
		it 'should fail if headers contain \n characters' do
			expect do
				server.write_headers(
					[["id", "5\nSet-Cookie: foo-bar"]]
				)
			end.to raise_error(Protocol::HTTP1::BadHeader)
		end
	end
end
