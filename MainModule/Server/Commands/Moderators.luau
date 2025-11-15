return function(Vargs, env)
	local server = Vargs.Server;
	local service = Vargs.Service;

	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	if env then setfenv(1, env) end

	local Routine = env.Routine
	local Pcall = env.Pcall

	local activePT = false

	return {
		AdminList = {
			Prefix = Settings.Prefix;
			Commands = {"admins", "adminlist", "ranks"};
			Args = {};
			Description = "Shows you the list of admins, also shows admins that are currently in the server";
			AdminLevel = 100;
			ListUpdater = function(plr: Player)
				local RANK_DESCRIPTION_FORMAT = "Rank: %s; Level: %d"
				local RANK_RICHTEXT = "<b><font color='rgb(77, 77, 255)'>%s (Level: %d)</font></b>"
				local RANK_TEXT_FORMAT = "%s [%s] [%s]"

				local temptable = {}
				local unsorted = {}

				table.insert(temptable, "<b><font color='rgb(60, 180, 0)'>Admins In-Game:</font></b>")

				for _, v in service.Players:GetPlayers() do
					local level, rankName = Admin.GetLevel(v);
					if level > 0 then
						local ONSHIFT_VARIABLE = server.Variables.shiftPlayers[v.UserId]
						local ONSHIFT = "<b><font color='rgb(255, 0, 0)'>OFF DUTY</font></b>"
						if ONSHIFT_VARIABLE then
							ONSHIFT = "<b><font color='rgb(0, 255, 0)'>ON DUTY</font></b>"
						else
							ONSHIFT = "<b><font color='rgb(255, 0, 0)'>OFF DUTY</font></b>"
						end
						table.insert(unsorted, {
							Text = string.format(RANK_TEXT_FORMAT, service.FormatPlayer(v), (rankName or (`Level: {level}`)), ONSHIFT);
							Desc = string.format(RANK_DESCRIPTION_FORMAT, rankName or (level >= 1000 and "Place Owner") or "Unknown", level);
							SortLevel = level;
						})
					end
				end

				table.sort(unsorted, function(one, two)
					return one.SortLevel > two.SortLevel
				end)

				for _, v in unsorted do
					v.SortLevel = nil
					table.insert(temptable, v)
				end

				table.clear(unsorted)

				table.insert(temptable, "")
				table.insert(temptable, "<b><font color='rgb(180, 60, 0)'>All Admins:</font></b>")

				for rank, data in Settings.Ranks do
					if not data.Hidden then
						table.insert(unsorted, {
							Text = string.format(RANK_RICHTEXT, rank, data.Level);
							Desc = "";
							Level = data.Level;
							Users = data.Users;
							Rank = rank;
						})
					end
				end

				table.sort(unsorted, function(one, two)
					return one.Level > two.Level
				end)

				for _, v in unsorted do
					local Users = v.Users or {};
					local Level = v.Level or 0;
					local Rank = v.Rank or "Unknown";

					v.Users = nil
					v.Level = nil
					v.Rank = nil

					table.insert(temptable, v)

					for _, user in Users do
						table.insert(temptable, {
							Text = `  {user}`;
							Desc = string.format(RANK_DESCRIPTION_FORMAT, Rank, Level);
							--SortLevel = data.Level;
						})
					end
				end

				return temptable
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Admin List";
					Icon = server.MatIcons["Admin panel settings"];
					Table = Logs.ListUpdaters.AdminList(plr);
					TextSelectable = true;
					Update = "AdminList";
					RichText = true;
				})
			end;
		};


		Bring = {
			Prefix = Settings.Prefix;
			Commands = {"bring"};
			Args = {"player"};
			Description = "Teleports the target player(s) to your position";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local players = service.GetPlayers(plr, if args[1] then args[1] else "me")
				if #players == 1 and players[1] == plr then
					Commands.Thru.Function(plr, {`@{plr.Name}`})
					return
				end
				if #players < 10 or not Commands.MassBring or Remote.GetGui(plr, "YesNoPrompt", {
					Title = "Suggestion";
					Icon = server.MatIcons.Feedback;
					Question = `Would you like to use {Settings.Prefix}massbring instead? (Arranges the {#players} players in rows.)`;
					}) ~= "Yes"
				then
					Commands.Teleport.Function(plr, {args[1], `@{plr.Name}`})
				else
					Process.Command(plr, `{Settings.Prefix}massbring{Settings.SplitKey}{args[1]}`)
				end
			end
		};

		BuildingTools = {
			Prefix = Settings.Prefix;
			Commands = {"btools", "f3x", "buildtools", "buildingtools", "buildertools"};
			Args = {"player"};
			Description = "Gives the target player(s) F3X building tools.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local F3X = Deps.Assets:FindFirstChild("F3X Deps") and (function(deps)
					local F3X = service.New("Tool", {
						GripPos = Vector3.new(0, 0, 0.4),
						CanBeDropped = false,
						ManualActivationOnly = false,
						ToolTip = "Building Tools by F3X",
						Name = "Building Tools"
					}, true)
					local clonedDeps = deps:Clone()

					for _, obj in clonedDeps:GetDescendants() do
						if obj:IsA("BaseScript") then
							obj.Disabled = false
						end
					end
					for _, obj in clonedDeps:GetChildren() do
						obj.Parent = F3X
					end

					clonedDeps:Destroy()
					return F3X
				end)(Deps.Assets:FindFirstChild("F3X Deps")) or Variables.F3XCached and Variables.F3XCached:Clone() or require(580330877)()
				Variables.F3XCached = Variables.F3XCached or F3X:Clone()
				service.New("StringValue", {
					Name = `__ADONIS_VARIABLES_{Variables.CodeName}`,
					Parent = F3X
				})

				for _, v in service.GetPlayers(plr, args[1]) do
					local Backpack = v:FindFirstChildOfClass("Backpack")

					if Backpack then
						F3X:Clone().Parent = Backpack
					end
				end

				F3X:Destroy()
			end
		};

		Cameras = {
			Prefix = Settings.Prefix;
			Commands = {"cameras", "cams"};
			Args = {};
			Description = "Shows a list of admin cameras";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local tab = table.create(#Variables.Cameras)
				for _, v in Variables.Cameras do
					table.insert(tab, {Text = v.Name, Desc = `Pos: {v.Brick.Position}`})
				end
				Remote.MakeGui(plr, "List", {Title = "Cameras", Tab = tab})
			end
		};

-- Unified Cases Command - Replace CaseHelp, CaseList, CaseTest, and MyCases with this

	Claim = {
		Prefix = Settings.Prefix;
		Commands = {"claim", "q"};
		Args = {"player"};
		Description = "Claim a help case";
		AdminLevel = 100;
		Function = function(plr: Player, args: {string})
			if not Variables or not Variables.HelpRequests then
				return Functions.Hint("Error: Help system not available", {plr})
			end

			local targetName = args[1]
			if not targetName then
				return Functions.Hint("Usage: ;claim <username>", {plr})
			end

			-- Find matching case (support partial names)
			local matchedCase = nil
			for username, caseData in pairs(Variables.HelpRequests) do
				if caseData and caseData.Pending and caseData.isIngame then
					if username:lower():find(targetName:lower(), 1, true) then
						matchedCase = username
						break
					end
				end
			end

			if not matchedCase then
				return Functions.Hint("No active case found for: " .. targetName, {plr})
			end

			local caseData = Variables.HelpRequests[matchedCase]

			-- Check if already claimed
			if caseData.ClaimedBy then
				return Functions.Hint(`Case for {matchedCase} is already claimed by {caseData.ClaimedBy}`, {plr})
			end

			-- Claim the case
			caseData.ClaimedBy = plr.Name
			caseData.ClaimedTime = os.time()

			-- Log the action
			if Functions.LogCaseAction then
				Functions.LogCaseAction(plr, "CLAIM", matchedCase, `Moderator {plr.Name} claimed case`)
			end

			-- Start tracking the player
			local target = service.Players:FindFirstChild(matchedCase)
			if target then
				Commands.Track.Function(plr, {target.Name})
				Functions.Hint(`A moderator ({plr.Name}) is now helping you with your request!`, {target})
			end

			Functions.Hint(`Claimed case for {matchedCase} and started tracking`, {plr})
		end
	};

	Unclaim = {
		Prefix = Settings.Prefix;
		Commands = {"unclaim"};
		Args = {"player"};
		Description = "Unclaim a help case (allows another moderator to claim it)";
		AdminLevel = 100;
		Function = function(plr: Player, args: {string})
			if not Variables or not Variables.HelpRequests then
				return Functions.Hint("Error: Help system not available", {plr})
			end

			local targetName = args[1]
			if not targetName then
				return Functions.Hint("Usage: ;unclaim <username>", {plr})
			end

			local matchedCase = nil
			for username, caseData in pairs(Variables.HelpRequests) do
				if caseData and caseData.Pending and caseData.isIngame then
					if username:lower():find(targetName:lower(), 1, true) then
						matchedCase = username
						break
					end
				end
			end

			if not matchedCase then
				return Functions.Hint("No active case found for: " .. targetName, {plr})
			end

			local caseData = Variables.HelpRequests[matchedCase]

			if caseData.ClaimedBy and caseData.ClaimedBy ~= plr.Name then
				return Functions.Hint(`Case for {matchedCase} is claimed by {caseData.ClaimedBy}, not you`, {plr})
			end

			caseData.ClaimedBy = nil
			caseData.ClaimedTime = nil

			Functions.Hint(`Unclaimed case for {matchedCase}`, {plr})
		end
	};

	CloseCase = {
		Prefix = Settings.Prefix;
		Commands = {"close", "closecase"};
		Args = {"player"};
		Description = "Close a help case permanently";
		AdminLevel = 100;
		Function = function(plr: Player, args: {string})
			if not Variables or not Variables.HelpRequests then
				return Functions.Hint("Error: Help system not available", {plr})
			end

			local targetName = args[1]
			if not targetName then
				return Functions.Hint("Usage: ;close <username>", {plr})
			end

			local matchedCase = nil
			for username, caseData in pairs(Variables.HelpRequests) do
				if caseData and caseData.Pending and caseData.isIngame then
					if username:lower():find(targetName:lower(), 1, true) then
						matchedCase = username
						break
					end
				end
			end

			if not matchedCase then
				return Functions.Hint("No active case found for: " .. targetName, {plr})
			end

			local caseData = Variables.HelpRequests[matchedCase]

			if caseData.ClaimedBy and caseData.ClaimedBy ~= plr.Name then
				return Functions.Hint(`Case for {matchedCase} is claimed by {caseData.ClaimedBy}, not you`, {plr})
			end

			if Functions.LogCaseAction then
				Functions.LogCaseAction(plr, "CLOSE", matchedCase, `Moderator {plr.Name} closed case`)
			end

			local target = service.Players:FindFirstChild(matchedCase)
			if target then
				Functions.Hint(`Your help request has been closed by {plr.Name}. Thank you!`, {target})
			end

			Variables.HelpRequests[matchedCase] = nil

			Functions.Hint(`Closed case for {matchedCase}`, {plr})
		end
	};

	Cases = {
		Prefix = Settings.Prefix;
		Commands = {"cases", "case"};
		Args = {"view (all/mine/stats/help) - default: all"};
		Description = "Unified case management system - View and manage help cases";
		AdminLevel = 100;
		Function = function(plr: Player, args: {string})
			-- Check if Variables exists
			if not Variables then
				return Functions.Hint("Error: Variables not available", {plr})
			end

			-- Get all active cases
			local Cases = Variables.HelpRequests or {}

			-- Send to window UI
			Remote.MakeGui(plr, "Cases", {
				Cases = Cases;
				CmdPrefix = Settings.Prefix[1];
			})
		end
	};

		ChatLogs = {
			Prefix = Settings.Prefix;
			Commands = {"chatlogs", "chats", "chathistory"};
			Args = {"autoupdate? (default: true)"};
			Description = "Displays the current chat logs for the server";
			AdminLevel = 100;
			ListUpdater = "Chats";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Chat Logs";
					Tab = Logs.ListUpdaters.ChatLogs(plr);
					Dots = true;
					Update = "ChatLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
				})
			end
		};

		Clear = {
			Prefix = Settings.Prefix;
			Commands = {"clear", "cleargame", "clr"};
			Args = {};
			Description = "Remove admin objects";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				service.StopLoop("ChickenSpam")
				Functions.CleanWorkspace()
				for _, v in Variables.Objects do
					if v.ClassName == "Script" or v.ClassName == "LocalScript" then
						v.Disabled = true
					end
					v:Destroy()
				end

				for i, v in Variables.Cameras do
					if v then
						table.remove(Variables.Cameras, i)
						v:Destroy()
					end
				end

				for _, v in Variables.Jails do
					if not v.Player or not v.Player.Parent then
						local ind = v.Index
						service.StopLoop(`{ind}JAIL`)
						Pcall(function() v.Jail:Destroy() end)
						Variables.Jails[ind] = nil
					end
				end

				for _, v in workspace:GetChildren() do
					if v.ClassName == "Message" or v.ClassName == "Hint" then
						v:Destroy()
					end

					if string.match(v.Name, "A_Probe (.*)") then
						v:Destroy()
					end
				end

				table.clear(Variables.Objects)
				--RemoveMessage()
			end
		};

		ClearEffects = {
			Prefix = Settings.Prefix;
			Commands = {"cleareffects"};
			Args = {"player"};
			Description = "Removes all screen UI effects such as Spooky, Clown, ScreenImage, ScreenVideo, etc.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1] or "all") do
					Remote.RemoveGui(v, "Effect")
				end
			end
		};

		ClearGUIs = {
			Prefix = Settings.Prefix;
			Commands = {"clearadonisguis", "clearguis", "clearmessages", "clearhints", "clrguis"};
			Args = {"player", "delete all? (default: false)"};
			Description = `Removes Adonis on-screen GUIs for the target player(s); if <delete all> is false, wil, only clear {Settings.Prefix}m, {Settings.Prefix}n, {Settings.Prefix}h, {Settings.Prefix}alert and screen effect GUIs`;
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local deleteAll = args[2] and (args[2]:lower() == "true" or args[2]:lower() == "yes")
				for _, v in service.GetPlayers(plr, args[1]) do
					if deleteAll then
						Routine(Remote.RemoveGui, v, true)
					else
						Routine(function()
							for _, guiName in {"Message", "Hint", "Notify", "Effect", "Alert"} do
								Remote.RemoveGui(v, guiName)
							end
						end)
					end
					-- Remove Dex
					for _, name in Variables.DexNames do
						task.spawn(Remote.RemoveLocal, v, name, "PlayerGui")
					end
				end
			end
		};

		ClearLighting = {
			Prefix = Settings.Prefix;
			Commands = {"fixplayerlighting", "rplighting", "clearlighting", "serverlighting"};
			Args = {"player"};
			Description = "Sets the player's lighting to match the server's";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					for prop, val in Variables.LightingSettings do
						Remote.SetLighting(v, prop, val)
					end
				end
			end
		};

		Clip = {
			Prefix = Settings.Prefix;
			Commands = {"clip", "unnoclip"};
			Args = {"player"};
			Description = "Un-NoClips the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, p in service.GetPlayers(plr, args[1]) do
					local old = p.Character.Humanoid:FindFirstChild("ADONIS_NoClip")
					if old then
						if old.Clip.Value then
							old.Clip.Value = false

							task.delay(.5,function() old:Destroy() end)

							if Settings.CommandFeedback then
								Functions.Notification("Noclip", "Character noclip has been disabled. You will no longer be able to walk through walls.", {p}, 15, "Info") -- Functions.Notification(title,message,player,time,icon)
							end
						end
					end
				end
			end
		};

		CommandBox = {
			Prefix = Settings.Prefix;
			Commands = {"cmdbox", "commandbox"};
			Args = {};
			Description = "Command Box";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr,"CommandBox")
			end;
		};

		Countdown = {
			Prefix = Settings.Prefix;
			Commands = {"countdown", "timer", "cd"};
			Args = {"time (in seconds)"};
			Description = "Countdown";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local num = assert(tonumber(args[1]), "Missing or invalid time value (must be a number)")
				assert(num <= 1000, "Countdown cannot be longer than 1000 seconds.")
				assert(num >= 0, "Countdown cannot be negative.")
				for _, v in service.GetPlayers() do
					Remote.MakeGui(v, "Countdown", {
						Time = math.round(num);
					})
				end
			end
		};

		CountdownPM = {
			Prefix = Settings.Prefix;
			Commands = {"countdownpm", "timerpm", "cdpm"};
			Args = {"player", "time (in seconds)"};
			Description = "Countdown on a target player(s) screen.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player and time value!")
				local num = assert(tonumber(args[2]), "Missing or invalid time value (must be a number)")
				assert(num <= 1000, "Countdown cannot be longer than 1000 seconds.")
				assert(num >= 0, "Countdown cannot be negative.")
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.MakeGui(v, "Countdown", {
						Time = math.round(num);
					})
				end
			end
		};


		DeleteWaypoint = {
			Prefix = Settings.Prefix;
			Commands = {"delwaypoint", "delwp", "delcheckpoint", "deletewaypoint", "deletewp", "deletecheckpoint"};
			Args = {"name"};
			Description = "Deletes the waypoint named <name> if it exist";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, v in Variables.Waypoints do
					if string.sub(string.lower(i), 1, #args[1])==string.lower(args[1]) or string.lower(args[1])=="all" then
						Variables.Waypoints[i]=nil
						Functions.Hint(`Deleted waypoint {i}`, {plr})
					end
				end
			end
		};

		ESP = {
			Prefix = Settings.Prefix;
			Commands = {"esp"};
			Args = {"target (optional)", "brickcolor (optional)"};
			Filter = true;
			Description = "Allows you to see <target> (or all humanoids if no target is supplied) through walls";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string}, data: {})
				Remote.Send(plr, "Function", "CharacterESP", false)

				if args[1] then
					for _2, v2 in service.GetPlayers(plr, args[1]) do
						if not v2.Character then
							continue
						end

						Remote.Send(plr, "Function", "CharacterESP", true, v2.Character, args[2] and BrickColor.new(args[2]).Color)
					end
				else
					Remote.Send(plr, "Function", "CharacterESP", true)
				end
			end
		};

		ExploitLogs = {
			Prefix = Settings.Prefix;
			Commands = {"exploitlogs", "exploitlog"};
			Args = {"autoupdate? (default: true)"};
			Description = "View the exploit logs for the server OR a specific player";
			AdminLevel = 100;
			ListUpdater = "Exploit";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Exploit Logs";
					Tab = Logs.ListUpdaters.ExploitLogs(plr);
					Dots = true;
					Update = "ExploitLogs";
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
				})
			end
		};

		Fly = {
			Prefix = Settings.Prefix;
			Commands = {"fly", "flight", "flynoclip"};
			Args = {"player", "speed", "noclip? (default: true)"};
			Description = "Lets the target player(s) fly";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local speed = tonumber(args[2]) or 2
				local scr = Deps.Assets.Fly:Clone()
				local sVal = service.New("NumberValue", {
					Name = "Speed";
					Value = speed;
					Parent = scr;
				})
				local NoclipVal = service.New("BoolValue", {
					Name = "Noclip";
					Value = not args[3] or (args[3] and (string.lower(args[3]) == "true" or string.lower(args[3]) == "yes"));
					Parent = scr;
				})
				

				scr.Name = "ADONIS_FLIGHT"

				for i, v in service.GetPlayers(plr, args[1]) do
					local part = v.Character and v.Character:FindFirstChild("HumanoidRootPart")
					if part then
						local oldp = part:FindFirstChild("ADONIS_FLIGHT_POSITION")
						local oldpa = part:FindFirstChild("ADONIS_FLIGHT_POSITION_ATTACHMENT")
						local oldg = part:FindFirstChild("ADONIS_FLIGHT_GYRO")
						local oldga = part:FindFirstChild("ADONIS_FLIGHT_GYRO_ATTACHMENT")
						local olds = part:FindFirstChild("ADONIS_FLIGHT")
						if oldp then oldp:Destroy() end
						if oldpa then oldpa:Destroy() end
						if oldg then oldg:Destroy() end
						if oldga then oldga:Destroy() end
						if olds then Remote.Send(v, "Function", "Unfly") olds:Destroy() end

                        local new = scr:Clone()
						local flightPositionAttachment: Attachment = service.New("Attachment", {
							Name = "ADONIS_FLIGHT_POSITION_ATTACHMENT",
							Parent = part
						})
						local flightGyroAttachment: Attachment = service.New("Attachment", {
							Name = "ADONIS_FLIGHT_GYRO_ATTACHMENT",
							Parent = part
						})
						local flightPosition: AlignPosition = service.New("AlignPosition", {
							Name = "ADONIS_FLIGHT_POSITION",
							MaxForce = 0,
							Position = part.Position,
							Attachment0 = flightPositionAttachment,
							Mode = Enum.PositionAlignmentMode.OneAttachment,
							Parent = part
						})
						local flightGyro: AlignOrientation = service.New("AlignOrientation", {
							Name = "ADONIS_FLIGHT_GYRO",
							MaxTorque = 0,
							CFrame = part.CFrame,
							Attachment0 = flightGyroAttachment,
							Mode = Enum.OrientationAlignmentMode.OneAttachment,
							Parent = part
						})

						new.Parent = part
						new.Disabled = false
					end
				end
                scr:Destroy()

				Functions.Notification("Flight", "You are now flying - press E to toggle flight", service.GetPlayers(plr, args[1], {DontError = true}), 10)
			end
		};

		FlySpeed = {
			Prefix = Settings.Prefix;
			Commands = {"flyspeed", "flightspeed"};
			Args = {"player", "speed"};
			Description = "Change the target player(s) flight speed";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local speed = tonumber(args[2])

				for i, v in service.GetPlayers(plr, args[1]) do
					local part = v.Character:FindFirstChild("HumanoidRootPart")
					if part then
						local scr = part:FindFirstChild("ADONIS_FLIGHT")
						if scr then
							local sVal = scr:FindFirstChild("Speed")
							if sVal then
								sVal.Value = speed
								if Settings.CommandFeedback then
									Functions.Notification("Notification", `Character fly speed has been set to {speed}`, {v}, 15)
								end
							end
						end
					end
				end
			end
		};


		ForceField = {
			Prefix = Settings.Prefix;
			Commands = {"ff";"forcefield";};
			Args = {"player", "visible? (default: true)"};
			Description = "Gives a force field to the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						service.New("ForceField", v.Character).Visible = if args[2] and args[2]:lower() == "false" then false else true
					end
				end
			end
		};


		Freeze = {
			Prefix = Settings.Prefix;
			Commands = {"freeze"};
			Args = {"player"};
			Description = "Freezes the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						if v.Character then
							for a, obj in v.Character:GetChildren() do
								if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then obj.Anchored = true end
							end
						end
					end)
				end
			end
		};

		FullGod = {
			Prefix = Settings.Prefix;
			Commands = {"fullgod", "totalgod"};
			Args = {"player"};
			Description = `Same as {Functions.GetMainPrefix()}god, but also provides blast protection`;
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.MaxHealth = math.huge
						hum.Health = 9e9
						service.New("ForceField", {
							Parent = hum.Parent;
							Name = "ADONIS_FULLGOD";
							Visible = false;
						})
						if Settings.CommandFeedback then
							Functions.Notification("God Mode", "Character god mode has been enabled. You will not take any damage.", {v}, 15, "Info")
						end
					end
				end
			end
		};

		GetGroupRank = {
			Prefix = Settings.Prefix;
			Commands = {"rank", "getrank", "grouprank"};
			Args = {"player", "group name"};
			Description = "Shows you what rank the target player(s) are in the specified group";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[2], "Missing group name (argument #2)")
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					local groupInfo = Admin.GetPlayerGroup(v, args[2])
					if groupInfo then
						Functions.Hint(string.format("%s has rank [%d] %s in %s", service.FormatPlayer(v), groupInfo.Rank, groupInfo.Role, groupInfo.Name), {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v)} is not in the group {args[2]}`, {plr})
					end
				end
			end
		};

		GetPing = {
			Prefix = Settings.Prefix;
			Commands = {"getping"};
			Args = {"player"};
			Description = "Shows the target player's ping";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Functions.Hint(`{service.FormatPlayer(v)}'s Ping is {v:GetNetworkPing() * 1000}ms`, {plr})
				end
			end
		};

		GiveStarterPack = {
			Prefix = Settings.Prefix;
			Commands = {"startertools", "starttools"};
			Args = {"player"};
			Description = "Gives the target player(s) tools that are in the game's StarterPack";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local Backpack = v:FindFirstChildOfClass("Backpack")
					if Backpack then
						for a, q in service.StarterPack:GetChildren() do
							local q = q:Clone()
							if not q:FindFirstChild(Variables.CodeName) then
								service.New("StringValue", q).Name = Variables.CodeName
							end
							q.Parent = Backpack
						end
					end
				end
			end
		};

		God = {
			Prefix = Settings.Prefix;
			Commands = {"god", "immortal"};
			Args = {"player"};
			Description = "Makes the target player(s) immortal, makes their health so high that normal non-explosive weapons can't kill them";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.MaxHealth = math.huge
						hum.Health = 9e9
						if Settings.CommandFeedback then
							Functions.Notification("God mode", "Character God mode has been enabled. You will not take damage from non-explosive weapons.", {v}, 15, "Info")
						end
					end
				end
			end
		};


		HandTo = {
			Prefix = Settings.Prefix;
			Commands = {"handto"};
			Args = {"player"};
			Description = "Hands an item to a player";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local target = service.GetPlayers(plr, args[1])[1]
				if not target then return end
				if target == plr then
					Functions.Hint("[HANDTO]: Cannot give item to yourself", {plr})
					return
				end

				local targetchar = target.Character
				local plrChar = plr.Character
				if not targetchar or not plrChar then
					Functions.Hint(`[HANDTO]: Unable to hand item to {target.Name}`, {plr})
					return
				end

				local tool = plrChar:FindFirstChildOfClass("Tool")
				if not tool then
					Functions.Hint("[HANDTO]: You must be holding an item", {plr})
					return
				end

				local foundToolInTargetCharacter = targetchar:FindFirstChildOfClass("Tool")
				tool.Parent = if foundToolInTargetCharacter then target.Backpack else targetchar
				Functions.Hint(`[HANDTO]: Successfully given the item '{tool.Name}' to {target.Name}`, {plr})
			end;
		};

		Heal = {
			Prefix = Settings.Prefix;
			Commands = {"heal"};
			Args = {"player"};
			Description = "Heals the target player(s) (Regens their health)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.Health = hum.MaxHealth
					end
				end
			end
		};

		HealthList = {
			Prefix = Settings.Prefix;
			Commands = {"healthlist", "healthlogs", "healths", "hlist","hlogs"};
			Args = {"autoupdate? (default: true)"};
			Description = "Shows a list of all players' current and max healths.";
			AdminLevel = 100;
			ListUpdater = function(plr: Player, args: {string})
				local rawTable = {}
				for _, v in Functions.GetPlayers(plr, "all") do
					if v.Character and v.Character:FindFirstChildOfClass("Humanoid") then
						table.insert(rawTable, {service.FormatPlayer(v), v.Character:FindFirstChildOfClass("Humanoid").Health, v.Character:FindFirstChildOfClass("Humanoid").MaxHealth})
					else
						table.insert(rawTable, {service.FormatPlayer(v), 0, 0})
					end
				end

				table.sort(rawTable, function(a,b)
					if a[3] == b[3] then
						if a[2] == b[2] then
							return(a[1] < b[1])
						else
							return(a[2] > b[2])
						end
					else
						return(a[3] > b[3])
					end
				end)

				local goddedCheck = false
				local normalCheck = false
				local godTable = {}
				local zeroTable = {}
				local normalTable = {}

				for _, v in rawTable do
					if tostring(v[3]) == "inf" then
						table.insert(godTable, v)
						goddedCheck = true
					else
						if v[3] <= 0 then
							table.insert(zeroTable, v)
							normalCheck = true
						else
							table.insert(normalTable, v)
							normalCheck = true
						end
					end
				end

				local logTable = {}

				if goddedCheck == true then
					table.insert(logTable, "<b><u>Godded Players: </u></b>")
				end

				for _, v in godTable do
					local color = "100, 175, 255"
					table.insert(logTable, `{v[1]} :: <font color = "rgb({color})">[{math.round(v[2])}/{math.round(v[3])}]</font>`)
				end

				if normalCheck == true then
					table.insert(logTable, "<b><u>Normal Players: </u></b>")
				end

				for _, v in normalTable do
					local color
					if v[2]/v[3] >= .5 then
						color =  `{math.round(100 + 155 * (v[2]/v[3] * -2 + 2))}, 255, 100`
					else
						color =  `255, {math.round(100 + 155 * v[2]/v[3] * 2)}, 100`
					end
					table.insert(logTable, `{v[1]} :: <font color = "rgb({color})">[{math.round(v[2])}/{math.round(v[3])}]</font>`)
				end

				for _, v in zeroTable do
					local color = "255, 100, 100"
					table.insert(logTable, `{v[1]} :: <font color = "rgb({color})">[N/A]</font>`)
				end

				return logTable
			end;

			Function = function(plr: Player, args: {string})
				Functions.Hint("Fetching player healths.", {plr})
				Remote.MakeGui(plr, "List", {
					Title = "Player Healths";
					Tab = Logs.ListUpdaters.HealthList(plr);
					Dots = true;
					Update = "HealthList";
					AutoUpdate = if args[1] and (args[1]:lower() == "false" or args[1]:lower() == "no") then nil else 1;
					Sanitize = false;
					Stacking = true;
					RichText = true;
				})
			end
		};

		Hint = {
			Prefix = Settings.Prefix;
			Commands = {"h", "hint"};
			Args = {"message"};
			Filter = true;
			Description = "Makes a hint";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing message")
				Functions.Hint(string.format("%s: %s", service.FormatPlayer(plr), service.BroadcastFilter(args[1], plr)), service.GetPlayers(), nil, service.FormatPlayer(plr), `rbxthumb://type=AvatarHeadShot&id={plr.UserId}&w=48&h=48`)
			end
		};

		HintCountdown = {
			Prefix = Settings.Prefix;
			Commands = {"hcountdown", "hc"};
			Args = {"time"};
			Description = "Hint Countdown";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local num = math.min(assert(tonumber(args[1]), "Time must be a number"), 120)
				local loop
				loop = service.StartLoop("HintCountdown", 1, function()
					if num < 1 then
						loop.Running = false
					else
						Functions.Hint(num, service.GetPlayers(), 2.5)
						num -= 1
					end
				end)
			end
		};

		Invisible = {
			Prefix = Settings.Prefix;
			Commands = {"invisible", "invis"};
			Args = {"player"};
			Description = "Makes the target player(s) invisible";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						for a, obj in v.Character:GetChildren() do
							if obj:IsA("BasePart") then
								obj.Transparency = 1
								if obj:FindFirstChild("face") then
									obj.face.Transparency = 1
								end
								if obj:FindFirstChildOfClass("BillboardGui") then
									obj:FindFirstChildOfClass("BillboardGui").Enabled = false
								end
							elseif obj:IsA("Accoutrement") and obj:FindFirstChild("Handle") then
								obj.Handle.Transparency = 1
							elseif obj:IsA("Tool") then
								for _, Descendant in obj:GetDescendants() do
									if Descendant:IsA("BasePart") or Descendant:IsA("Decal") or Descendant:IsA("UnionOperation") then
										Descendant:SetAttribute('ADONIS_OriginalTransparency',Descendant.Transparency)
										Descendant.Transparency = 1
									end
								end
							elseif obj:IsA("ForceField") then
								obj.Visible = false
							elseif obj:IsA("BillboardGui") then
								obj.Enabled = false
							elseif obj.Name == "Head" then
								local face = obj:FindFirstChildOfClass("Decal")
								if face then
									face.Transparency = 1
								end
							end
						end
					end
				end
			end
		};

		Jail = {
			Prefix = Settings.Prefix;
			Commands = {"jail", "imprison"};
			Args = {"player","Duration: Optional","BrickColor: Optional"};
			Description = "Jails the target player(s), removing their tools until they are un-jailed; Put an optional time function to set when they get released from jail; Specify a BrickColor to change the color of the jail bars";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local Duration, Valid
				if args[2] then
					if args[2]:lower() ~= ("inf" or "infinite" or "infinity" or "unlimited") then
						Duration, Valid = args[2]:gsub("^(%d+)([smhd])$", function(val, unit)
							return if unit == "s" then val
								elseif unit == "m" then val * 60
								elseif unit == "h" then val * 60 * 60
								else val * 60 * 60 * 24
						end)
						assert(Valid > 0, "Invalid duration value (argument #2)")
					else
						Duration = math.huge
					end
				end

				local Color = args[3] and (string.lower(args[3]) == "rainbow" and "rainbow" or string.match(args[3], "%d") and Functions.ParseColor3(args[3]) or Functions.ParseBrickColor(args[3], true)) or BrickColor.new("White")

				for _, v in service.GetPlayers(plr, args[1]) do
					local cHumanoidRootPart	= v.Character and v.Character.PrimaryPart or v.Character and v.Character:FindFirstChild("HumanoidRootPart")
					if cHumanoidRootPart then
						local CF = CFrame.new(cHumanoidRootPart.CFrame.p + Vector3.new(0, 1, 0))
						local OrigPos = cHumanoidRootPart.Position

						local Model = service.New("Model", {
							Name = `{v.Name}_ADONISJAIL`,
							Archivable = false,
							ModelStreamingMode = Enum.ModelStreamingMode.Persistent
						})
						local top = service.New("Part", {
							Locked = true,
							Size = Vector3.new(6, 1, 6),
							TopSurface = 0,
							BottomSurface = 0,
							Anchored = true,
							CanCollide = true,
							BrickColor = BrickColor.new("Really black"),
							Transparency = 1,
							CFrame = CF*CFrame.new(0, 3.5, 0),

							Parent = Model,
						})

						local bottom = top:Clone()
						bottom.Transparency = 0
						bottom.CanCollide = true
						bottom.CFrame = CF * CFrame.new(0,-3.5, 0)
						local front = top:Clone()
						front.Transparency = 1
						front.Reflectance = 0
						front.Size = Vector3.new(6, 6, 1)
						front.CFrame = CF * CFrame.new(0, 0,-3)
						local back = front:Clone()
						back.Transparency = 1
						back.CFrame = CF * CFrame.new(0, 0, 3)
						back.Parent = Model
						local right = front:Clone()
						right.Transparency = 1
						right.Size = Vector3.new(1, 6, 6)
						right.CFrame = CF * CFrame.new(3, 0, 0)
						local left = right:Clone()
						left.Transparency = 1
						left.CFrame = CF * CFrame.new(-3, 0, 0)

						bottom.Parent = Model
						front.Parent = Model
						right.Parent = Model
						left.Parent = Model

						local msh = service.New("BlockMesh", {
							Scale = Vector3.new(1, 1, 0),
							Parent = front
						})

						local msh2 = msh:Clone()
						local msh3 = msh:Clone()
						msh3.Scale = Vector3.new(0, 1, 1)

						local msh4 = msh3:Clone()
						msh2.Parent = back
						msh3.Parent = right
						msh4.Parent = left

						local brick = service.New("Part", Model)
						local box = service.New("SelectionBox", {
							Adornee = brick,
							Parent = brick,
						})
						if typeof(Color) == "BrickColor" then
							box.Color3 = Color.Color
						elseif typeof(Color) == "Color3" then
							box.Color3 = Color
						end

						brick.Anchored = true
						brick.CanCollide = false
						brick.Transparency = 1
						brick.Size = Vector3.new(5, 7, 5)
						brick.CFrame = CF
						--table.insert(Variables.Objects, mod)

						local value = service.New("StringValue", {
							Name = "Player",
							Value = v.Name,
							Parent = Model,
						})

						cHumanoidRootPart.CFrame = CF

						local ind = tostring(v.UserId)
						local jail = {
							Player = v;
							Name = v.Name;
							Index = ind;
							Jail = Model;
							Tools = {};
							EndTime = if Duration then os.time()+Duration else nil;
						}
						Variables.Jails[ind] = jail

						v.Character.Humanoid:UnequipTools()
						local Backpack = v:FindFirstChildOfClass("Backpack")
						if Backpack then
							for _, k in Backpack:GetChildren() do
								if k:IsA("BackpackItem") then
									table.insert(jail.Tools,k)
									k.Parent = nil
								end
							end
						end

						Model.Parent = workspace

						service.TrackTask(`Thread: JailLoop{ind}`, function()
							while task.wait() and Variables.Jails[ind] == jail and Model.Parent == workspace do
								if Variables.Jails[ind] == jail and service.Players:FindFirstChild(jail.Name) then
									if Settings.ReJail then
										v = service.Players:FindFirstChild(jail.Name)
									end
									if Color == "rainbow" then
										box.Color3 = Color3.fromHSV(tick()%5/5, 1, 1)
									end

									if v.Character then
										local torso = v.Character:FindFirstChild("HumanoidRootPart")
										if torso then

											v.Character.Humanoid:UnequipTools()
											local Backpack = v:FindFirstChildOfClass("Backpack")
											if Backpack then
												for _, k in Backpack:GetChildren() do
													if k:IsA("BackpackItem") then
														table.insert(jail.Tools, k)
														k.Parent = nil
													end
												end
											end

											if (torso.Position-OrigPos).Magnitude > 3.3 then
												torso.CFrame = CF
											end
										end
									end
								elseif Variables.Jails[ind] ~= jail then
									Model:Destroy()
									break;
								end
							end

							if Model then
								Model:Destroy()
							end
						end)

						if Duration then
							service.TrackTask(`Thread: JailTimeLoop :: {ind}`, function()
								while true do
									if os.time() < jail.EndTime and Model.Parent == workspace and Variables.Jails[ind] == jail then
										task.wait(1)
									else
										Commands.UnJail.Function(plr,{v.Name})
										break
									end
								end
							end)
						end
					end
				end
			end
		};

		JoinLogs = {
			Prefix = Settings.Prefix;
			Commands = {"joinlogs", "joins", "joinhistory"};
			Args = {"autoupdate? (default: true)"};
			Description = "Displays the current join logs for the server";
			AdminLevel = 100;
			ListUpdater = "Joins";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Join Logs";
					Tab = Logs.ListUpdaters.JoinLogs(plr);
					Dots = true;
					Update = "JoinLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
				})
			end
		};

		JoinServer = {
			Prefix = Settings.Prefix;
			Commands = {"toserver", "joinserver", "jserver", "jplace"};
			Args = {"player", "JobId"};
			Description = "Send player(s) to a specific server using the server's JobId";
			NoStudio = true;
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local players = service.GetPlayers(plr, assert(args[1], "Missing argument #1 (players)"))
				local teleportOptions = service.New("TeleportOptions", {
					ServerInstanceId = assert(args[2], "Missing argument #2 (server JobId)")
				})

				service.TeleportService:TeleportAsync(game.PlaceId, players, teleportOptions)
				Functions.Message("Adonis", `Teleporting to server "{args[2]}"\nPlease wait...`, players, false, 10)
			end
		};

		Jump = {
			Prefix = Settings.Prefix;
			Commands = {"jump"};
			Args = {"player"};
			Description = "Forces the target player(s) to jump";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local Humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if Humanoid then
						Humanoid.Jump = true
					end
				end
			end
		};

		JumpHeight = {
			Prefix = Settings.Prefix;
			Commands = {"jheight", "jumpheight"};
			Args = {"player", "number"};
			Description = "Set the target player(s)'s jump height to <number>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.JumpHeight = args[2] or 7.2
						hum.JumpPower = (args[2] or 7.2) * (50/7.2)
					end
				end
			end
		};

		JumpPower = {
			Prefix = Settings.Prefix;
			Commands = {"jpower", "jpow", "jumppower"};
			Args = {"player", "number"};
			Description = "Set the target player(s)'s jump power to <number>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.JumpPower = args[2] or 50
						hum.JumpHeight = (args[2] or 50) / (50/7.2)
					end
				end
			end
		};

		Kick = {
			Prefix = Settings.Prefix;
			Commands = {"kick"};
			Args = {"player", "optional reason"};
			Filter = true;
			Description = "Disconnects the target player from the server";
			AdminLevel = 100;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {})
				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target player (argument #1)"), {IsKicking = true}) do
					if Admin.CheckAuthority(plr, v, "kick") then
						local playerName = service.FormatPlayer(v)
						if not service.Players:FindFirstChild(v.Name) then
							Remote.Send(v, "Function", "Kill")
						else
							v:Kick(args[2])
						end
						Functions.LogAdminAction(plr, "Kick", v.Name, args[2] or "No reason provided")
						Functions.Hint(`Kicked {playerName}`, {plr})
					end
				end
			end
		};

		Kill = {
			Prefix = Settings.Prefix;
			Commands = {"kill"};
			Args = {"player"};
			Description = "Kills the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local hum = v.Character:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.Health = 0
						end
						v.Character:BreakJoints()
					end
				end
			end
		};

		KillLogs = {
			Prefix = Settings.Prefix;
			Commands = {"killlogs", "kills", "killhistory", "klogs", "klog"};
			Args = {"autoupdate? (default: true)"};
			Description = "Displays the current kill logs for the server";
			AdminLevel = 100;
			ListUpdater = "Kills";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Kill Logs";
					Tab = Logs.ListUpdaters.KillLogs(plr);
					Dots = true;
					Update = "KillLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
				})
			end
		};

		LeaveLogs = {
			Prefix = Settings.Prefix;
			Commands = {"leavelogs", "leaves", "leavehistory"};
			Args = {"autoupdate? (default: true)"};
			Description = "Displays the current leave logs for the server";
			AdminLevel = 100;
			ListUpdater = "Leaves";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Leave Logs";
					Tab = Logs.ListUpdaters.LeaveLogs(plr);
					Dots = true;
					Update = "LeaveLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
				})
			end
		};

		LoadAvatar = {
			Prefix = Settings.Prefix;
			Commands = {"loadavatar", "loadchar", "loadcharacter", "clone", "cloneplayer", "duplicate"};
			Args = {"player", "copies (max: 50 | default: 1)", "appearence (optional)", "avatar type(R6/R15) (optional)"};
			Description = "Copies the target character in front of you with the specified amount of copies.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local count = tonumber(args[2] or 1)
				assert(count <= 50, "Cannot make more than 50 clones")
				local isSelf = args[3] and string.lower(args[3]) == "me"
				local avatarType = args[4] and assert(Enum.HumanoidRigType[string.upper(args[4])], "Invalid avatar type given")
				local appearenceId = not isSelf and args[3] and (tonumber(string.match(args[3], "^userid%-(%d*)")) or assert(Functions.GetUserIdFromNameAsync(args[3]), "Unable to fetch user."))
				local description = appearenceId and assert(select(2, xpcall(service.Players.GetHumanoidDescriptionFromUserId, warn, service.Players, appearenceId)), "Unable to get avatar for target appearence.")

				for _, v in service.GetPlayers(plr, args[1]) do
					local character = v.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					local localDescription = humanoid and humanoid:GetAppliedDescription()
					if not humanoid then
						continue
					end

					local oldArchivable, charPivot = character.Archivable, character:GetPivot()
					character.Archivable = true

					for i = 1, count do
						task.spawn(function()
							local clone = avatarType and service.Players:CreateHumanoidModelFromDescription(description or localDescription, avatarType, Enum.AssetTypeVerification.Always) or character:Clone()
							table.insert(Variables.Objects, clone)

							local oldAnimate, animate = clone:FindFirstChild("Animate"), nil
							if oldAnimate and oldAnimate:IsA("LocalScript") then
								animate = humanoid.RigType == Enum.HumanoidRigType.R15 and Deps.Assets.R15Animate:Clone() or Deps.Assets.R6Animate:Clone()
								animate:ClearAllChildren()
								for _, v in oldAnimate:GetChildren() do
									v.Parent = animate
								end
								oldAnimate:Destroy()
								animate.Parent = clone
							end

							clone:PivotTo(charPivot * CFrame.Angles(0, math.rad((360/count)*i+90), 0) * CFrame.new((count*0.2)+5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))

							if animate then
								animate.Disabled = false
							end

							clone:FindFirstChildOfClass("Humanoid").Died:Once(function()
								service.Debris:AddItem(clone, service.Players.RespawnTime)
							end)

							clone.Archivable = false
							clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
							clone.Parent = workspace
							if appearenceId and not avatarType then
								clone.Name = Functions.GetNameFromUserIdAsync(appearenceId)
								clone:FindFirstChildOfClass("Humanoid"):ApplyDescription(description, Enum.AssetTypeVerification.Always)
							end
						end)
					end

					character.Archivable = oldArchivable
				end
			end
		};

		LocalLog = {
			Prefix = Settings.Prefix;
			Commands = {"locallog", "clientlog", "locallogs", "localoutput", "clientlogs"};
			Args = {"player", "autoupdate? (default: true)"};
			Description = "View local log";
			AdminLevel = 100;
			NoFilter = true;
			ListUpdater = function(plr: Player, target: Player)
				return if target and target.Parent then Remote.Get(target, "ClientLog") else {"Player is currently unreachable"}
			end;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.MakeGui(plr, "List", {
						Title = `{service.FormatPlayer(v)}'s Local Log`;
						Table = Logs.ListUpdaters.LocalLog(plr, v);
						Update = "LocalLog";
						UpdateArg = v;
						AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
						Stacking = true;
						Sanitize = true;
						TextSelectable = true;
					})
				end
			end
		};

		Lock = {
			Prefix = Settings.Prefix;
			Commands = {"lock", "lockplr", "lockplayer"};
			Args = {"player"};
			Description = "Locks the target player(s), preventing the use of btools on the character";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						for a, obj in v.Character:GetChildren() do
							if obj:IsA("BasePart") then
								obj.Locked = true
							elseif obj:IsA("Accoutrement") and obj:FindFirstChild("Handle") then
								obj.Handle.Locked = true
							end
						end
					end
				end
			end
		};

		Logs = {
			Prefix = Settings.Prefix;
			Commands = {"logs", "log", "commandlogs"};
			Args = {"autoupdate? (default: true)"};
			Description = "View the command logs for the server";
			AdminLevel = 100;
			ListUpdater = function(plr: Player)
				local Count = if Logs.Commands.__meta == "DLL" then Logs.Commands.count else #Logs.Commands
				local tab = table.create(Count)
				for i, v in
					if Logs.Commands.__meta == "DLL" then
						Logs.Commands:GetAsTable()
						else
						Logs.Commands
				do
					table.insert(tab, i, {
						Time = v.Time;
						Text = `{v.Text}: {v.Desc}`;
						Desc = v.Desc;
					})
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Command Logs";
					Table = Logs.ListUpdaters.Logs(plr);
					Dots = true;
					Update = "Logs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
				})
			end
		};


		MassBring = {
			Prefix = Settings.Prefix;
			Commands = {"massbring", "bringrows", "bringlines"};
			Args = {"player(s)", "lines (default: 3)"};
			Description = "Teleports the target player(s) to you; positioning them evenly in specified lines";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local plrRootPart = assert(
					assert(plr.Character,"Your character is missing"):FindFirstChild("HumanoidRootPart"),
					"Your HumanoidRootPart is missing"
				)
				local players = service.GetPlayers(plr, assert(args[1], "Missing target players (argument #1)"))
				local numPlayers = #players
				if numPlayers == 0 then return end

				local minLines = math.min(tonumber(args[2]) or 3, numPlayers)
				local lines = math.clamp(minLines, 1, numPlayers)

				for l = 1, lines do
					local offsetX = if l == 1 then 0
						elseif l % 2 == 1 then -(math.ceil((l - 2) / 2) * 4)
						else math.ceil(l / 2) * 4

					for i = (l-1) * math.floor(numPlayers/lines) + 1, l * math.floor(numPlayers/lines) do
						local char = players[i].Character
						if not char then continue end

						char:SetAttribute("ADONIS_isTeleporting", true)
						task.delay(0.5, function() if char then char:SetAttribute("ADONIS_isTeleporting", nil) end end)

						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							if hum.SeatPart then
								Functions.RemoveSeatWelds(hum.SeatPart)
							end
							if hum.Sit then
								hum.Sit = false
								hum.Jump = true
							end
						end

						task.wait()

						local rootPart = char:FindFirstChild("HumanoidRootPart")
						Variables.ReturnPoints[players[i]] = rootPart.CFrame

						if rootPart then
							rootPart.CFrame = (
								plrRootPart.CFrame
									* CFrame.Angles(0, math.rad(90), 0)
									* CFrame.new(5 + ((i-1) - (l-1) * math.floor(numPlayers/lines)) * 2, 0, offsetX)
							) * CFrame.Angles(0, math.rad(90), 0)
						end
					end
				end
				if numPlayers%lines ~= 0 then
					for i = lines*math.floor(numPlayers/lines)+1, lines*math.floor(numPlayers/lines) + numPlayers%lines do
						local char = players[i].Character
						if not char then continue end

						char:SetAttribute("ADONIS_isTeleporting", true)
						task.delay(0.5, function() if char then char:SetAttribute("ADONIS_isTeleporting", nil) end end)

						local r = i % (lines*math.floor(numPlayers/lines))
						local offsetX = if r == 1 then 0
							elseif r % 2 == 1 then -(math.ceil((r - 2) / 2) * 4)
							else math.ceil(r / 2) * 4

						--[[if n.Character.Humanoid.Sit then
							n.Character.Humanoid.Sit = false
							wait(0.5)
						end]]

						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.Jump = true
						end
						task.wait()

						local rootPart = char:FindFirstChild("HumanoidRootPart")
						Variables.ReturnPoints[players[i]] = rootPart.CFrame

						if rootPart then
							rootPart.CFrame = (
								plrRootPart.CFrame
									* CFrame.Angles(0, math.rad(90), 0)
									* CFrame.new(5 + (math.floor(numPlayers/lines)) * 2, 0, offsetX)
							) * CFrame.Angles(0, math.rad(90), 0)
						end
					end
				end
			end
		};

		Message = {
			Prefix = Settings.Prefix;
			Commands = {"m", "message"};
			Args = {"message"};
			Filter = true;
			Description = "Makes a message";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Functions.Message(plr, `Message from {service.FormatPlayer(plr)}`, service.BroadcastFilter(assert(args[1], "Missing message"), plr), nil, service.GetPlayers(), true)
			end
		};

		MessagePM = {
			Prefix = Settings.Prefix;
			Commands = {"mpm", "messagepm"};
			Args = {"player", "message"};
			Filter = true;
			Description = "Makes a message on the target player(s) screen.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				assert(args[2], "Missing message")

				local Sender = string.format("Message from %s", service.FormatPlayer(plr))
				for _, v in service.GetPlayers(plr, args[1]) do
					Functions.Message(Sender, service.Filter(args[2], plr, v), {v}, true)
				end
			end
		};

		ModerationDuty = {
			Prefix = Settings.Prefix;
			Commands = {"moderationduty", "md", "shift"};
			Args = {};
			Description = "Toggles your Moderation Duty";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local user = plr
				local OnShift = server.Variables.shiftPlayers[user.UserId]
				if OnShift then
					Functions.Notify("Notification", `You are no longer on shift.`, {plr}, 10)
					local elapsed = os.time() - server.Variables.shiftPlayers[user.UserId].StartTime

					local function formatTime(seconds)
					    if seconds < 60 then
					        return string.format("%d seconds", seconds)
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
					local formattedTime = formatTime(elapsed)
					Functions.LogShiftAction(plr, "Shift has been ended.", "\n\nTotal Shift Time: " .. formattedTime, 15548997)

					-- Save shift data to datastore
					if server.ShiftData then
						server.ShiftData.SavePlayerData(user.UserId, elapsed, "Moderation")
					end

					server.Variables.shiftPlayers[user.UserId] = nil
				else
					server.Variables.shiftPlayers[user.UserId] = {
						StartTime = os.time()
					}
					Functions.Notify("Notification", "You are now on shift. Your activities are now being logged.", {plr}, 10)
					Functions.LogShiftAction(plr, "Shift has been started.", "\n\nShift Start Time: " .. os.date("%Y-%m-%d %H:%M:%S", server.Variables.shiftPlayers[user.UserId].StartTime), 5763719)
				end
			end
		};

		ShiftStats = {
			Prefix = Settings.Prefix;
			Commands = {"shiftstats", "viewshiftstats"};
			Args = {"player/userid"};
			Description = "View shift statistics for any player (online or offline)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				if not server.ShiftData then
					return Functions.Hint("ShiftData module not available", {plr})
				end

				local target = args[1]
				if not target then
					return Functions.Hint("Usage: ;shiftstats <player/userid>", {plr})
				end

				local userId = tonumber(target)
				local playerName = target

				if not userId then
					-- Try to get player from name
					local players = service.GetPlayers(plr, target, {DontError = true, UseFakePlayer = true})
					if #players > 0 then
						userId = players[1].UserId
						playerName = players[1].Name
					else
						-- Try to get userId from username
						userId = Functions.GetUserIdFromNameAsync(target)
						if userId then
							playerName = target
						else
							return Functions.Hint(`Player '{target}' not found`, {plr})
						end
					end
				else
					-- Get name from userId
					local success, name = pcall(service.Players.GetNameFromUserIdAsync, service.Players, userId)
					if success then
						playerName = name
					end
				end

				local stats = server.ShiftData.GetFormattedStats(userId, playerName)
				Remote.MakeGui(plr, "Output", {
					Title = "Shift Statistics";
					Message = stats;
					RichText = true;
				})
			end
		};

		Mute = {
			Prefix = Settings.Prefix;
			Commands = {"mute", "silence"};
			Args = {"player", "duration (optional)"};
			Description = "Makes it so the target player(s) can't talk";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string}, data: {})
				local Duration, Valid
				if args[2] then
					if args[2]:lower() ~= table.find({"inf", "infinite", "infinity", "unlimited"}, string.lower(args[2])) then
						Duration, Valid = args[2]:gsub("^(%d+)([smhd])$", function(val, unit)
							return if unit == "s" then val
								elseif unit == "m" then val * 60
								elseif unit == "h" then val * 60 * 60
								else val * 60 * 60 * 24
						end)
						assert(Valid > 0, "Invalid duration value (argument #2)")
					else
						Duration = math.huge
					end
				end

				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					if Admin.CheckAuthority(plr, v, "mute", false) then
						--Remote.LoadCode(v,[[service.StarterGui:SetCoreGuiEnabled("Chat", false) client.Variables.ChatEnabled = false client.Variables.Muted = true]])
						local check = true
						for _, m in Settings.Muted do
							if Admin.DoCheck(v, m) then
								check = false
							end
						end

						if check then
							table.insert(Settings.Muted, `{v.Name}:{v.UserId}`)
							service.Events.PlayerMuted:Fire({
								Target = v.UserId;
								Moderator = plr.UserId;
							})

							Functions.Hint(`Muted {service.FormatPlayer(v)}`, {plr})

							Functions.Notification("Notification", `You have been muted!`, {v}, 10, "MatIcon://Warning")
						end

						if Duration then
							local endTime = os.time()+Duration

							service.TrackTask(`Thread: MuteDuration :: {tostring(v.UserId)}`, function()
								while true do
									if os.time() < endTime then
										task.wait(1)
									else
										Commands.UnMute.Function(plr, {v.Name})
										break;
									end
								end
							end)
						end
					end
				end
			end
		};

		MuteList = {
			Prefix = Settings.Prefix;
			Commands = {"mutelist", "mutes", "muted"};
			Args = {};
			Description = "Shows a list of currently muted players";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local list = table.clone(Settings.Muted)
				for _, v in HTTP.Trello.Mutes do
					table.insert(list, `[Trello] {v}`)
				end

				Remote.MakeGui(plr, "List", {Title = "Mute List", Table = list, TextSelectable = true})
			end
		};


		NoClip = {
			Prefix = Settings.Prefix;
			Commands = {"noclip"};
			Args = {"player"};
			Description = "NoClips the target player(s); allowing them to walk through walls";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local clipper = Deps.Assets.Clipper:Clone()
				clipper.Name = "ADONIS_NoClip"

				for i, p in service.GetPlayers(plr, args[1]) do
					Admin.RunCommand(`{Settings.Prefix}clip`, p.Name)
					local new = clipper:Clone()
					new.Parent = p.Character.Humanoid
					new.Clip.Value = true
					new.Disabled = false
					if Settings.CommandFeedback then
						Functions.Notification("Noclip", "Character noclip has been enabled. You will now be able to walk through walls.", {p}, 15, "Info") -- Functions.Notification(title,message,player,time,icon)
					end
				end
			end
		};

		Notification = {
			Prefix = Settings.Prefix;
			Commands = {"notify", "notification", "notice"};
			Args = {"player", "message"};
			Description = "Sends the player a notification";
			Filter = true;
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[2], "Missing message")

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing player name")) do
					Functions.Notification("Notification", service.Filter(args[2], plr, v), {v})
				end
			end
		};

		Notify = {
			Prefix = Settings.Prefix;
			Commands = {"n", "smallmessage", "nmessage", "nmsg", "smsg", "smessage"};
			Args = {"message"};
			Filter = true;
			Description = "Makes a small message";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Functions.Notify(`Message from @{plr.Name}`, service.BroadcastFilter(assert(args[1], "Missing message"), plr), service.GetPlayers(), nil, plr)
			end
		};

		NotifyPM = {
			Prefix = Settings.Prefix;
			Commands = {"npm", "smallmessagepm", "nmessagepm", "nmsgpm", "npmmsg", "smsgpm", "spmmsg", "smessagepm"};
			Args = {"player", "message"};
			Filter = true;
			Description = "Makes a small message on the target player(s) screen.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				assert(args[2], "Missing message")
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.RemoveGui(v, "Notify")
					Functions.Notify(`Message from {service.FormatPlayer(plr)}`, service.Filter(args[2], plr, v), {v})
				end
			end
		};

		OldLogs = {
			Prefix = Settings.Prefix;
			Commands = {"oldlogs", "oldserverlogs", "oldcommandlogs"};
			Args = {"autoupdate? (default: true)"};
			Description = "View the command logs for previous servers ordered by time";
			AdminLevel = 100;
			ListUpdater = function(plr: Player)
				if Core.DataStore then
					local tab = table.create(Logs.OldCommandLogsLimit)
					local data = Core.GetData("OldCommandLogs")
					if data then
						for i, v in Logs.DeserializeOldlogs(data) do
							tab[i] = {
								Time = v.Time,
								Text = `{v.Text}: {v.Desc}`,
								Desc = v.Desc
							}
						end
					end
					return tab
				end
				return {"DataStore is not available in game"}
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Old Server Logs";
					Table = Logs.ListUpdaters.OldLogs(plr);
					Dots = true;
					Update = "OldLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
					TimeOptions = {
						WithDate = true;
					};
				})
			end
		};

		OrderedVote = {
			Prefix = Settings.Prefix;
			Commands = {"orderedvote","ovote"};
			Args = {"player", "answer1,answer2,etc (NO SPACES)", "question"};
			Filter = true;
			Description = `Same as {Settings.Prefix}vote, but with more options, such as randomizing the order of the choices.`;
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local question = args[3]
				if not question then error("You forgot to supply a question!") end
				local answers = args[2]
				local anstab = {}
				local responses = {}
				local voteKey = `ADONISVOTE{service.GenerateGUID(false)}`;
				local players = service.GetPlayers(plr, args[1])
				local startTime = os.clock();

				local function voteUpdate()
					local total = #responses
					local results = table.create(total)

					local tab = {
						`Question: {question}`;
						`Total Responses: {total}`;
						`Didn't Vote: {#players-total}`;
						`Time Left: {math.ceil(math.max(0, 120 - (os.clock()-startTime)))}`;
					}

					for _, v in responses do
						if not results[v] then results[v] = 0 end
						results[v] += 1
					end

					for _, v in anstab do
						local ans = v
						local num = results[v]
						local percent
						if not num then
							num = 0
							percent = 0
						else
							percent = math.floor((num/total)*100)
						end

						table.insert(tab, {
							Text=`{ans} | {percent}% - {num}/{total}`,
							Desc=`Number: {num}/{total} | Percent: {percent}`
						})
					end

					return tab;
				end

				Logs.TempUpdaters[voteKey] = voteUpdate;

				if not answers then
					anstab = {"Yes", "No"}
				else
					for ans in string.gmatch(answers, "([^,]+)") do
						table.insert(anstab, ans)
					end
				end

				for i, v in players do
					Routine(function()
						local response = Remote.GetGui(v, "Vote", {
							Question = question;
							Answers = anstab;
							IsRandomOrder = false;
						})
						if response then
							table.insert(responses, response)
						end
					end)
				end

				Remote.MakeGui(plr, "List", {
					Title = "Results";
					Tab = voteUpdate();
					Update = "TempUpdate";
					UpdateArgs = {{UpdateKey = voteKey}};
					AutoUpdate = 1;
				})

				delay(120, function() Logs.TempUpdaters[voteKey] = nil end)
			end
		};


		PeaceTimer = {
			Prefix = Settings.Prefix;
			Commands = {"pt", "peacetime"};
			Args = {"time"};
			Description = "Enable, disable, or adjust Peacetime. Use 'off' to disable. Max time is 15 minutes (900 seconds). Formats: 5m, 1h, 100.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local input = args[1]
				if not input then return end
			
				local function parseTime(str)
					str = string.lower(str)
					if str == "off" or str == "false" or str == "0" then
						return "off"
					elseif str:match("^%d+h$") then
						local h = tonumber(str:match("(%d+)"))
						return h and h * 3600 or nil
					elseif str:match("^%d+m$") then
						local m = tonumber(str:match("(%d+)"))
						return m and m * 60 or nil
					elseif str:match("^%d+$") then
						return tonumber(str)
					end
					return nil
				end
			
				local parsed = parseTime(input)
			
				if parsed == "off" then
					if activePT then
						activePT = false
						if pt then task.cancel(pt) end
						Functions.Notify("Notification", "Peacetime has been disabled.", service.GetPlayers(), 10)
					end
					return
				end
			
				if not parsed then
					Functions.Notify("Error", "Invalid time format. Use formats like 5m, 100, or 1h.", {plr}, 10)
					return
				end
			
				if parsed > 900 then
					Functions.Notify("Error", "Peacetime cannot exceed 15 minutes (900 seconds).", {plr}, 10)
					return
				end
			
				if activePT then
					remainingTime = parsed
					Functions.Notify("Notification", `Peacetime time updated. Remaining time: {remainingTime} seconds.`, service.GetPlayers(), 10)
				else
					activePT = true
					remainingTime = parsed
					Functions.Notify("Notification", "Peacetime has been enabled. End all Priorities. Do not start any chase.", service.GetPlayers(), 10)
				
					pt = task.spawn(function()
						while task.wait(1) do
							if not activePT then break end
							remainingTime -= 1
							if remainingTime <= 0 then
								activePT = false
								Functions.Notify("Notification", "Peacetime has been disabled.", service.GetPlayers(), 10)
								break
							end
							local mins = math.floor(remainingTime / 60)
							local secs = remainingTime % 60
							local display = mins > 0 and `{mins}m {secs}s` or `{secs}s`
							Functions.Hint(`Peacetime ends in {display}`, service.GetPlayers(), 1)
						end
					end)
				end
			end
		};

		Piano = {
			Prefix = Settings.Prefix;
			Commands = {"piano"};
			Args = {"player"};
			Description = "Gives you a playable keyboard piano. Credit to NickPatella.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, v in service.GetPlayers(plr, args[1]) do
					local Dropper = v:FindFirstChildOfClass("PlayerGui") or v:FindFirstChildOfClass("Backpack")
					if Dropper then
						local piano = Deps.Assets.Piano:Clone()
						piano.Parent = Dropper
						piano.Disabled = false
					end
				end
			end
		};


		PlayerList = {
			Prefix = Settings.Prefix;
			Commands = {"players", "playerlist", "listplayers"};
			Args = {"autoupdate? (default: true)"};
			Description = "Shows you all players currently in-game, including nil ones";
			AdminLevel = 100;
			ListUpdater = function(plr: Player)
				local players = Functions.GrabNilPlayers("all")
				local tab = {
					`# Players: {#players}`,
					"―――――――――――――――――――――――",
				}
				for _, v in players do
					if type(v) == "string" and v == "NoPlayer" then
						table.insert(tab, {
							Text = "PLAYERLESS CLIENT";
							Desc = "PLAYERLESS SERVERREPLICATOR: COULD BE LOADING/LAG/EXPLOITER. CHECK AGAIN IN A MINUTE!";
						})
					else
						if v and service.Players:FindFirstChild(v.Name) then
							local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
							table.insert(tab, {
								Text = string.format("[%d ms] %s", v:GetNetworkPing() * 1000, service.FormatPlayer(v, true));
								Desc = string.format("Lower: %s | Health: %d | MaxHealth: %d | WalkSpeed: %d | JumpPower: %d | Humanoid Name: %s", v.Name:lower(), hum and hum.Health or 0, hum and hum.MaxHealth or 0, hum and hum.WalkSpeed or 0, hum and hum.JumpPower or 0, hum and hum.Name or "?");
							})
						else
							table.insert(tab, {
								Text = `[LOADING] {service.FormatPlayer(v, true)}`;
								Desc = `Lower: {string.lower(v.Name)} | Ping: {v:GetNetworkPing() * 1000}`;
							})
						end
					end
				end
				for i = 0.1, 5, 0.1 do
					if service.CountTable(tab) - 2 >= service.CountTable(players) then break end
					wait(0.1)
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Players",
					Icon = server.MatIcons.People;
					Tab = Logs.ListUpdaters.PlayerList(plr);
					Size = {300, 240};
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Update = "PlayerList";
					TextSelectable = true;
				})
			end
		};

		PrivateChat = {
			Prefix = Settings.Prefix;
			Commands = {"privatechat", "dm", "pchat"};
			Args = {"player", "message (optional)"};
			Filter = true;
			Description = "Send a private message to a player";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")

				local sessionName = service.HttpService:GenerateGUID(false) --// Used by the private chat windows
				local newSession = Remote.NewSession("PrivateChat")
				local history = {}

				newSession.Data.History = history

				local function getPeerList()
					local peers = {}
					for peer in newSession.Users do
						table.insert(peers, {
							Name = peer.Name;
							DisplayName = peer.DisplayName;
							UserId = peer.UserId;
							--Instance = service.UnWrap(peer);
						})
					end
					return peers
				end

				local function systemMessage(msg)
					local data = {
						Name = "* SYSTEM *";
						UserId = 0;
						Icon = 0;
					};
					table.insert(history, {
						Sender = data;
						Message = msg;
					});
					newSession:SendToUsers("PlayerSentMessage", data, msg)
				end;

				newSession:ConnectEvent(function(p, cmd, ...)
					local args = table.pack(...)

					if not p then -- System event(s)
						if cmd == "LastUserRemoved" then
							newSession:End()
						end
					else	-- Player event(s)
						if cmd == "SendMessage" then
							local message = string.sub(tostring(args[1]), 1, 140)
							local filtered = service.BroadcastFilter(message, p)

							if filtered ~= message then
								Remote.MakeGui(p, "Output", {
									Title = "Filter error",
									Message = "A message filtering error occurred; please try again."
								})
							else
								local gotIcon, status = service.Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48);
								local data, msg = {
									Name = p.Name;
									DisplayName = p.DisplayName;
									UserId = p.UserId;
									Icon = status and gotIcon or "rbxasset://textures/ui/GuiImagePlaceholder.png";
								}, filtered

								table.insert(history, {
									Sender = data;
									Message = msg;
								})

								if #history > 200 then
									table.remove(history, 1)
								end

								newSession:SendToUsers("PlayerSentMessage", data, msg)
							end
						elseif cmd == "LeaveSession" or cmd == "RemovedFromSession" then
							newSession:RemoveUser(p)
							systemMessage(string.format("<i>%s has left the session</i>", p.Name))
							newSession:SendToUsers("UpdatePeerList", getPeerList())

							if p == plr then
								systemMessage("<i>Session ended: Session owner left</i>")
								newSession:End()
							end
						elseif cmd == "EndSession" and p == plr then
							systemMessage("<i>Session ended</i>")
							newSession:End()
						elseif cmd == "AddPlayerToSession" and (p == plr or Admin.CheckAdmin(p)) then
							local player = args[1]

							if player then
								newSession:AddUser(player)
								newSession:SendToUser(player, "AddedToSession")
								systemMessage(string.format("<i>%s added %s to the session</i>", p.Name, player.Name))
								Remote.MakeGui(player, "PrivateChat", {
									Owner = plr;
									SessionKey = newSession.SessionKey;
									SessionName = sessionName;
									History = history;
									CanManageUsers = Admin.CheckAdmin(player);
								})
								newSession:SendToUsers("UpdatePeerList", getPeerList())
							end
						elseif cmd == "RemovePlayerFromSession" and (p == plr or Admin.CheckAdmin(p)) then
							local peer = args[1]

							if peer then
								for pr in newSession.Users do
									if peer.UserId and peer.UserId == pr.UserId then
										newSession:SendToUser(pr, "RemovedFromSession")
										newSession:RemoveUser(pr)
										systemMessage(string.format("<i>%s removed %s from the session</i>", p.Name, pr.Name))
									end
								end
							end

							newSession:SendToUsers("UpdatePeerList", getPeerList())
						elseif cmd == "GetPeerList" then
							newSession:SendToUser(p, "UpdatePeerList", getPeerList())
						end
					end
				end)

				systemMessage("<i>Chat session started</i>")

				if args[2] then
					local gotIcon, status = service.Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					local data = {
						Name = plr.Name;
						DisplayName = plr.DisplayName;
						UserId = plr.UserId;
						Icon = status and gotIcon or "rbxasset://textures/ui/GuiImagePlaceholder.png";
					}

					table.insert(history, {
						Sender = data;
						Message = args[2];
					})
				end

				newSession:AddUser(plr)
				Remote.MakeGui(plr, "PrivateChat", {
					Owner = plr;
					SessionKey = newSession.SessionKey;
					SessionName = sessionName;
					History = history;
					CanManageUsers = true;
				})

				for i, v in service.GetPlayers(plr, args[1]) do
					if v ~= plr then
						newSession:AddUser(v)
						Remote.MakeGui(v, "PrivateChat", {
							Owner = plr;
							SessionKey = newSession.SessionKey;
							SessionName = sessionName;
							History = history;
							CanManageUsers = Admin.CheckAdmin(v);
						})
					end
				end
			end
		};

		PrivateMessage = {
			Prefix = Settings.Prefix;
			Commands = {"pm", "privatemessage"};
			Args = {"player", "message"};
			Filter = true;
			Description = "Send a private message to a player";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				assert(args[2], "Missing message")
				for _, v in service.GetPlayers(plr, args[1]) do
					local replyTicket = service.HttpService:GenerateGUID(false)
					Variables.PMtickets[replyTicket] = plr

					Remote.MakeGui(v, "PrivateMessage", {
						Title = `Message from {service.FormatPlayer(plr)}`;
						Player = plr;
						Message = service.Filter(args[2], plr, v);
						replyTicket = replyTicket;
					})
				end
			end
		};


		Refresh = {
			Prefix = Settings.Prefix;
			Commands = {"refresh", "ref"};
			Args = {"player"};
			Description = "Refreshes the target player(s)'s character";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, p in service.GetPlayers(plr, args[1]) do
					task.defer(function()
						local oChar = p.Character;
						local oTools, pBackpack, oHumanoid, oPrimary, oPos;

						if oChar then
							oHumanoid = oChar:FindFirstChildOfClass("Humanoid");
							oPrimary = oChar.PrimaryPart or (oHumanoid and oHumanoid.RootPart) or oChar:FindFirstChild("HumanoidRootPart");

							if oPrimary then
								oPos = oPrimary.CFrame;
							end
						end

						--// Handle tool saving
						pBackpack = p:FindFirstChildOfClass("Backpack")

						local ev
						if pBackpack then
							oTools = {};
							ev = pBackpack.ChildAdded:Connect(function(c)
								table.insert(oTools, c)
								c.Parent = nil
							end)

							if oHumanoid then oHumanoid:UnequipTools() end
							for _, child in pBackpack:GetChildren() do
								table.insert(oTools, child)
								child.Parent = nil
							end
						end

						--// Handle respawn and repositioning
						local newChar, newHumanoid, newPrimary;
						task.delay(0.1, pcall, p.LoadCharacter, p)
						if ev then ev:Disconnect() end

						--// Reposition if possible
						if oPos then
							newChar = p.Character ~= oChar and p.Character or p.CharacterAdded:Wait()

							if newChar then
								wait(); -- Let it finish loading character contents

								newHumanoid = newChar:FindFirstChildOfClass("Humanoid");
								newPrimary = newChar.PrimaryPart or (newHumanoid and newHumanoid.RootPart) or oChar:FindFirstChild("HumanoidRootPart");

								local forcefield = newChar:FindFirstChildOfClass("ForceField")
								if forcefield then
									forcefield:Destroy()
								end

								if newPrimary then
									newPrimary.CFrame = oPos
								else
									newChar:MoveTo(oPos.Position)
								end
							end
						end

						--// Bring previous tools back
						local newBackpack = p:FindFirstChildOfClass("Backpack")
						if newBackpack and oTools then
							newBackpack:ClearAllChildren();
							for _, t in oTools do
								t.Parent = newBackpack
							end
						end
					end)
				end
			end
		};

		RemoteLogs = {
			Prefix = Settings.Prefix;
			Commands = {"remotelogs", "remotelog", "rlogs", "remotefires", "remoterequests"};
			Args = {"autoupdate? (default: true)"};
			Description = "View the remote logs for the server";
			AdminLevel = 100;
			ListUpdater = "RemoteFires";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Remote Logs";
					Table = Logs.ListUpdaters.RemoteLogs(plr);
					Dots = true;
					Update = "RemoteLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
				})
			end
		};

		ResetButtonEnabled = {
			Prefix = Settings.Prefix;
			Commands = {"resetbuttonenabled", "resetenabled", "canreset", "allowreset"};
			Args = {"player", "can reset? (true/false)"};
			Description = "Sets whether the target player(s) can reset their character";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player")
				args[2] = string.lower(assert(args[2], "Missing argument #2 (boolean expected)"))
				assert(args[2] == "true" or args[2] == "false", "Invalid argument #2 (boolean expected)")
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.Send(v, "Function", "SetCore", "ResetButtonCallback", if args[2] == "true" then true else false)
				end
			end
		};

		ResetLighting = {
			Prefix = Settings.Prefix;
			Commands = {"resetlighting", "undisco", "unflash", "fixlighting", "resetatmosphere", "fixatmosphere"};
			Args = {};
			Description = "Reset lighting back to the setting it had on server start";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				service.StopLoop("LightingTask")
				for i, v in Variables.OriginalLightingSettings do
					if i ~= "Sky" and service.Lighting[i] ~= nil then
						Functions.SetLighting(i, v)
					end
				end
				for i, v in service.Lighting:GetChildren() do
					if v.ClassName == "Sky" then
						service.Delete(v)
					end
				end
				if Variables.OriginalLightingSettings.Sky then
					Variables.OriginalLightingSettings.Sky:Clone().Parent = service.Lighting
				end

				-- Atmosphere
				local atmosphere = service.Lighting:FindFirstChildWhichIsA("Atmosphere")
				if atmosphere then
					if Variables.OriginalAtmosphereSettings.Name then
						atmosphere.Name = Variables.OriginalAtmosphereSettings.Name
						atmosphere.Density = Variables.OriginalAtmosphereSettings.Density
						atmosphere.Offset = Variables.OriginalAtmosphereSettings.Offset
						atmosphere.Color = Variables.OriginalAtmosphereSettings.Color
						atmosphere.Decay = Variables.OriginalAtmosphereSettings.Decay
						atmosphere.Glare = Variables.OriginalAtmosphereSettings.Glare
						atmosphere.Haze = Variables.OriginalAtmosphereSettings.Haze
					else
						atmosphere:Destroy()
					end
				end
			end
		};

		ResetView = {
			Prefix = Settings.Prefix;
			Commands = {"resetview", "rv", "fixview", "fixcam", "unwatch", "unview"};
			Args = {"optional player"};
			Description = "Resets your view";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character and v.Character.PrimaryPart then
						Functions.ResetReplicationFocus(v)
					else
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a character and/or HumanoidRootPart`, {plr})
					end

					Remote.Send(v, "Function", "SetView", "reset")

					if Variables.PersistView[v.UserId] then
						Variables.PersistView[v.UserId] = nil
					end
				end
			end
		};

		Respawn = {
			Prefix = Settings.Prefix;
			Commands = {"respawn", "re", "reset", "res"};
			Args = {"player"};
			Description = "Respawns the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					task.defer(function()
						pcall(v.LoadCharacter, v)
						Remote.Send(v, "Function", "SetView", "reset")
					end)
				end
			end
		};

		Return = {
			Prefix = Settings.Prefix;
			Commands = {"back", "return"};
			Args = {"player"};
			Description = "Returns the player to their original position";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, player in service.GetPlayers(plr, args[1]) do
					if Variables.ReturnPoints[player] then
						player.Character.HumanoidRootPart.CFrame = Variables.ReturnPoints[player]
						Variables.ReturnPoints[player] = nil;
					end
				end
			end
		};

		Reverb = {
			Prefix = Settings.Prefix;
			Commands = {"reverb", "ambientreverb"};
			Args = {"reverbType", "optional player"};
			Description = "Lets you change the reverb type with an optional player argument (CASE SENSITTIVE)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string}, data: {})
				local rev = args[1]

				local ReverbType = Enum.ReverbType
				local reverbs = ReverbType:GetEnumItems()
				if not rev or not ReverbType[rev] then

					Functions.Hint("Reverb type was not specified or is invalid. Opening list of valid reverb types", {plr})

					local tab = table.create(#reverbs)
					table.insert(tab, {Text = "Note: Argument is CASE SENSITIVE"})
					for _, v in reverbs do
						table.insert(tab, {Text = v.Name})
					end
					Remote.MakeGui(plr, "List", {Title = "Reverbs"; Table = tab;})

					return
				end

				if args[2] then
					for _, v in service.GetPlayers(plr, args[2]) do
						Remote.LoadCode(v, `game:GetService(\"SoundService\").AmbientReverb = Enum.ReverbType[{rev}]`)
					end

					Functions.Hint("Changed Ambient Reverb of specified player(s)", {plr})
				else
					service.SoundService.AmbientReverb = ReverbType[rev]
					Functions.Hint(`Successfully changed the Ambient Reverb to {rev}`, {plr})
				end
			end
		};

		ScriptLogs = {
			Prefix = Settings.Prefix;
			Commands = {"scriptlogs", "scriptlog", "adminlogs", "adminlog", "scriptlogs"};
			Args = {"autoupdate? (default: true)"};
			Description = "View the admin logs for the server";
			AdminLevel = 100;
			ListUpdater = "Script";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Script Logs";
					Table = Logs.ListUpdaters.ScriptLogs(plr);
					Dots = true;
					Update = "ScriptLogs";
					TextSelectable = true;
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
				})
			end
		};

		SelectPlayers = {
			Prefix = Settings.Prefix;
			Commands = {"select", "selectplayers", "count",  "countplayers", "getplayers"};
			Args = {"player(s)", "autoupdate? (default: false)"};
			Description = `Shows you a list and count of players selected in the supplied argument, ex: '{Settings.Prefix}select %raiders true' to monitor people in the 'raiders' team`;
			AdminLevel = 100;
			ListUpdater = function(plr: Player, selection: string?)
				local players = service.GetPlayers(plr, selection, {DontError = true})
				local tab = {
					{
						Text = `Specified: "{selection or `{Settings.SpecialPrefix}me`}"`;
					},
					{
						Text = `# Players: {#players}`;
					},
					{
						Text = `―――――――――――――――――――――――`;
					}
				}

				for _, v: Player in players do
					table.insert(tab, {
						Text = `[{v.UserId}] {service.FormatPlayer(v)}`;
					})
				end
				return tab
			end;
			Function = function(plr: Player, args: {[number]:string})
				Remote.MakeGui(plr, "List", {
					Title = "Selected Players";
					Icon = server.MatIcons.People;
					Tab = Logs.ListUpdaters.SelectPlayers(plr, args[1]);
					TextSelectable = true;
					Update = "SelectPlayers";
					UpdateArg = args[1];
					AutoUpdate = if args[2] and (args[2]:lower() == "true" or args[2]:lower() == "yes") then 1 else nil;
				})
			end
		};

		ServerBan = {
			Prefix = Settings.Prefix;
			Commands = {"serverban", "ban"};
			Args = {"player/user", "reason"};
			Description = "Bans the target player(s) from the server";
			AdminLevel = 100;
			Filter = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local reason = args[2] or "No reason provided"
				for _, v in service.GetPlayers(plr, args[1], {
					IsKicking = true;
					UseFakePlayer = true;
					})
				do
					if Admin.CheckAuthority(plr, v, "server-ban", false) then
						Admin.AddBan(v, reason, false, plr, "Server")
						Functions.LogAdminAction(plr, "Server Ban", v.Name, `Reason: {reason}`)
						Functions.Hint(`Server-banned {service.FormatPlayer(v, true)}`, {plr})
					end
				end
			end
		};

		TimeBan = {
			Prefix = Settings.Prefix;
			Commands = {"timeban", "timedban", "tempban", "tban", "temporaryban"};
			Args = {"username(s)", "number<s/m/h/d>", "reason"};
			Description = `Bans the target user(s) from the game for the supplied amount of time; data-persistent; undo using {Settings.Prefix}unban`;
			Filter = true;
			AdminLevel = 100;
			Function = function(plr: Player, args: {string}, data: {})
				assert(args[1], "Missing target user (argument #1)")

				local duration, valid = assert(args[2], "Missing duration (argument #2)"):gsub("^(%d+)([smhd])$", function(val, unit)
					return if unit == "s" then val
						elseif unit == "m" then val * 60
						elseif unit == "h" then val * 60 * 60
						else val * 60 * 60 * 24
				end)
				assert(valid > 0, "Invalid duration value (argument #2)")

				local reason = args[3] or "No reason provided"

				for i in string.gmatch(args[1], "[^,]+") do
					local UserId = Functions.GetUserIdFromNameAsync(i)
					if UserId then
						if UserId == plr.UserId then
							Functions.Hint("You cannot ban yourself", {plr})
							continue
						end

						local getNameSuccess, actualName = pcall(service.Players.GetNameFromUserIdAsync, service.Players, UserId)

						Admin.AddTimeBan({UserId = UserId, Name = if getNameSuccess then actualName else i}, duration, reason, plr)
						Functions.LogAdminAction(plr, "Time Ban", actualName or i, `Duration: {args[2]}, Reason: {reason}`)
						Functions.Hint(
							`Time-banned {if getNameSuccess then `@{actualName}` else `'{i}'`} for {args[2]}`,
							{plr}
						)
					else
						Functions.Hint(`No user named '{i}' exists (Please try again if you think this is an internal error)`, {plr})
					end
				end
			end
		};

		PermBan = {
			Prefix = Settings.Prefix;
			Commands = {"permban", "permanentban", "pban", "gameban", "gban"};
			Args = {"username(s)", "reason"};
			Description = "Permanently bans the specified user(s) from the game; saves";
			AdminLevel = 100;
			Filter = true;
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

						Functions.Hint(`Permanently banned {if getNameSuccess then `@{username}` else `'{username}'`} from the game`, {plr})
						Functions.LogAdminAction(plr, "Permanent Ban", username, `Reason: {reason}`)
					else
						Functions.Hint(`No user named '{i}' exists! (Please try again if you think this is an internal error)`, {plr})
					end
				end
			end
		};

		Warning = {
			Prefix = Settings.Prefix;
			Commands = {"warning", "warn"};
			Args = {"player", "reason"};
			Description = "Sends a warning to the target player(s) and saves it";
			AdminLevel = 100;
			Filter = true;
			Function = function(plr: Player, args: {string}, data: {any})
				local reason = args[2] or "No reason provided"
				for _, v in service.GetPlayers(plr, args[1]) do
					if Admin.CheckAuthority(plr, v, "warn", false) then
						-- Add warning to storage
						Admin.AddWarning(v, reason, plr)

						-- Show warning notification to the player
						Remote.MakeGui(v, "Output", {
							Title = "Warning";
							Message = `You have been warned by {plr.Name}\nReason: {reason}`;
							Color = Color3.fromRGB(255, 170, 0);
							Time = 15;
						})

						Functions.LogAdminAction(plr, "Warning", v.Name, `Reason: {reason}`)
						Functions.Hint(`Warned {service.FormatPlayer(v, true)}`, {plr})
					end
				end
			end
		};

		WarningList = {
			Prefix = Settings.Prefix;
			Commands = {"warninglist", "warnings", "warns"};
			Args = {};
			Description = "Shows you the warning list";
			AdminLevel = 100;
			ListUpdater = function(plr: Player)
				local tab = table.create(#Core.Variables.Warnings + 2)
				local count = 0
				for _, v in Core.Variables.Warnings do
					count += 1
					local entry = ""
					local reason = "No reason provided"
					local moderator = "%UNKNOWN%"
					local timestamp = ""

					if type(v) == "table" then
						if v.Name and v.UserId then
							entry = `{v.Name}:{v.UserId}`
						elseif v.UserId then
							entry = `ID: {v.UserId}`
						elseif v.Name then
							entry = v.Name
						end
						if v.Reason then
							reason = v.Reason
						end
						if v.Moderator then
							moderator = v.Moderator
						end
						if v.Timestamp then
							timestamp = ` | {os.date("%Y-%m-%d %H:%M:%S", v.Timestamp)}`
						end
					else
						entry = tostring(v)
					end
					table.insert(tab, {
						Text = tostring(entry),
						Desc = string.format("Issued by: %s | Reason: %s%s", moderator, reason, timestamp)
					})
				end
				table.insert(tab, 1, `# Warnings: {count}`)
				table.insert(tab, 2, "―――――――――――――――――――――――")
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Warning List";
					Icon = server.MatIcons.Warning;
					Tab = Logs.ListUpdaters.WarningList(plr);
					Update = "WarningList";
					TextSelectable = true;
				})
			end;
		};

		BanMenu = {
			Prefix = Settings.Prefix;
			Commands = {"banmenu", "bm"};
			Args = {};
			Description = "Opens the ban menu GUI";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local adminLevel = Admin.GetLevel(plr)
				Remote.MakeGui(plr, "BanMenu", {
					AdminLevel = adminLevel;
					CanBan = Admin.CheckAdmin(plr, false);
					CanTimeBan = Admin.CheckAdmin(plr, false);
					CanPermBan = Admin.CheckAdmin(plr, false);
				})
			end
		};

		ServerLog = {
			Prefix = Settings.Prefix;
			Commands = {"serverlog", "serverlogs", "serveroutput"};
			Args = {"autoupdate? (default: true)"};
			Description = "View server log";
			AdminLevel = 100;
			NoFilter = true;
			ListUpdater = function(plr: Player)
				local MESSAGE_TYPE_COLORS = {
					[Enum.MessageType.MessageWarning] = Color3.fromRGB(221, 187, 13),
					[Enum.MessageType.MessageError] = Color3.fromRGB(255, 50, 14),
					[Enum.MessageType.MessageInfo] = Color3.fromRGB(14, 78, 255)
				}
				local logHistory: {{message: string, messageType: Enum.MessageType, timestamp: number}} = service.LogService:GetLogHistory()
				local tab = table.create(#logHistory)
				for i = #logHistory, 1, -1 do
					local log = logHistory[i]
					for i, v in service.ExtractLines(log.message) do
						table.insert(tab, {
							Text = v;
							Time = if i == 1 then log.timestamp else nil;
							Desc = log.messageType.Name:match("^Message(.+)$");
							Color = MESSAGE_TYPE_COLORS[log.messageType];
						})
					end
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Server Log";
					Table = Logs.ListUpdaters.ServerLog(plr);
					Update = "ServerLog";
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Stacking = true;
					Sanitize = true;
					TextSelectable = true;
				})
			end
		};

		SetHealth = {
			Prefix = Settings.Prefix;
			Commands = {"health", "sethealth"};
			Args = {"player", "number"};
			Description = "Set the target player(s)'s health and max health to <number>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.MaxHealth = args[2]
						hum.Health = hum.MaxHealth
					end
				end
			end
		};

		SetTeam = {
			Prefix = Settings.Prefix;
			Commands = {"team", "setteam", "changeteam"};
			Args = {"player", "team"};
			Description = "Set the target player(s)'s team to <team>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				assert(args[2], "Missing team name")
				for _, v in service.GetPlayers(plr, args[1]) do
					for a, tm in service.Teams:GetChildren() do
						if string.sub(string.lower(tm.Name), 1, #args[2]) == string.lower(args[2]) then
							v.Team = tm
							if Settings.CommandFeedback then
								Functions.Notification("Team", `You are now on the '{tm.Name}' team.`, {v}, 15, "Info") -- Functions.Notification(title,message,player,time,icon)
							end
						end
					end
				end
			end
		};

		Shadows = {
			Prefix = Settings.Prefix;
			Commands = {"shadows"};
			Args = {"on/off", "optional player"};
			Description = "Determines if shadows are on or off";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				if string.lower(args[1])=="on" or string.lower(args[1])=="true" then
					if args[2] then
						for _, v in service.GetPlayers(plr, args[2]) do
							Remote.SetLighting(v, "GlobalShadows", true)
						end
					else
						Functions.SetLighting("GlobalShadows", true)
					end
				elseif string.lower(args[1])=="off" or string.lower(args[1])=="false" then
					if args[2] then
						for _, v in service.GetPlayers(plr, args[2]) do
							Remote.SetLighting(v, "GlobalShadows", false)
						end
					else
						Functions.SetLighting("GlobalShadows", false)
					end
				end
			end
		};

		ShowBackpack = {
			Prefix = Settings.Prefix;
			Commands = {"showtools", "viewtools", "seebackpack", "viewbackpack", "showbackpack", "displaybackpack", "displaytools", "listtools"};
			Args = {"player",  "autoupdate? (default: false)"};
			Description = "Shows you a list of items currently in the target player(s) backpack";
			AdminLevel = 100;
			ListUpdater = function(plr: Player, target: Player)
				local tab = {}
				local equippedTool = target.Character and target.Character:FindFirstChildWhichIsA("BackpackItem")
				if equippedTool then
					table.insert(tab, {
						Text = `[EQUIPPED] {equippedTool.Name}`;
						Desc = string.format("Class: %s | %s", equippedTool.ClassName, if equippedTool:IsA("Tool") then `ToolTip: {equippedTool.ToolTip}` else `BinType: {equippedTool.BinType}`);
					})
				end
				local backpack = target:FindFirstChildOfClass("Backpack")
				if backpack then
					for _, t in backpack:GetChildren() do
						table.insert(tab, {
							Text = t.Name;
							Desc = if t:IsA("BackpackItem") then
								string.format("Class: %s | %s", t.ClassName, if t:IsA("Tool") then `ToolTip: {t.ToolTip}` else `BinType: {t.BinType}`)
								else `Class: {t.ClassName}`;
						})
					end
				else
					table.insert(tab, "This player has no backpack present.")
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						Remote.MakeGui(plr, "List", {
							Title = `{service.FormatPlayer(v)}'s tools`;
							Icon = server.MatIcons["Inventory 2"];
							Table = Logs.ListUpdaters.ShowBackpack(plr, v);
							AutoUpdate = if args[2] and (args[2]:lower() == "true" or args[2]:lower() == "yes") then 1 else nil;
							Update = "ShowBackpack";
							UpdateArg = v;
							Size = {280, 225};
							TitleButtons = {
								{
									Text = "";
									OnClick = Core.Bytecode(`client.Remote.Send('ProcessCommand','{Functions.GetMainPrefix()}tools')`);
									Children = {
										{
											Class = "ImageLabel";
											Size = UDim2.new(0, 18, 0, 18);
											Position = UDim2.new(0, 6, 0, 1);
											Image = server.MatIcons.Build;
											BackgroundTransparency = 1;
											ZIndex = 3;
										}
									}
								}
							};
						})
					end)
				end
			end
		};

		ShowLogs = {
			Prefix = Settings.Prefix;
			Commands = {"showlogs", "showcommandlogs"};
			Args = {"player", "autoupdate? (default: true)"};
			Description = "Shows the target player(s) the command logs.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local autoUpdate = false
				if not args[2] or table.find({"yes", "true", "1", "autoupdate", "on"}, args[2]:lower()) then
					autoUpdate = true
				end
				local str = `{Settings.Prefix}logs {tostring(autoUpdate) or ""}`
				for _, v in service.GetPlayers(plr, args[1]) do
					Admin.RunCommandAsPlayer(str, v)
				end
			end
		};

		ShowTasks = {
			Prefix = "";
			Commands = {":tasks", ":tasklist", `{Settings.Prefix}tasks`, `{Settings.Prefix}tasklist`};
			Args = {"player"};
			Description = "Displays running tasks";
			AdminLevel = 100;
			ListUpdater = function(plr: Player, target)
				if target then
					for _, v in Functions.GetPlayers(plr, target, {UseFakePlayer = true}) do
						local cTasks = Remote.Get(v, "TaskManager", "GetTasks") or {}
						local temp = table.create(#cTasks + 1)

						table.insert(temp, {
							Text = "Client Tasks",
							Desc = "Tasks their client is performing"})

						for _, t in cTasks do
							table.insert(temp, {
								Text = `{t.Name or t.Function}- Status: {t.Status} - Elapsed: {t.CurrentTime - t.Created}`;
								Desc = tostring(t.Function);
							})
						end

						return temp
					end
				else
					local tasks = service.GetTasks()
					local temp = {}
					local cTasks = Remote.Get(plr, "TaskManager", "GetTasks") or {}

					table.insert(temp, {Text = "Server Tasks"; Desc = "Tasks the server is performing";})

					for _, v in tasks do
						table.insert(temp, {
							Text = `{v.Name or v.Function} - Status: {v.Status} - Elapsed: {os.time()-v.Created}`;
							Desc = tostring(v.Function);
						})
					end

					table.insert(temp, " ")
					table.insert(temp, {
						Text = "Client Tasks",
						Desc = "Tasks your client is performing"
					})

					for _, v in cTasks do
						table.insert(temp, {
							Text = `{v.Name or v.Function} - Status: {v.Status} - Elapsed: {v.CurrentTime-v.Created}`;
							Desc = tostring(v.Function);
						})
					end

					return temp
				end
			end;
			Function = function(plr: Player, args: {string})
				if args[1] then
					for i, v in service.GetPlayers(plr, args[1]) do
						Remote.MakeGui(plr, "List", {
							Title = `{v.Name}'s Tasks`;
							Table = Logs.ListUpdaters.ShowTasks(plr, v);
							Font = "Code";
							Update = "ShowTasks";
							UpdateArgs = {v};
							AutoUpdate = 1;
							Size = {500, 400};
						})
					end
				else
					Remote.MakeGui(plr, "List", {
						Title = "Tasks",
						Table = Logs.ListUpdaters.ShowTasks(plr),
						Font = "Code",
						Update = "ShowTasks",
						AutoUpdate = 1,
						Size = {500, 400},
					})
				end
			end
		};

		Sit = {
			Prefix = Settings.Prefix;
			Commands = {"sit", "seat"};
			Args = {"player"};
			Description = "Forces the target player(s) to sit";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local Humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if Humanoid then
						Humanoid.Sit = true
					end
				end
			end
		};

		SlowMode = {
			Prefix = Settings.Prefix;
			Commands = {"slowmode"};
			Args = {"seconds or \"disable\""};
			Description = "Chat Slow Mode";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local num = args[1] and tonumber(args[1]) --math.min(tonumber(args[1]), 120)

				if num then
					Admin.SlowMode = num;
					Functions.Hint(`Chat slow mode enabled ({num}s)`, service.GetPlayers())
				else
					Admin.SlowMode = nil;
					table.clear(Admin.SlowCache)
					Functions.Hint("Chat slow mode disabled", {plr})
				end
			end
		};

		Speed = {
			Prefix = Settings.Prefix;
			Commands = {"speed", "setspeed", "walkspeed", "ws"};
			Args = {"player", "number"};
			Description = "Set the target player(s)'s WalkSpeed to <number>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(not args[2] or args[2]:lower() ~= "inf", "Speed cannot be infinite")
				local speed = tonumber(args[2]) or 16
				assert(speed >= 0, "Speed cannot be negative")
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.WalkSpeed = speed
						if Settings.CommandFeedback then
							Functions.Notification("Notification", `Character walk speed has been set to {speed}`, {v}, 15)
						end
					end
				end
			end
		};

		StarterSpeed = {
			Prefix = Settings.Prefix;
			Commands = {"starterspeed", "startspeed", "persistspeed"};
			Args = {"player", "speed"};
			Description = "Sets the target player(s)'s starting speed";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local speed = tonumber(args[2])
				assert(speed, "Invalid speed value")
				local plrs = service.GetPlayers(plr, args[1])
				for _, v in plrs do
					server.Variables.Starter.Speed[tostring(v.UserId)] = speed
				end

				Functions.Hint(`Your starter speed was set to {speed}`, plrs)
				if Settings.CommandFeedback then
					Functions.Hint(`You set {#plrs} players starter speed to {speed}`, {plr})
				end
			end
		};

		StopCountdown = {
			Prefix = Settings.Prefix;
			Commands = {"stopcountdown", "stopcd"};
			Args = {};
			Description = "Stops all currently running countdowns";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.RemoveGui(v, "Countdown")
				end
				service.StopLoop("HintCountdown")
			end
		};

		Stun = {
			Prefix = Settings.Prefix;
			Commands = {"stun"};
			Args = {"player"};
			Description = "Stuns the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local Humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")

					if Humanoid then
						Humanoid.PlatformStand = true
					end
				end
			end
		};

		TeamList = {
			Prefix = Settings.Prefix;
			Commands = {"teams", "teamlist", "manageteams"};
			Args = {};
			Description = "Opens the teams manager GUI";
			AdminLevel = 100;
			Function = function(plr: Player, args: {[number]:string})
				Remote.MakeGui(plr, "Teams", {
					CmdPrefix = Functions.GetMainPrefix(); CmdPlayerPrefix = Settings.PlayerPrefix; CmdSpecialPrefix = Settings.SpecialPrefix; CmdSplitKey = Settings.SplitKey;
				})
			end
		};

		Teleport = {
			Prefix = Settings.Prefix;
			Commands = {"tp", "teleport", "transport"};
			Args = {"player1", "player2"};
			Description = "Teleport player1(s) to player2, a waypoint, or specific coords, use :tp player1 waypoint-WAYPOINTNAME to use waypoints, x,y,z for coords";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})

				if args[2] and (string.match(args[2], "^waypoint%-(.*)") or string.match(args[2], "wp%-(.*)")) then
					local m = string.match(args[2], "^waypoint%-(.*)") or string.match(args[2], "wp%-(.*)")
					local point

					for i, v in Variables.Waypoints do
						if string.sub(string.lower(i), 1, #m)==string.lower(m) then
							point=v
						end
					end

					for _, v in service.GetPlayers(plr, args[1]) do
						if point then
							local Character = v.Character

							if not Character then
								continue
							end

							Character:SetAttribute("ADONIS_isTeleporting", true)
							task.delay(0.5, function() if Character then Character:SetAttribute("ADONIS_isTeleporting", nil) end end)

							if workspace.StreamingEnabled == true then
								v:RequestStreamAroundAsync(point)
							end

							local Humanoid = Character:FindFirstChildOfClass("Humanoid")
							local root = (Humanoid and Humanoid.RootPart or Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart"))
							local FlightPos = root:FindFirstChild("ADONIS_FLIGHT_POSITION")
							local FlightGyro = root:FindFirstChild("ADONIS_FLIGHT_GYRO")

							if Humanoid then
								if Humanoid.SeatPart~=nil then
									Functions.RemoveSeatWelds(Humanoid.SeatPart)
								end
								if Humanoid.Sit then
									Humanoid.Sit = false
									Humanoid.Jump = true
								end
							end

							if FlightPos and FlightGyro then
								FlightPos.Position = root.Position
								FlightGyro.CFrame = root.CFrame
							end

							Variables.ReturnPoints[v] = root.CFrame

							task.wait()

							if root then
								root.CFrame = CFrame.new(point)
								if FlightPos and FlightGyro then
									FlightPos.Position = root.Position
									FlightGyro.CFrame = root.CFrame
								end
							end
						end
					end

					if not point then Functions.Hint(`Waypoint {m} was not found.`, {plr}) end
				elseif args[2] and string.find(args[2], ",") then
					local x, y, z = string.match(args[2], "(.*),(.*),(.*)")
					for _, v in service.GetPlayers(plr, args[1]) do
						local Character = v.Character
						local root = Character and Character:FindFirstChild('HumanoidRootPart')

						if not root then continue end

						Character:SetAttribute("ADONIS_isTeleporting", true)
						task.delay(0.5, function() if Character then Character:SetAttribute("ADONIS_isTeleporting", nil) end end)

						if workspace.StreamingEnabled == true then
							v:RequestStreamAroundAsync(Vector3.new(x,y,z))
						end

						local Humanoid = Character:FindFirstChildOfClass("Humanoid")
						local FlightPos = root:FindFirstChild("ADONIS_FLIGHT_POSITION")
						local FlightGyro = root:FindFirstChild("ADONIS_FLIGHT_GYRO")

						if Humanoid then
							if Humanoid.SeatPart~=nil then
								Functions.RemoveSeatWelds(Humanoid.SeatPart)
							end
							if Humanoid.Sit then
								Humanoid.Sit = false
								Humanoid.Jump = true
							end
						end

						if FlightPos and FlightGyro then
							FlightPos.Position = root.Position
							FlightGyro.CFrame = root.CFrame
						end

						Variables.ReturnPoints[v] = root.CFrame

						task.wait()

						root.CFrame = CFrame.new(Vector3.new(tonumber(x), tonumber(y), tonumber(z)))

						if FlightPos and FlightGyro then
							FlightPos.Position = root.Position
							FlightGyro.CFrame = root.CFrame
						end
					end
				else
					local target = service.GetPlayers(plr, args[2])[1]
					local players = service.GetPlayers(plr, args[1])

					if #players == 1 and players[1] == target then
						local v = players[1]
						local Character = v.Character
						local root = Character and Character:FindFirstChild('HumanoidRootPart')

						if root and target.Character:FindFirstChild("HumanoidRootPart") then
							local Humanoid = Character:FindFirstChildOfClass("Humanoid")
							local FlightPos = root:FindFirstChild("ADONIS_FLIGHT_POSITION")
							local FlightGyro = root:FindFirstChild("ADONIS_FLIGHT_GYRO")

							Character:SetAttribute("ADONIS_isTeleporting", true)
							task.delay(0.5, function() if Character then Character:SetAttribute("ADONIS_isTeleporting", nil) end end)

							if workspace.StreamingEnabled == true then
								v:RequestStreamAroundAsync((target.Character.HumanoidRootPart.CFrame*CFrame.Angles(0, math.rad(90/#players*1), 0)*CFrame.new(5+.2*#players, 0, 0))*CFrame.Angles(0, math.rad(90), 0).Position)
							end

							if Humanoid then
								if Humanoid.SeatPart~=nil then
									Functions.RemoveSeatWelds(Humanoid.SeatPart)
								end
								if Humanoid.Sit then
									Humanoid.Sit = false
									Humanoid.Jump = true
								end
							end
							if FlightPos and FlightGyro then
								FlightPos.Position = root.Position
								FlightGyro.CFrame = root.CFrame
							end

							Variables.ReturnPoints[v] = root.CFrame

							task.wait()

							root.CFrame = (target.Character.HumanoidRootPart.CFrame*CFrame.Angles(0, math.rad(90/#players*1), 0)*CFrame.new(5+.2*#players, 0, 0))*CFrame.Angles(0, math.rad(90), 0)

							if FlightPos and FlightGyro then
								FlightPos.Position = root.Position
								FlightGyro.CFrame = root.CFrame
							end
						end
					else
						if not target then return end

						local targ_root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
						if targ_root then
							for k, v in players do
								if v ~= target then
									local Character = v.Character

									if not Character or not Character:FindFirstChild("HumanoidRootPart") then
										continue
									end

									Character:SetAttribute("ADONIS_isTeleporting", true)
									task.delay(0.5, function() if Character then Character:SetAttribute("ADONIS_isTeleporting", nil) end end)

									if workspace.StreamingEnabled == true then
										v:RequestStreamAroundAsync((targ_root.CFrame*CFrame.Angles(0, math.rad(90/#players*k), 0)*CFrame.new(5+.2*#players, 0, 0))*CFrame.Angles(0, math.rad(90), 0).Position)
									end

									local Humanoid = Character:FindFirstChildOfClass("Humanoid")
									local root = Character:FindFirstChild('HumanoidRootPart')
									local FlightPos = root:FindFirstChild("ADONIS_FLIGHT_POSITION")
									local FlightGyro = root:FindFirstChild("ADONIS_FLIGHT_GYRO")
									if Humanoid then
										if Humanoid.SeatPart ~= nil then
											Functions.RemoveSeatWelds(Humanoid.SeatPart)
										end
										if Humanoid.Sit then
											Humanoid.Sit = false
											Humanoid.Jump = true
										end
									end
									if FlightPos and FlightGyro then
										FlightPos.Position = root.Position
										FlightGyro.CFrame = root.CFrame
									end

									Variables.ReturnPoints[v] = root.CFrame

									task.wait()

									if root and targ_root then
										root.CFrame = (targ_root.CFrame*CFrame.Angles(0, math.rad(90/#players*k), 0)*CFrame.new(5+.2*#players, 0, 0))*CFrame.Angles(0, math.rad(90), 0)
										if FlightPos and FlightGyro then
											FlightPos.Position = root.Position
											FlightGyro.CFrame = root.CFrame
										end
									end
								end
							end
						end
					end
				end
			end
		};

		Thaw = {
			Prefix = Settings.Prefix;
			Commands = {"thaw", "unfreeze", "unice"};
			Args = {"player"};
			Description = "UnFreezes the target players, thaws them out";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
							local ice = v.Character:FindFirstChild("Adonis_Ice")
							local plate
							if ice then
								plate = service.New("Part", {
									Parent = v.Character;
									Name = "Adonis_Water";
									Anchored = true;
									CanCollide = false;
									TopSurface = "Smooth";
									BottomSurface = "Smooth";
									Size = Vector3.new(0.2, 0.2, 0.2);
									BrickColor = BrickColor.new("Steel blue");
									Transparency = ice.Transparency;
									CFrame = v.Character.HumanoidRootPart.CFrame * CFrame.new(0, -3, 0);
								})
								service.New("CylinderMesh", plate)
								for i = 0.2, 3, 0.2 do
									ice.Size = Vector3.new(5, ice.Size.Y - i, 5)
									ice.CFrame = v.Character.HumanoidRootPart.CFrame * CFrame.new(0, -i, 0)
									plate.Size = Vector3.new(i + 5, 0.2, i + 5)
									wait()
								end
								ice:Destroy()
							end

							for _, obj in v.Character:GetChildren() do
								if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and obj ~= plate then
									obj.Anchored = false
								end
							end
							wait(3)
							pcall(function() plate:Destroy() end)
						end
					end)
				end
			end
		};

		Thru = {
			Prefix = Settings.Prefix;
			Commands = {"thru", "pass", "through"};
			Args = {"distance? (default: 5)"};
			Description = "Lets you pass through an object or a wall";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local rawDistance = tonumber(args[1] or 5)
				assert(rawDistance, "Invalid distance value (must be a number)")

				local distance = rawDistance * -1
				if plr.Character:FindFirstChild("HumanoidRootPart") then
					if plr.Character.Humanoid.SeatPart~=nil then
						Functions.RemoveSeatWelds(plr.Character.Humanoid.SeatPart)
					end
					if plr.Character.Humanoid.Sit then
						plr.Character.Humanoid.Sit = false
						plr.Character.Humanoid.Jump = true
					end
					Variables.ReturnPoints[plr] = plr.Character.HumanoidRootPart.CFrame

					task.wait()
					plr.Character:PivotTo(plr.Character:GetPivot() * CFrame.new(0, 0, distance))
				end
			end
		};

		Time = {
			Prefix = Settings.Prefix;
			Commands = {"time", "timeofday"};
			Args = {"time", "optional player"};
			Description = "Change Time";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				if args[2] then
					for _, v in service.GetPlayers(plr, args[2]) do
						Remote.SetLighting(v, "TimeOfDay", args[1])
					end
				else
					Functions.SetLighting("TimeOfDay", args[1])
				end
			end
		};

		TimeHint = {
			Prefix = Settings.Prefix;
			Commands = {"th", "timehint", "thint"};
			Args = {"time", "message"};
			Filter = true;
			Description = "Makes a hint and make it stay on the screen for the specified amount of time";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Functions.Hint(service.BroadcastFilter(assert(args[2], "Missing message"), plr), service.GetPlayers(), assert(tonumber(args[1]), "Invalid time amount (must be a number)"), service.FormatPlayer(plr), `rbxthumb://type=AvatarHeadShot&id={plr.UserId}&w=48&h=48`)
			end
		};

		TimeMessage = {
			Prefix = Settings.Prefix;
			Commands = {"tm", "timem", "timedmessage", "timemessage"};
			Args = {"time", "message"};
			Filter = true;
			Description = "Make a message and makes it stay for the amount of time (in seconds) you supply";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Functions.Message(`Message from {service.FormatPlayer(plr)}`, service.BroadcastFilter(assert(args[2], "Missing message"), plr), service.GetPlayers(), true, assert(tonumber(args[1]), "Invalid time amount (must be number)"))
			end
		};

		To = {
			Prefix = Settings.Prefix;
			Commands = {"to", "goto"};
			Args = {"destination  ('<player>'/'waypoint-<name>'/'<x>,<y>,<z>')"};
			Description = "Teleports you to the target player, waypoint or coordinates";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Commands.Teleport.Function(plr, {`@{plr.Name}`, if args[1] then args[1] else "me"})
			end
		};

		ToggleFreecam = {
			Prefix = Settings.Prefix;
			Commands = {"togglefreecam"};
			Args = {"player"};
			Description = "Toggles Freecam";
			AdminLevel = "Tester";
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local plrgui = v:FindFirstChildOfClass("PlayerGui")
					local freecam = plrgui and plrgui:FindFirstChild("Freecam")
					local remote: RemoteFunction? = freecam and freecam:FindFirstChildOfClass("RemoteFunction")

					if remote then
						task.defer(pcall, remote.InvokeClient, remote, v, "Toggle")
					end
				end
			end
		};

		Track = {
			Prefix = Settings.Prefix,
			Commands = {"track", "trace", "find", "locate", "roblox"},
			Args = {"player", "persistent? (default: true)"},
			Description = "Shows you where the target player(s) is/are",
			AdminLevel = 100,
			Function = function(plr: Player, args: { string })
				local plrChar = plr.Character
				assert(plrChar, "You don't have a character")
				local plrHum = plrChar:FindFirstChildOfClass("Humanoid")
				assert(plrHum, "You don't have a humanoid")

				-- Always persistent
				if type(Variables.TrackingTable[plr.Name]) ~= "table" then
					Variables.TrackingTable[plr.Name] = {}
				end

				local trackedNames = {}
				local isAll = false
				do
					local arg = args[1]
					if arg and (arg:lower() == "all" or arg:lower() == "others") then
						isAll = true
					else
						for _, v: Player in service.GetPlayers(plr, arg) do
							trackedNames[v.Name:lower()] = true
						end
					end
				end

				local function addTracker(target: Player)
					local char = target.Character
					if not char then
						target.CharacterAdded:Wait()
						char = target.Character
					end

					local rootPart = char:FindFirstChild("HumanoidRootPart")
					local head = char:FindFirstChild("Head")
					if not (rootPart and head) then
						Functions.Hint(`{service.FormatPlayer(target)} doesn't currently have a HumanoidRootPart/Head`, { plr })
						return
					end

					task.defer(function()
						local gui = service.New("BillboardGui", {
							Name = `{target.Name}_Tracker`,
							Adornee = head,
							AlwaysOnTop = true,
							StudsOffset = Vector3.new(0, 2, 0),
							Size = UDim2.new(0, 200, 0, 80),
						})
						local frame = service.New("Frame", {
							Parent = gui,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
						})
						local name = service.New("TextLabel", {
							Parent = frame,
							Text = service.FormatPlayer(target) .. "\n" .. (target.Team and target.Team.Name or ""),
							BackgroundTransparency = 1,
							Font = Enum.Font.Arial,
							TextColor3 = Color3.new(1, 1, 1),
							TextStrokeColor3 = Color3.new(0, 0, 0),
							TextStrokeTransparency = 0,
							Size = UDim2.new(1, 0, 0, 50),
							TextScaled = true,
							TextWrapped = true,
						})

						Remote.MakeLocal(plr, gui, false)

						local function removeTracker()
							Remote.RemoveLocal(plr, `{target.Name}_Tracker`)
						end

						local charRemovingConn = target.CharacterRemoving:Connect(removeTracker)
						local diedConn
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							diedConn = hum.Died:Connect(removeTracker)
						end

						local plrCharRemovingConn = plr.CharacterRemoving:Connect(removeTracker)

						-- Clean up connections when tracker is removed
						gui.AncestryChanged:Connect(function()
							if charRemovingConn then charRemovingConn:Disconnect() end
							if diedConn then diedConn:Disconnect() end
							if plrCharRemovingConn then plrCharRemovingConn:Disconnect() end
						end)
					end)
				end

				-- Track current targets
				for _, v: Player in service.GetPlayers(plr, args[1]) do
					Variables.TrackingTable[plr.Name][v] = true
					addTracker(v)
				end

				-- Listen for new players joining
				if not Variables.TrackingTable[plr.Name]._connections then
					Variables.TrackingTable[plr.Name]._connections = {}

					local playerAddedConn = service.Players.PlayerAdded:Connect(function(newPlr)
						if isAll or trackedNames[newPlr.Name:lower()] then
							Variables.TrackingTable[plr.Name][newPlr] = true
							addTracker(newPlr)
							newPlr.CharacterAdded:Connect(function()
								addTracker(newPlr)
							end)
						end
					end)
					table.insert(Variables.TrackingTable[plr.Name]._connections, playerAddedConn)

					-- For all tracked players, listen for respawn
					for _, trackedPlr in service.Players:GetPlayers() do
						if isAll or trackedNames[trackedPlr.Name:lower()] then
							local charAddedConn = trackedPlr.CharacterAdded:Connect(function()
								addTracker(trackedPlr)
							end)
							table.insert(Variables.TrackingTable[plr.Name]._connections, charAddedConn)
						end
					end
				end
			end
		};

		Transparency = {
			Prefix = Settings.Prefix;
			Commands = {"transparency", "trans"};
			Args = {"player", "% value (0-1)"};
			Description = "Set the transparency of the target's character";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						for k, p in v.Character:GetChildren() do
							if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
								p.Transparency = args[2]
								if p.Name == "Head" then
									for _, v2 in p:GetChildren() do
										if v2:IsA("Decal") then
											v2.Transparency = args[2]
										end
									end
								end
							elseif p:IsA("Accessory") and #p:GetChildren() ~= 0 then
								for _, v2 in p:GetChildren() do
									if v2:IsA("BasePart") then
										v2.Transparency = args[2]
									end
								end
							end
						end
					end
				end
			end
		};


		UnESP = {
			Prefix = Settings.Prefix;
			Commands = {"unesp"};
			Args = {};
			Filter = true;
			Description = "Removes ESP";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string}, data: {})
				Remote.Send(plr, "Function", "CharacterESP", false)
			end
		};

		UnFly = {
			Prefix = Settings.Prefix;
			Commands = {"unfly", "ground"};
			Args = {"player"};
			Description = "Removes the target player(s)'s ability to fly";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local part = v.Character and v.Character:FindFirstChild("HumanoidRootPart")
					if part then
						local oldp = part:FindFirstChild("ADONIS_FLIGHT_POSITION")
						local oldpa = part:FindFirstChild("ADONIS_FLIGHT_POSITION_ATTACHMENT")
						local oldg = part:FindFirstChild("ADONIS_FLIGHT_GYRO")
						local oldga = part:FindFirstChild("ADONIS_FLIGHT_GYRO_ATTACHMENT")
						local olds = part:FindFirstChild("ADONIS_FLIGHT")
						if oldp then oldp:Destroy() end
						if oldpa then oldpa:Destroy() end
						if oldg then oldg:Destroy() end
						if oldga then oldga:Destroy() end
						if olds then Remote.Send(v, "Function", "Unfly") olds:Destroy() end
					end
				end
			end
		};

		UnForcefield = {
			Prefix = Settings.Prefix;
			Commands = {"unff", "unforcefield"};
			Args = {"player"};
			Description = "Removes force fields on the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						Routine(function()
							for _, c in v.Character:GetChildren() do
								if c:IsA("ForceField") and c.Name ~= "ADONIS_FULLGOD" then
									c:Destroy()
								end
							end
						end)
					end
				end
			end
		};

		UnFreecam = {
			Prefix = Settings.Prefix;
			Commands = {"unfreecam"};
			Args = {"player"};
			Description = "UnFreecam";
			AdminLevel = "Tester";
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local plrgui = v:FindFirstChildOfClass("PlayerGui")
					local freecam = plrgui and plrgui:FindFirstChild("Freecam")
					if freecam then
						task.defer(function()
							local remote: RemoteFunction? = freecam:FindFirstChildOfClass("RemoteFunction")
							if remote then
								pcall(remote.InvokeClient, remote, v, "End")
							end

							Remote.Send(v, "Function", "SetView", "reset")
							service.Debris:AddItem(freecam, 2)
							Functions.Notification("Notification", "Freecam has been disabled.", {v}, 15)
						end)
					end
				end
			end
		};

		UnGod = {
			Prefix = Settings.Prefix;
			Commands = {"ungod", "mortal", "unfullgod", "untotalgod"};
			Args = {"player"};
			Description = "Makes the target player(s) mortal again";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.MaxHealth = 100
						hum.Health = hum.MaxHealth
						local fullGodFF = v.Character:FindFirstChild("ADONIS_FULLGOD")
						if fullGodFF and fullGodFF:IsA("ForceField") then
							fullGodFF:Destroy()
						end
						if Settings.CommandFeedback then
							Functions.Notification("God Mode", "Character god mode has been disabled.", {v}, 15, "Info")
						end
					end
				end
			end
		};

		UnGuiView = {
			Prefix = Settings.Prefix;
			Commands = {"unguiview", "unshowguis", "unviewguis"};
			Args = {};
			Description = "Removes the viewed player's GUIs";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				Remote.Send(plr, "Function", "UnLoadGuiData")
			end;
		};

		UnJail = {
			Prefix = Settings.Prefix;
			Commands = {"unjail", "free", "release"};
			Args = {"player"};
			Description = "UnJails the target player(s) and returns any tools that were taken from them while jailed";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local found = false

				for _, v in service.GetPlayers(plr, args[1]) do
					local ind = tostring(v.UserId)
					local jail = Variables.Jails[ind]
					if jail then
						--service.StopLoop(`{ind}JAIL`)
						Pcall(function()
							for _, tool in jail.Tools do
								tool.Parent = v.Backpack
							end
						end)
						Pcall(function() jail.Jail:Destroy() end)
						Variables.Jails[ind] = nil
						found = true
					end
				end

				if not found then
					for i, v in Variables.Jails do
						if string.sub(string.lower(v.Name), 1, #args[1]) == string.lower(args[1]) then
							local ind = v.Index
							service.StopLoop(`{ind}JAIL`)
							Pcall(function() v.Jail:Destroy() end)
							Variables.Jails[ind] = nil
						end
					end
				end
			end
		};

		UnLock = {
			Prefix = Settings.Prefix;
			Commands = {"unlock", "unlockplr", "unlockplayer"};
			Args = {"player"};
			Description = "UnLocks the the target player(s), makes it so you can use btools on them";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						for a, obj in v.Character:GetChildren() do
							if obj:IsA("BasePart") then
								obj.Locked = false
							elseif obj:IsA("Accoutrement") and obj:FindFirstChild("Handle") then
								obj.Handle.Locked = false
							end
						end
					end
				end
			end
		};

		UnMute = {
			Prefix = Settings.Prefix;
			Commands = {"unmute", "unsilence"};
			Args = {"player"};
			Description = "Makes it so the target player(s) can talk again. No effect if on Trello mute list.";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					for k, m in Settings.Muted do
						if Admin.DoCheck(v, m) then
							table.remove(Settings.Muted, k)
							--Remote.LoadCode(v,[[if not client.Variables.CustomChat then service.StarterGui:SetCoreGuiEnabled("Chat", true) client.Variables.ChatEnabled = false end client.Variables.Muted = true]])
						end
					end
					service.Events.PlayerUnMuted:Fire({
						Target = v.UserId;
						Moderator = plr.UserId;
					})

					Functions.Hint(`Unmuted {service.FormatPlayer(v)}`, {plr})

					Functions.Notification("Notification", `You have been unmuted!`, {v}, 10, "MatIcon://Warning")
				end
			end
		};

		UnStun = {
			Prefix = Settings.Prefix;
			Commands = {"unstun"};
			Args = {"player"};
			Description = "UnStuns the target player(s)";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local Humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")

					if Humanoid then
						Humanoid.PlatformStand = false
					end
				end
			end
		};

		Unteam = {
			Prefix = Settings.Prefix;
			Commands = {"unteam", "removefromteam", "neutral"};
			Args = {"player"};
			Description = "Takes the target player(s) off of a team and sets them to 'Neutral' ";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, player in Functions.GetPlayers(plr, args[1]) do
					player.Neutral = true
					player.Team = nil
					player.TeamColor = BrickColor.new(194) -- Neutral Team
					if Settings.CommandFeedback then
						Functions.Notification("Team", "Your team has been reset and you are now on the Neutral team.", {player}, 15, "Info") -- Functions.Notification(title,message,player,time,icon)
					end
				end
			end
		};

		UnTrack = {
		    Prefix = Settings.Prefix;
		    Commands = {"untrack", "untrace", "unfind", "unlocate", "notrack"};
		    Args = {"player"};
		    Description = "Stops tracking the target player(s)";
		    AdminLevel = 100;
		    Function = function(plr: Player, args: {string})
		        local trackData = Variables.TrackingTable[plr.Name]
			
		        if not args[1] or args[1]:lower() == `{Settings.SpecialPrefix}all` then
		            -- Disconnect all stored connections
		            if trackData and trackData._connections then
		                for _, conn in ipairs(trackData._connections) do
		                    conn:Disconnect()
		                end
		            end
				
		            -- Clear tracking table
		            Variables.TrackingTable[plr.Name] = nil
				
		            -- Remove all trackers
		            Remote.RemoveLocal(plr, "Tracker", false, true)
		        else
		            if trackData then
		                for _, v in service.GetPlayers(plr, args[1]) do
		                    Remote.RemoveLocal(plr, `{v.Name}_Tracker`)
		                    trackData[v] = nil
		                end
		            end
		        end
		    end
		};

		View = {
			Prefix = Settings.Prefix;
			Commands = {"view", "watch", "nsa", "viewplayer"};
			Args = {"player", "persist (default: true)"};
			Description = "Makes you view the target player";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local function viewPlayer(plr: Player, rootPart: BasePart, humanoid: Humanoid)
						Functions.ResetReplicationFocus(plr)
						plr.ReplicationFocus = rootPart
						Remote.Send(plr, "Function", "SetView", humanoid)
					end

					local hum = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if not hum then
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a character humanoid`, {plr})
						continue
					end
					local rootPart = v.Character.PrimaryPart
					if not rootPart then
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a HumanoidRootPart`, {plr})
						continue
					end

					viewPlayer(plr, rootPart, hum)

					if v.UserId == plr.UserId and Variables.PersistView[plr.UserId] then
						Variables.PersistView[plr.UserId] = nil
						continue
					end

					local persist = args[2]
					local event

					if persist and persist:lower() == "false" then
						continue
					end

					Variables.PersistView[plr.UserId] = {
						Viewing = v
					}

					event = v.CharacterAdded:Connect(function(char)
						task.wait(0.5)

						local newhum = char:FindFirstChildOfClass("Humanoid")
						local newRootPart = char.PrimaryPart

						if Variables.PersistView[plr.UserId] and Variables.PersistView[plr.UserId].Viewing then
							if Variables.PersistView[plr.UserId].Viewing.UserId == v.UserId then
								viewPlayer(plr, newRootPart, newhum)
							else
								event:Disconnect()
							end
							return;
						else
							Variables.PersistView[plr.UserId] = nil
							event:Disconnect()

							return;
						end
					end)
				end
			end
		};

		ViewCamera = {
			Prefix = Settings.Prefix;
			Commands = {"viewcam", "viewc", "camview", "watchcam", "cam"};
			Args = {"camera"};
			Description = "Makes you view the target camera";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, v in Variables.Cameras do
					if string.sub(v.Name, 1, #args[1]) == args[1] then
						Remote.Send(plr, "Function", "SetView", v.Brick)
					end
				end
			end
		};

		Visible = {
			Prefix = Settings.Prefix;
			Commands = {"visible", "vis", "uninvisible"};
			Args = {"player"};
			Description = "Makes the target player(s) visible";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				for i, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						for a, obj in v.Character:GetChildren() do
							if obj:IsA("BasePart") and obj.Name~="HumanoidRootPart" then
								obj.Transparency = 0
								if obj:FindFirstChild("face") then
									obj.face.Transparency = 0
								end
								if obj:FindFirstChildOfClass("BillboardGui") then
									obj:FindFirstChildOfClass("BillboardGui").Enabled = true
								end
							elseif obj:IsA("Accoutrement") and obj:FindFirstChild("Handle") then
								obj.Handle.Transparency = 0
							elseif obj:IsA("Tool") then
								for _, Descendant in obj:GetDescendants() do
									if Descendant:IsA("BasePart") or Descendant:IsA("Decal") or Descendant:IsA("UnionOperation") then
										local Transparency = Descendant:GetAttribute('ADONIS_OriginalTransparency') or 0
										Descendant.Transparency = Transparency
										Descendant:SetAttribute('ADONIS_OriginalTransparency',nil)
									end
								end
							elseif obj:IsA("ForceField") and obj.Name ~="ADONIS_FULLGOD" then
								obj.Visible = true
							elseif obj:IsA("BillboardGui") then
								obj.Enabled = true
							elseif obj.Name == "Head" then
								local face = obj:FindFirstChildOfClass("Decal")
								if face then
									face.Transparency = 0
								end
							end
						end
					end
				end
			end
		};

		Vote = {
			Prefix = Settings.Prefix;
			Commands = {"vote", "makevote", "startvote", "question", "survey"};
			Args = {"player", "answer1,answer2,etc (NO SPACES)", "question"};
			Filter = true;
			Description = "Lets you ask players a question with a list of answers and get the results";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local question = args[3]
				if not question then error("You forgot to supply a question!") end
				local answers = args[2]
				local anstab = {}
				local responses = {}
				local voteKey = `ADONISVOTE{service.HttpService:GenerateGUID(false)}`;
				local players = service.GetPlayers(plr, args[1])
				local startTime = os.clock();

				local function voteUpdate()
					local total = #responses
					local results = table.create(total)

					local tab = {
						`Question: {question}`;
						`Total Responses: {total}`;
						`Didn't Vote: {#players-total}`;
						`Time Left: {math.ceil(math.max(0, 120 - (os.clock()-startTime)))}`;
					}

					for _, v in responses do
						if not results[v] then results[v] = 0 end
						results[v] += 1
					end

					for _, v in anstab do
						local ans = v
						local num = results[v]
						local percent
						if not num then
							num = 0
							percent = 0
						else
							percent = math.floor((num/total)*100)
						end

						table.insert(tab, {Text=`{ans} | {percent}% - {num}/{total}`, Desc=`Number: {num}/{total} | Percent: {percent}`})
					end

					return tab;
				end

				Logs.TempUpdaters[voteKey] = voteUpdate;

				if not answers then
					anstab = {"Yes", "No"}
				else
					for ans in string.gmatch(answers, "([^,]+)") do
						table.insert(anstab, ans)
					end
				end

					for i, v in players do
					Routine(function()
						local response = Remote.GetGui(v, "Vote", {
							Question = question;
							Answers = anstab;
							IsRandomOrder = true;
						})
						if response then
							table.insert(responses, response)
						end
					end)
				end

				Remote.MakeGui(plr, "List", {
					Title = "Results";
					Tab = voteUpdate();
					Update = "TempUpdate";
					UpdateArgs = {{UpdateKey = voteKey}};
					AutoUpdate = 1;
				})

				delay(120, function() Logs.TempUpdaters[voteKey] = nil end)
			end
		};

		Waypoint = {
			Prefix = Settings.Prefix;
			Commands = {"waypoint", "wp", "checkpoint"};
			Args = {"name"};
			Filter = true;
			Description = "Makes a new waypoint/sets an exiting one to your current position with the name <name> that you can teleport to using :tp me waypoint-<name>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local name = args[1] or tostring(#Variables.Waypoints + 1)
				if plr.Character:FindFirstChild("HumanoidRootPart") then
					Variables.Waypoints[name] = plr.Character.HumanoidRootPart.Position
					Functions.Hint(`Made waypoint {name} | {Variables.Waypoints[name]}`, {plr})
				end
			end
		};

		Note = {
			Prefix = Settings.Prefix;
			Commands = {"note", "writenote", "makenote"};
			Args = {"player", "note"};
			Filter = true;
			Description = "Makes a note on the target player(s) that says <note>";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				assert(args[2], "Missing note (argument #2)")
				for _, v in service.GetPlayers(plr, args[1], {UseFakePlayer = true}) do
					local PlayerData = Core.GetPlayer(v)
					if not PlayerData.AdminNotes then PlayerData.AdminNotes = {} end
					table.insert(PlayerData.AdminNotes, args[2])
					Functions.Hint(`Added {service.FormatPlayer(v)} Note {args[2]}`, {plr})
					Core.SavePlayer(v, PlayerData)
				end
			end
		};

		Waypoints = {
			Prefix = Settings.Prefix;
			Commands = {"waypoints"};
			Args = {};
			Description = "Shows available waypoints, mouse over their names to view their coordinates";
			AdminLevel = 100;
			Function = function(plr: Player, args: {string})
				local temp={}
				for i, v in Variables.Waypoints do
					local x, y, z=tostring(v):match("(.*),(.*),(.*)")
					table.insert(temp, {Text=i, Desc=`X:{x} Y:{y} Z:{z}`})
				end
				Remote.MakeGui(plr, "List", {
					Title = 'Waypoints';
					Icon = server.MatIcons.People;
					Tab = temp;
				})
			end
		};

	}
end
