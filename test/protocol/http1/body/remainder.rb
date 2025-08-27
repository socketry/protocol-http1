# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "protocol/http1/body/remainder"
require "protocol/http1/connection"

describe Protocol::HTTP1::Body::Remainder do
	let(:content) {"Hello World"}
	let(:buffer) {StringIO.new(content)}
	let(:connection) {Protocol::HTTP1::Connection.new(buffer, state: :open)}
	let(:body) {subject.new(connection)}
	
	with "#inspect" do
		it "can be inspected" do
			expect(body.inspect).to be =~ /reading/
		end
	end
	
	with "#as_json" do
		it "returns JSON representation" do
			expect(body.as_json).to have_keys(
				class: be == "Protocol::HTTP1::Body::Remainder",
				length: be_nil,
				stream: be == false,
				ready: be == false,
				empty: be == false,
				block_size: be == 65536,
				state: be == "open"
			)
		end
		
		it "shows finished state after reading all data" do
			body.read # Read all available data (this will read until EOF and close connection)
			# Need to read again to trigger the EOF handling that closes the connection
			body.read # This returns nil and sets @connection = nil
			expect(body.as_json).to have_keys(
				empty: be == true,
				state: be == "closed"
			)
		end
	end
	
	with "#empty?" do
		it "returns whether EOF was reached" do
			expect(body.empty?).to be == false
		end
	end
	
	with "#stop" do
		it "closes the stream" do
			body.close(EOFError)
			expect(buffer).to be(:closed?)
			
			expect(connection).to be(:half_closed_remote?)
		end
		
		it "closes the stream when EOF was reached" do
			body.read
			body.close(EOFError)
			expect(buffer).to be(:closed?)
			
			expect(connection).to be(:half_closed_remote?)
		end
	end
	
	with "#read" do
		it "retrieves chunks of content" do
			expect(body).not.to be(:empty?)
			
			expect(body.read).to be == "Hello World"
			expect(body.read).to be == nil
			
			expect(body).to be(:empty?)
			
			expect(connection).to be(:half_closed_remote?)
		end
	end
	
	with "#call" do
		it "streams the content" do
			stream = StringIO.new
			body.call(stream)
			expect(stream.string).to be == "Hello World"
			
			expect(connection).to be(:half_closed_remote?)
		end
	end
	
	with "#join" do
		it "returns all content" do
			expect(body).not.to be(:empty?)
			
			expect(body.join).to be == "Hello World"
			
			expect(body).to be(:empty?)
			
			expect(connection).to be(:half_closed_remote?)
		end
	end
end
