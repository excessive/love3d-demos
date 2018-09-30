local iqm = require "iqm"
local cpml = require "cpml"

local shader = love.graphics.newShader [[
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
uniform vec4 u_light;

const float exposure = 1.5;
const float gamma = 2.2;

vec4 effect(vec4 _col, Image s_color, vec2 _uv, vec2 _sc) {
	vec4 color  = gammaToLinear(_col);
	vec3 normal = normalize(f_normal);

	float shade = max(0.0, dot(normal, u_light.xyz));
	color.rgb *= shade;
	color.rgb *= u_light.w;

	// RomBinDaHouse
	color.rgb = exp( -1.0 / ( 2.72*color.rgb + 0.15 ) );
	color.rgb = pow(color.rgb, vec3(1.0 / gamma));

	return vec4(color.rgb, 1.0);
}
#endif
]]

local object = {
	model = iqm.load("assets/cthulhu.iqm"),
	position = cpml.vec3(0, 0, 0)
}

local camera_fov = 60
local camera_pos = cpml.vec3(0, -5, -15)
local light_direction = cpml.vec3(0, -0.76, 0.65):normalize()
local light_intensity = 3

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
	-- view matrix (i.e. camera transform)
	local v = cpml.mat4()
	v:translate(v, camera_pos)
	v:rotate(v, -math.pi/2, cpml.vec3.unit_x)
	v:rotate(v, angle.y, cpml.vec3.unit_x)
	v:rotate(v, angle.x, cpml.vec3.unit_z)

	-- projection matrix (i.e. screen transform)
	local w, h = love.graphics.getDimensions()
	local p = cpml.mat4.from_perspective(camera_fov, w/h, 0.1, 1000.0)

	love.graphics.setShader(shader)
	-- update shader uniforms. set viewProj once, model for each.
	shader:send("u_viewProj", (v*p):to_vec4s())
	shader:send("u_light", {
		light_direction.x, light_direction.y, light_direction.z,
		light_intensity
	})

	-- enable depth and draw only front-facing polygons
	love.graphics.setDepthMode("lequal", true)
	love.graphics.setMeshCullMode("back")
	love.graphics.setBlendMode("replace")

	-- model matrix (i.e. local transform)
	local m = cpml.mat4()
	m = m:translate(m, object.position)
	shader:send("u_model", m:to_vec4s())

	for _, buffer in ipairs(object.model) do
		object.model.mesh:setDrawRange(buffer.first, buffer.last)
		love.graphics.draw(object.model.mesh)
	end

	-- reset everything so you can draw 2D again.
	love.graphics.setDepthMode()
	love.graphics.setMeshCullMode("none")
	love.graphics.setBlendMode("alpha")
	love.graphics.setShader()
end)
