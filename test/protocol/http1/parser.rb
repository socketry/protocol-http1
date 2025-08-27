# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http1/connection"

describe Protocol::HTTP1 do
	describe "REQUEST_LINE" do
		it "parses in linear time"  do
			skip_unless_method_defined(:linear_time?, Regexp.singleton_class)
			
			expect(Regexp).to be(:linear_time?, Protocol::HTTP1::REQUEST_LINE)
		end
	end
	
	describe "HEADER" do
		it "parses in linear time"  do
			skip_unless_method_defined(:linear_time?, Regexp.singleton_class)
			
			expect(Regexp).to be(:linear_time?, Protocol::HTTP1::HEADER)
		end
	end
	
	describe "VALID_FIELD_NAME" do
		it "parses in linear time"  do
			skip_unless_method_defined(:linear_time?, Regexp.singleton_class)
			
			expect(Regexp).to be(:linear_time?, Protocol::HTTP1::VALID_FIELD_NAME)
		end
	end
	
	describe "VALID_FIELD_VALUE" do
		it "parses in linear time"  do
			skip_unless_method_defined(:linear_time?, Regexp.singleton_class)
			
			expect(Regexp).to be(:linear_time?, Protocol::HTTP1::VALID_FIELD_VALUE)
		end
	end
end
