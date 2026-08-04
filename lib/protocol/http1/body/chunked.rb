# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require "protocol/http/body/readable"

module Protocol
	module HTTP1
		module Body
			# Represents a chunked body, which is a series of chunks, each with a length prefix.
			#
			# See https://tools.ietf.org/html/rfc7230#section-4.1 for more details on the chunked transfer encoding.
			class Chunked < HTTP::Body::Readable
				CRLF = "\r\n"
				
				# The maximum amount of body data returned by a single read.
				BLOCK_SIZE = 1024 * 64
				
				# Initialize the chunked body.
				#
				# @parameter connection [Protocol::HTTP1::Connection] the connection to read the body from.
				# @parameter headers [Protocol::HTTP::Headers] the headers to read the trailer into, if any.
				def initialize(connection, headers)
					@connection = connection
					@finished = false
					
					@headers = headers
					
					@length = 0
					@count = 0
					@remaining = nil
				end
				
				# @attribute [Integer] the number of chunks read so far.
				attr :count
				
				# @attribute [Integer] the length of the body if known.
				def length
					# We only know the length once we've read the final chunk:
					if @finished
						@length
					end
				end
				
				# @returns [Boolean] true if the body is empty, in other words {read} will return `nil`.
				def empty?
					@connection.nil?
				end
				
				# Close the connection and mark the body as finished.
				#
				# @parameter error [Exception | Nil] the error that caused the body to be closed, if any.
				def close(error = nil)
					if connection = @connection
						@connection = nil
						
						unless @finished
							connection.close_read
						end
					end
					
					super
				end
				
				VALID_CHUNK_LENGTH = /\A[0-9a-fA-F]+\z/
				
				# Read a chunk of data.
				#
				# Follows the procedure outlined in https://tools.ietf.org/html/rfc7230#section-4.1.3
				#
				# @returns [String | Nil] the next chunk of data, or `nil` if the body is finished.
				# @raises [EOFError] if the connection is closed before the expected length is read.
				def read
					while !@finished
						unless @connection
							raise EOFError, "Connection closed before expected length was read!"
						end
						
						if @remaining
							if @remaining > 0
								chunk = @connection.readpartial([@remaining, BLOCK_SIZE].min)
								@remaining -= chunk.bytesize
								@length += chunk.bytesize
								
								return chunk
							end
							
							terminator = @connection.read(CRLF.bytesize)
							
							unless terminator&.bytesize == CRLF.bytesize
								raise EOFError, "Connection closed before expected length was read!"
							end
							
							unless terminator == CRLF
								raise BadRequest, "Invalid chunk terminator: #{terminator.inspect}"
							end
							
							@remaining = nil
							@count += 1
						else
							length, _extensions = @connection.read_line.split(";", 2)
							
							unless length =~ VALID_CHUNK_LENGTH
								raise BadRequest, "Invalid chunk length: #{length.inspect}"
							end
							
							length = Integer(length, 16)
							
							if length == 0
								read_trailer
								
								# The final chunk has been read and the connection is now closed:
								@connection.receive_end_stream!
								@connection = nil
								@finished = true
								
								return nil
							end
							
							@remaining = length
						end
					end
				rescue EOFError
					if connection = @connection
						@connection = nil
						connection.close_read
					end
					
					raise
				end
				
				# @returns [String] a human-readable representation of the body.
				def inspect
					"\#<#{self.class} #{@length} bytes read in #{@count} chunks, #{@finished ? 'finished' : 'reading'}>"
				end
				
				# @returns [Hash] JSON representation for tracing and debugging.
				def as_json(...)
					super.merge(
						count: @count,
						finished: @finished,
						state: @connection ? "open" : "closed"
					)
				end
				
				private
				
				# Read the trailer from the connection, and add any headers to the trailer.
				def read_trailer
					while line = @connection.read_line
						# Empty line indicates end of trailer:
						break if line.empty?
						
						if match = line.match(HEADER)
							@headers.add(match[1], match[2], trailer: true)
						else
							raise BadHeader, "Could not parse header: #{line.inspect}"
						end
					end
				end
			end
		end
	end
end
