# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http1/connection"

require "socket"

ConnectionContext = Sus::Shared("a connection") do
	let(:sockets) {Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)}
	
	let(:client) {Protocol::HTTP1::Connection.new(sockets.first)}
	let(:server) {Protocol::HTTP1::Connection.new(sockets.last)}
end
