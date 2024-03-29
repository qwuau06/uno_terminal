class Card
	POOL = ['0','1','2','3','4','5','6','7','8','9','Backwards','Skip','Plus2','WildCard','Plus4',"N/A"]
	COLOR = ['Red','Green','Blue','Yellow','Black','N/A']

	def initialize(str)
		@color = str[0].to_i
		@num = str[1].to_i(16)
	end

	def clr
		return @color
	end

	def ==(cd)
		return false if !cd.instance_of? Card
		return true if @color==cd.clr && @num==cd.num
		return false
	end

	def num
		return @num
	end

	def fakeclr(clr)
		@color = clr
		@num = 15
	end

	def to_s
		return @color.to_s + @num.to_s(16)
	end

	def to_readable
		if (@num==15)&&(@color==5) then
			str = "Empty" 
		elsif (@color<4)&&(@num<13) then
			str =  COLOR[@color]+"-"+POOL[@num]
		elsif (@color==4) then
			str =  POOL[@num]
		elsif (@num==15) then
			str =  COLOR[@color]
		end
		return str+"("+to_s+")"
	end

	def accum
		return 2 if @num==12
		return 4 if @num==14
		return 0
	end

	def playable? cd
		return true if cd.num==15 && cd.clr == 5
		return true if @num==14 || @num==13
		return true if cd.clr==@color && cd.clr< 4
		return true if cd.num==@num && cd.num < 13
		return false
	end

	def self.strnize(num,color)
		return color.to_s+num.to_s(16)
	end
end

class Deck
	def initialize
		@deck = Array.new
		4.times do |color|
		(1..12).each do |num|
			str = Card.strnize(num,color)
			@deck.push(Card.new(str))
			@deck.push(Card.new(str))
		end
		end
		4.times do |color|
			@deck.push(Card.new(Card.strnize(0,color)))
			@deck.push(Card.new(Card.strnize(13,4)))
			@deck.push(Card.new(Card.strnize(14,4)))
		end
		@deck.shuffle!

		@garbage = Array.new
	end

	def reshuffle
		@deck.concat @garbage
		@deck.shuffle!
		@garbage = Array.new
	end

	def draw
		return @deck.shift
	end

	def discard(cd)
		@garbage.push(cd)
	end

	def to_s
		str = ""
		@deck.each do |card|
			str+= card.to_s + ","
		end
		return str[0..-2]
	end

	def empty?
		return true if @deck.size == 0
		return false 
	end
end

class Hand
	RED = 0
	GREEN = 1
	BLUE = 2
	YELLOW = 3
	NA = 4
	REAR = 5

	def initialize 
		@hand = Array.new
		@playable = Array.new
		@df = Array.new [0,0,0,0,0,0]
	end

	def any_to_s(tar,readable=false)
		str = ""
		tar.each do |card|
			str += card.to_s + ","
		end if !readable
		tar.each do |card|
			str += card.to_readable + ","
		end if readable
		return str[0..-2]
	end

	def has?(cd)
		return false if !cd.instance_of?Card
		@hand.each do |cur|
			if cur==cd then 
				return true
			end
		end
		return false
	end

	def to_s
		return any_to_s(@hand,false)
	end

	def to_readable
		return any_to_s(@hand,true)
	end

	def show_playable
		return any_to_s(@playable,true)
	end

	def add(cd)
		place = 0
		(@df[cd.clr]...@df[cd.clr+1]).each do |card|
			next if @hand[card].num < cd.num
			place = card
			break
		end
		@hand.insert(place,cd)
		(cd.clr+1..5).each do |pt|
			@df[pt]+=1
		end
	end

	def num
		return @df[REAR]
	end

	def empty?
		return true if @df[REAR] == 0
		return false
	end

	def play(cd)
		flag = false
		card = nil
		@playable.each do |cur|
			if cur==cd then
				card = cur
				flag = true
				break
			end
		end
		return false if flag == false
		@hand-=[card]
		@playable-=[card]
		(card.clr+1..5).each do |pt|
			@df[pt]-=1
		end
		return true
	end

	def has_playable?(cd)
		mark_playable
		return true if @playable.size>0
		return false
	end

	def mark_playable(cd)
		@playable = Array.new
		@hand.each do |cur|
			@playable.push cur if cur.playable?(cd)
		end
		return @playable
	end
end
