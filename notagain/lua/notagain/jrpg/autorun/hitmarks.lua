local hitmarkers = _G.hitmarkers or {}
_G.hitmarkers = hitmarkers

if CLIENT then
	local function set_blend_mode(how)
		if not render.OverrideBlendFunc then return end

		if how == "additive" then
			render.OverrideBlendFunc(true, BLEND_SRC_ALPHA, BLEND_ONE, BLEND_SRC_ALPHA, BLEND_ONE)
		elseif how == "multiplicative" then
			render.OverrideBlendFunc(true, BLEND_DST_COLOR, BLEND_ZERO, BLEND_DST_COLOR, BLEND_ZERO)
		else
			render.OverrideBlendFunc(false)
		end
	end

	local draw_line = requirex("draw_line")
	local draw_rect = requirex("draw_skewed_rect")
	local prettytext = requirex("pretty_text")

	local gradient = CreateMaterial(tostring({}), "UnlitGeneric", {
		["$BaseTexture"] = "gui/center_gradient",
		["$BaseTextureTransform"] = "center .5 .5 scale 1 1 rotate 90 translate 0 0",
		["$VertexAlpha"] = 1,
		["$VertexColor"] = 1,
		["$Additive"] = 0,
	})

	local border = CreateMaterial(tostring({}), "UnlitGeneric", {
		["$BaseTexture"] = "props/metalduct001a",
		["$VertexAlpha"] = 1,
		["$VertexColor"] = 1,
	})

	local function draw_health_bar(x,y, w,h, health, last_health, fade, border_size, skew)
		surface.SetDrawColor(200, 200, 200, 50*fade)
		draw.NoTexture()
		draw_rect(x,y,w,h, skew)

		surface.SetMaterial(gradient)

		surface.SetDrawColor(200, 50, 50, 255*fade)
		for _ = 1, 2 do
			draw_rect(x,y,w*last_health,h, skew, 0, 70, 5, gradient:GetTexture("$BaseTexture"):Width())
		end

		surface.SetDrawColor(0, 200, 100, 255*fade)
		for _ = 1, 2 do
			draw_rect(x,y,w*health,h, skew, 0, 70, 5, gradient:GetTexture("$BaseTexture"):Width())
		end

		surface.SetDrawColor(150, 150, 150, 255*fade)
		surface.SetMaterial(border)

		for _ = 1, 2 do
			draw_rect(x,y,w,h, skew, 1, 64,border_size, border:GetTexture("$BaseTexture"):Width(), true)
		end
	end


	local gradient = Material("gui/gradient_up")
	local border = CreateMaterial(tostring({}), "UnlitGeneric", {
		["$BaseTexture"] = "props/metalduct001a",
		["$VertexAlpha"] = 1,
		["$VertexColor"] = 1,
		["$Additive"] = 1,
	})

	local function draw_weapon_info(x,y, w,h, color, fade)
		set_blend_mode("additive")
		local skew = 0
		surface.SetDrawColor(25, 25, 25, 200*fade)
		draw.NoTexture()
		draw_rect(x,y,w,h, skew)

		surface.SetMaterial(gradient)

		surface.SetDrawColor(color.r, color.g, color.b, 255*fade)
		for _ = 1, 2 do
			draw_rect(x,y,w,h, skew)
		end

		surface.SetDrawColor(200, 200, 200, 255*fade)
		surface.SetMaterial(border)

		for _ = 1, 2 do
			draw_rect(x,y,w,h, skew, 3, 64,4, border:GetTexture("$BaseTexture"):Width(), true)
		end
		set_blend_mode()
	end

	local hitmark_fonts = {
		{
			min = 0,
			max = 0.25,
			font = "Gabriola",
			blur_size = 4,
			weight = 30,
			size = 100,
			color = Color(0, 0, 0, 255),
		},
		{
			min = 0.25,
			max = 0.5,
			font = "Gabriola",
			blur_size = 4,
			weight = 30,
			size = 200,
			color = Color(150, 150, 50, 255),
		},
		{
			min = 0.5,
			max = 1,
			font = "Gabriola",
			blur_size = 4,
			weight = 30,
			size = 300,
			color = Color(200, 50, 50, 255),
		},
		{
			min = 1,
			max = math.huge,
			font = "Gabriola",
			blur_size = 4,
			weight = 100,
			size = 400,
			--color = Color(200, 50, 50, 255),
		},
	}

	local function find_head_pos(ent)
		if not ent.bc_head or ent.bc_last_mdl ~= ent:GetModel() then
			for i = 0, ent:GetBoneCount() do
				local name = ent:GetBoneName(i):lower()
				if name:find("head") then
					ent.bc_head = i
					ent.bc_last_mdl = ent:GetModel()
					break
				end
			end
		end

		if ent.bc_head then
			return ent:GetBonePosition(ent.bc_head)
		end

		return ent:EyePos(), ent:EyeAngles()
	end

	local line_mat = Material("particle/Particle_Glow_04")

	local line_width = 8
	local line_height = -31
	local max_bounce = 2
	local bounce_plane_height = 5

	local life_time = 3
	local hitmarks = {}
	local height_offset = 0

	local health_bars = {}
	local weapon_info = {}

	hook.Add("HUDDrawTargetID", "hitmarks", function()
		return false
	end)

	local function surface_DrawTexturedRectRotatedPoint( x, y, w, h, rot)

		x = math.ceil(x)
		y = math.ceil(y)
		w = math.ceil(w)
		h = math.ceil(h)

		local y0 = -h/2
		local x0 = -w/2

		local c = math.cos( math.rad( rot ) )
		local s = math.sin( math.rad( rot ) )

		local newx = y0 * s - x0 * c
		local newy = y0 * c + x0 * s

		surface.DrawTexturedRectRotated( x + newx, y + newy, w, h, rot )

	end

	-- close enough
	local function draw_RoundedBoxOutlined(border_size, x, y, w, h, color )
		x = math.ceil(x)
		y = math.ceil(y)
		w = math.ceil(w)
		h = math.ceil(h)
		border_size = border_size/2
		surface.SetDrawColor(color)
		surface.DrawRect(x, y, border_size*2, h, color)
		surface.DrawRect(x+border_size*2, y, w-border_size*4, border_size*2)

		surface.DrawRect(x+w-border_size*2, y, border_size*2, h)
		surface.DrawRect(x+border_size*2, y+h-border_size*2, w-border_size*4, border_size*2)
	end

	hook.Add("HUDPaint", "hitmarks", function()
		if hook.Call("HideHitmarks") then
			return
		end

		local ply = LocalPlayer()
		local boss_bar_y = 0

		for i = #health_bars, 1, -1 do
			local data = health_bars[i]
			local ent = data.ent

			if ent:IsValid() then
				local t = RealTime()
				local fraction = (data.time - t) / life_time * 2

				local name

				if ent:IsPlayer() then
					name = ent:Nick()
				else
					name = ent:GetClass()

					local npcs = ents.FindByClass(name)
					if npcs[2] then
						for i, other in ipairs(npcs) do
							other.hm_letter = string.char(64 + i%26)
						end
					end

					if language.GetPhrase(name) then
						name = language.GetPhrase(name)
					end

					if ent.hm_letter then
						name = name .. " " .. ent.hm_letter
					end
				end

				local pos = (ent:NearestPoint(ent:EyePos() + Vector(0,0,100000)) + Vector(0,0,2)):ToScreen()

				if pos.visible then
					surface.DrawRect(pos.x, pos.y, 1,1)

					local cur = ent.hm_cur_health or ent:Health()
					local max = ent.hm_max_health or ent:GetMaxHealth()
					local last = ent.hm_last_health or max

					if max == 0 or cur > max then
						max = 100
						cur = 100
					end

					if not ent.hm_last_health_time or ent.hm_last_health_time < CurTime() then
						last = cur
					end

					data.cur_health_smooth = data.cur_health_smooth or cur
					data.last_health_smooth = data.last_health_smooth or last

					data.cur_health_smooth = data.cur_health_smooth + ((cur - data.cur_health_smooth) * FrameTime() * 5)
					data.last_health_smooth = data.last_health_smooth + ((last - data.last_health_smooth) * FrameTime() * 5)

					local cur = data.cur_health_smooth
					local last = data.last_health_smooth

					local fade = math.Clamp(fraction ^ 0.25, 0, 1)

					local w, h = prettytext.GetTextSize(name, "Candara", 20, 30, 2)

					local height = 8
					local border_size = 3
					local skew = 0
					local width = math.Clamp(ent:BoundingRadius() * 3.5 * (ent:GetModelScale() or 1), w * 1.5,  ScrW()/2)

					if max > 1000 then
						height = 35
						height = 35
						pos.x = ScrW() / 2
						pos.y = 50 + boss_bar_y
						width = ScrW() / 1.1
						skew = 30
						border_size = 10
						boss_bar_y = boss_bar_y + height + 20
					end

					local width2 = width/2
					local text_x_offset = 15

					draw_health_bar(pos.x - width2, pos.y-height/2, width, height, math.Clamp(cur / max, 0, 1), math.Clamp(last / max, 0, 1), fade, border_size, skew)

					prettytext.Draw(name, pos.x - width2 - text_x_offset, pos.y - 5, "Arial", 20, 800, 3, Color(230, 230, 230, 255 * fade), nil, 0, -1)
				end

				if fraction <= 0 then
					table.remove(health_bars, i)
				end
			end
		end

		for i = #weapon_info, 1, -1 do
			local data = weapon_info[i]
			local ent = data.ent

			if not ent:IsValid() then
				table.remove(weapon_info, i)
				continue
			end

			local pos = (ent:NearestPoint(ent:EyePos() + Vector(0,0,100000)) + Vector(0,0,2)):ToScreen()

			if pos.visible then
				local time = RealTime()

				if data.time > time then
					local fade = math.min(((data.time - time) / data.length) + 0.75, 1)
					local w, h = prettytext.GetTextSize(data.name, "Arial", 20, 800, 2)

					local x, y = pos.x, pos.y
					x = x - w / 2
					y = y - h * 3

					local bg
					local fg

					if ent == ply or (ent:IsPlayer() and (ent:GetFriendStatus() == "friend")) then
						fg = Color(200, 220, 255, 255 * fade)
						bg = Color(25, 75, 150, 255 * fade)
					else
						fg = Color(255, 220, 200, 255 * fade)
						bg = Color(200, 50, 25, 255)
					end

					local border = 13
					local scale_h = 0.5

					local border = border
					draw_weapon_info(x - border, y - border*scale_h, w + border*2, h + border*2*scale_h, bg, fade)

					prettytext.Draw(data.name, x, y, "Arial", 20, 600, 3, fg)
				else
					table.remove(weapon_info, i)
				end
			end
		end

		if hitmarks[1] then
			local d = FrameTime()

			for i = #hitmarks, 1, -1 do
				local data = hitmarks[i]
				local t = RealTime() + data.offset

				local fraction =  (data.life - t) / life_time
				local pos = data.real_pos

				if data.ent:IsValid() then
					pos = LocalToWorld(data.real_pos, Angle(0,0,0), data.ent:GetPos(), data.first_angle)
					data.last_pos = pos
				else
					pos = data.last_pos or pos
				end

				local fade = math.Clamp(fraction ^ 0.25, 0, 1)

				if data.bounced < max_bounce then
					data.vel = data.vel + Vector(0,0,-0.25)
					data.vel = data.vel * 0.99
				else
					data.vel = data.vel * 0.85
				end

				if data.pos.z < -bounce_plane_height and data.bounced < max_bounce then
					data.vel.z = -data.vel.z * 0.5
					data.pos.z = -bounce_plane_height

					data.bounced = data.bounced + 1

					if data.bounced == max_bounce then
						data.vel.z = data.vel.z * -1
					end
				end

				data.pos = data.pos + data.vel * d * 25

				pos = (pos + data.pos + Vector(0, 0, bounce_plane_height)):ToScreen()

				local txt = math.Round(Lerp(math.Clamp(fraction-0.95, 0, 1), data.dmg, 0))

				if data.dmg == 0 then
					txt = "MISS"
				elseif data.dmg > 0 then
					txt = "+" .. txt
				end

				if pos.visible then

					local x = pos.x + data.pos.x
					local y = pos.y + data.pos.y

					if fade < 0.5 then
						y = y + (fade-0.5)*150
					end

					surface.SetAlphaMultiplier(fade)

					local fraction = -data.dmg / data.max_health

					local font_info = hitmark_fonts[1]

					for _, info in ipairs(hitmark_fonts) do
						if fraction >= info.min and fraction <= info.max then
							font_info = info
							break
						end
					end

					if fraction >= 1 then
						font_info.color = HSVToColor((t*500)%360, 0.75, 1)
					end


					local w, h = prettytext.GetTextSize(txt, font_info.font, font_info.size, font_info.weight, font_info.blur_size)
					local hoffset = data.height_offset * -h * 0.5

					if data.dmg == 0 then
						surface.SetDrawColor(255, 255, 255, 255)
					elseif data.rec then
						surface.SetDrawColor(100, 255, 100, 255)
					else
						surface.SetDrawColor(255, 100, 100, 255)
					end

					surface.SetMaterial(line_mat)

					draw_line(
						x - w, hoffset + y + h + line_height,
						x - w + w * 3, hoffset + y + h + line_height,
						line_width,
						true
					)

					prettytext.Draw(txt, x, hoffset + y, font_info.font, font_info.size, font_info.weight, font_info.blur_size, Color(255, 255, 255, 255), font_info.color)

					surface.SetAlphaMultiplier(1)
				end

				if fraction <= 0 then
					table.remove(hitmarks, i)
				end
			end
		end
	end)

	function hitmarkers.ShowHealth(ent, focus)
		if focus then
			table.Empty(health_bars)
		else
			for i, data in ipairs(health_bars) do
				if data.ent == ent then
					table.remove(health_bars, i)
					break
				end
			end
		end
		table.insert(health_bars, {ent = ent, time = focus and math.huge or (RealTime() + life_time * 2)})
	end

	function hitmarkers.ShowAttack(ent, name)
		for i, data in ipairs(weapon_info) do
			if data.ent == ent then
				table.remove(weapon_info, i)
				break
			end
		end

		local length = 2
		table.insert(weapon_info, {name = name, ent = ent, time = RealTime() + length, length = length})
	end

	function hitmarkers.ShowDamage(ent, dmg, pos, type)
		ent = ent or NULL
		dmg = dmg or 0
		pos = pos or ent:EyePos()

		if ent:IsValid() then
			pos = ent:WorldToLocal(pos)
		end

		local rec = dmg > 0

		local vel = VectorRand()
		local offset = math.random() * 10

		height_offset = (height_offset + 1)%5

		table.insert(
			hitmarks,
			{
				ent = ent,
				first_angle = ent:IsValid() and ent:GetAngles() or Angle(0,0,0),
				real_pos = pos,
				dmg = dmg,
				max_health = ent.hm_max_health or dmg,

				life = RealTime() + offset + life_time + math.random(),
				dir = vel,
				pos = Vector(),
				vel = vel,
				rec = rec,

				offset = offset,
				height_offset = height_offset,

				bounced = 0,
				type = type,
			}
		)

		hitmarkers.ShowHealth(ent)
	end

	timer.Create("hitmark", 0.25, 0, function()
		local ply = LocalPlayer()
		if not ply:IsValid() then return end
		local data = ply:GetEyeTrace()
		local ent = data.Entity
		if ent:IsNPC() or ent:IsPlayer() then
			hitmarkers.ShowHealth(ent)
		end

		for _, ent in pairs(ents.FindInSphere(ply:GetPos(), 1000)) do
			if ent:IsNPC() or ent:IsPlayer() then
				local wep = ent:GetActiveWeapon()
				local name

				if wep:IsValid() and wep:GetClass() ~= ent.hm_last_wep then
					name = wep:GetClass()
					ent.hm_last_wep = name
				end

				if ent:IsNPC() then
					local seq_name = ent:GetSequenceName(ent:GetSequence()):lower()

					if not seq_name:find("idle") and not seq_name:find("run") and not seq_name:find("walk") then
						local fixed = seq_name:gsub("shoot", "")
						fixed = fixed:gsub("attack", "")
						fixed = fixed:gsub("loop", "")

						if fixed:Trim() == "" or not fixed:find("[a-Z]") then
							name = seq_name
						else
							name = fixed
						end

						name = name:gsub("_", " ")
						name = name:gsub("%d", "")
						name = name:gsub("^%l", function(s) return s:upper() end)
						name = name:gsub(" %l", function(s) return s:upper() end)
						name = name:Trim()

						if name == "" then
							name = seq_name
						end
					end
				end

				if name then
					if language.GetPhrase(name) then
						name = language.GetPhrase(name)
					end

					hitmarkers.ShowAttack(ent, name)
					hitmarkers.ShowHealth(ent)
				end
			end
		end
	end)

	net.Receive("hitmark", function()
		local ent = net.ReadEntity()
		local dmg = math.Round(net.ReadFloat())
		local pos = net.ReadVector()
		local cur = math.Round(net.ReadFloat())
		local max = math.Round(net.ReadFloat())
		local type = net.ReadInt(32)

		if not ent.hm_last_health_time or ent.hm_last_health_time < CurTime() then
			ent.hm_last_health = ent.hm_cur_health or max
		end

		ent.hm_last_health_time = CurTime() + 3

		ent.hm_cur_health = cur
		ent.hm_max_health = max


		hitmarkers.ShowDamage(ent, dmg, pos, type)
	end)
