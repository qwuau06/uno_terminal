require './uno.rb'
require 'socket'
require 'thread'

# Server maintains the deck

class Server
	def initialize pc,port=8915
		@mutex = Mutex.new
		@server = 
			begin
				TCPServer.new(port)
			rescue SyscallError => ex
				raise "open port failed, #{ex}"
			end
		@player = 0
		@clients = Array.new
		@thpool = Array.new
		@client_que = Array.new
		puts "Successfully established. "

		wait_th = Thread.new {
			pc.times do |order|
				th = Thread.fork(@server.accept) do |client|
					@mutex.synchronize do
						@clients.size.times do |n|
							com n,"msg","player #{client} joined game."
						end
					end
					puts "player #{client} joined game."
					@mutex.synchronize do
						@clients.push(client)
						@client_que.push(Queue.new)
						@client_que[-1].push 0
						@client_que[-1].pop
					end
					com order,"handshake","#{order}"
					com order,"msg","Connection Established, waiting for others."

					while str = @clients[order].gets.chomp do
						@client_que[order].push str
					end
				end
				@thpool.push(th)
			end
		}
		puts "Waiting for clients..."

		#control player numbers

		while str = gets.chomp do
			if (@clients.size < pc) && (@clients.size > 1) && (str.eql?"start") then
				(@clients.size...pc).each do |n|
					Thread.kill(@thpool[n])
				end
				Thread.kill(wait_th)
				wait_th.join
			elsif @clients.size==pc then
				puts "Game Begin"
			else
				puts "Input 'start' to start"
			end
			if @clients.size==pc then
				break
			end
		end
		puts "Current player: #{@clients.size}, Queue size #{@client_que.size},maximum player #{pc}"

		broadcast "start",@clients.size.to_s

		# go back to main stream
	end

	def get_player_num
		return @clients.size
	end

	def clean_up
		@thpool.each do |th|
			Thread.kill(th)
		end
	end

	def get_resp(n)
		while @client_que[n].empty? do
			next
		end
		return @client_que[n].pop
	end

	def com(clt,type,msg="")
		@clients[clt].puts type
		@clients[clt].puts msg.to_s
	end

	def broadcast(type,str)
		@clients.size.times do |clt|
			com clt,type,str
		end
	end
end

class UnoGame_Server
	def initialize players=4
		@deck = Deck.new
		puts "deck is #{@deck.to_s}"
		@cur = -1
		@dir = 1
		@last = Card.new("5F")
		@hand = Array.new
		@server = Server.new(players)
		@players = @server.get_player_num
		puts "Player Num: #{@players}"
		@players.times do 
			@hand.push(Hand.new)
		end
		@winners = Array.new
		@accum = 0
	end

	def game
		#initialize
		game_in_play = true

		puts "Draw 5 cards."

		@players.times do |player|
			5.times do draw(player) end
		end

		#turn and check
		
		loop do
			next_one
			puts "Current turn if #{@cur}"
			next if @winners.include?@cur
			wait_for_play
			if @hand[@cur].empty? then
				win
				if @winners.size == @Players.size then
					game_in_play = false
					break
				end
			end
			break if game_in_play == false
		end
	end

	def infos
		str = ""
		@players.times do |n|
			str += @hand[n].num.to_s+","
		end
		str += @dir.to_s + ","
		str += @cur.to_s + ","
		str += @last.to_s + ","
		return str
	end

	def next_one
		pf = @last.num
		inc = 1
		if pf==10 then
			@dir = -@dir
		elsif pf==11 then
			inc = 2
		end
		if @dir == 1 then
			@cur=(@cur+inc) % @players
			while @winners.include?(@cur) do
				@cur = (@cur+1) % @players
			end
		else
			@cur=(@cur-inc) % @players
			while @winners.include?(@cur) do
				@cur = (@cur-1) % @players
			end
		end
		puts "next is #{@cur}"
		@server.broadcast "turn",infos()
	end

	def draw(player=@cur)
		if @deck.empty? then
			@deck.reshuffle
		end
		card = @deck.draw
		@hand[player].add(card)
		@server.com player,"draw",card.to_s
	end

	def accum_send(player=@cur)
		if @deck.empty? then
			@deck.reshuffle
		end
		card = @deck.draw
		@hand[player].add(card)
		@server.com player,"accum",card.to_s
	end

	def check_card(player=@cur,card)
		if !@hand[player].has? card then 
			@server.com player,"check","0"
			return false
		end
		if card.playable?@last then
			@server.com player,"check","1"
			return true
		else
			@server.com player,"check","0"
			return false
		end
	end

	def play(player=@cur,card)
		@hand[player].play(card)
		@deck.discard(card)
		if (card.num == 13)||(card.num == 14) then
			puts "wait for color"
			@server.com @cur,"inquiry"
			ret = @server.get_resp @cur
			card.fakeclr(ret.to_i)
			puts "color is #{ret.to_i}"
		end
		@last = card
	end

	def wait_for_play
		valid = false
		ret = "p"
		card = nil
		accumflag = false
		while valid == false do
			ret = @server.get_resp @cur
			if (!accumflag) && (ret.eql?"p") && (@accum>0) then
				accum_cal
				accumflag = true
			end
			while ret.eql?"p" do
				draw
				ret = @server.get_resp @cur
			end
			card = Card.new(ret)
			valid = check_card(card)
		end
		if (card.accum==0) && (@accum>0) && (!accumflag) then
			accum_cal
			accumflag = true
		elsif (card.accum >0) && (!accumflag) then
			@accum+=card.accum
		end
		play(card)
	end

	def accum_cal
		@server.com @cur,"msg","Congratulations! Draw your deal."
		@accum.times do 
			accum_send
		end
		@accum = 0
	end

	def win(player=@cur)
		@winners.push(player)
	end
end
