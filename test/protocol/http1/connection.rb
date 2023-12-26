# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.
# Copyright, 2020, by Bruno Sutic.

require 'protocol/http1/connection'
require 'protocol/http/body/buffered'

require 'connection_context'

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	with '#read_request' do
		it "reads request without body" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n"
			client.stream.close
			
			expect(server).to receive(:read_request_line)
			
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
			expect(server).to be(:persistent?, version, method, headers)
		end
		
		it "reads request with CONNECT method" do
			client.stream.write "CONNECT localhost:443 HTTP/1.1\r\nHost: localhost\r\n\r\n"
			client.stream.close
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(authority).to be == 'localhost'
			expect(method).to be == 'CONNECT'
			expect(target).to be == 'localhost:443'
			expect(version).to be == 'HTTP/1.1'
			expect(headers).to be == {}
			expect(body).to be_a(Protocol::HTTP1::Body::Remainder)
			expect(server).not.to be(:persistent?, version, method, headers)
		end
		
		it "fails with broken request" do
			client.stream.write "Accept: */*\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::InvalidRequest)
		end
		
		it "fails with missing version" do
			client.stream.write "GET foo\r\n"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::InvalidRequest)
		end
	end
	
	with '#write_response' do
		it "fails to write a response with invalid header name" do
			invalid_header_names = [
				'foo bar',
				'foo:bar',
				'foo: bar',
				'foo bar:baz',
				'foo\r\nbar',
				'foo\nbar',
				'foo\rbar',
			]
				
			invalid_header_names.each do |name|
				expect(name).not.to be =~ Protocol::HTTP1::VALID_FIELD_NAME
				
				expect do
					server.write_response("HTTP/1.1", 200, {name => 'baz'}, [])
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end
	end
	
	with '#write_interim_response' do
		it 'can write iterm response' do
			server.write_interim_response("HTTP/1.1", 100, {})
			server.close
			
			expect(client.stream.read).to be == "HTTP/1.1 100 Continue\r\n\r\n"
		end
	end
	
	with '#persistent?' do
		describe "HTTP 1.0" do
			it "should not be persistent by default" do
				expect(server).not.to be(:persistent?, "HTTP/1.0", "GET", {})
			end

			it "should be persistent if connection: keep-alive is set" do
				headers = Protocol::HTTP::Headers[
					"connection" => "keep-alive"
				]
				
				expect(server).to be(:persistent?, "HTTP/1.0", "GET", headers)
			end

			it "should allow case-insensitive 'connection' value" do
				headers = Protocol::HTTP::Headers[
					"connection" => "Keep-Alive"
				]
				
				expect(server).to be(:persistent?, "HTTP/1.0", "GET", headers)
			end
		end

		describe "HTTP 1.1" do
			it "should be persistent by default" do
				expect(server).to be(:persistent?, "HTTP/1.1", "GET", {})
			end

			it "should not be persistent if connection: close is set" do
				headers = Protocol::HTTP::Headers[
					"connection" => "close"
				]
				
				expect(server).not.to be(:persistent?, "HTTP/1.1", "GET", headers)
			end

			it "should allow case-insensitive 'connection' value" do
				headers = Protocol::HTTP::Headers[
					"connection" => "Close"
				]
				
				expect(server).not.to be(:persistent?, "HTTP/1.1", "GET", headers)
			end
		end
	end
	
	with '#read_response' do
		it "should read successful response" do
			server.stream.write("HTTP/1.1 200 Hello\r\nContent-Length: 0\r\n\r\n")
			server.stream.close
			
			expect(client).to receive(:read_response_line)
			
			version, status, reason, headers, body = client.read_response("GET")
			
			expect(version).to be == 'HTTP/1.1'
			expect(status).to be == 200
			expect(reason).to be == "Hello"
			expect(headers).to be == {}
			expect(body).to be_nil
		end
	end
	
	with '#read_response_body' do
		with "GET" do
			it "should ignore body for informational responses" do
				expect(client.read_response_body("GET", 100, {'content-length' => '10'})).to be_nil
			end
			
			it "should handle non-chunked transfer-encoding" do
				body = client.read_response_body("GET", 200, {'transfer-encoding' => ['identity']})
				expect(body).to be_a(::Protocol::HTTP1::Body::Remainder)
			end
			
			it "should be an error if both transfer-encoding and content-length is set" do
				expect do
					client.read_response_body("GET", 200, {'content-length' => '10', 'transfer-encoding' => ['chunked']})
				end.to raise_exception(Protocol::HTTP1::BadRequest)
			end
		end
		
		with "HEAD" do
			it "can read length of head response" do
				body = client.read_response_body("HEAD", 200, {'content-length' => '3773'})
				
				expect(body).to be_a ::Protocol::HTTP::Body::Head
				expect(body.length).to be == 3773
				expect(body.read).to be_nil
			end
			
			it "ignores zero length body" do
				body = client.read_response_body("HEAD", 200, {'content-length' => '0'})
				
				expect(body).to be_nil
			end
			
			it "raises error if content-length is invalid" do
				expect do
					client.read_response_body("HEAD", 200, {'content-length' => 'foo'})
				end.to raise_exception(Protocol::HTTP1::BadRequest)
			end
		end
		
		with "CONNECT" do
			it "should ignore body for informational responses" do
				expect(client.read_response_body("CONNECT", 200, {})).to be_a(Protocol::HTTP1::Body::Remainder)
			end
		end
	end
	
	with '#write_chunked_body' do
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
			
			expect(headers).to have_keys('etag')
		end
		
		with "HEAD request" do
			it "can generate and read chunked response" do
				server.write_chunked_body(body, true)
				server.close
				
				headers = client.read_headers
				expect(headers).to be == [["transfer-encoding", "chunked"]]
				
				body = client.read_response_body("HEAD", 200, headers)
				expect(body).to be_nil
			end
		end
	end
	
	with '#write_fixed_length_body' do
		let(:chunks) {["Hello", "World"]}
		let(:body) {::Protocol::HTTP::Body::Buffered.wrap(chunks)}
		
		it "can generate a valid response" do
			server.write_fixed_length_body(body, 10, false)
			server.close
			
			headers = client.read_headers
			expect(headers).to be == [['content-length', '10']]
			
			body = client.read_body(headers, false)
			expect(body.join).to be == chunks.join
		end
		
		with "a length smaller than stream size" do
			it "raises an error" do
				expect do
					server.write_fixed_length_body(body, 100, false)
				end.to raise_exception(Protocol::HTTP1::ContentLengthError)
			end
		end
		
		with "a length larger than stream size" do
			it "raises an error" do
				expect do
					server.write_fixed_length_body(body, 1, false)
				end.to raise_exception(Protocol::HTTP1::ContentLengthError)
			end
		end
		
		with "HEAD request" do
			it "can generate a valid response" do
				server.write_fixed_length_body(body, 10, true)
				server.close
				
				headers = client.read_headers
				expect(headers).to be == [['content-length', '10']]
				
				body = client.read_response_body("HEAD", 200, headers)
				expect(body).to be_a(Protocol::HTTP::Body::Head)
				expect(body.length).to be == 10
				expect(body.read).to be_nil
			end
		end
	end
	
	with '#write_upgrade_body' do
		let(:body) {::Protocol::HTTP::Body::Buffered.new(["Hello ", "World!"])}
		
		it "can generate and read upgrade response" do
			server.write_upgrade_body("text", body)
			server.close
			
			headers = client.read_headers
			expect(headers).to have_keys(
				'connection' => be == ['upgrade'],
				'upgrade' => be == ['text']
			)
			
			body = client.read_body(headers, true)
			expect(body.join).to be == "Hello World!"
		end
	end
	
	with '#write_tunnel_body' do
		let(:body) {::Protocol::HTTP::Body::Buffered.new(["Hello ", "World!"])}
		
		it "can generate and read tunnel response" do
			server.write_tunnel_body("HTTP/1.1", body)
			server.close
			
			headers = client.read_headers
			expect(headers).to have_keys(
				'connection' => be == ['close'],
			)
			
			body = client.read_body(headers, true)
			expect(body.join).to be == "Hello World!"
		end
	end
	
	with '#write_body_and_close' do
		let(:body) {::Protocol::HTTP::Body::Buffered.new(["Hello ", "World!"])}
		
		it "can generate and write response" do
			server.write_body_and_close(body, false)
			server.close
			
			headers = client.read_headers
			expect(headers).to be(:empty?)
			
			body = client.read_body(headers, true)
			expect(body.join).to be == "Hello World!"
		end
		
		with "HEAD request" do
			it "can generate and write response" do
				server.write_body_and_close(body, true)
				server.close
				
				headers = client.read_headers
				expect(headers).to be(:empty?)
				
				body = client.read_response_body("HEAD", 200, headers)
				expect(body).to be_nil
			end
		end
	end
	
	with '#write_body' do
		let(:body) {Protocol::HTTP::Body::Buffered.new}
		
		it "can write empty body" do
			expect(body).to receive(:empty?).and_return(true)
			expect(body).to receive(:length).and_return(false)
			
			expect(server).to receive(:write_empty_body)
			server.write_body("HTTP/1.0", body)
			
			headers = client.read_headers
			expect(headers).to be == [["connection", "keep-alive"], ["content-length", "0"]]
			
			body = client.read_body(headers, true)
			expect(body).to be_nil
		end
		
		it "can write nil body" do
			expect(server).to receive(:write_empty_body)
			server.write_body("HTTP/1.0", nil)
			server.close
			
			headers = client.read_headers
			expect(headers).to be == [["connection", "keep-alive"], ["content-length", "0"]]
			
			body = client.read_body(headers, true)
			expect(body).to be_nil
		end
		
		it "can write fixed length body" do
			expect(body).to receive(:length).and_return(1024)
			expect(server).to receive(:write_fixed_length_body).and_return(true)
			server.write_body("HTTP/1.0", body)
		end
		
		it "can write chunked body" do
			expect(server.persistent).to be == true
			
			expect(body).to receive(:empty?).and_return(false)
			expect(body).to receive(:length).and_return(nil)
			
			expect(server).to receive(:write_chunked_body)
			server.write_body("HTTP/1.1", body)
		end
		
		it "can write fixed length body for HTTP/1.1" do
			expect(body).to receive(:length).and_return(1024)
			expect(server).to receive(:write_fixed_length_body).and_return(true)
			server.write_body("HTTP/1.1", body)
		end
		
		it "can write closed body" do
			expect(server.persistent).to be == true
			
			expect(body).to receive(:empty?).and_return(false)
			expect(body).to receive(:length).and_return(nil)
			
			expect(server).to receive(:write_body_and_close)
			server.write_body("HTTP/1.0", body)
		end
	end
	
	with 'bad requests' do
		it "should fail with negative content length" do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: -1\r\n\r\nHello World"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::BadRequest)
		end
		
		it "should fail with invalid headers" do
			client.stream.write "GET / HTTP/1.1\r\nHost: \000localhost\r\n\r\nHello World"
			client.stream.close
			
			expect do
				server.read_request
			end.to raise_exception(Protocol::HTTP1::BadHeader)
		end
	end
	
	with 'bad responses' do
		it 'should fail if headers contain \r characters' do
			expect do
				server.write_headers(
					[["id", "5\rSet-Cookie: foo-bar"]]
				)
			end.to raise_exception(Protocol::HTTP1::BadHeader)
		end
		
		it 'should fail if headers contain \n characters' do
			expect do
				server.write_headers(
					[["id", "5\nSet-Cookie: foo-bar"]]
				)
			end.to raise_exception(Protocol::HTTP1::BadHeader)
		end
	end
end
