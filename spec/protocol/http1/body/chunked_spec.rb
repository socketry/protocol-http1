# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative '../connection_context'

require 'protocol/http1/body/chunked'

RSpec.describe Protocol::HTTP1::Body::Chunked do
	include_context RSpec::Memory
	include_context RSpec::Files::Buffer
	
	let(:content) {"Hello World"}
	let(:postfix) {nil}
	let(:headers) {Protocol::HTTP::Headers.new}
	subject {described_class.new(buffer, headers)}
	
	before do
		buffer.write "#{content.bytesize.to_s(16)}\r\n#{content}\r\n0\r\n#{postfix}\r\n"
		buffer.seek(0)
	end
	
	describe "#empty?" do
		it "returns whether EOF was reached" do
			expect(subject.empty?).to be == false
		end
	end
	
	describe "#stop" do
		it "closes the stream" do
			subject.close(EOFError)
			expect(buffer).to be_closed
		end
		
		it "marks body as finished" do
			subject.close(EOFError)
			expect(subject).to be_empty
		end
	end
	
	describe "#read" do
		it "retrieves chunks of content" do
			expect(subject.read).to be == "Hello World"
			expect(subject.read).to be == nil
			expect(subject.read).to be == nil
		end
		
		it "updates number of bytes retrieved" do
			subject.read
			subject.read # realizes there are no more chunks
			expect(subject).to be_empty
		end
		
		context "with trailer" do
			let(:postfix) {"ETag: abcd\r\n"}
			
			it "can read trailing etag" do
				headers.add('trailer', 'etag')
				
				expect(subject.read).to be == "Hello World"
				expect(headers['etag']).to be_nil
				
				expect(subject.read).to be == nil
				expect(headers['etag']).to be == 'abcd'
			end
		end
	end
end
