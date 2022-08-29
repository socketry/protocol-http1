# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

# Run the fuzz test.
def run
	system("AFL_SKIP_BIN_CHECK=1 afl-fuzz -i input/ -o output/ -t 1000  -m 1000 -- ruby script.rb")
end
