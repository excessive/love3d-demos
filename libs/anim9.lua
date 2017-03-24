local cpml = require "cpml"

local anim = {
	_LICENSE     = "anim9 is distributed under the terms of the MIT license. See LICENSE.md.",
	_URL         = "https://github.com/excessive/anim9",
	_VERSION     = "0.1.2",
	_DESCRIPTION = "Animation library for LÖVE3D.",
}
anim.__index = anim

local function calc_bone_matrix(pos, rot, scale)
	local out = cpml.mat4()
	return out
		:translate(out, pos)
		:rotate(out, rot)
		:scale(out, scale)
end

local function bind_pose(skeleton)
	local pose = {}
	for i = 1, #skeleton do
		pose[i] = {
			translate = skeleton[i].position,
			rotate    = skeleton[i].rotation,
			scale     = skeleton[i].scale
		}
	end
	return pose
end

local function add_poses(skeleton, p1, p2)
	local new_pose = {}
	for i = 1, #skeleton do
		local inv = p1[i].rotate:clone()
		inv = inv:inverse()
		new_pose[i] = {
			translate = p1[i].translate + (p2[i].translate - p1[i].translate),
			rotate    = (p2[i].rotate * inv) * p1[i].rotate,
			scale     = p1[i].scale + (p2[i].scale - p1[i].scale)
		}
	end
	return new_pose
end

local function mix_poses(skeleton, p1, p2, weight)
	local new_pose = {}
	for i = 1, #skeleton do
		local r = cpml.quat.slerp(p1[i].rotate, p2[i].rotate, weight)
		r = r:normalize()
		new_pose[i] = {
			translate = cpml.vec3.lerp(p1[i].translate, p2[i].translate, weight),
			rotate    = r,
			scale     = cpml.vec3.lerp(p1[i].scale, p2[i].scale, weight)
		}
	end
	return new_pose
end

