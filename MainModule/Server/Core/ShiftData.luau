--!nonstrict
--// ShiftData Module - Handles persistent storage of shift statistics
return function(Vargs, GetEnv)
	local env = GetEnv(nil, {script = script})
	setfenv(1, env)

	local server = Vargs.Server
	local service = Vargs.Service

	local Settings, Core, Logs
	local logError = env.logError

	local ShiftDataStore = nil

	local function Init()
		Settings = server.Settings
		Core = server.Core
		Logs = server.Logs

		-- Initialize the datastore
		local success, result = pcall(function()
			return service.DataStoreService:GetDataStore("Madonis_Shift_Data", "ShiftStats")
		end)

		if success and result then
			ShiftDataStore = result
			Logs:AddLog("Script", "ShiftData Module Initialized Successfully")
		else
			warn("Failed to initialize ShiftData DataStore:", result)
			Logs:AddLog("Script", "ShiftData Module Failed to Initialize: " .. tostring(result))
		end
	end

	--[[
		Data Structure for each player:
		{
			TotalShiftTime = 0,           -- Total seconds spent on shift
			TotalShifts = 0,              -- Total number of shifts completed
			LastShiftType = "Moderation", -- Type of last shift (for future expansion)
			LastShiftTime = 0,            -- Duration of last shift in seconds
			LastShiftDate = "",           -- ISO date of last shift
		}
	]]--

	-- Forward declare functions
	local GetPlayerData, SavePlayerData, GetAverageShiftTime, FormatTime, GetFormattedStats

	--// Format seconds into readable time string
	FormatTime = function(seconds)
		if seconds < 60 then
			return string.format("%d second%s", seconds, seconds ~= 1 and "s" or "")
		elseif seconds < 3600 then
			local minutes = math.floor(seconds / 60)
			local secs = seconds % 60
			return string.format("%d minute%s %d second%s", minutes, minutes ~= 1 and "s" or "", secs, secs ~= 1 and "s" or "")
		else
			local hours = math.floor(seconds / 3600)
			local minutes = math.floor((seconds % 3600) / 60)
			local secs = seconds % 60
			return string.format("%d hour%s %d minute%s %d second%s", hours, hours ~= 1 and "s" or "", minutes, minutes ~= 1 and "s" or "", secs, secs ~= 1 and "s" or "")
		end
	end

	--// Get shift data for a player
	GetPlayerData = function(userId: number)
		if not ShiftDataStore then
			warn("ShiftDataStore not initialized")
			return nil
		end

		local success, data = pcall(function()
			return ShiftDataStore:GetAsync(tostring(userId))
		end)

		if success and data then
			return data
		else
			-- Return default data structure if no data exists or error occurred
			return {
				TotalShiftTime = 0,
				TotalShifts = 0,
				LastShiftType = "None",
				LastShiftTime = 0,
				LastShiftDate = "Never",
			}
		end
	end

	--// Save shift data for a player
	SavePlayerData = function(userId: number, shiftDuration: number, shiftType: string)
		if not ShiftDataStore then
			warn("ShiftDataStore not initialized")
			return false
		end

		local success, result = pcall(function()
			ShiftDataStore:UpdateAsync(tostring(userId), function(oldData)
				local data = oldData or {
					TotalShiftTime = 0,
					TotalShifts = 0,
					LastShiftType = "None",
					LastShiftTime = 0,
					LastShiftDate = "Never",
				}

				-- Update the data
				data.TotalShiftTime = data.TotalShiftTime + shiftDuration
				data.TotalShifts = data.TotalShifts + 1
				data.LastShiftType = shiftType
				data.LastShiftTime = shiftDuration
				data.LastShiftDate = os.date("%Y-%m-%d %H:%M:%S", os.time())

				return data
			end)
		end)

		if success then
			Logs:AddLog("ShiftData", "Successfully saved shift data for UserId: " .. tostring(userId))
			return true
		else
			warn("Failed to save shift data for UserId:", userId, "Error:", result)
			Logs:AddLog("ShiftData", "Failed to save shift data for UserId: " .. tostring(userId) .. " Error: " .. tostring(result))
			return false
		end
	end

	--// Calculate average shift time for a player
	GetAverageShiftTime = function(userId: number)
		local data = GetPlayerData(userId)

		if data and data.TotalShifts > 0 then
			return math.floor(data.TotalShiftTime / data.TotalShifts)
		else
			return 0
		end
	end

	--// Get formatted statistics for a player
	GetFormattedStats = function(userId: number, playerName: string)
		local data = GetPlayerData(userId)
		local averageTime = GetAverageShiftTime(userId)

		if not data then
			return "Unable to retrieve shift data."
		end

		local stats = string.format(
			"<b><font color='rgb(100, 200, 255)'>Shift Statistics for %s</font></b>\n\n" ..
			"<b>Total Shifts:</b> %d\n" ..
			"<b>Total Time on Duty:</b> %s\n" ..
			"<b>Average Shift Duration:</b> %s\n" ..
			"<b>Last Shift Type:</b> %s\n" ..
			"<b>Last Shift Duration:</b> %s\n" ..
			"<b>Last Shift Date:</b> %s",
			playerName,
			data.TotalShifts,
			FormatTime(data.TotalShiftTime),
			FormatTime(averageTime),
			data.LastShiftType,
			FormatTime(data.LastShiftTime),
			data.LastShiftDate
		)

		return stats
	end

	--// Reset shift data for a player
	local ResetPlayerData = function(userId: number)
		if not ShiftDataStore then
			warn("ShiftDataStore not initialized")
			return false
		end

		local success, result = pcall(function()
			ShiftDataStore:SetAsync(tostring(userId), {
				TotalShiftTime = 0,
				TotalShifts = 0,
				LastShiftType = "None",
				LastShiftTime = 0,
				LastShiftDate = "Never",
			})
		end)

		if success then
			Logs:AddLog("ShiftData", "Successfully reset shift data for UserId: " .. tostring(userId))
			return true
		else
			warn("Failed to reset shift data for UserId:", userId, "Error:", result)
			Logs:AddLog("ShiftData", "Failed to reset shift data for UserId: " .. tostring(userId) .. " Error: " .. tostring(result))
			return false
		end
	end

	local ShiftData = {
		Init = Init,
		GetPlayerData = GetPlayerData,
		SavePlayerData = SavePlayerData,
		GetAverageShiftTime = GetAverageShiftTime,
		FormatTime = FormatTime,
		GetFormattedStats = GetFormattedStats,
		ResetPlayerData = ResetPlayerData,
	}

	server.ShiftData = ShiftData
	return ShiftData
end
