-- this is just a bootstrap for all the demos, nothing interesting here.
-- check the files in src/, instead!

local demos = {
	current = 1,
	"forward",
	"deferred",
	"skeletal-animation"
}

local callbacks = {}

function switch(demo)
	callbacks = {}
	require("src." .. demo)
end

function register(callback, fn)
	callbacks[callback] = fn
end

function love.load()
	switch(demos[demos.current])
end

local cbs = {
	"mousemoved",
	"mousepressed",
	"mousereleased",
	"keyreleased",
	"textinput",
	"textedited",
}

for _, cb in ipairs(cbs) do
	love[cb] = function(...)
		if callbacks[cb] then
			callbacks[cb](...)
		end
	end
end

function love.keypressed(k)
	if love.keyboard.isDown("lshift", "rshift") and k == "escape" then
		love.event.quit()
	end

	local do_switch = false
	local demo = demos[demos.current]
	if k == "left" then
		demos.current = demos.current - 1
		if demos.current < 1 then
			demos.current = #demos
		end
		do_switch = true
	elseif k == "right" then
		demos.current = demos.current + 1
		if demos.current > #demos then
			demos.current = 1
		end
		do_switch = true
	end

	if do_switch then
		love.graphics.reset()
		package.loaded["src."..demo] = nil
		switch(demos[demos.current])
		return
	end

	if callbacks.keypressed then
		callbacks.keypressed(k)
	end
end

function love.update(dt)
	if callbacks.update then
		callbacks.update(dt)
	end
end

function love.draw()
	if callbacks.draw then
		love.graphics.push("all")
		callbacks.draw()
		love.graphics.pop()
	end
end
