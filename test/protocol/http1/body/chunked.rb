# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'protocol/http1/body/chunked'
require 'connection_context'

describe Protocol::HTTP1::Body::Chunked do
	let(:content) {"Hello World"}
	let(:postfix) {nil}
	let(:headers) {Protocol::HTTP::Headers.new}
	let(:buffer) {StringIO.new("#{content.bytesize.to_s(16)}\r\n#{content}\r\n0\r\n#{postfix}\r\n")}
	let(:body) {subject.new(buffer, headers)}
	
	with "#inspect" do
		it "can be inspected" do
			expect(body.inspect).to be =~ /0 bytes read in 0 chunks/
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
		end
		
		it "marks body as finished" do
			body.close(EOFError)
			expect(body).to be(:empty?)
		end
	end
	
	with "#read" do
		it "retrieves chunks of content" do
			expect(body.read).to be == "Hello World"
			expect(body.read).to be == nil
			expect(body.read).to be == nil
		end
		
		it "updates number of bytes retrieved" do
			body.read
			body.read # realizes there are no more chunks
			expect(body).to be(:empty?)
		end
		
		with "trailer" do
			let(:postfix) {"ETag: abcd\r\n"}
			
			it "can read trailing etag" do
				headers.add('trailer', 'etag')
				
				expect(body.read).to be == "Hello World"
				expect(headers['etag']).to be_nil
				
				expect(body.read).to be == nil
				expect(headers['etag']).to be == 'abcd'
			end
		end
		
		with "bad trailers" do
			let(:postfix) {":ETag abcd\r\n"}
			
			it "raises error" do
				headers.add('trailer', 'etag')
				
				expect(body.read).to be == "Hello World"
				expect(headers['etag']).to be_nil
				
				expect{body.read}.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end
	end
end
