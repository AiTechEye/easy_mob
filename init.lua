minetest.register_entity("easy_mob:basicmob",{
-- entity properties

	hp_max = 20,
	collisionbox = {-0.35,-0.01,-0.35,0.35,1.8,0.35},
	physical = true,
	visual = "mesh",
	mesh = "character.b3d",	-- the model & texture is used from the player_ap mod
	textures = {"character.png"},-- so you can borrow resurses from other mods by adding them in the mod.conf --> depends (before it was called depends.txt, now it is outdated)  

-- you can declare variables here too, will be able in "self"

	animation = {
		stand={x=0,y=79,speed=30,loop=false},
		walk={x=168,y=187,speed=30},
		run={x=168,y=187,speed=40},
		attack={x=200,y=219,speed=30},
	},
	type = "npc",
	team = "default",
	time = 0,
	hp = 20,
	damage = 1,
	id = 0,
	movingspeed = 2,
	lifetime = 120,
	
 -- called while the entity is activate and deactivated, the string will be saved in the entity
-- i like to do a "storage" variable so everyting in it will be automacly saved, simple

	get_staticdata = function(self)
		self.storage.hp = self.hp
		return minetest.serialize(self.storage)
	end,


	on_activate=function(self, staticdata)
		self.storage = minetest.deserialize(staticdata) or {}	--load storage or a new
		self.hp = self.storage.hp
		self.object:set_velocity({x=0,y=-1,z=0})
		self.object:set_acceleration({x=0,y=-10,z =0})		-- set the entity gravity, you only need to do it 1 time
		self.id = math.random(1,9999)			--so the mob can determine difference from other mobs
		anim(self,"stand")
								--now the mob is ready
	end,
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		local en = puncher:get_luaentity()
		local dmg = 0
		self.last_punched_by = puncher or self.last_punched_by
		dmg = tool_capabilities.damage_groups.fleshy or 1

		if puncher:is_player() then -- adds wear to the tool, advanced stuff
			local item = minetest.registered_tools[puncher:get_wielded_item():get_name()]
			if item and item.tool_capabilities and item.tool_capabilities.damage_groups then
				local d = tool_capabilities.damage_groups.fleshy
				if d and d > 0 then
					local tool = puncher:get_wielded_item()
					tool:add_wear(math.ceil(self.add_wear/(dmg*dmg)))
					puncher:set_wielded_item(tool)
				end
			end
		end
		self.hp = self.hp - dmg
		self.object:set_properties({nametag=self.hp ,nametag_color="#00ff00"})
		if self.hp <= 0 then
			self.object:remove()
		end
		return self
	end,
	on_step = function(self, dtime)

-- updating the mob each 0.5s is enought and makes it not lag
		self.time = self.time + dtime
		self.lifetime = self.lifetime -dtime
		if self.lifetime <= 0 then -- removing the mob after a time, or there will be too many
			self.object:remove()
			return
		elseif self.target and self.time < 0.1 or not self.target and self.time < 0.5 then
			return self
		end
		self.time = 0
		

		local pos = self.object:get_pos()

--rnd walking
		if self.target == nil then
			local r = math.random(1,4)
			local v = self.object:get_velocity()
			if r == 1 then-- walk randomly
				self.object:set_yaw(math.random(0,6.28))
				walk(self)
			elseif r == 2 then
				stand(self)
			else
				walk(self)
			end
		end

--look for targets

		if self.target == nil then
			local rnd_target
			for _, ob in pairs(minetest.get_objects_inside_radius(pos, 10)) do
				local en = ob:get_luaentity() -- players do not have this property
				local obp = ob:get_pos()

				if (en == nil or en and en.id ~= self.id) and visiable(self,obp) and viewfield(self,obp) then
					rnd_target = ob
					if math.random(1,3) == 1 then --choosing random targets
						break
					end
				end
			end
			self.target = rnd_target
		end
-- attack target
		if self.target then
			local tarp = self.target:get_pos()
			if tarp == nil or visiable(self,tarp) == false or viewfield(self,tarp) == false then-- sometimes the object is gone but not the object
				self.target = nil
				return
			end
			lookat(self,tarp)
			walk(self,2)
			self.lifetime = 120 -- resets lifetime

			if vector.distance(pos,tarp) <= 3 then
				anim(self,"attack")
				self.target:punch(self.object,1,{full_punch_interval=1,damage_groups={fleshy=self.damage}})
				if self.target:get_hp() <= 0 then
					self.target = nil
				end
			end
		end

		if minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name,"cracky") > 0 then -- always jump on nodes with the group "cracky"
			jump(self)
		end
	end
})






