# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'protocol/http1/body/remainder'

RSpec.describe Protocol::HTTP1::Body::Remainder do
	include_context RSpec::Memory
	include_context RSpec::Files::Buffer
	
	let(:content) {"Hello World"}
	subject! {described_class.new(buffer)}
	
	before do
		buffer.write content
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
		
		it "closes the stream when EOF was reached" do
			subject.read
			subject.close(EOFError)
			expect(buffer).to be_closed
		end
	end
	
	describe "#read" do
		it "retrieves chunks of content" do
			expect(subject.read).to be == "Hello World"
			expect(subject.read).to be == nil
		end
		
		it "updates number of bytes retrieved" do
			subject.read
			expect(subject).to be_empty
		end
	end
	
	describe "#join" do
		it "returns all content" do
			expect(subject.join).to be == "Hello World"
			expect(subject.join).to be == ""
		end
		
		it "updates number of bytes retrieved" do
			subject.read
			expect(subject).to be_empty
		end
	end
end
