# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'protocol/http/body/readable'

module Protocol
	module HTTP1
		module Body
			# A body that reads all remaining data from the stream.
			class Remainder < HTTP::Body::Readable
				BLOCK_SIZE = 1024 * 64
				
				# block_size may be removed in the future. It is better managed by stream.
				def initialize(stream)
					@stream = stream
				end
				
				def empty?
					@stream.nil?
				end
				
				def close(error = nil)
					if @stream
						# We can't really do anything in this case except close the connection.
						@stream.close_read
						@stream = nil
					end
					
					super
				end
				
				def read
					@stream&.readpartial(BLOCK_SIZE)
				rescue EOFError, IOError
					@stream = nil
					# I noticed that in some cases you will get EOFError, and in other cases IOError!?
					return nil
				end
				
				def inspect
					"\#<#{self.class} state=#{@stream ? 'open' : 'closed'}>"
				end
			end
		end
	end
end