function walk(self)
	if math.random(1,3) > 1 then-- stands at 1
		local v = self.object:get_velocity()
		-- setts its old y velocity to not change its fall
		self.object:set_velocity({
			x=math.random(-1,1), 
			y=v.y,
			z=math.random(-1,1)
		})
	end
end

-- check if the anim exists, use it if it's not same as the last
function anim(self,type)
	if self.visual ~= "mesh" or type == self.anim or not self.animation then return end
	local a=self.animation[type]
	if not a then return end
	self.object:set_animation({x=a.x, y=a.y,},a.speed,false,a.loop)
	self.anim=type
end

function jump(self)
	local v = self.object:get_velocity()
	if v.y == 0 then-- dont jump in air
		self.object:set_velocity({x=v.x, y=5.5, z=v.z})
	end
end

function stand(self)
	local v = self.object:get_velocity()
	self.object:set_velocity({
		x = 0,
		y = v.y,	--keep falling
		z = 0
	})
	anim(self,"stand")
end

function walk(self,speed)
	speed = speed and (self.movingspeed*speed) or self.movingspeed -- choosing movingspeed as default if speed is nil

	local yaw = self.object:get_yaw()
	local v = self.object:get_velocity()
	local x = (math.sin(yaw) * -1) * speed
	local z = (math.cos(yaw) * 1) * speed
	self.object:set_velocity({
		x = x,
		y = v.y,
		z = z
	})

	if speed > self.movingspeed then
		anim(self,"run")
	else
		anim(self,"walk")
	end
end

function lookat(self,pos2)
	local pos1 = self.object:get_pos()
	local vec = {x=pos1.x-pos2.x, y=pos1.y-pos2.y, z=pos1.z-pos2.z}
	local yaw = math.atan(vec.z/vec.x)-math.pi/2
	if pos1.x >= pos2.x then
		yaw = yaw+math.pi
	end
	self.object:set_yaw(yaw)
end

function visiable(self,pos2)-- checking if someting is blocking the mobs view
	local pos1 = self.object:get_pos()
	local v = {x = pos1.x - pos2.x, y = pos1.y - pos2.y-1, z = pos1.z - pos2.z}
	v.y=v.y-1
	local amount = (v.x ^ 2 + v.y ^ 2 + v.z ^ 2) ^ 0.5
	local d=vector.distance(pos1,pos2)
	v.x = (v.x  / amount)*-1
	v.y = (v.y  / amount)*-1
	v.z = (v.z  / amount)*-1
	for i=1,d,1 do
		local node = minetest.registered_nodes[minetest.get_node({x=pos1.x+(v.x*i),y=pos1.y+(v.y*i),z=pos1.z+(v.z*i)}).name]
		if node and node.walkable then
			return false
		end
	end
	return true
end

function viewfield(self,p2) -- if target is in the view field
	local ob1 = self.object
	local p1 = ob1:get_pos()
	local a = vector.normalize(vector.subtract(p2, p1))
	local yaw = math.floor(ob1:get_yaw()*100)/100
	local b = {x=math.sin(yaw)*-1,y=0,z=math.cos(yaw)*1}
	local deg = math.acos((a.x*b.x)+(a.y*b.y)+(a.z*b.z)) * (180 / math.pi)
	return not (deg < 0 or deg > 50)
end

minetest.register_craftitem("easy_mob:basicmob_spawner", {
	description = "basicmob spawner",
	inventory_image = "default_stick.png",
	on_place = function(itemstack, user, pointed_thing)
		if pointed_thing.type=="node" then
			local p = pointed_thing.above
			minetest.add_entity({x=p.x,y=p.y+1,z=p.z}, "easy_mob:basicmob"):set_yaw(math.random(0,6.28))
			itemstack:take_item()
		end
		return itemstack
	end
})

minetest.register_abm({
	nodenames = {"default:dirt_with_grass","default:wood"},
	interval = 30,
	chance = 500,
	action = function(pos)
		local u = {x=pos.x,y=pos.y+1,z=pos.z}
		local n = minetest.get_node(u).name
		if n == "air" and (minetest.get_node_light(u) or 0) > 5 then-- place the mob in air in light, get_node_light sometimes returns nil
			minetest.add_entity(u,"easy_mob:basicmob"):set_yaw(math.random(0,6.28))
		end
	end
})