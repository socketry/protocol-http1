# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

ENV["TRACES_BACKEND"] ||= "traces/backend/test"
require "traces"

require "covered/sus"
include Covered::Sus
