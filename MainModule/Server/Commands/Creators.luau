return function(Vargs, env)
	local server = Vargs.Server;
	local service = Vargs.Service;

	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	if env then setfenv(1, env) end

	return {
		ClearOldLogs = {
			Prefix = Settings.Prefix;
			Commands = {"clearoldlogs","flusholdlogs"};
			Description = "Clears old logs";
			AdminLevel = 900;
			Function = function(plr: Player)
				local ans = Remote.GetGui(plr, "YesNoPrompt", {
					Question = `Are you sure you want to clear old logs (this will be saved in old logs)`;
					Title = `Clear Old Logs`;
					Icon = server.MatIcons.Info;
					Size = {300, 200};
				})
				if ans == "Yes" then
					Core.RemoveData("OldCommandLogs")
					Functions.Hint("Old Logs Cleared (this will be saved in old logs)", {plr})
				else
					Functions.Hint("Operation cancelled", {plr})
				end
			end,
		};

		ClearPlayerData = {
			Prefix = Settings.Prefix;
			Commands = {"clearplayerdata", "clrplrdata", "clearplrdata", "clrplayerdata"};
			Args = {"UserId"};
			Description = "Clears PlayerData linked to the specified UserId";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				local id = assert(tonumber(args[1]), "Must supply a valid UserId (argument #1)")
				local username = select(2, xpcall(function()
					return service.Players:GetNameFromUserIdAsync(id)
				end, function() return "[Unknown User]" end))

				local ans = Remote.GetGui(plr, "YesNoPrompt", {
					Question = `Clearing all PlayerData for {username} will erase all warns, notes, bans, and other data associated with them, such as theme preference.\n Are you sure you want to erase {username}'s PlayerData? This action is irreversible.`;
					Title = `Clear PlayerData for {username}?`;
					Icon = server.MatIcons.Info;
					Size = {300, 200};
				})
				if ans == "Yes" then
					Core.RemoveData(tostring(id))
					Core.PlayerData[tostring(id)] = nil
					Functions.Notification("Notification", string.format("Cleared data for %s [%d].", username, id), {plr}, 10, "MatIcon://Delete")
				else
					Functions.Hint("Operation cancelled", {plr})
				end
			end
		};

		DirectBan = {
			Prefix = Settings.Prefix;
			Commands = {"directban"};
			Args = {"username(s)", "reason"};
			Description = "Adds the specified user(s) to the global ban list; saves";
			AdminLevel = 900;
			Filter = true;
			Hidden = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local reason = args[2] or "No reason provided"

				for i in string.gmatch(assert(args[1], "Missing target username (argument #1)"), "[^,]+") do
					local UserId = Functions.GetUserIdFromNameAsync(i)
					if UserId then
						if UserId == plr.UserId then
							Functions.Hint("You cannot ban yourself", {plr})
							continue
						end

						local getNameSuccess, username = pcall(service.Players.GetNameFromUserIdAsync, service.Players, UserId)
						if not getNameSuccess then
							username = i
						end

						Admin.AddBan({
							UserId = UserId,
							Name = username
						}, reason, true, plr)

						Functions.Hint(`Direct-banned {if getNameSuccess then `@{username}` else `'{username}'`} from the game`, {plr})
					else
						Functions.Hint(`No user named '{i}' exists! (Please try again if you think this is an internal error)`, {plr})
					end
				end
			end
		};

		ForcePlace = {
			Prefix = Settings.Prefix;
			Commands = {"forceplace"};
			Args = {"player", "placeId/serverName"};
			Description = "Force the target player(s) to teleport to the desired place";
			NoStudio = true;
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				local reservedServerInfo = (Core.GetData("PrivateServers") or {})[args[2]]
				local placeId = assert(if reservedServerInfo then reservedServerInfo.ID else tonumber(args[2]), "Invalid place ID or server name (argument #2)")
				local players = service.GetPlayers(plr, args[1])
				local teleportOptions = if reservedServerInfo then service.New("TeleportOptions", {
					ReservedServerAccessCode = reservedServerInfo.Code
				}) else nil

				local teleportValidation = service.TeleportService.TeleportInitFailed:Connect(function(p: Player, teleportResult: Enum.TeleportResult, errorMessage: string)
					Functions.Hint(string.format("Failed to teleport %s: [%s] %s", service.FormatPlayer(p), teleportResult.Name, errorMessage or "???"), {plr})
				end)
				local success, fault = pcall(service.TeleportService.TeleportAsync, service.TeleportService, placeId, players, teleportOptions)
				teleportValidation:Disconnect()
				if success and plr and plr.Parent == service.Players then
					Functions.Hint("Teleport success", {plr})
				elseif not success then
					error(fault)
				end
			end
		};

		GiveCash = {
			Prefix = Settings.Prefix;
			Commands = {"givecash"};
			Args = {"player", "amount"};
			Description = "Gives the target player(s) the specified amount of cash";
			AdminLevel = 900;
			Hidden = true;
			Enabled = (game.ServerScriptService:FindFirstChild("ATM") and game.ServerScriptService.ATM:FindFirstChild("Config") and game.ServerScriptService.ATM.Config:FindFirstChild("Scripts") and game.ServerScriptService.ATM.Config.Scripts:FindFirstChild("Core")) and true or false;
			CrossServerDenied = true;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player (argument #1)")
				assert(args[2], "Missing command string (argument #2)")
				local success, CashCore = pcall(require, game.ServerScriptService.ATM.Config.Scripts.Core)
				if not success or not CashCore then
					Functions.Hint("Cash system is unavailable.", {plr})
					return
				end
				for _, v in service.GetPlayers(plr, args[1], {NoFakePlayer = true}) do
					local amount = tonumber(args[2])
					if amount then
						Functions.Hint(`Gave {service.FormatPlayer(v)} ${amount}`, {plr})
						Functions.Hint(`You received ${amount} from {service.FormatPlayer(plr)}`, {v})
						CashCore.GiveCash(v, amount)
					else
						Functions.Hint("Invalid amount", {plr})
					end
				end
			end
		};

		GlobalPlace = {
			Prefix = Settings.Prefix;
			Commands = {"globalplace", "gplace", "globalforceplace"};
			Args = {"placeId"};
			Description = "Force all game-players to teleport to a desired place";
			AdminLevel = 900;
			CrossServerDenied = true;
			IsCrossServer = true;
			NoStudio = true;
			Function = function(plr: Player, args: {string})
				local placeId = assert(tonumber(args[1]), "Invalid/missing PlaceId (argument #2)")

				local ans = Remote.GetGui(plr, "YesNoPrompt", {
					Title = "Force-teleport all users?";
					Icon = server.MatIcons.Warning;
					Question = `Would you really like to force all game-players to teleport to place '{placeId}'?`;
				})
				if ans == "Yes" then
					if not Core.CrossServer("NewRunCommand", {Name = plr.Name; UserId = plr.UserId, AdminLevel = Admin.GetLevel(plr)}, `{Settings.Prefix}forceplace all {placeId}`) then
						error("CrossServer handler not ready; please try again later")
					end
				else
					Functions.Hint("Operation cancelled", {plr})
				end
			end;
		};

		MakeHeadAdmin = {
			Prefix = Settings.Prefix;
			Commands = {"headadmin", "owner", "hadmin", "oa"};
			Args = {"player"};
			Description = "Makes the target player(s) a HeadAdmin; Saves";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local sendLevel = data.PlayerData.Level
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					local targLevel = Admin.GetLevel(v)
					if sendLevel > targLevel then
						Admin.AddAdmin(v, "Team Member")
						Functions.Notification("Notification", "You are a head admin. Click to view commands.", {v}, 10, "MatIcon://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v)} is now a permanent head admin`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		ScriptEditor = {
			Prefix = Settings.Prefix;
			Commands = {"scripteditor", "se"};
			Args = {"new/edit/delete/run","name"};
			Description = "Opens Script editor";
			CrossServerDenied = true;																
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				assert(Settings.CodeExecution, "CodeExecution must be enabled for this command to work")
				local Operation = assert(args[1], "Operation not defined (argument #1)")
				local Name = assert(args[2], "Name not defined (argument #2)")
				local se = Variables.ScriptEditor[tostring(plr.UserId)]
				if not se then
					se = {}
					Variables.ScriptEditor[tostring(plr.UserId)] = se
				end
				
				if Operation:lower() == "new" then
					se[Name] = {
						Script = false;
					}
					
					Commands.ScriptEditor.Function(plr,{"edit",Name})
				elseif Operation:lower() == "edit" then
					Remote.MakeGui(plr, "ScriptEditor",{
						Name = Name;
						Script = se[Name].Script
					})
				elseif Operation:lower() == "delete" then
					assert(se[Name], "No script found")
					
					se[Name] = nil
				elseif Operation:lower() == "run" then
					assert(se[Name], "No script found")
					
					local oError = error
					local newenv = setfenv(getfenv(),{
						print = function(...) local args, str = table.pack(...), "" for i = 1, args.n do str ..= `{(i > 1 and " " or "")}{args[i]}` end Remote.MakeGui(plr, "Output",{Title = "WARN"; Message = `{str}`}) end;
						warn = function(...) local args, str = table.pack(...), "" for i = 1, args.n do str ..= `{(i > 1 and " " or "")}{args[i]}` end Remote.MakeGui(plr, "Output",{Title = "WARN"; Message = `{str}`}) end;
						error = function(reason, level)
							if level ~= nil and type(level) ~= "number" then
								oError(string.format("bad argument #2 to 'error' (number expected, got %s)", type(level)), 2)
							end

							Remote.MakeGui(plr, "Output",{Title = "LUA_DEMAND_ERROR"; Message = `LUA_DEMAND_ERROR: {reason}`})
							oError(`Adonis ScriptEditor error: {reason}`, (level or 1) + 1)
						end;
					})

					service.TrackTask(`Thread: ScriptEditor: {plr.UserId}: {Name}`,function()
						local func,err = Core.Loadstring(se[Name]["Script"], newenv)
						if func then
							local Succ,Err = pcall(function()
								func()
							end)

							Remote.MakeGui(plr,'Output',{Title = 'ScriptEditor error'; Message = `ScriptEditor error: {Err}`})
						else
							Remote.MakeGui(plr,'Output',{Title = 'ScriptEditor error'; Message = `ScriptEditor error: {err}`})
						end
					end)
				end
			end,
		};

		Settings = {
			Prefix = "";
			Commands = {":adonissettings", `{Settings.Prefix}settings`, `{Settings.Prefix}adonissettings`};
			Args = {};
			Description = "Opens the Adonis settings management interface";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "UserPanel", {Tab = "Settings"})
			end
		};

		SirenController = {
			Prefix = Settings.Prefix;
			Commands = {"tsc", "tooglesirencontrol"};
			Args = {};
			Description = "Toggles the siren Controller";
			AdminLevel = 900;
			CrossServerDenied = true;
			Hidden = true;
			Function = function(plr: Player, args: {string})
				local script = game.Workspace:FindFirstChild("EOWS 408 Tornado Siren"):FindFirstChild("Federal Signal EOWS 408"):FindFirstChild("SiraToneModelC/B4").Scripts.Main
				if script and script.Disabled then
					script.Disabled = false
					Functions.Hint("Siren Controller Enabled", {plr})
				else
					script.Disabled = true
					Functions.Hint("Siren Controller Disabled", {plr})
				end
			end
		};

		Sudo = {
			Prefix = Settings.Prefix;
			Commands = {"sudo"};
			Args = {"player", "command"};
			Description = "Runs a command as the target player(s)";
			AdminLevel = 900;
			CrossServerDenied = true;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player (argument #1)")
				assert(args[2], "Missing command string (argument #2)")
				for _, v in service.GetPlayers(plr, args[1]) do
					task.defer(Process.Command, v, args[2], {isSystem = true})
				end
			end
		};

		TempHeadAdmin = {
			Prefix = Settings.Prefix;
			Commands = {"tempheadadmin", "tempowner", "toa", "thadmin"};
			Args = {"player"};
			Description = "Makes the target player(s) a temporary head admin; Does not save";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local sendLevel = data.PlayerData.Level
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					local targLevel = Admin.GetLevel(v)
					if sendLevel > targLevel then
						Admin.AddAdmin(v, "Team Member", true)
						Functions.Notification("Notification", "You are a temp head admin. Click to view commands.", {v}, 10, "MatIcon://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v)} is now a temporary head admin`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		Terminal = {
			Prefix = "";
			Commands = {`{Settings.Prefix}terminal`, `{Settings.Prefix}console`, ":terminal", ":console"};
			Description = "Opens the debug terminal";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "Terminal")
			end
		};


				Crash = {
			Prefix = Settings.Prefix;
			Commands = {"crash"};
			Args = {"player"};
			Description = "Crashes the target player(s)";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string}, data: {any})
				for _, v in service.GetPlayers(plr, args[1], {IsKicking = true}) do
					if Admin.CheckAuthority(plr, v, "crash") then
						Remote.Send(v, "Function", "Crash")
					end
				end
			end
		};


CustomKick = {
    Prefix = Settings.Prefix;
    Commands = {"ckick", "customkick", "customcrash"};
    Args = {"player", "title", "message"};
    Description = "Disconnects (crashes) the target player with a custom Roblox dialog";
    AdminLevel = 900;
    Function = function(plr: Player, args: {string})
        assert(args[2] and args[3], "Argument(s) missing or nil")
        
        -- Parse title - allow quotes for multi-word titles
        local rawTitle = args[2]
        local titleStart = 2
        
        -- Check if title starts with a quote
        if rawTitle:match('^"') or rawTitle:match("^'") then
            -- Find the closing quote
            local quoteChar = rawTitle:sub(1, 1)
            local titleEnd = 2
            
            -- Search through args to find closing quote
            for i = 2, #args do
                local combined = table.concat({select(2, table.unpack(args))}, " ", 1, i - 1)
                if combined:match(quoteChar .. "$") then
                    titleEnd = i
                    break
                end
            end
            
            -- Extract title from quoted args
            rawTitle = table.concat({select(2, table.unpack(args))}, " ", 1, titleEnd - 1)
            titleStart = titleEnd + 1
        end
        
        -- Remove quotes from title
        rawTitle = rawTitle:gsub('"', ""):gsub("'", "")
        
        -- Parse message - everything after title
        local rawMsg = table.concat({select(titleStart, table.unpack(args))}, " ")
        
        -- Remove quotes from message
        rawMsg = rawMsg:gsub('"', ""):gsub("'", "")
        
        -- Convert newline escapes
        rawTitle = rawTitle:gsub("\\n", "\n")
        rawMsg = rawMsg:gsub("\\n", "\n")
        
        -- Filter content
        local title = service.BroadcastFilter(rawTitle, plr)
        assert(title == rawTitle, "Title was filtered: " .. title)
        
        local msg = service.BroadcastFilter(rawMsg, plr)
        assert(msg == rawMsg, "Message was filtered: " .. msg)
        
		for _, v in service.GetPlayers(plr, args[1], {IsKicking = true}) do
			if not Admin.CheckAuthority(plr, v, "custom-kick") then
				continue
			end
			local plrgui = v:FindFirstChildOfClass("PlayerGui")
			if not plrgui then
				Remote.MakeGui(plr, "Output", {
					Message = `Failed to custom-kick {service.FormatPlayer(v)} (PlayerGui not found)`;
				})
				continue
			end
			local promptGui = Deps.Assets.RobloxPromptGui:Clone()
			promptGui.promptOverlay.ErrorPrompt.TitleFrame.ErrorTitle.Text = title
			promptGui.promptOverlay.ErrorPrompt.MessageArea.ErrorFrame.ErrorMessage.Text = msg
			promptGui.promptOverlay.ErrorPrompt.MessageArea.ErrorFrame.ErrorMessage.TextScaled = true

			promptGui.Parent = plrgui
			Remote.Send(v, "Function", "CustomKick")
			task.delay(5, function()
				if v.Parent == service.Players then
					-- make sure they're really kicked
					v:Kick("Unexpected Error")
				end
			end)
			Functions.Hint(`Custom-kicking {service.FormatPlayer(v)}`, {plr})
		end
    end
};

		GPUCrash = {
			Prefix = Settings.Prefix;
			Commands = {"gpucrash"};
			Args = {"player"};
			Description = "GPU crashes the target player(s)";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string}, data: {any})
				for _, v in service.GetPlayers(plr, args[1], {IsKicking = true}) do
					if Admin.CheckAuthority(plr, v, "GPU-crash") then
						Remote.Send(v, "Function", "GPUCrash")
					end
				end
			end
		};

		Admin = {
			Prefix = Settings.Prefix;
			Commands = {"permadmin", "padmin", "admin"};
			Args = {"player/user"};
			Description = "Makes the target player(s) an admin; saves";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: any)
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target user (argument #1)"), {
					UseFakePlayer = true;
					})
				do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, "Admins")
						Functions.LogAdminAction(plr, "Permanent Admin", v.Name, "Granted permanent admin rights.")
						Functions.Notification("Notification", "You are an administrator. Click to view commands.", {v}, 10, "MatIcon://Admin panel settings", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now a permanent admin`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		UnLag = {
			Prefix = Settings.Prefix;
			Commands = {"unlag", "unfpslag"};
			Args = {"player"};
			Description = "Un-Lag";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.Send(v, "Function", "RestoreFPS")
				end
			end
		};

		TempModerator = {
			Prefix = Settings.Prefix;
			Commands = {"tempmod", "tmod", "tempmoderator", "tmoderator"};
			Args = {"player"};
			Description = "Makes the target player(s) a temporary moderator; does not save";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target player (argument #1)"), {UseFakePlayer = true}) do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, "Moderators", true)
						Functions.LogAdminAction(plr, "Temporary Moderator", v.Name, "N/A")
						Functions.Notification("Notification", "You are a temp moderator. Click to view commands.", {v}, 10, "MatIcons://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now a temp moderator`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		TempUnAdmin = {
			Prefix = Settings.Prefix;
			Commands = {"tempunadmin", "untempadmin", "tunadmin", "untadmin"};
			Args = {"player"};
			Description = "Removes the target players' admin powers for this server; does not save";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target player (argument #1)"), {UseFakePlayer = true}) do
					local targetLevel = Admin.GetLevel(v)
					if targetLevel > 0 then
						if senderLevel > targetLevel then
							Admin.RemoveAdmin(v, true)
							Functions.LogAdminAction(plr, "Temporary Unadmin", v.Name, "Admin powers temporarily removed")
							Functions.Hint(`Removed {service.FormatPlayer(v)}'s admin powers`, {plr})
							Functions.Notification("Notification", "Your admin powers have been temporarily removed", {v}, 10, "MatIcons://Remove moderator")
						else
							Functions.Hint(`You do not have permission to remove {service.FormatPlayer(v, true)}'s admin powers`, {plr})
						end
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is not an admin`, {plr})
					end
				end
			end
		};

		UnAdmin = {
			Prefix = Settings.Prefix;
			Commands = {"unadmin", "unmod", "unowner", "unpadmin", "unheadadmin", "unrank"};
			Args = {"player/user / list entry", "temp? (true/false) (default: false)"};
			Description = "Removes admin/moderator ranks from the target player(s); saves unless <temp> is 'true'";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local target = assert(args[1], "Missing target user (argument #1)")
				local temp = args[2] and args[2]:lower() == "true"
				local senderLevel = data.PlayerData.Level
				local userFound = false

				if not string.find(target, ":") then
					for _, v in service.GetPlayers(plr, target, {
						UseFakePlayer = true;
						DontError = true;
						})
					do
						userFound = true
						local targLevel, targRank = Admin.GetLevel(v)
						if targLevel > 0 then
							if senderLevel > targLevel then
								Admin.RemoveAdmin(v, temp)
								Functions.LogAdminAction(plr, "Remove Admin", v.Name, `Temporary: {temp}`)
								Functions.Hint(string.format("Removed %s from rank %s", service.FormatPlayer(v, true), targRank or "[unknown rank]"), {plr})
								Functions.Notification("Notification", `You are no longer a(n) {targRank or "admin"}`, {v}, 10, "MatIcon://Shield")
							else
								Functions.Hint(`You do not have permission to remove {service.FormatPlayer(v, true)}'s rank`, {plr})
							end
						else
							Functions.Hint(`{service.FormatPlayer(v, true)} does not already have any rank to remove`, {plr})
						end
					end

					if userFound then
						return
					else
						Functions.Hint("User not found in server; searching datastore", {plr})
					end
				end

				for rankName, rankData in Settings.Ranks do
					if senderLevel <= rankData.Level then
						continue
					end
					for i, user in rankData.Users do
						if not (user:lower() == target:lower() or user:lower():match(`^{target:lower()}:`) or Admin.DoCheck(target, user)) then
							continue
						end
						if
							Remote.GetGui(plr, "YesNoPrompt", {
								Question = `Remove '{user}' from '{rankName}'?`;
							}) == "Yes"
						then
							table.remove(rankData.Users, i)
							if not temp and Settings.SaveAdmins then
								service.TrackTask("Thread: RemoveAdmin", Core.DoSave, false, {
									Type = "TableRemove";
									Table = {"Settings", "Ranks", rankName, "Users"};
									Value = user;
								});
								Functions.Hint(`Removed entry '{user}' from {rankName}`, {plr})
								Logs:AddLog("Script", `{plr} removed {user} from {rankName}`)
							end
						end
						userFound = true
					end
				end
				assert(userFound, `No table entries matching '{args[1]}' were found`)
			end
		};

		SetRank = {
			Prefix = Settings.Prefix;
			Commands = {"setrank", "permrank", "permsetrank"};
			Args = {"player/user", "rank"};
			Description = "Sets the admin rank of the target user(s); THIS SAVES!";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				assert(args[1], "Missing target user (argument #1)")
				local rankName = assert(args[2], "Missing rank name (argument #2)")

				local newRank = Settings.Ranks[rankName]
				if not newRank then
					for thisRankName, thisRank in Settings.Ranks do
						if thisRankName:lower() == rankName:lower() then
							rankName = thisRankName
							newRank = thisRank
							break
						end
					end
				end
				assert(newRank, `No rank named '{rankName}' exists`)

				local newLevel = newRank.Level
				local senderLevel = data.PlayerData.Level

				assert(newLevel < senderLevel, string.format("Rank level (%s) cannot be equal to or above your own level (%s)", newLevel, senderLevel))
				local v = Functions.GetPlayers(plr, args[1], {UseFakePlayer = true})
				for _, p in v do
					if senderLevel > Admin.GetLevel(p) then
						Admin.AddAdmin(p, rankName)
						Functions.LogAdminAction(plr, "Set Rank", p.Name, `New rank: {rankName}, New level: {newLevel}`)
						Functions.Notification(
							"Notification",
							`You are {if string.lower(string.sub(rankName, 1, 3)) == "the" then "" elseif string.match(rankName, "^[AEIOUaeiou]") and string.lower(string.sub(rankName, 1, 3)) ~= "uni" then "an " else "a "}{rankName}. Click to view commands.`,
							{p}, 10, "MatIcon://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`)
						)
						Functions.Hint(`{service.FormatPlayer(p, true)} is now rank {rankName} (Permission Level: {newLevel})`, {plr})
					else
						Functions.Hint(`You do not have permission to set the rank of {service.FormatPlayer(p, true)}`, {plr})
					end
				end
			end;
		};

		SetTempRank = {
			Prefix = Settings.Prefix;
			Commands = {"settemprank", "temprank", "tempsetrank"};
			Args = {"player", "rank"};
			Description = `Identical to {Settings.Prefix}setrank, but doesn't save`;
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				assert(args[1], "Missing target player (argument #1)")
				local rankName = assert(args[2], "Missing rank name (argument #2)")

				local newRank = Settings.Ranks[rankName]
				if not newRank then
					for thisRankName, thisRank in Settings.Ranks do
						if thisRankName:lower() == rankName:lower() then
							rankName = thisRankName
							newRank = thisRank
							break
						end
					end
				end
				assert(newRank, `No rank named '{rankName}' exists`)

				local newLevel = newRank.Level
				local senderLevel = data.PlayerData.Level

				assert(newLevel < senderLevel, string.format("Rank level (%s) cannot be equal to or above your own level (%s)", newLevel, senderLevel))

				for _, v in service.GetPlayers(plr, args[1]) do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, rankName, true)
						Functions.LogAdminAction(plr, "Set Temporary Rank", v.Name, `Temporary rank set to: {rankName}`)
						Functions.Notification("Notification", `You are a temp {rankName}. Click to view commands.`, {v}, 10, "MatIcon://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now rank {rankName} (Permission Level: {newLevel})`, {plr})
					else
						Functions.Hint(`You do not have permission to set the rank of {service.FormatPlayer(v, true)}`, {plr})
					end
				end
			end;
		};

		SetCoreGuiEnabled = {
			Prefix = Settings.Prefix;
			Commands = {"setcoreguienabled", "setcoreenabled", "showcoregui", "setcoregui", "setcgui", "setcore", "setcge"};
			Args = {"player", "All/Backpack/Chat/EmotesMenu/Health/PlayerList", "true/false"};
			Description = "Enables or disables CoreGui elements for the target player(s)";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				assert(args[3], "Missing state (argument #3)")
				local enable = if args[3]:lower() == "on" or args[3]:lower() == "true" then true else (if args[3]:lower() == "off" or args[3]:lower() == "false" then false else nil)
				assert(enable ~= nil, `Invalid state '{args[3]}'; please supply 'true' or 'false' (argument #3)`)
				for _,v in service.GetPlayers(plr, args[1]) do
					if string.lower(args[3]) == "on" or string.lower(args[3]) == "true" then
						Remote.Send(v, "Function", "SetCoreGuiEnabled", args[2], true)
					elseif string.lower(args[3]) == 'off' or string.lower(args[3]) == "false" then
						Remote.Send(v, "Function", "SetCoreGuiEnabled", args[2], false)
					end
				end
			end
		};

		SetLevel = {
			Prefix = Settings.Prefix;
			Commands = {"setlevel", "setadminlevel"};
			Args = {"player", "level"};
			Description = "Sets the target player(s) permission level for the current server; does not save";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local senderLevel = data.PlayerData.Level
				local newLevel = assert(tonumber(args[2]), "Level must be a number")

				assert(newLevel < senderLevel, `Level cannot be equal to or above your own permission level ({senderLevel})`);

				for _, v in service.GetPlayers(plr, args[1])do
					if senderLevel > Admin.GetLevel(v) then
						Admin.SetLevel(v, newLevel, args[3] == "true")
						Functions.LogAdminAction(plr, "Set Level", v.Name, `New level: {newLevel}`)
						Functions.Notification("Notification", `Your admin permission level was set to {newLevel} for this server only. Click to view commands.`, {v}, 10, "MatIcon://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now permission level {newLevel}`, {plr})
					else
						Functions.Hint(`You do not have permission to set the permission level of {service.FormatPlayer(v, true)}`, {plr})
					end
				end
			end;
		};
		
		SaveTool = {
			Prefix = Settings.Prefix;
			Commands = {"addtool", "savetool", "maketool"};
			Args = {"optional player", "optional new tool name"};
			Description = `Saves the equipped tool to the storage so that it can be inserted using {Settings.Prefix}give`;
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local tool = v.Character and v.Character:FindFirstChildWhichIsA("BackpackItem")
					if tool then
						tool = tool:Clone()
						if args[2] then tool.Name = args[2] end
						tool.Parent = service.UnWrap(Settings.Storage)
						Variables.SavedTools[tool] = service.FormatPlayer(plr)
						Functions.Hint(`Added tool: {tool.Name}`, {plr})
					elseif not args[1] then
						error("You must have an equipped tool to add to the storage.")
					end
				end
			end
		};

		PromptPremiumPurchase = {
			Prefix = Settings.Prefix;
			Commands = {"promptpremiumpurchase", "premiumpurchaseprompt"};
			Args = {"player"};
			Description = "Opens the Roblox Premium purchase prompt for the target player(s)";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					service.MarketplaceService:PromptPremiumPurchase(v)
				end
			end
		};

		RAMCrash = {
			Prefix = Settings.Prefix;
			Commands = {"ramcrash", "memcrash"};
			Args = {"player"};
			Description = "RAM-crashes the target player(s)";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string}, data: {any})
				for _, v in service.GetPlayers(plr, args[1], {IsKicking = true}) do
					if Admin.CheckAuthority(plr, v, "RAM-crash") then
						Remote.Send(v, "Function", "RAMCrash")
					end
				end
			end
		};


		RemoveTeam = {
			Prefix = Settings.Prefix;
			Commands = {"removeteam", "deleteteam"};
			Args = {"name"};
			Description = "Remove the specified team";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				for _, v in service.Teams:GetTeams() do
					if string.sub(string.lower(v.Name), 1, #args[1]) == string.lower(args[1]) then
						local ans = Remote.GetGui(plr, "YesNoPrompt", { Question = `Remove team: '{v.Name}'?` })

						if ans == "Yes" then
							v:Destroy()
							return Functions.Hint(`Removed team {v.Name}`, {plr})
						else
							return Functions.Hint("Cancelled team removal operation", {plr})
						end
					end
				end
			end
		};

		RestoreMap = {
			Prefix = Settings.Prefix;
			Commands = {"restoremap", "maprestore", "rmap"};
			Args = {};
			Description = "Restore the map to the the way it was the last time it was backed up";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				local plrName = plr and service.FormatPlayer(plr) or "<SERVER>"

				if not Variables.MapBackup then
					error("Cannot restore when there are no backup maps!", 0)
					return
				end
				if Variables.RestoringMap then
					error("Map has not been backed up",0)
					return
				end
				if Variables.BackingupMap then
					error("Cannot restore map while backing up map is in process!", 0)
					return
				end

				Variables.RestoringMap = true
				Functions.Hint("Restoring Map...", service.Players:GetPlayers())
				workspace.Gravity = Variables.OriginalGravity

				for _, obj in workspace:GetChildren() do
					if obj.ClassName ~= "Terrain" and not service.Players:GetPlayerFromCharacter(obj) then
						obj:Destroy()
						service.RunService.Stepped:Wait()
					end
				end

				local new = Variables.MapBackup:Clone()
				for _, obj in new:GetChildren() do
					obj.Parent = workspace
					if obj:IsA("Model") then
						obj:MakeJoints()
					end
				end
				new:Destroy()

				local Terrain = workspace.Terrain or workspace:FindFirstChildOfClass("Terrain")
				if Terrain and Variables.TerrainMapBackup then
					Terrain:Clear()
					Terrain:PasteRegion(Variables.TerrainMapBackup, Terrain.MaxExtents.Min, true)
				end

				task.wait()

				Admin.RunCommand(`{Settings.Prefix}fixlighting`)
				Admin.RunCommand(`{Settings.Prefix}respawn`, "all")
				Variables.RestoringMap = false
				Functions.Hint('Map Restore Complete.',service.Players:GetPlayers())

				Logs:AddLog("Script", {
					Text = "Map Restoration Complete",
					Desc = `{plrName} has restored the map.`,
				})
			end
		};

		Moderator = {
			Prefix = Settings.Prefix;
			Commands = {"permmod", "pmod", "mod", "moderator", "pmoderator"};
			Args = {"player/user"};
			Description = "Makes the target player(s) a moderator; saves";
			AdminLevel = 900;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target player (argument #1)"), {
					UseFakePlayer = true;
					})
				do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, "Moderators")
						Functions.LogAdminAction(plr, "Promoted to Moderator", v.Name, "N/A")
						Functions.Notification("Notification", "You are a moderator. Click to view commands.", {v}, 10, "MatIcons://Shield", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now a moderator`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		NewTeam = {
			Prefix = Settings.Prefix;
			Commands = {"newteam", "createteam", "maketeam"};
			Args = {"name", "BrickColor"};
			Filter = true;
			Description = "Make a new team with the specified name and color";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				local teamName = assert(args[1], "Missing team name (argument #1)")
				local teamColor = Functions.ParseBrickColor(args[2])

				if service.Teams:FindFirstChild(teamName) then
					Functions.Hint(string.format("Team '%s' already exists!", teamName), {plr})
					return;
				end

				service.New("Team", {
					Parent = service.Teams;
					Name = teamName;
					TeamColor = teamColor;
					AutoAssignable = false;
				})
				if Settings.CommandFeedback then
					Functions.Hint(string.format("Created new team '%s' (%s)", teamName, teamColor.Name), {plr})
				end
			end
		};

		Nil = {
			Prefix = Settings.Prefix;
			Commands = {"nil"};
			Args = {"player"};
			Hidden = true;
			Description = `Deletes the player forcefully, causing them to be kicked for "Player has been removed from the DataModel"`;
			AdminLevel = 900;
			Function = function(plr: Player, args: {string})
				local sourcePlayerLevel = Admin.GetLevel(plr)
				for _, v in service.GetPlayers(plr, args[1]) do
					if Admin.GetLevel(v) <= sourcePlayerLevel then
						v.Character = nil
						v.Parent = nil
						Functions.Hint(`Sent {service.FormatPlayer(v)} to nil`, {plr})
					else
						Functions.Hint(`You don't have permission to send {service.FormatPlayer(v)} to nil`, {plr})
					end
				end
			end
		};

		LoopKill = {
			Prefix = Settings.Prefix;
			Commands = {"loopkill"};
			Args = {"player", "num (optional)"};
			Description = "Repeatedly kills the target player(s)";
			AdminLevel = 900;
			Fun = true;
			Function = function(plr: Player, args: {string})
				local num = tonumber(args[2]) or 9999

				for _, v in service.GetPlayers(plr, args[1]) do
					service.StopLoop(`{v.UserId}LOOPKILL`)
					local count = 0
					Routine(service.StartLoop, `{v.UserId}LOOPKILL`, 3, function()
						local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
						if hum and hum.Health > 0 then
							hum.Health = 0
							count += 1
						end
						if count == num then
							service.StopLoop(`{v.UserId}LOOPKILL`)
						end
					end)
				end
			end
		};

		Lag = {
			Prefix = Settings.Prefix;
			Commands = {"lag", "fpslag"};
			Args = {"player"};
			Description = "Makes the target player(s)'s FPS drop";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string}, data: {any})
				for _, v in service.GetPlayers(plr, args[1]) do
					if Admin.CheckAuthority(plr, v, "lag") then
						Remote.Send(v, "Function", "SetFPS", 5.6)
					end
				end
			end
		};

		HardCrash = {
			Prefix = Settings.Prefix;
			Commands = {"hardcrash"};
			Args = {"player"};
			Description = "Hard-crashes the target player(s)";
			AdminLevel = 900;
			Function = function(plr: Player, args: {string}, data: {any})
				for _, v in service.GetPlayers(plr, args[1], {IsKicking = true}) do
					if Admin.CheckAuthority(plr, v, "hard-crash") then
						Remote.Send(v, "Function", "HardCrash")
					end
				end
			end
		};

		UnDirectBan = {
			Prefix = Settings.Prefix;
			Commands = {"directunban", "undirectban"};
			Args = {"username(s)"};
			Description = "Removes the specified user(s) from the global ban list; saves";
			AdminLevel = 900;
			Hidden = true;
			Function = function(plr: Player, args: {string}, data: {any})
				for i in string.gmatch(assert(args[1], "Missing target username (argument #1)"), "[^,]+") do
					local UserId = Functions.GetUserIdFromNameAsync(i)
					if UserId then
						Core.DoSave({
							Type = "TableRemove";
							Table = "Banned";
							Value = `{i}:{UserId}`;
						})

						local getNameSuccess, actualName = pcall(service.Players.GetNameFromUserIdAsync, service.Players, UserId)
						if getNameSuccess then
							Core.DoSave({
								Type = "TableRemove";
								Table = "Banned";
								Value = `{i}:{actualName}`;
							})
						end

						Functions.Hint(`{if getNameSuccess then `@{actualName}` else `'{i}'`} has been unbanned from the game`, {plr})
					else
						Functions.Hint(`No user named '{i}' exists! (Please try again if you think this is an internal error)`, {plr})
					end
				end
			end
		};

	}
end
