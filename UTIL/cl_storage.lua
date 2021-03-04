--[[
---------------------------------------------------
LUXART VEHICLE CONTROL V3 (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_storage.lua
PURPOSE: Handle save/load functions and version 
		 checking
---------------------------------------------------
]]
Storage = { }

local save_prefix = "lvc_"
local repo_version = nil
local backup_tone_table = {}
local custom_tone_names = false
local SIRENS_backup_string = nil

------------------------------------------------
--Deletes all saved KVPs for that vehicle profile
RegisterCommand('lvcfactoryreset', function(source, args)
	local choice = HUD:FrontEndAlert("Warning", "Are you sure you want to delete all saved LVC data and Factory Reset?")
	if choice then
		local handle = StartFindKvp(save_prefix);
		local key = FindKvp(handle)
		while key ~= nil do
			DeleteResourceKvp(key)
			UTIL:Print("LVC Info: Deleting Key \"" .. key .. "\"", true)
			key = FindKvp(handle)
			Citizen.Wait(0)
		end
		Storage:ResetSettings()
		UTIL:Print("Success: cleared all save data.", true)
		HUD:ShowNotification("~g~Success~s~: You have deleted all save data and reset LVC.", true)
	end
end)
------------------------------------------------
-- Resource Start Initialization
Citizen.CreateThread(function()
	Citizen.Wait(500)
	TriggerServerEvent('lvc_GetRepoVersion_s')
end)

--[[Getter for current version used in RageUI.]]
function Storage:GetCurrentVersion()
	local curr_version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
	if curr_version ~= nil then
		return curr_version
	else
		return "unknown"
	end
end

--[[Getter for repo version used in RageUI.]]
function Storage:GetRepoVersion()
	return repo_version
end

--[[Getter for out-of-date notification for RageUI.]]
function Storage:GetIsNewerVersion()
	return IsNewerVersion(repo_version, curr_version)
end

--[[Saves all KVP values.]]
function Storage:SaveSettings()
	local settings_string = nil
	SetResourceKvp(save_prefix .. "save_version", Storage:GetCurrentVersion())
	
	--HUD Settings
	local hud_save_data = { Show_HUD = HUD:GetHudState(),
							HUD_Scale = HUD:GetHudScale(), 
							HUD_pos = HUD:GetHudPosition() 
						  }
	SetResourceKvp(save_prefix .. "hud_data",  json.encode(hud_save_data))

	--Profile Specific Settings
	if UTIL:GetVehicleProfileName() ~= nil then
		local profile_name = string.gsub(UTIL:GetVehicleProfileName(), " ", "_")
		if profile_name ~= nil then
			local profile_save_data = {  PMANU = UTIL:GetToneID('PMANU'), 
										 SMANU = UTIL:GetToneID('SMANU'),
										 AUX   = UTIL:GetToneID('AUX'),
										 airhorn_intrp 		= tone_airhorn_intrp,
										 main_reset_standby = tone_main_reset_standby,
										 park_kill 			= park_kill,
										 custom_tone_names 	= custom_tone_names,
										 tone_options = json.encode(UTIL:GetToneOptionsTable()),
									   }

			SetResourceKvp(save_prefix .. "profile_"..profile_name,  json.encode(profile_save_data))
			UTIL:Print("LVC:STORAGE: saving "..save_prefix .. "profile_"..profile_name)
			
			if custom_tone_names then
				local tone_names = { }
				for i, siren_pkg in pairs(SIRENS) do
					table.insert(tone_names, siren_pkg)
				end
				SetResourceKvp(save_prefix .. "siren_names", json.encode(tone_names))
				UTIL:Print("LVC:STORAGE: saving "..save_prefix.."profile_"..profile_name.."_siren_names...")		
			end
			
			--Audio Settings
			local audio_save_data = {	button_sfx_scheme = button_sfx_scheme,
										on_volume 					= on_volume,
										off_volume 					= off_volume,
										upgrade_volume 				= upgrade_volume,
										downgrade_volume 			= downgrade_volume,
										activity_reminder_volume 	= activity_reminder_volume,
										hazards_volume 				= hazards_volume,
										lock_volume 				= lock_volume,
										lock_reminder_volume 		= lock_reminder_volume,
										airhorn_button_SFX 			= airhorn_button_SFX,
										manu_button_SFX 			= manu_button_SFX,
										activity_reminder_index 	= activity_reminder_index,	
									}						
			SetResourceKvp(save_prefix.."profile_"..profile_name.."_audio_data",  json.encode(audio_save_data))
			UTIL:Print("LVC:STORAGE: saving profile_"..profile_name.."_audio_data")
		else
			HUD:ShowNotification("~b~LVC: ~r~ SAVE ERROR~s~: profile_name after gsub is nil.", true)
		end
	else
		HUD:ShowNotification("~b~LVC: ~r~SAVE ERROR~s~: UTIL:GetVehicleProfileName() returned nil.", true)
	end
end

------------------------------------------------
--[[Loads all KVP values.]]
function Storage:LoadSettings()	
	local comp_version = GetResourceMetadata(GetCurrentResourceName(), 'compatible', 0)
	local save_version = GetResourceKvpString(save_prefix .. "save_version")
	local incompatible = IsNewerVersion(comp_version, save_version)
	
	--Is save present if so what version
	if incompatible then
		AddTextEntry("lvc_mismatch_version","~r~~h~Warning:~h~ ~s~Luxart Vehicle Control Save Version Mismatch.\n~b~Compatible Version: " .. comp_version .. "\n~o~Save Version: " .. save_version .. "~s~\nYou may experience issues, to prevent this message from appearing verify settings and resave.")
		SetNotificationTextEntry("lvc_mismatch_version")
		DrawNotification(false, true)
	end
	
	if save_version ~= nil then
		--HUD Settings	
		local hud_save_data = GetResourceKvpString(save_prefix.."hud_data")
		if hud_save_data ~= nil then
			hud_save_data = json.decode(hud_save_data)
			HUD:SetHudState(hud_save_data.Show_HUD)
			HUD:SetHudScale(hud_save_data.HUD_Scale)
			HUD:SetHudPosition(hud_save_data.HUD_pos)
			UTIL:Print("LVC:STORAGE: loaded HUD data.")		
		end
		
		--Profile Specific Settings
		if UTIL:GetVehicleProfileName() ~= nil then
			local profile_name = string.gsub(UTIL:GetVehicleProfileName(), " ", "_")	
			if profile_name ~= nil then
				local profile_save_data = GetResourceKvpString(save_prefix.."profile_"..profile_name)
				if profile_save_data ~= nil then
					profile_save_data = json.decode(profile_save_data)
					UTIL:SetToneByID('PMANU', profile_save_data.PMANU)
					UTIL:SetToneByID('SMANU', profile_save_data.SMANU)
					UTIL:SetToneByID('AUX', profile_save_data.AUX)
					if main_siren_settings_masterswitch then
						tone_airhorn_intrp 		= profile_save_data.airhorn_intrp
						tone_main_reset_standby = profile_save_data.main_reset_standby
						park_kill 				= profile_save_data.park_kill
						custom_tone_names 		= profile_save_data.custom_tone_names
						local tone_options = json.decode(profile_save_data.tone_options)
							if tone_options ~= nil then
								for tone_id, option in pairs(tone_options) do
									if SIRENS[tone_id] ~= nil then
										SIRENS[tone_id].Option = option
									end
								end
							end
					end
					UTIL:Print("LVC:STORAGE: loaded "..profile_name..".")
				end
			
				if main_siren_settings_masterswitch then
					if custom_tone_names then
						local tone_names = GetResourceKvpString(save_prefix.."profile_"..profile_name.."_tone_names")
						if tone_names ~= nil then
							tone_names = json.decode(tone_names)
							for i, name in pairs(tone_names) do
								if SIRENS[i] ~= nil then
									SIRENS[i].Name = name
								end
							end
						end
						UTIL:Print("LVC:STORAGE: loaded "..profile_name.." custom tone names.")
					end
				end
			
				--Audio Settings 
				local audio_save_data = GetResourceKvpString(save_prefix.."profile_"..profile_name.."_audio_data")
				if audio_save_data ~= nil then
					audio_save_data = json.decode(audio_save_data)
					button_sfx_scheme 			= audio_save_data.button_sfx_scheme
					on_volume 					= audio_save_data.on_volume
					off_volume 					= audio_save_data.off_volume
					upgrade_volume 				= audio_save_data.upgrade_volume
					downgrade_volume 			= audio_save_data.downgrade_volume
					activity_reminder_volume 	= audio_save_data.activity_reminder_volume
					hazards_volume 				= audio_save_data.hazards_volume
					lock_volume 				= audio_save_data.lock_volume
					lock_reminder_volume 		= audio_save_data.lock_reminder_volume
					airhorn_button_SFX 			= audio_save_data.airhorn_button_SFX
					manu_button_SFX 			= audio_save_data.manu_button_SFX
					activity_reminder_index 	= audio_save_data.activity_reminder_index
					UTIL:Print("LVC:STORAGE: loaded audio data.")
				end
			else
				HUD:ShowNotification("~b~LVC:~r~ LOADING ERROR~s~: profile_name after gsub is nil.", true)
			end
		end
	end
end

------------------------------------------------
--[[Resets all KVP/menu values to their default.]]
function Storage:ResetSettings()
	settings_init = false
	show_HUD = hud_first_default
	HUD:SetHudScale(0.7)
	HUD:ResetPosition()
	key_lock = false				
	
	UTIL:SetToneByPos('ARHRN', 1)
	UTIL:SetToneByPos('PMANU', 2)
	UTIL:SetToneByPos('SMANU', 3)
	UTIL:SetToneByPos('AUX',	2)
	UTIL:SetToneByPos('MAIN_MEM', 2)
	
	tone_main_reset_standby = reset_to_standby_default
	tone_airhorn_intrp = airhorn_interrupt_default
	park_kill = park_kill_default
	custom_tone_names = false
	Storage:RestoreBackupTable()
	UTIL:BuildToneOptions()
	
	airhorn_button_SFX = false
	manu_button_SFX = false
	activity_reminder_index = 1
	last_activity_timer = 0

	button_sfx_scheme_id = 1
	button_sfx_scheme 			= default_sfx_scheme_name
	on_volume 					= default_on_volume	
	off_volume 					= default_off_volume	
	upgrade_volume 				= default_upgrade_volume	
	downgrade_volume 			= default_downgrade_volume
	hazards_volume 				= default_hazards_volume
	lock_volume 				= default_lock_volume
	lock_reminder_volume 		= default_lock_reminder_volume
	activity_reminder_volume 	= default_reminder_volume
end

------------------------------------------------
--[[Setter for JSON string backup of SIRENS table in case of reset since we modify SIREN table directly.]]
function Storage:SetBackupTable()
	SIRENS_backup = json.encode(SIRENS)
end

--[[Setter for SIRENS table using backup string of table.]]
function Storage:RestoreBackupTable()
	SIRENS = json.decode(SIRENS_backup)
end

--[[Setter for bool that is used in saving to determine if tone strings have been modified.]]
function Storage:SetCustomToneStrings(toggle)
	custom_tone_names = toggle
end

------------------------------------------------
--HELPER FUNCTIONS for main siren settings saving:end
--Compare Version Strings: Is version newer than test_version
function IsNewerVersion(version, test_version)
	if version == nil or test_version == nil then
		return false
	end
	
	_, _, s1, s2, s3 = string.find( version, "(%d+)%.(%d+)%.(%d+)" )
	_, _, c1, c2, c3 = string.find( test_version, "(%d+)%.(%d+)%.(%d+)" )
	
	if s1 > c1 then				-- s1.0.0 Vs c1.0.0
		return true
	elseif s1 < c1 then
		return false
	else
		if s2 > c2 then			-- 0.s2.0 Vs 0.c2.0
			return true
		elseif s2 < c2 then
			return false
		else
			if s3 > c3 then		-- 0.0.s3 Vs 0.0.c3
				return true
			else
				return false
			end
		end
	end
end

---------------------------------------------------------------------
--[[Callback for Server -> Client version update.]]
RegisterNetEvent("lvc_SendRepoVersion_c")
AddEventHandler("lvc_SendRepoVersion_c", function(sender, version)
	repo_version = version
end)