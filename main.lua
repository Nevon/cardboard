Class = require "lib.class"
require "lib.LUBE"

local server = true
local conn
local numConnected = 0

Card = Class{function(self, id)
	self.id = id
	self.value = (id % 13) + 2
	self.width = 75
	self.height = 107
	self.x = math.random(0, 1125)
	self.y = math.random(0, 590)
	self.flipped = false

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

	self.image = love.graphics.newImage("images/cards/"..self.suit.."-"..self.value.."-75.png")
end}

function Card:draw()
	if not self.flipped then
		love.graphics.draw(self.image, self.x, self.y)
	else
		love.graphics.draw(back, self.x, self.y)
	end
end

function Card:moved(x, y, remote)
	print (self.name .. " (" .. self.id .. ") " .. "was moved to " .. x .. "/" .. y)

	self.x = x
	self.y = y

	love.audio.play('sounds/place.ogg')

	--Move 
	local thisCard
	for i,v in ipairs(deck) do
		if self.id == v.id then
			thisCard = table.remove(deck, i)
			break
		end
	end

	table.insert(deck, thisCard)

	if not remote then
		conn:send(("moved:%d:%d:%d\n"):format(self.id, x, y))
	end
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

function Card:flip()
	self.flipped = not self.flipped
	
	conn:send(("flipped:%d:%d\n"):format(self.id, self.flipped and 1 or 0))
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

do
    -- will hold the currently playing sources
    local sources = {}

    -- check for sources that finished playing and remove them
    -- add to love.update
    function love.audio.update()
        local remove = {}
        for _,s in pairs(sources) do
            if s:isStopped() then
                remove[#remove + 1] = s
            end
        end

        for i,s in ipairs(remove) do
            sources[s] = nil
        end
    end

    -- overwrite love.audio.play to create and register source if needed
    local play = love.audio.play
    function love.audio.play(what, how, loop)
        local src = what
        if type(what) ~= "userdata" or not what:typeOf("Source") then
            src = love.audio.newSource(what, how)
            src:setLooping(loop or false)
        end

        play(src)
        sources[src] = src
        return src
    end

    -- stops a source
    local stop = love.audio.stop
    function love.audio.stop(src)
        if not src then return end
        stop(src)
        sources[src] = nil
    end
end

local function clientRecv(data)
	data = data:match("^(.-)\n*$")
	if data:match("^moved:") then
		local id, x, y = data:match("^moved:(%d+):(%d+):(%d+)")
		assert(id, "Invalid message")
		id, x, y = tonumber(id), tonumber(x), tonumber(y)
		for i, v in ipairs(deck) do
			if v.id == id then
				v:moved(x, y, true)
				break
			end
		end
	elseif data:match("^flipped:") then
		local id, flipped = data:match("^flipped:(%d+):(%d)")
		assert(id, "Invalid message")
		id = tonumber(id)
		flipped = (flipped == "1")
		for i, v in ipairs(deck) do
			if v.id == id then
				v.flipped = flipped
				break
			end
		end
	end
end

local function serverRecv(data, clientid)
	data = data:match("^(.-)\n*$")
	if data:match("^getDeck") then
		for i = 1, #deck do
			conn:send(
				("%d:%d:%d:%d\n"):format(deck[i].id, deck[i].x, deck[i].y, deck[i].flipped and 1 or 0),
				clientid)
		end
	else
		return clientRecv(data)
	end
end

local function prepareNetwork(args)
	if args[1] == "client" then
		server = false
		table.remove(args, 1)
	else
		if args[1] == "server" then
			table.remove(args, 1)
		else
			print("Invalid mode, defaulting to server")
		end
		server = true
	end

	if server then
		conn = lube.tcpServer()
		conn.handshake = "helloCardboard"
		conn:setPing(true, 16, "areYouStillThere?\n")
		conn:listen(3410)
		conn.callbacks.recv = serverRecv
		conn.callbacks.connect = function() numConnected = numConnected + 1 end
		conn.callbacks.disconnect = function() numConnected = numConnected - 1 end
	else
		local host = args[1]
		if not host then
			print("Invalid host, defaulting to localhost")
			host = "localhost"
		end
		conn = lube.tcpClient()
		conn.handshake = "helloCardboard"
		conn:setPing(true, 2, "areYouStillThere?\n")
		assert(conn:connect(host, 3410, true))
		conn.callbacks.recv = clientRecv
	end
end

local getLine
do
	local msg
	local it

	local function getMsg()
		repeat
			msg = conn:receive()
			love.timer.sleep(0.005)
		until msg
	end

	function getLine()
		if not msg then
			getMsg()
			it = msg:gmatch("[^\n]+")
		end
		local line = it()
		if not line then
			msg = nil
			return getLine()
		end
		return line
	end
end

local function prepareDeck()
	if server then
		--Shuffle the shit out of it
		for i=#deck, 1, -1 do
			local toMove = math.random(i)
			deck[toMove], deck[i] = deck[i], deck[toMove]
		end
	else
		local msg, line, id, x, y, flipped
		conn:send("getDeck\n")
		for i = 1, #deck do
			repeat
				local line = getLine()
				id, x, y, flipped = line:match("(%d+):(%d+):(%d+):(%d)")
				if not id then
					clientRecv(msg)
				end
			until id and x and y
			id, x, y = tonumber(id), tonumber(x), tonumber(y)
			flipped = (flipped == "1")
			deck[i]:construct(id)
			deck[i].x, deck[i].y = x, y
			deck[i].flipped = flipped
			id, x, y, flipped = nil, nil, nil, nil
		end
	end
end

function love.load(args)
	math.randomseed(os.time())
	math.random()
	math.random()
	math.random()
	
	bg = love.graphics.newImage('images/felt.png')
	back = love.graphics.newImage('images/cards/back.png')
	selected = false
	--Initialize deck
	deck = {}
	for i = 0,51 do
		deck[i+1] = Card(i)
	end

	love.audio.play('sounds/shuffle.ogg')

	local nwArgs = {}
	for i = 2, #args do
		table.insert(nwArgs, args[i])
	end
	prepareNetwork(nwArgs)
	prepareDeck()
end

function love.update(dt)
	conn:update(dt)
end

function love.draw()
	love.graphics.draw(bg, 0, 0)

	for i,v in ipairs(deck) do
		v:draw()
	end

	if selected then
		x,y = love.mouse.getPosition()
		x = math.ceil(x-75/2)
		y = math.ceil(y-107/2)
		love.graphics.setColor(94,167,214, 177)
		love.graphics.rectangle('fill', x, y, 75, 107)
		love.graphics.setColor(157,190,250, 255)
		love.graphics.rectangle('line', x-1, y-1, 76, 108)
		love.graphics.setColor(255,255,255,255)
	end

	if server then
		love.graphics.print(numConnected .. " clients connected", 10, 10)
	end
end

function love.mousepressed(x, y, button)
	for i,v in ripairs(deck) do
		if v:clicked(x, y) then
			if button == 'l' then
				selected = v.id
			elseif button == 'r' then
				v:flip()
			end
			break
		end
	end
end

function love.mousereleased(x, y, button)
	if selected then
		for i,v in ipairs(deck) do
			if v.id == selected then
				v:moved(math.ceil(x-v.width/2),math.ceil(y-v.height/2))
			end
		end
		selected = false
	end
end

function love.quit()
	if not server then
		conn:disconnect()
	end
end
