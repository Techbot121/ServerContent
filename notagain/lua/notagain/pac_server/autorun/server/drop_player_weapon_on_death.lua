local remove_me = {}

hook.Add("DoPlayerDeath", "drop_player_weapon_on_death", function(ply)
	if remove_me[ply] and remove_me[ply]:IsValid() and not remove_me[ply]:GetOwner():IsValid() then
		if remove_me[ply].death_drop_pos then
			remove_me[ply]:SetPos(remove_me[ply].death_drop_pos)
			remove_me[ply]:SetAngles(remove_me[ply].death_drop_ang)
		end
	end

	local wep = ply:GetActiveWeapon()
	if wep:IsValid() then
		ply:DropWeapon(wep)
		remove_me[ply] = wep

		local atch = ply:GetAttachment(ply:LookupAttachment("anim_attachment_RH"))
		if atch then
			wep:SetPos(atch.Pos)
			wep:SetAngles(atch.Ang)

			wep.death_drop_pos = atch.Pos
			wep.death_drop_ang = atch.Ang

			wep:GetPhysicsObject():SetVelocity(Vector(0,0,0))
		end
	end
end)

hook.Add("PlayerSpawn", "drop_player_weapon_on_death", function(ply)
	if remove_me[ply] and remove_me[ply]:IsValid() and not remove_me[ply]:GetOwner():IsValid() then
		remove_me[ply]:Remove()
	end

	remove_me[ply] = nil
end)

