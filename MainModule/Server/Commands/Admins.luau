--!nocheck
return function(Vargs, env)
	local server = Vargs.Server;
	local service = Vargs.Service;
	local TornadoEnabled = false

	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	if env then setfenv(1, env) end

	local Routine = env.Routine

	return {
		Alert = {
			Prefix = Settings.Prefix;
			Commands = {"alert", "alarm", "annoy"};
			Args = {"player", "message"};
			Filter = true;
			Description = "Get someone's attention";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr,string.lower(args[1]))do
					Remote.MakeGui(v, "Alert", {Message = args[2] and service.Filter(args[2],plr, v) or "Wake up; Your attention is required"})
				end
			end
		};

		Broadcast = {
			Prefix = Settings.Prefix;
			Commands = {"broadcast", "bc"};
			Args = {"Message"};
			Filter = true;
			Description = "Makes a message in the chat window";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string}, data: {any})
				for _, v in service.GetPlayers() do
					if service.TextChatService and service.TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
						local TextToUse = args[1]
						if data.Options.Chat ~= true then
							TextToUse = service.SanitizeXML(args[1] or "Hello world!")
						end
						Remote.Send(
							v, "Function", "DisplaySystemMessageInTextChat", nil, `{
							string.format(`<font color="rgb(255, 64, 77)"><b>[%s]</b></font> <font color="rgb(235, 99, 108)">%s</font>`, Settings.SystemTitle, service.Filter(TextToUse), plr, v)
							}`)
					else
						Remote.Send(v, "Function", "ChatMessage", string.format("[%s] %s", Settings.SystemTitle, service.Filter(args[1], plr, v)), Color3.fromRGB(255,64,77))
					end
				end
			end
		};

		ClearSavedTools = {
			Prefix = Settings.Prefix;
			Commands = {"clraddedtools", "clearaddedtools", "clearsavedtools", "clrsavedtools"};
			Args = {};
			Description = `Removes any tools in the storage added using {Settings.Prefix}savetool`;
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				local count = 0
				for tool in Variables.SavedTools do
					count += 1
					tool:Destroy()
				end
				table.clear(Variables.SavedTools)
				Functions.Hint(string.format("Cleared %d saved tool%s.", count, count == 1 and "" or "s"), {plr})
			end
		};


		CustomMessage = {
			Prefix = Settings.Prefix;
			Commands = {"cm", "custommessage"};
			Args = {"Upper message", "message"};
			Filter = true;
			Description = "Same as message but says whatever you want upper message to be instead of your name.";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing message title (argument #1)")
				assert(args[2], "Missing message (argument #2)")
				for _, v in service.Players:GetPlayers() do
					Remote.RemoveGui(v, "Message")
					Remote.MakeGui(v, "Message", {
						Title = args[1];
						Message = args[2];
						Time = (#tostring(args[1]) / 19) + 2.5;
						--service.Filter(args[1],plr, v);
					})
				end
			end
		};

		DeleteNote = {
			Prefix = Settings.Prefix;
			Commands = {"removenote", "remnote", "deletenote", "clearnote"};
			Args = {"player", "note (specify 'all' to delete all notes)"};
			Description = "Removes a note on the target player(s)";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				assert(args[2], "Missing note (argument #2)")
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					local PlayerData = Core.GetPlayer(v)
					if PlayerData.AdminNotes then
						if string.lower(args[2]) == "all" then
							PlayerData.AdminNotes = {}
						else
							for k, m in PlayerData.AdminNotes do
								if string.sub(string.lower(m), 1, #args[2]) == string.lower(args[2]) then
									Functions.Hint(`Removed {service.FormatPlayer(v)} Note {m}`, {plr})
									table.remove(PlayerData.AdminNotes, k)
								end
							end
						end
						Core.SavePlayer(v, PlayerData)
					end
				end
			end
		};

		Disguise = {
			Prefix = Settings.Prefix;
			Commands = {"disguise", "masquerade"};
			Args = {"player", "username"};
			Description = "Names the player, chars the player, and modifies the player's chat tag";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				assert(args[2], "Argument missing or nil")
				local userId = Functions.GetUserIdFromNameAsync(args[2])
				assert(userId, "Invalid username supplied/user not found")

				local username = select(2, xpcall(function()
					return service.Players:GetNameFromUserIdAsync(userId)
				end, function() return args[2] end))

				if service.Players:GetPlayerByUserId(userId) then
					error("You cannot disguise as this player (currently in server)")
				end

				Commands.Char.Function(plr, args)
				Commands.DisplayName.Function(plr, {args[1], username})

				for _, v in service.GetPlayers(plr, args[1]) do
					if Variables.DisguiseBindings[v.UserId] then
						Variables.DisguiseBindings[v.UserId].Rename:Disconnect()
						Variables.DisguiseBindings[v.UserId].Rename = nil
					end

					Variables.DisguiseBindings[v.UserId] = {
						TargetUsername = username;
						Rename = v.CharacterAppearanceLoaded:Connect(function(char)
							Commands.DisplayName.Function(v, {v.Name, username})
						end);
					}
				end
			end
		};



		LockMap = {
			Prefix = Settings.Prefix;
			Commands = {"lockmap"};
			Args = {};
			Description = "Locks the map";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, obj in workspace:GetDescendants()do
					if obj:IsA("BasePart")then
						obj.Locked = true
					end
				end
			end
		};


		Notif = {
			Prefix = Settings.Prefix;
			Commands = {"setmessage", "notif", "setmsg", "permhint"};
			Args = {"message OR off"};
			Filter = true;
			Description = "Sets a small hint message at the top of the screen";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing message (or enter 'off' to disable)")

				if args[1] == "off" or args[1] == "false" then
					Variables.NotifMessage = nil
					for _, v in service.GetPlayers() do
						Remote.RemoveGui(v, "Notif")
					end
				else
					Variables.NotifMessage = args[1]
					for _, v in service.GetPlayers() do
						Remote.MakeGui(v, "Notif", {
							Message = Variables.NotifMessage;
						})
					end
				end
			end
		};


		RobloxNotify = {
			Prefix = Settings.Prefix;
			Commands = {"rbxnotify", "robloxnotify", "robloxnotif", "rblxnotify", "rnotif", "rn"};
			Args = {"player", "duration (seconds)", "text"};
			Filter = true;
			Description = "Sends a Roblox-styled notification for the target player(s)";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.Send(v, "Function", "SetCore", "SendNotification", {
						Title = "Notification";
						Text = args[3] or "Hello, from Adonis!";
						Duration = tonumber(args[2]) or 5;
					})
				end
			end
		};


		ServerLock = {
			Prefix = Settings.Prefix;
			Commands = {"slock", "serverlock", "lockserver"};
			Args = {"on/off"};
			Description = "Enables/disables server lock";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				local arg = args[1] and string.lower(args[1])
				Functions.LogAdminAction(plr, "Server Lock", "Server is now " .. (if (arg == "on" or arg == "true") then "locked" else "unlocked"), "")
				if (not arg and Variables.ServerLock ~= true) or arg == "on" or arg == "true" then
					Variables.ServerLock = true
					Functions.Hint("Server Locked", service.Players:GetPlayers())
				elseif Variables.ServerLock == true or arg == "off" or arg == "false" then
					Variables.ServerLock = false
					Functions.Hint("Server Unlocked", service.Players:GetPlayers())
				end
			end
		};


		SetLockMessage = {
			Prefix = Settings.Prefix;
			Commands = {"setlockmessage", "slockmsg", "setlmsg"};
			Args = {"message"};
			Filter = true;
			Description = "Sets the lock message unwhitelisted players see if :whitelist or :slock is on";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				Variables.LockMessage = assert(args[1], "Missing message (argument #1)")
			end
		};

		ShowNotes = {
			Prefix = Settings.Prefix;
			Commands = {"notes", "viewnotes"};
			Args = {"player"};
			Description = "Views notes on the target player(s)";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					local PlayerData = Core.GetPlayer(v)
					local notes = PlayerData.AdminNotes
					if not notes then
						Functions.Hint(`No notes found on {service.FormatPlayer(v)}`, {plr})
						continue
					end
					Remote.MakeGui(plr, "List", {Title = service.FormatPlayer(v), Table = notes})
				end
			end
		};

		Shutdown = {
			Prefix = Settings.Prefix;
			Commands = {"shutdown"};
			Args = {"reason"};
			Description = "Shuts the server down";
			Filter = true;
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				if Core.DataStore then
					Core.UpdateData("ShutdownLogs", function(logs)
						table.insert(logs, 1, {
							User = plr and plr.Name or "[Server]",
							Time = os.time(),
							Reason = args[1] or "N/A"
						})

						local nlogs = #logs
						if nlogs > Logs.OldCommandLogsLimit then
							table.remove(logs, nlogs)
						end

						return logs
					end)
				end

				Functions.Shutdown(args[1])
			end
		};

		ShutdownLogs = {
			Prefix = Settings.Prefix;
			Commands = {"shutdownlogs", "shutdownlog", "slogs", "shutdowns"};
			Args = {};
			Description = "Shows who shutdown or restarted a server and when";
			AdminLevel = 200;
			ListUpdater = function(plr: Player)
				local logs = Core.GetData("ShutdownLogs") or {}
				local tab = {}
				for i, v in logs do
					if v.Restart then v.Time ..= " [RESTART]" end
					tab[i] = {
						Text = `{v.Time}: {v.User}`;
						Desc = `Reason: {v.Reason}`;
					}
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Shutdown Logs";
					Table = Logs.ListUpdaters.ShutdownLogs(plr);
					Update = "ShutdownLogs";
				})
			end
		};

		SystemMessage = {
			Prefix = Settings.Prefix;
			Commands = {"sm", "systemmessage", "sysmsg"};
			Args = {"message"};
			Filter = true;
			Description = "Same as message but says SYSTEM MESSAGE instead of your name, or whatever system message title is server to...";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				Functions.Message(Settings.SystemTitle, service.BroadcastFilter(assert(args[1], "Missing message (argument #1)"), plr), service.GetPlayers(), true)
			end
		};

		SystemNotify = {
			Prefix = Settings.Prefix;
			Commands = {"sn", "systemnotify", "sysnotif", "sysnotify", "systemsmallmessage", "snmessage", "snmsg", "ssmsg", "ssmessage"};
			Args = {"message"};
			Filter = true;
			Description = "Makes a system small message";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing message")
				for _, v in service.GetPlayers() do
					Remote.RemoveGui(v, "Notify")
					Functions.Notify(Settings.SystemTitle, service.Filter(args[1], plr, v), {v})
				end
			end
		};

		UnDisguise = {
			Prefix = Settings.Prefix;
			Commands = {"undisguise", "removedisguise", "cleardisguise", "nodisguise"};
			Args = {"player"};
			Description = "Removes the player's disguise";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if Variables.DisguiseBindings[v.UserId] then
						Variables.DisguiseBindings[v.UserId].Rename:Disconnect()
						Variables.DisguiseBindings[v.UserId].Rename = nil
					end
					Variables.DisguiseBindings[v.UserId] = nil
				end
				Commands.UnChar.Function(plr, args)
				Commands.UnDisplayName.Function(plr, args)
			end
		};

		UnlockMap = {
			Prefix = Settings.Prefix;
			Commands = {"unlockmap"};
			Args = {};
			Description = "Unlocks the map";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, obj in workspace:GetDescendants()do
					if obj:IsA("BasePart")then
						obj.Locked = false
					end
				end
			end
		};

		UnLoopKill = {
			Prefix = Settings.Prefix;
			Commands = {"unloopkill"};
			Args = {"player"};
			Description = "Un-Loop Kill";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					service.StopLoop(`{v.UserId}LOOPKILL`)
				end
			end
		};


		Whitelist = {
			Prefix = Settings.Prefix;
			Commands = {"wl", "enablewhitelist", "whitelist"};
			Args = {"on/off/add/remove/list/clear", "optional player"};
			Description = "Enables/disables the server whitelist; :wl username to add them to the whitelist";
			AdminLevel = 200;
			Function = function(plr: Player, args: {string})
				local sub = string.lower(args[1])

				if sub == "on" or sub == "enable" then
					Variables.Whitelist.Enabled = true
					Functions.Hint("Enabled server whitelist", service.Players:GetPlayers())
				elseif sub == "off" or sub == "disable" then
					Variables.Whitelist.Enabled = false
					Functions.Hint("Disabled server whitelist", service.Players:GetPlayers())
				elseif sub == "add" then
					if args[2] then
						local plrs = service.GetPlayers(plr, args[2], {
							DontError = true;
							IsServer = false;
							IsKicking = false;
							UseFakePlayer = true;
						})
						if #plrs>0 then
							for _, v in plrs do
								table.insert(Variables.Whitelist.Lists.Settings, `{v.Name}:{v.UserId}`)
								Functions.Hint(`Added {service.FormatPlayer(v)} to the whitelist`, {plr})
							end
						else
							table.insert(Variables.Whitelist.Lists.Settings, args[2])
						end
					else
						error("Missing user argument")
					end
				elseif sub == "remove" then
					if args[2] then
						for i, v in Variables.Whitelist.Lists.Settings do
							if string.sub(string.lower(v), 1,#args[2]) == string.lower(args[2])then
								table.remove(Variables.Whitelist.Lists.Settings,i)
								Functions.Hint(`Removed {v} from the whitelist`, {plr})
							end
						end
					else
						error("Missing user argument")
					end
				elseif sub == "list" then
					local Tab = {}
					for Key, List in Variables.Whitelist.Lists do
						local Prefix = Key == "Settings" and "" or `[{Key}] `
						for _, User in List do
							table.insert(Tab, {Text = Prefix .. User, Desc = User})
						end
					end
					Remote.MakeGui(plr, "List", {Title = "Whitelist List"; Tab = Tab;})
				elseif sub == "clear" then
					Variables.Whitelist.Lists.Settings = {}
					Functions.Hint("Cleared server whitelist", service.Players:GetPlayers())
				else
					error("Invalid subcommand (on/off/add/remove/list/clear)")
				end
			end
		};

	}
end
