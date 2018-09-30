local iqm   = require "iqm"
local anim9 = require "anim9"
local cpml  = require "cpml"

local filename = "assets/cthulhu.iqm"
local model = iqm.load(filename)
local anim = anim9(iqm.load_anims(filename))

anim:play("walk")
anim:update(0)

local camera_fov = 60
local camera_pos = cpml.vec3(0, -5, -15)
local lightv = cpml.vec3(0, 0.76, 0.65)
lightv = lightv:normalize()

local shader = love.graphics.newShader [[
varying vec3 v_normal;

#ifdef VERTEX
attribute vec4 VertexWeight;
attribute vec4 VertexBone;
attribute vec3 VertexNormal;

uniform mat4 u_model, u_viewproj;
uniform mat4 u_pose[100];

vec4 position(mat4 _, vec4 vertex) {
	mat4 skeleton = u_pose[int(VertexBone.x*255.0)] * VertexWeight.x +
		u_pose[int(VertexBone.y*255.0)] * VertexWeight.y +
		u_pose[int(VertexBone.z*255.0)] * VertexWeight.z +
		u_pose[int(VertexBone.w*255.0)] * VertexWeight.w;

	mat4 transform = u_model * skeleton;

	v_normal = mat3(transform) * VertexNormal;

	return u_viewproj * transform * vertex;
}
#endif
#ifdef PIXEL
uniform vec3 u_light;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
	float shade = max(0, dot(v_normal, u_light)) + 0.25;
	return vec4(vec3(shade) * color.rgb, 1.0);
}
#endif
]]

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

local now = 0
register("update", function(dt)
	now = now + dt
	anim:update(dt)
end)

love.graphics.setBackgroundColor(0.1, 0.2, 0.2)
register("draw", function()
	local w, h = love.graphics.getDimensions()

	local m = cpml.mat4():identity()
	m:translate(m, camera_pos)
	m:rotate(m, -math.pi/2, cpml.vec3.unit_x)
	m:rotate(m, angle.y, cpml.vec3.unit_x)
	m:rotate(m, angle.x, cpml.vec3.unit_z)

	local p = cpml.mat4.from_perspective(camera_fov, w/h, 0.1, 1000.0)

	love.graphics.setShader(shader)
	shader:send("u_model", m:to_vec4s())
	shader:send("u_viewproj", p:to_vec4s())
	shader:send("u_pose", unpack(anim.current_pose))
	shader:send("u_light", {lightv:unpack()})

	love.graphics.setDepthMode("lequal", true)
	love.graphics.setMeshCullMode("back")

	for _, buffer in ipairs(model) do
		model.mesh:setDrawRange(buffer.first, buffer.last)
		love.graphics.draw(model.mesh)
	end

	love.graphics.setDepthMode()
	love.graphics.setMeshCullMode('none')
	love.graphics.setShader()
end)