local function update_matrices(skeleton, base, pose)
	local animation_buffer = {}
	local transform = {}
	local bone_lookup = {}

	for i, joint in ipairs(skeleton) do
		local m = calc_bone_matrix(pose[i].translate, pose[i].rotate, pose[i].scale)
		local render

		if joint.parent > 0 then
			assert(joint.parent < i)
			transform[i] = m * transform[joint.parent]
			render       = base[i] * transform[i]
		else
			transform[i] = m
			render       = base[i] * m
		end

		bone_lookup[joint.name] = transform[i]
		table.insert(animation_buffer, render:to_vec4s())
	end
	table.insert(animation_buffer, animation_buffer[#animation_buffer])
	return animation_buffer, bone_lookup
end

local function new(data, anims)
	if not data.skeleton then return end

	local t = {
		active       = {},
		animations   = {},
		skeleton     = data.skeleton,
		inverse_base = {},
		bind_pose    = bind_pose(data.skeleton)
	}

	-- Calculate inverse base pose.
	for i, bone in ipairs(data.skeleton) do
		local m = calc_bone_matrix(bone.position, bone.rotation, bone.scale)
		local inv = cpml.mat4():invert(m)

		if bone.parent > 0 then
			assert(bone.parent < i)
			t.inverse_base[i] = t.inverse_base[bone.parent] * inv
		else
			t.inverse_base[i] = inv
		end
	end

	local o = setmetatable(t, anim)
	if anims ~= nil and not anims then
		return o
	end
	for _, v in ipairs(anims or data) do
		o:add_animation(v, data.frames)
	end
	return o
end

function anim:add_animation(animation, frame_data)
	local new_anim = {
		name      = animation.name,
		frames    = {},
		length    = animation.last - animation.first,
		framerate = animation.framerate,
		loop      = animation.loop
	}

	for i = animation.first, animation.last do
		table.insert(new_anim.frames, frame_data[i])
	end
	self.animations[new_anim.name] = new_anim
end

local function new_animation(name, weight, rate, callback)
	return {
		name     = assert(name),
		frame    = 1,
		time     = 0,
		marker   = 0,
		rate     = rate or 1,
		weight   = weight or 1,
		callback = callback or false,
		playing  = true,
		blend    = 1.0
	}
end

function anim:reset(name)
	if not self.active[name] then
		for _, v in ipairs(self.active) do
			self:reset(v.name)
		end
		return
	end

	if not self.active[name] then return end
	self.active[name].time   = 0
	self.active[name].marker = 0
	self.active[name].frame  = 1
end

function anim:transition(name, time, callback)
	if self.transitioning and self.transitioning.name == name then
		return
	end

	if self.active[name] then
		return
	end

	self.transitioning = {
		name = name,
		length = time,
		time = 0
	}

	self:play(name, 1.0, 1.0, callback)
	self.active[name].blend = 0.0
end

function anim:play(name, weight, rate, callback)
	if self.active[name] then
		self.active[name].playing = true
		return
	end
	assert(self.animations[name], string.format("Invalid animation: '%s'", name))
	self.active[name] = new_animation(name, weight, rate, callback)
	table.insert(self.active, self.active[name])
end

function anim:pause(name)
	if not self.active[name] then
		for _, v in ipairs(self.active) do
			self:pause(v.name)
		end
		return
	end
	self.active[name].playing = not self.active[name].playing
end

function anim:stop(name)
	if not self.active[name] then
		for _, v in ipairs(self.active) do
			self:stop(v.name)
		end
		return
	end
	self.active[name] = nil
	for i, v in ipairs(self.active) do
		if v.name == name then
			table.remove(self.active, i)
			break
		end
	end
end

function anim:length(aname)
	local _anim = assert(self.animations[aname], string.format("Invalid animation: \'%s\'", aname))
	return _anim.length / _anim.framerate
end

function anim:step(name, reverse)
	assert(self.animations[name], string.format("Invalid animation: '%s'", name))
	local _anim = self.animations[name]
	local length = _anim.length / _anim.framerate
	local meta = self.animations[name]

	if reverse then
		meta.time = meta.time - (1/_anim.framerate)
	else
		meta.time = meta.time + (1/_anim.framerate)
	end

	if _anim.loop then
		if meta.time < 0 then
			meta.time = meta.time + length
		end
		meta.time = cpml.utils.wrap(meta.time, length)
	else
		if meta.time < 0 then
			meta.time = 0
		end
		meta.time = math.min(meta.time, length)
	end

	local position = self.current_time * _anim.framerate
	local frame = _anim.frames[math.floor(position)+1]
	meta.frame = frame

	-- Update the final pose
	local pose = mix_poses(self.skeleton, frame, frame, 0)
	self.current_pose, self.current_matrices = update_matrices(
		self.skeleton, self.inverse_base, pose
	)
end

function anim:update(dt)
	if #self.active == 0 then
		return
	end

	if self.transitioning then
		local t = self.transitioning
		t.time = t.time + dt

		local progress = math.min(t.time / t.length, 1)

		for _, meta in ipairs(self.active) do
			meta.blend = cpml.utils.lerp(0, 1, progress)

			-- invert the target, so it crossfades.
			if meta.name ~= t.name then
				meta.blend = 1.0-meta.blend
			end
		end

		if progress == 1 then
			for _, v in ipairs(self.active) do
				if v.name ~= t.name then
					self:stop(v.name)
				end
			end
			self.transitioning = nil
		end
	end

	local pose = self.bind_pose
	for _, meta in ipairs(self.active) do
		local over = false
		local _anim = self.animations[meta.name]
		local length = _anim.length / _anim.framerate
		meta.time = meta.time + dt * meta.rate
		if meta.time >= length then
			if type(meta.callback) == "function" then
				meta.callback(self)
			end
		end

		-- If we're not looping, we just want to leave the animation at the end.
		if _anim.loop then
			meta.time = cpml.utils.wrap(meta.time, length)
		else
			if meta.time > length then
				over = true
			end
			meta.time = math.min(meta.time, length)
		end

		local position = meta.time * _anim.framerate
		local f1, f2 = math.floor(position), math.ceil(position)
		position = position - f1
		f2 = f2 % (_anim.length)

		meta.frame = f1

		-- Update the final pose
		local interp = mix_poses(
			self.skeleton,
			_anim.frames[f1+1],
			_anim.frames[f2+1],
			position
		)

		local mix = mix_poses(self.skeleton, pose, interp, meta.weight * meta.blend)
		pose = add_poses(self.skeleton, pose, mix)

		if over then
			self:stop(meta.name)
		end
	end

	self.current_pose, self.current_matrices = update_matrices(
		self.skeleton, self.inverse_base, pose
	)
end

return setmetatable({
	new = new
}, {
	__call = function(_, ...) return new(...) end
})