end

if SERVER then
	function hitmarkers.ShowDamage(ent, dmg, pos, type, filter)
		ent = ent or NULL
		dmg = dmg or 0
		pos = pos or ent:EyePos()
		type = type or 0
		filter = filter or player.GetAll()

		net.Start("hitmark")
			net.WriteEntity(ent)
			net.WriteFloat(dmg)
			net.WriteVector(pos)
			net.WriteFloat(ent.ACF and ent.ACF.Health or ent.ee_cur_hp or ent:Health())
			net.WriteFloat(ent.ACF and ent.ACF.MaxHealth or ent.ee_max_hp or ent:GetMaxHealth())
			net.WriteInt(type, 32)
		net.Send(filter)
	end

	util.AddNetworkString("hitmark")

	hook.Add("EntityTakeDamage", "hitmarker", function(ent, dmg)
		if not (dmg:GetAttacker():IsNPC() or dmg:GetAttacker():IsPlayer()) then return end

		local filter = {}
		for k,v in pairs(player.GetAll()) do
			if v ~= ent and v:GetPos():Distance(ent:GetPos()) < 1500 * (ent:GetModelScale() or 1) then
				table.insert(filter, v)
			end
		end

		local last_health = ent:Health()
		local health = -dmg:GetDamage()
		local pos = dmg:GetDamagePosition()

		if pos == vector_origin then
			pos = ent:GetPos()
		end

		if ent.ee_cur_hp then
			last_health = ent.ee_cur_hp
		end

		timer.Simple(0, function()
			if ent:IsValid() then
				if ent.ee_cur_hp then
					health = -(last_health - ent.ee_cur_hp)
				elseif last_health == ent:Health() then
					if ent:IsNPC() or ent:IsPlayer() then
						health = 0
					else
						return
					end
				elseif (ent:Health() - last_health) ~= health then
					health = ent:Health() - last_health
				end

				hitmarkers.ShowDamage(ent, health, pos, dmg:GetDamageType(), filter)
			end
		end)
	end)

	if ACF_Damage then
		old_ACF_Damage = old_ACF_Damage or ACF_Damage

		function ACF_Damage(...)
			local res = {old_ACF_Damage(...)}

			local data = res[1]
			if type(data) == "table" and data.Damage then
				local ent = select(1, ...)
				if IsEntity(ent) and ent:IsValid() and math.floor(data.Damage) ~= 0 then
					hitmarkers.ShowDamage(ent, -data.Damage, ent:GetPos(), data.Damage > 500)
				end
			end

			return unpack(res)
		end
	end

	timer.Create("hitmarker",1, 0, function()
		for _, ent in ipairs(ents.GetAll()) do
			if ent:IsPlayer() or ent:IsNPC() then
				if ent.hm_last_health ~= ent:Health() then
					local diff = ent:Health() - (ent.hm_last_health or 0)
					if diff > 0 then
						hitmarkers.ShowDamage(ent, diff)
					end
					ent.hm_last_health = ent:Health()
				end
			end
		end
	end)
end

return hitmarkers