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
			expect(server).to be_persistent(version, headers)
		end
		
		it "fails with broken request" do
			client.stream.write "Accept: */*\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(NameError, /wrong constant name Accept:/)
		end
		
		it "fails with missing version" do
			client.stream.write "GET foo\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(Protocol::HTTP1::InvalidRequest)
		end
		
		it "fails with invalid method" do
			client.stream.write "GETT /foo HTTP/1.0\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_error(Protocol::HTTP1::InvalidMethod)
		end
		
		it "should be persistent by default" do
			expect(client).to be_persistent('HTTP/1.1', {})
			expect(server).to be_persistent('HTTP/1.1', {})
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
		it "should ignore body for informational responses" do
			client.close
			
			expect(client.read_response_body("GET", 100, {'content-length' => '10'})).to be_nil
		end
	end
	
	describe '#write_chunked_body' do
		it "can generate and read chunked response" do
			chunks = ["Hello", "World"]
			
			server.write_chunked_body(chunks, false)
			server.close
			
			headers = client.read_headers
			expect(headers).to be == [['transfer-encoding', 'chunked']]
			
			body = client.read_body(headers, false)
			expect(body.join).to be == chunks.join
		end
	end
	
	describe '#write_fixed_length_body' do
		it "can generate and read chunked response" do
			chunks = ["Hello", "World"]
			
			server.write_fixed_length_body(chunks, 10, false)
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
			
			expect(server).to receive(:write_empty_body)
			server.write_body("HTTP/1.0", body)
		end
		
		it "can write fixed length body" do
			expect(body).to receive(:empty?).and_return(false)
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
	end
end
