require "socket"
require "thread"

server = TCPServer.open(3002)
client = server.accept
