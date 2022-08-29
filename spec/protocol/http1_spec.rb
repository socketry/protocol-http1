# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'protocol/http1/version'

RSpec.describe Protocol::HTTP1 do
	it "has a version number" do
		expect(Protocol::HTTP1::VERSION).not_to be nil
	end
end
