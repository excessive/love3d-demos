function love.conf(t)
	t.window.title  = "LÖVE3D Demo"
	t.window.width  = 1280
	t.window.height = 720
	t.window.msaa   = 4

	love.filesystem.setRequirePath(
		love.filesystem.getRequirePath()
		.. ";libs/?.lua;libs/?/init.lua"
		.. ";src/?.lua;src/?/init.lua"
	)
end
