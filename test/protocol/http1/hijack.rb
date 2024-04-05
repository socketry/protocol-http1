# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.
# Copyright, 2024, by Anton Zhuravsky.

require 'protocol/http1/connection'
require 'connection_context'

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	with '#hijack' do
		let(:response_version) {Protocol::HTTP1::Connection::HTTP10}
		let(:response_headers) {Hash.new('upgrade' => 'websocket')}
		let(:body) {Protocol::HTTP::Body::Buffered.new}
		let(:text) {"Hello World!"}
		
		it "should not be persistent after hijack" do
			server_wrapper = server.hijack!
			expect(server.persistent).to be == false
		end

		it "should repord itself as #hijacked? after the hijack" do
			expect(server.hijacked?).to be == false
			server.hijack!
			expect(server.hijacked?).to be == true
		end
		
		it "should use non-chunked output" do
			expect(body).to receive(:ready?).and_return(false)
			expect(body).to receive(:empty?).and_return(false)
			expect(body).to receive(:length).twice.and_return(nil)
			expect(body).to receive(:each).and_return(nil)
			
			expect(server).to receive(:write_body_and_close)
			server.write_response(response_version, 101, response_headers)
			server.write_body(response_version, body)
			
			server_stream = server.hijack!
			
			version, status, reason, headers, body = client.read_response("GET")
			
			expect(version).to be == response_version
			expect(status).to be == 101
			expect(headers).to be == response_headers
			expect(body).to be_nil # due to 101 status
			
			client_stream = client.hijack!
			
			client_stream.write(text)
			client_stream.close
			
			expect(server_stream.read).to be == text
		end
	end
end
