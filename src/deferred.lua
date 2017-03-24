local l3d = require "love3d"
local iqm = require "iqm"
local cpml = require "cpml"

local w, h = love.graphics.getDimensions()
local gbuffer = {
	l3d.new_canvas(w, h, "rgba16f", 1, true), -- color/depth
	love.graphics.newCanvas(w, h, "rg11b10f") -- normals
}

local gb_fill = love.graphics.newShader [[
varying vec3 f_normal;

#ifdef VERTEX
attribute vec3 VertexNormal;

uniform mat4 u_model;
uniform mat4 u_viewProj;

vec4 position(mat4 _, vec4 vertex) {
	f_normal = mat3(u_model) * VertexNormal;

	return u_viewProj * u_model * vertex;
}
#endif

#ifdef PIXEL
	void effects(vec4 _col, Image _tex, vec2 _uv, vec2 _sc) {
		// base color
		love_Canvases[0] = gammaToLinear(_col);

		// world space normals
		love_Canvases[1] = vec4(f_normal * 0.5 + 0.5, 1.0);
	}
#endif
]]

local post = love.graphics.newShader [[
	uniform sampler2D s_normal;
	uniform vec4 u_light;

	const float exposure = 1.5;
	const float gamma = 2.2;

	vec4 effect(vec4 _col, Image s_color, vec2 _uv, vec2 _sc) {
		vec2 uv = vec2(_uv.x, 1.0-_uv.y);
		vec4 color  = texture2D(s_color, uv);
		vec3 normal = normalize(texture2D(s_normal, uv).rgb * 2.0 - 1.0);

		float shade = max(0.0, dot(normal, u_light.xyz));
		color.rgb *= shade;
		color.rgb *= u_light.w;

		// RomBinDaHouse
		color.rgb = exp( -1.0 / ( 2.72*color.rgb + 0.15 ) );
		color.rgb = pow(color.rgb, vec3(1.0 / gamma));

		return vec4(color.rgb, 1.0);
	}
]]

local objects = {
	{
		model = iqm.load("assets/cthulhu.iqm"),
		position = cpml.vec3(0, 0, 0),
		orientation = cpml.quat()
	}
}

local camera_fov = 60
local camera_pos = cpml.vec3(0, -5, -15)
local light_direction = cpml.vec3(0, -0.76, 0.65):normalize()
local light_intensity = 3.0

local dragging = false
register("mousepressed", function(x, y, b)
	if b == 1 then
		dragging = true
		love.mouse.setRelativeMode(true)
	end
end)

register("mousereleased", function(x, y, b)
	if b == 1 then
		dragging = false
		love.mouse.setRelativeMode(false)
	end
end)

local angle = cpml.vec2(0, 0)
local sensitivity = 0.5
register("mousemoved", function(x, y, mx, my)
	if dragging then
		angle.x = angle.x + math.rad(mx * sensitivity)
		angle.y = angle.y + math.rad(my * sensitivity)
	end
end)

register("draw", function()
	-- bind the gbuffer
	love.graphics.setCanvas(unpack(gbuffer))
	love.graphics.clear(
		{ love.graphics.getBackgroundColor() },
		{ 0.0, 1.0, 0.0 }
	)
	l3d.clear()


	-- view matrix (i.e. camera transform)
	local v = cpml.mat4()
	v:translate(v, camera_pos)
	v:rotate(v, -math.pi/2, cpml.vec3.unit_x)
	v:rotate(v, angle.y, cpml.vec3.unit_x)
	v:rotate(v, angle.x, cpml.vec3.unit_z)

	-- projection matrix (i.e. screen transform)
	local p = cpml.mat4.from_perspective(camera_fov, w/h, 0.1, 1000.0)

	-- update shader uniforms. set viewProj once, model for each.
	love.graphics.setShader(gb_fill)
	gb_fill:send("u_viewProj", (v*p):to_vec4s())

	-- enable depth and draw only front-facing polygons
	l3d.set_depth_test("less")
	l3d.set_culling("back")
	love.graphics.setBlendMode("replace")

	for _, object in ipairs(objects) do
		-- model matrix (i.e. local transform)
		local m = cpml.mat4()
		m = m:translate(m, object.position)
		m = m:rotate(m, object.orientation)
		gb_fill:send("u_model", m:to_vec4s())

		for _, buffer in ipairs(object.model) do
			object.model.mesh:setDrawRange(buffer.first, buffer.last)
			love.graphics.draw(object.model.mesh)
		end
	end

	-- reset depth so we can draw 2D again
	l3d.set_depth_test()
	l3d.set_culling()

	love.graphics.setCanvas()

	love.graphics.setShader(post)
	post:send("u_light", {
		light_direction.x, light_direction.y, light_direction.z,
		light_intensity
	})
	post:send("s_normal", gbuffer[2])
	love.graphics.draw(gbuffer[1])

	-- reset blend mode so you can draw things with alpha.
	love.graphics.setBlendMode("alpha")
end)
