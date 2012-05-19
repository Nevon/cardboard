Class = require "lib.class"

Card = Class{function(self, id)
	self.id = id
	self.value = (id % 13) + 2
	self.width = 75
	self.height = 107
	self.x = math.random(0, 1125)
	self.y = math.random(0, 590)
	local suit
	local color
	local name

	if id<13 then self.suit = "spades"
	elseif id < 26 then self.suit = "clubs"
	elseif id < 39 then self.suit = "hearts"
	elseif id < 52 then self.suit = "diamonds" end

	if self.suit == "spades" or self.suit == "clubs" then self.color = "black"
	else self.color = "red" end

	if self.value < 11 then self.name = self.value.." of "..self.suit
	elseif self.value == 11 then self.name = "Jack of "..self.suit
	elseif self.value == 12 then self.name = "Queen of "..self.suit
	elseif self.value == 13 then self.name = "King of "..self.suit
	elseif self.value == 14 then self.name = "Ace of "..self.suit end

	self.image = love.graphics.newImage("images/cards/"..self.suit.."-"..self.value.."-75.png");
end}

function Card:draw()
	love.graphics.draw(self.image, self.x, self.y);
end

function Card:moved(x,y)
	print (self.name .. " (" .. self.id .. ") " .. "was moved to " .. x .. "/" .. y)

	self.x = x
	self.y = y

	--Move 
	local thisCard
	for i,v in ipairs(deck) do
		if self.id == v.id then
			thisCard = table.remove(deck, i)
			break
		end
	end

	table.insert(deck, thisCard)
end

function Card:clicked(x, y)
	--Point in rect
	if x>self.x and x<self.x+self.width
	and y>self.y and y<self.y+self.height then
		print (self.name .. ' was clicked')
		return true
	else
		return false
	end
end

function ripairs(t)
  local max = 1
  while t[max] ~= nil do
    max = max + 1
  end
  local function ripairs_it(t, i)
    i = i-1
    local v = t[i]
    if v ~= nil then
      return i,v
    else
      return nil
    end
  end
  return ripairs_it, t, max
end

function love.load()
	math.randomseed(os.time())
	math.random()
	math.random()
	math.random()
	
	bg = love.graphics.newImage('images/felt.png')
	selected = false
	--Initialize deck
	deck = {}
	for i = 0,51 do
		deck[i+1] = Card(i)
	end

	--Shuffle the shit out of it
	for i=#deck, 1, -1 do
		local toMove = math.random(i)
		deck[toMove], deck[i] = deck[i], deck[toMove]
	end

	deck[6]:moved(500, 300)
end

function love.update(dt)

end

function love.draw()
	love.graphics.draw(bg, 0, 0);

	for i,v in ipairs(deck) do
		v:draw();
	end

	love.graphics.setColor(255,0,0,255)
	love.graphics.rectangle('fill', 500, 300, 10, 10)
	love.graphics.setColor(255,255,255,255)
end

function love.mousepressed(x, y, button)
	for i,v in ripairs(deck) do
		if v:clicked(x, y) then
			selected = i
			break
		end
	end
end

function love.mousereleased(x, y, button)
	if selected then
		deck[selected]:moved(x,y)
		selected = false
	end
end