return function(Vargs, env)
	local server = Vargs.Server;
	local service = Vargs.Service;
	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	if env then setfenv(1, env) end

	return {
		AwardBadge = {
			Prefix = Settings.Prefix;
			Commands = {"awardbadge", "badge", "givebadge"};
			Args = {"player", "badgeId"};
			Description = "Awards the badge of the specified ID to the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				if not Variables.BadgeInfoCache then
					Variables.BadgeInfoCache = {}
				end

				local badgeId = assert(tonumber(args[2]), "Invalid badge ID specified!")
				local badgeInfo = Variables.BadgeInfoCache[tostring(badgeId)]
				if not badgeInfo then
					local success
					badgeInfo = nil
					local tries = 0
					repeat
						tries += 1
						success, badgeInfo = pcall(service.BadgeService.GetBadgeInfoAsync, service.BadgeService, badgeId)
					until success or tries > 2
					Variables.BadgeInfoCache[tostring(badgeId)] = assert(success and badgeInfo, "Unable to retrieve badge information; please try again")
				end

				for _, v: Player in service.GetPlayers(plr, args[1]) do
					local success, hasBadge = nil, nil
					local tries = 0
					repeat
						tries += 1
						success, hasBadge = pcall(service.BadgeService.UserHasBadgeAsync, service.BadgeService, v.UserId, badgeId)
					until success or tries > 2
					if not success then
						Functions.Hint(string.format("ERROR: Unable to get badge ownership status for %s; skipped", service.FormatPlayer(v)))
						continue
					end
					if hasBadge then
						Functions.Hint(string.format("%s already has the badge '%s'", service.FormatPlayer(v), badgeInfo.Name), {plr})
					elseif service.BadgeService:AwardBadge(v.UserId, badgeId) then
						Functions.Hint(string.format("Successfully awarded badge '%s' for %s", badgeInfo.Name, service.FormatPlayer(v)), {plr})
					else
						Functions.Hint(string.format("ERROR: Failed to award badge '%s' for %s due to an unexpected internal error", badgeInfo.Name, service.FormatPlayer(v)), {plr})
					end
				end
			end
		};

		BackupMap = {
			Prefix = Settings.Prefix;
			Commands = {"backupmap", "mapbackup", "bmap"};
			Args = {};
			Description = "Changes the backup for the restore map command to the map's current state";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local plr_name = if plr then service.FormatPlayer(plr) else "%SYSTEM%"

				if plr then
					Functions.Hint("Updating Map Backup...", {plr})
				end

				if Variables.BackingupMap then
					error("Backup Map is in progress. Please try again later!")
					return
				end
				if Variables.RestoringMap then
					error("Cannot backup map while map is being restored!")
					return
				end

				Variables.BackingupMap = true
				Variables.OriginalGravity = workspace.Gravity

				local Lighting = service.Lighting
				local atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")

				Variables.OriginalLightingSettings = {
					Ambient = Lighting.Ambient,
					OutdoorAmbient = Lighting.OutdoorAmbient,
					Brightness = Lighting.Brightness,
					TimeOfDay = Lighting.TimeOfDay,
					FogColor = Lighting.FogColor,
					FogEnd = Lighting.FogEnd,
					FogStart = Lighting.FogStart,
					GlobalShadows = Lighting.GlobalShadows,
					Outlines = Lighting.Outlines,
					ShadowColor = Lighting.ShadowColor,
					ColorShift_Bottom = Lighting.ColorShift_Bottom,
					ColorShift_Top = Lighting.ColorShift_Top,
					GeographicLatitude = Lighting.GeographicLatitude,
					Name = Lighting.Name,
					Sky = Lighting:FindFirstChildOfClass("Sky") and Lighting:FindFirstChildOfClass("Sky"):Clone(),
				}
				Variables.OriginalAtmosphereSettings = {
					Name = atmosphere and atmosphere.Name,
					Density = atmosphere and atmosphere.Density,
					Offset = atmosphere and atmosphere.Offset,
					Color = atmosphere and atmosphere.Color,
					Decay = atmosphere and atmosphere.Decay,
					Glare = atmosphere and atmosphere.Glare,
					Haze = atmosphere and atmosphere.Haze,
				}

				local tempmodel = service.New("Model", {
					Name = "BACKUP_MAP_MODEL"
				})
				for _, v in workspace:GetChildren() do
					if v.ClassName ~= "Terrain" and not service.Players:GetPlayerFromCharacter(v) then
						local archive = v.Archivable
						v.Archivable = true
						v:Clone().Parent = tempmodel
						v.Archivable = archive
					end
				end
				Variables.MapBackup = tempmodel:Clone()
				tempmodel:Destroy()

				local Terrain = workspace.Terrain or workspace:FindFirstChildOfClass("Terrain")
				if Terrain then
					Variables.TerrainMapBackup = Terrain:CopyRegion(Terrain.MaxExtents)
				end

				if plr then
					Functions.Hint('Backup Complete', {plr})
				end

				Variables.BackingupMap = false

				Logs.AddLog(Logs.Script, {
					Text = "Backup Complete";
					Desc = `{plr_name} has successfully backed up the map.`;
				})
			end
		};

		BanList = {
			Prefix = Settings.Prefix;
			Commands = {"banlist", "banned", "bans", "banland"};
			Args = {};
			Description = "Shows you the normal ban list";
			AdminLevel = 700;
			Hidden = true;
			ListUpdater = function(plr: Player)
				local tab = table.create(#Settings.Banned + 2)
				local count = 0
				for _, v in Settings.Banned do
					local entry = type(v) == "string" and v
					local reason = "No reason provided"
					local moderator = "%UNKNOWN%"

					local banType = if typeof(v) == 'table' and v.BanType == "Server" then
						"SERVER"
					else "GLOBAL";

					count +=1
					if type(v) == "table" then
						if v.Name and v.UserId then
							entry = `[{banType}] {v.Name}:{v.UserId}`
						elseif v.UserId then
							entry = `[{banType}] ID: {v.UserId}`
						elseif v.Name then
							entry = `[{banType}] {v.Name}`
						end
						if v.Reason then
							reason = v.Reason
						end
						if v.Moderator then
							moderator = v.Moderator
						end
					else
						entry = `[{banType}] {v}`
					end
					table.insert(tab, {
						Text = tostring(entry),
						Desc = string.format("Issued by: %s | Reason: %s", moderator, reason)
					})
				end
				table.insert(tab, 1, `# Banned Users: {count}`)
				table.insert(tab, 2, "―――――――――――――――――――――――")
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Ban List";
					Icon = server.MatIcons.Gavel;
					Tab = Logs.ListUpdaters.BanList(plr);
					Update = "BanList";
					TextSelectable = true;
				})
			end;
		};

		Bots = {
			Prefix = Settings.Prefix;
			Commands = {"bot", "trainingbot"};
			Args = {"player", "num (max: 50)", "walk", "attack", "friendly", "health", "speed", "damage"};
			Description = "AI bots made for training; ':bot scel 5 true true'";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local num = tonumber(args[2]) and math.clamp(tonumber(args[2]), 1, 50) or 1
				local health = tonumber(args[6]) or 100
				local speed = tonumber(args[7]) or 16
				local damage = tonumber(args[8]) or 5
				local attack = args[4] == "true" and true or false
				local friendly = args[5] == "true" and true or false
				local walk

				if args[3] == "false" then
					walk = false
				else
					walk = true
				end

				for _, v in service.GetPlayers(plr, args[1]) do
					Functions.makeRobot(v, num, health, speed, damage, walk, attack, friendly)
				end
			end
		};

		Cape = {
			Prefix = Settings.Prefix;
			Commands = {"cape", "givecape"};
			Args = {"player", "name/color", "material", "reflectance", "id"};
			Description = `Gives the target player(s) the cape specified, do {Settings.Prefix}capes to view a list of available capes`;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local color="White"
				if pcall(function() return BrickColor.new(args[2]) end) then color = args[2] end
				local mat = args[3] or "Fabric"
				local ref = args[4]
				local id = args[5]
				if args[2] and not args[3] then
					for k, cape in Variables.Capes do
						if string.lower(args[2])==string.lower(cape.Name) then
							color = cape.Color
							mat = cape.Material
							ref = cape.Reflectance
							id = cape.ID
						end
					end
				end
				for _, v in service.GetPlayers(plr, args[1]) do
					Functions.Cape(v, false, mat, color, id, ref)
				end
			end
		};

		Capes = {
			Prefix = Settings.Prefix;
			Commands = {"capes", "capelist"};
			Args = {};
			Description = "Shows you the list of capes for the cape command";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local list = table.create(#Variables.Capes)
				for _, v in Variables.Capes do
					table.insert(list, v.Name)
				end
				Remote.MakeGui(plr, "List", {Title = "Cape List", Tab = list;})
			end
		};


		Control = {
			Prefix = Settings.Prefix;
			Commands = {"control", "takeover"};
			Args = {"player"};
			Description = "Lets you take control of the target player";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local Humanoid = v.Character.Humanoid

						local HumanoidDescription = Humanoid:GetAppliedDescription() or service.Players:GetHumanoidDescriptionFromUserId(v.UserId)
						local newCharacterModel: Model = service.Players:CreateHumanoidModelFromDescription(HumanoidDescription, v.Character.Humanoid.RigType)
						local Animate: BaseScript = newCharacterModel.Animate

						newCharacterModel.Humanoid.DisplayName = Humanoid.DisplayName
						newCharacterModel.Name = v.Name

						local oldCFrame = v.Character and v.Character:GetPivot() or CFrame.new()

						if plr.Character then
							plr.Character = nil
							v.Character = nil
						end
						plr.Character = newCharacterModel

						newCharacterModel:PivotTo(oldCFrame)
						newCharacterModel.Parent = workspace

						-- hacky way to fix other people being unable to see animations.
						for _ = 1, 2 do
							if Animate then
								Animate.Disabled = not Animate.Disabled
							end
						end

						server.Remote.Send(plr, "Function", "SetView", plr.Character.Humanoid)
						server.Remote.Send(v, "Function", "SetView", plr.Character.Humanoid)
					end
				end
			end
		};

		CopyCharacter = {
			Prefix = Settings.Prefix;
			Commands = {"copychar", "copycharacter", "copyplayercharacter"};
			Args = {"player", "target"};
			Description = "Changes specific players' character to the target's character. (i.g. To copy Player1's character, do ':copychar me Player1')";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				assert(args[2], "Missing player name. What player would you want to copy?")

				local target = service.GetPlayers(plr, args[2])[1]
				local target_character = target.Character
				if target_character then
					target_character.Archivable = true
					target_character = target_character:Clone()
				end

				assert(target_character, "Target player doesn't have a character or has a locked character")

				local target_humandescrip = target and target.Character:FindFirstChildOfClass("Humanoid") and target.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("HumanoidDescription")

				assert(target_humandescrip, "Target player doesn't have a HumanoidDescription or has a locked HumanoidDescription [Cannot copy target's character]")

				target_humandescrip.Archivable = true
				target_humandescrip = target_humandescrip:Clone()

				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						if (v and v.Character and v.Character:FindFirstChildOfClass("Humanoid")) and (target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")) then
							v.Character.Archivable = true

							for _, a in v.Character:GetChildren() do
								if a:IsA("Accessory") then
									a:Destroy()
								end
							end

							local cl = target_humandescrip:Clone()
							cl.Parent = v.Character:FindFirstChildOfClass("Humanoid")
							pcall(function() v.Character:FindFirstChildOfClass("Humanoid"):ApplyDescription(cl, Enum.AssetTypeVerification.Always) end)

							for _, a in target_character:GetChildren() do
								if a:IsA("Accessory") then
									a:Clone().Parent = v.Character
								end
							end
						end
					end)
				end
			end
		};

		CustomFace = {
			Prefix = Settings.Prefix;
			Commands = {"customface"};
			Args = {"player", "id"};
			Description = "Give the target player(s) the face that belongs to <ID>. Supports images and catalog items.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local faceId = assert(tonumber(args[2]), "Invalid asset ID provided")
				local faceAssetTypeId = service.MarketPlace:GetProductInfo(tonumber(args[2])).AssetTypeId
				local asset;

				if faceAssetTypeId == 1 then
					asset = service.New("Decal", {
						Name = "face";
						Face = "Front";
						Texture = `rbxassetid://{args[2]}`;
					});
				elseif faceAssetTypeId == 13 and Functions.GetTexture(faceId) ~= 6825455804 then -- just incase GetTexture actually works?
					asset = service.New("Decal", {
						Name = "face";
						Face = "Front";
						Texture = `rbxassetid://{Functions.GetTexture(faceId)}`;
					});
				elseif faceAssetTypeId == 18 then
					asset = service.Insert(faceId)
				else
					error("Invalid face(Image/robloxFace)", 0)
				end

				for i, v in service.GetPlayers(plr, args[1]) do
					local Head = v.Character and v.Character:FindFirstChild("Head")
					local face = Head and Head:FindFirstChild("face")

					if Head then
						if face then
							face:Destroy()--.Texture = `http://www.roblox.com/asset/?id={args[2]}`
						end

						local clone = asset:Clone();
						clone.Parent = v.Character:FindFirstChild("Head")
					end
				end
			end
		};

		CustomNotify = {
			Prefix = Settings.Prefix;
			Commands = {"cn", "customsmallmessage", "cnmessage"};
			Args = {"title", "message"};
			Filter = true;
			Description = `Same as {Functions.GetMainPrefix()}n but says whatever you want the title to be instead of your name.`;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				Functions.Notify(service.BroadcastFilter(assert(args[1], "Missing title"), plr), service.BroadcastFilter(assert(args[2], "Missing message")	, plr), service.GetPlayers())
			end
		};


		ClickTeleport = {
			Prefix = Settings.Prefix;
			Commands = {"clickteleport", "teleporttoclick", "ct", "clicktp", "forceteleport", "ctp", "ctt"};
			Args = {"player"};
			Description = "Gives you a tool that lets you click where you want the target player to stand, hold r to rotate them";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local plrBackpack = assert(plr:FindFirstChildOfClass("Backpack"), "You have no backpack")
				for _, v in service.GetPlayers(plr, args[1]) do
					local scr = Deps.Assets.ClickTeleport:Clone()
					scr.Mode.Value = "Teleport"
					scr.Target.Value = v.Name
					local tool = service.New("Tool", {
						ToolTip = `ClickTP - {service.FormatPlayer(v)}`;
						CanBeDropped = false;
						RequiresHandle = false;
					})
					service.New("StringValue", tool).Name = Variables.CodeName
					scr.Parent = tool
					scr.Disabled = false
					tool.Parent = plrBackpack
				end
			end
		};

		ClickWalk = {
			Prefix = Settings.Prefix;
			Commands = {"clickwalk", "cw", "ctw", "forcewalk", "walktool", "walktoclick", "clickcontrol", "forcewalk"};
			Args = {"player"};
			Description = "Gives you a tool that lets you click where you want the target player to walk, hold r to rotate them";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local plrBackpack = assert(plr:FindFirstChildOfClass("Backpack"), "You have no backpack")
				for _, v in service.GetPlayers(plr, args[1]) do
					local scr = Deps.Assets.ClickTeleport:Clone()
					scr.Mode.Value = "Walk"
					scr.Target.Value = v.Name
					local tool = service.New("Tool", {
						ToolTip = `ClickWalk - {service.FormatPlayer(v)}`;
						CanBeDropped = false;
						RequiresHandle = false;
					})
					service.New("StringValue", tool).Name = Variables.CodeName
					scr.Parent = tool
					scr.Disabled = false
					tool.Parent = plrBackpack
				end
			end
		};

		Clean = {
			Prefix = Settings.Prefix;
			Commands = {"clean"};
			Args = {};
			Description = "Cleans some useless junk out of workspace";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				Functions.CleanWorkspace()
			end
		};

		CharacterAudio = {
			Prefix = Settings.Prefix;
			Commands = {"charaudio", "charactermusic", "charmusic"};
			Args = {"player", "audioId", "volume", "loop(true/false)", "pitch"};
			Description = "Plays an audio from the target player's character";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				assert(args[2] and tonumber(args[2]), "Missing or invalid AudioId")

				local volume = tonumber(args[3]) or 1
				local looped = args[4]
				local pitch = tonumber(args[5]) or 1

				if looped then
					if looped == "true" or looped == "1" then
						looped = true
					else
						looped = false
					end
				else
					looped = true -- should be on by default
				end

				local audio = service.New("Sound", {
					Volume = volume;
					Looped = looped;
					Pitch = pitch;
					Name = "ADONIS_AUDIO";
					SoundId = `rbxassetid://{args[2]}`;
				})

				for i, v in service.GetPlayers(plr, args[1]) do
					local char = v.Character
					local rootPart = char and char:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local new = audio:Clone()

						if looped == false then
							new.Ended:Connect(function()
								new:Destroy() -- Destroy character audio after sound is finished if loop is off.
							end)
						end

						new.Parent = rootPart
						new:Play()
					end
				end
			end;
		};

		Char = {
			Prefix = Settings.Prefix;
			Commands = {"char", "character", "appearance"};
			Args = {"player", "username"};
			Description = "Changes the target player(s)'s character appearence to <ID/Name>.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				local target = service.GetPlayers(plr, assert(args[2], "Missing username or UserId"), {
					AllowUnknownUsers = true;
					UseFakePlayer = true
				})
				if target then
					target = target[1]
					local success, desc = pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, target.UserId)

					if success then
						for _, v in service.GetPlayers(plr, args[1]) do
							v.CharacterAppearanceId = target.UserId

							if v.Character and v.Character:FindFirstChildOfClass("Humanoid") then
								v.Character.Humanoid:ApplyDescription(desc, Enum.AssetTypeVerification.Always)
							end
						end
					else
						error("Unable to get avatar for target user")
					end
				end
			end
		};

		CopyTools = {
			Prefix = Settings.Prefix;
			Commands = {"copytools"};
			Args = {"player1", "player2"};
			Description = "Copies player1's tools and gives them to player2";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local p1 = service.GetPlayers(plr, args[1])
				local p2 = service.GetPlayers(plr, args[2])
				for _, v in p1 do
					local backpack = v:FindFirstChildOfClass("Backpack")
					if not backpack then continue end
					for _, m in p2 do
						for _, n in backpack:GetChildren() do
							n:Clone().Parent = m:FindFirstChildOfClass("Backpack")
						end
					end
				end
			end
		};

		Abort = {
			Prefix = Settings.Prefix;
			Commands = {"abort", "stoploop", "unloop", "unrepeat"};
			Args = {"username", "command"};
			Description = "Aborts a looped command. Must supply name of player who started the loop or \"me\" if it was you, or \"all\" for all loops. :abort sceleratis :kill bob or :abort all";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local name = string.lower(args[1])
				if name=="me" then
					Variables.CommandLoops[string.lower(plr.Name)..args[2]] = nil
				elseif name=="all" then
					for i, v in Variables.CommandLoops do
						Variables.CommandLoops[i] = nil
					end
				elseif args[2] then
					Variables.CommandLoops[name..args[2]] = nil
				end
			end
		};

		AbortAll = {
			Prefix = Settings.Prefix;
			Commands = {"abortall", "stoploops"};
			Args = {"username (optional)"};
			Description = "Aborts all existing command loops";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local name = args[1] and string.lower(args[1])

				if name and name=="me" then
					for i, v in Variables.CommandLoops do
						if string.lower(string.sub(i, 1, plr.Name)) == string.lower(plr.Name) then
							Variables.CommandLoops[string.lower(plr.Name)..args[2]] = nil
						end
					end
				elseif name and name=="all" then
					for i, v in Variables.CommandLoops do
						Variables.CommandLoops[string.lower(plr.Name)..args[2]] = nil
					end
				elseif args[2] then
					if Variables.CommandLoops[name..args[2]] then
						Variables.CommandLoops[name..args[2]] = nil
					else
						Remote.MakeGui(plr, "Output", {Title = "Output"; Message = "No loops relating to your search"})
					end
				else
					for i, v in Variables.CommandLoops do
						Variables.CommandLoops[i] = nil
					end
				end
			end
		};

		AvatarItem = {
			Prefix = Settings.Prefix;
			Commands = {"avataritem", "giveavtaritem", "catalogitem", "accessory", "hat", "tshirt", "givetshirt", "shirt", "giveshirt", "pants", "givepants", "face", "anim",
				"torso", "larm", "leftarm", "rarm", "rightarm", "lleg", "leftleg", "rleg", "rightleg", "head", "walkanimation", "walkanim", "runanimation", "runanim", "jumpanimation",
				"jumpanim", "fallanimation", "fallanim"}; -- Legacy aliases from old commands
			Args = {"player", "ID"};
			Description = "Give the target player(s) the avatar/catalog item matching <ID> and adds it to their HumanoidDescription.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {[number]:string})
				local itemId = assert(tonumber(args[2]), "Argument 2 missing or invalid")

				local success, productInfo = pcall(service.MarketplaceService.GetProductInfo, service.MarketplaceService, itemId)
				assert(success and productInfo, "Invalid item ID")

				local AssetTypeNameDescriptionOverides = {
					DynamicHead = "Head";
					TShirt = "GraphicTShirt"
				}
				--local typeEnum = Enum.AvatarAssetType:FromValue(productInfo.AssetTypeId)
				local typeId = productInfo.AssetTypeId
				local typeEnum
				for _, enum in pairs(Enum.AvatarAssetType:GetEnumItems()) do
					if enum.Value == typeId then
						typeEnum = enum
						break
					end
				end

				for _, v: Player in service.GetPlayers(plr, args[1]) do
					local humanoid: Humanoid? = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local humanoidDesc: HumanoidDescription = humanoid:GetAppliedDescription()

						if not typeEnum then
							if v.Character:GetAttribute("LoadingSavedOutfit") then continue end

							local customHats = 0
							for _,x in v.Character:GetChildren() do
								if x.Name == "CustomAdonisAccessory" then
									customHats += 1
								end
							end

							if customHats > 7 then
								continue
							end

							service.SecureAccessory(v, itemId)
							continue
						end

						if typeEnum == Enum.AvatarAssetType.EmoteAnimation then
							humanoidDesc:AddEmote(productInfo.Name, itemId)
						else
							local accessoryType = service.AvatarEditorService:GetAccessoryType(typeEnum)
							if accessoryType and accessoryType ~= Enum.AccessoryType.Unknown then
								local accessories = humanoidDesc:GetAccessories(true)
								table.insert(accessories, {
									Order = #accessories,
									AssetId = itemId,
									AccessoryType = accessoryType
								})
								humanoidDesc:SetAccessories(accessories, true)
							elseif accessoryType == Enum.AccessoryType.Unknown then
								local typeName = typeEnum.Name
								if AssetTypeNameDescriptionOverides[typeName] then
									typeName = AssetTypeNameDescriptionOverides[typeName]
								end
								if humanoidDesc[typeName] then
									humanoidDesc[typeName] = itemId
								else
									error(`Asset type of {productInfo.Name} ({itemId}) not supported`)
								end
							end
						end

						task.defer(humanoid.ApplyDescription, humanoid, humanoidDesc, Enum.AssetTypeVerification.Always)
					end
				end
			end
		};

		DeleteServer = {
			Prefix = Settings.Prefix;
			Commands = {"delserver", "deleteserver", "removeserver", "rmserver"};
			Args = {"serverName"};
			Description = "Deletes a private server from the list.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local servers = Core.GetData("PrivateServers") or {}
				if servers[args[1]] then
					servers[args[1]] = nil
					Core.SetData("PrivateServers", servers)
					Functions.Hint(`Removed server {args[1]}`, {plr})
				else
					Functions.Hint(`Server {args[1]} was not found!`, {plr})
				end
			end
		};

		DirectTimeBan = {
			Prefix = Settings.Prefix;
			Commands = {"directtimeban", "directtimedban", "directtempban", "directtban", "directtemporaryban"};
			Args = {"username(s)", "number<s/m/h/d>", "reason"};
			Description = `Bans the target user(s) from the game for the supplied amount of time; data-persistent; undo using {Settings.Prefix}unban`;
			Filter = true;
			AdminLevel = 700;
			Hidden = true;
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
						Functions.LogAdminAction(plr, "Direct Time Ban", actualName or i, `Duration: {args[2]}, Reason: {reason}`)
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

		DisplayName = {
			Prefix = Settings.Prefix;
			Commands = {"displayname", "dname"};
			Args = {"player", "name/hide"};
			Filter = true;
			Description = "Name the target player(s) <name> or say hide to hide their character name";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local char = v.Character;
					local human = char and char:FindFirstChildOfClass("Humanoid");
					if human then
						if string.lower(args[2]) == "hide" then
							human.DisplayName = ""
							Functions.Notification("Notification", "Your character name has been hidden", {v}, 10)
						else
							human.DisplayName = args[2]
							Functions.Notification("Notification", `Your character name is now "{args[2]}"`, {v}, 10)
						end
					end
				end
			end
		};

		ErrorLogs = {
			Prefix = Settings.Prefix;
			Commands = {"errorlogs", "debuglogs", "errorlog", "errors", "debuglog", "scripterrors", "adminerrors"};
			Args = {"autoupdate? (default: true)"};
			Description = "View script error log";
			AdminLevel = 300;
			ListUpdater = function(plr: Player)
				local Count = if Logs.Errors.__meta == "DLL" then Logs.Errors.count else #Logs.Errors
				local tab = table.create(Count)
				for i, v in
					if Logs.Errors.__meta == "DLL" then
						Logs.Errors:GetAsTable()
					else
						Logs.Errors
				do
					table.insert(tab, i, {
						Time = v.Time;
						Text = `{v.Text}: {v.Desc}`;
						Desc = tostring(v.Desc);
					})
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Errors";
					Table = Logs.ListUpdaters.ErrorLogs(plr);
					Dots = true;
					Update = "ErrorLogs";
					AutoUpdate = if not args[1] or (args[1]:lower() == "true" or args[1]:lower() == "yes") then 1 else nil;
					Sanitize = true;
					Stacking = true;
					TextSelectable = true;
				})
			end
		};

		Explore = {
			Prefix = Settings.Prefix;
			Commands = {"explore", "explorer"};
			Args = {};
			Description = `Lets you explore the game, kinda like a file browser (alternative to {Settings.Prefix}dex)`;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "Explorer")
			end
		};

		Insert = {
			Prefix = Settings.Prefix;
			Commands = {"insert", "ins"};
			Args = {"id"};
			Description = "Inserts whatever object belongs to the ID you supply, the object must be in the place owner's or Roblox's inventory";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local id = string.lower(args[1])

				for i, v in Variables.InsertList do
					if id == string.lower(v.Name)then
						id = v.ID
						break
					end
				end

				for i, v in HTTP.Trello.InsertList do
					if id == string.lower(v.Name) then
						id = v.ID
						break
					end
				end

				local obj = service.Insert(tonumber(id), true)
				if obj and plr.Character then
					table.insert(Variables.InsertedObjects, obj)
					obj.Parent = workspace
					pcall(obj.MakeJoints, obj)
					obj:PivotTo(plr.Character:GetPivot())
				end
			end
		};

		Fling = {
			Prefix = Settings.Prefix;
			Commands = {"fling"};
			Args = {"player"};
			Fun = true;
			Description = "Fling the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						if v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") then
							local xran local zran
							repeat xran = math.random(-9999, 9999) until math.abs(xran) >= 5555
							repeat zran = math.random(-9999, 9999) until math.abs(zran) >= 5555
							v.Character.Humanoid.Sit = true
							v.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
							local Attachment = service.New("Attachment", v.Character.HumanoidRootPart)
							local frc = service.New("VectorForce", v.Character.HumanoidRootPart)
							frc.Name = "BFRC"
							frc.Attachment0 = Attachment
							frc.Force = Vector3.new(xran*4, 9999*5, zran*4)
							service.Debris:AddItem(frc,.1)
							service.Debris:AddItem(Attachment,.1)
						end
					end)
				end
			end
			};

		ForceRejoin = {
			Prefix = Settings.Prefix;
			Commands = {"forcerejoin"};
			Args = {"player"};
			Description = `Forces target player(s) to rejoin the server; same as them running {Settings.PlayerPrefix}rejoin`;
			NoStudio = true;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local players = service.GetPlayers(plr, args[1])
				local teleportOptions = service.New("TeleportOptions", {
					ServerInstanceId = game.JobId
				})
				service.TeleportService:TeleportAsync(game.PlaceId, players, teleportOptions)
			end
		};

		FullClear = {
			Prefix = Settings.Prefix;
			Commands = {"fullclear", "clearinstances", "fullclr"};
			Args = {};
			Description = "Removes any instance created server-side by Adonis; May break things";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local objects = service.GetAdonisObjects()
				for i, v in objects do
					v:Destroy()
				end
				table.clear(objects)

				--for i, v in Functions.GetPlayers() do
				--	Remote.Send(v, "Function", "ClearAllInstances")
				--end
			end
		};

		FullShutdown = {
			Prefix = Settings.Prefix;
			Commands = {"fullshutdown", "globalshutdown"};
			Args = {"reason"};
			Description = "Initiates a shutdown for every running game server";
			AdminLevel = 300;
			Filter = true;
			IsCrossServer = true;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Reason (argument #1) must be supplied for this command!")

				if
					Remote.GetGui(plr, "YesNoPrompt", {
						Question = `Shutdown all running servers for the reason '{args[1]}'?`;
						Title = "Global Shutdown";
					}) == "Yes"
				then
					assert(
						Core.CrossServer(
							"NewRunCommand",
							{
								Name = plr.Name,
								UserId = plr.UserId,
								AdminLevel = Admin.GetLevel(plr)
							},
							`{Settings.Prefix}shutdown {args[1]}\n\n\n[GLOBAL SHUTDOWN]`
						),
						"An error has occured"
					)
				end
			end;
		};

		Give = {
			Prefix = Settings.Prefix;
			Commands = {"give", "tool"};
			Args = {"player", "tool"};
			Description = "Gives the target player(s) the desired tool(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local found = {}
				local temp = service.New("Folder")
				for _, tool in if Settings.RecursiveTools then Settings.Storage:GetDescendants() else Settings.Storage:GetChildren() do
					if tool:IsA("BackpackItem") then
						if string.lower(args[2]) == "all" or string.sub(string.lower(tool.Name), 1, #args[2])==string.lower(args[2]) then
							tool.Archivable = true
							local parent = tool.Parent
							if not parent.Archivable then
								tool.Parent = temp
							end
							table.insert(found, tool:Clone())
							tool.Parent = parent
						end
					end
				end
				if #found > 0 then
					for _, v in service.GetPlayers(plr, args[1]) do
						for k, t in found do
							t:Clone().Parent = v.Backpack
						end
					end
				else
					error("Couldn't find anything to give")
				end
				if temp then
					temp:Destroy()
				end
			end
		};

		GivePackage = {
			Prefix = Settings.Prefix;
			Commands = {"package", "givepackage", "setpackage", "bundle"};
			Args = {"player", "id"};
			Description = "Gives the target player(s) the desired package (ID MUST BE A NUMBER)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local id = assert(assert(args[1], "Missing player name") and tonumber(args[2]), "Missing or invalid package ID")
				local suc,ers = pcall(function() return service.AssetService:GetBundleDetailsAsync(id) end)

				if suc then
					for _, item in ers.Items do
						if item.Type == "Asset" then
							Commands.AvatarItem.Function(plr, {args[1], item.Id})
							break
						end
					end
				else
					Remote.MakeGui(plr, "Output", {Title = "Output"; Message = `Package {id} doesn't exist.`})
					return
				end
			end
		};

		GlobalMessage = {
			Prefix = Settings.Prefix;
			Commands = {"globalmessage", "gm", "globalannounce"};
			Args = {"message"};
			Description = "Sends a global message to all servers";
			AdminLevel = 300;
			Filter = true;
			IsCrossServer = true;
			CrossServerDenied = true;
			Function = function(plr: Player, args: {string})
				if not Core.CrossServer("Message", plr.Name, assert(args[1], "Missing message")) then
					error("CrossServer handler not ready; please try again later")
				end
			end;
		};

		GlobalTimeMessage = {
			Prefix = Settings.Prefix;
			Commands = {"gtm", "globaltimedmessage", "globaltimemessage", "globaltimem"};
			Args = {"time", "message"};
			Description = "Sends a global message to all servers and makes it stay on the screen for the amount of time (in seconds) you supply";
			AdminLevel = 300;
			Filter = true;
			IsCrossServer = true;
			CrossServerDenied = true;
			Function = function(plr: Player, args: {string})
				if not Core.CrossServer("Message", plr.Name, assert(args[2], "Missing message"), assert(args[1], "Missing time amount")) then
					error("CrossServer handler not ready; please try again later")
				end
			end;
		};

		GRPlaza = {
			Prefix = Settings.Prefix;
			Commands = {"plazaconnect", "grplaza", "grouprecruitingplaza", "groupplaza"};
			Args = {"player"};
			Description = "Teleports the target player(s) to Plaza Connect to look for potential group members";
			NoStudio = true;
			Hidden = true;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				Functions.Notification("Teleport", "Click to teleport to Plaza Connect", service.GetPlayers(plr, args[1]), 30, "MatIcon://QR code scanner", Core.Bytecode("service.TeleportService:Teleport(5118029260)"))
			end
		};

		Incognito = {
			Prefix = Settings.Prefix;
			Commands = {"incognito"};
			Args = {"player", "hideFromNonAdmins(default true)", "hideCharacter(default true)"};
			Description = "Removes the target player from other clients' perspectives (persists until rejoin). Allows to set whether to hide only from nonadmins or from everyone.";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				local hidefromEveryone = false
				local hideCharacter = true
				if args[2] then
					if string.lower(args[2])=="false" or string.lower(args[2])=="no" then
						hidefromEveryone = true
					end
				end
				if args[3] then
					if string.lower(args[3])=="false" or string.lower(args[3])=="no" then
						hideCharacter = false
					end
				end

				for _, v: Player in service.GetPlayers(plr, args[1]) do
					if Variables.IncognitoPlayers[v] then
						Functions.Hint(`{service.FormatPlayer(v)} is already incognito.`, {plr})
						continue
					end
					Variables.IncognitoPlayers[v] = {
						time=os.time(),
						hide_from_everyone=hidefromEveryone,
						hide_character=hideCharacter
					}
					if hideCharacter then
						v.CharacterAdded:Connect(function(character: Model)
							for _, otherPlr: Player in service.Players:GetPlayers(v, if hidefromEveryone then "others" else "nonadmins") do
								if otherPlr == v then continue end
								Remote.LoadCode(otherPlr, [[
									local plrName = service.Players:GetNameFromUserIdAsync(]] .. v.UserId .. [[)
									local character = service.Workspace:FindFirstChild(plrName)
									if character:FindFirstChildWhichIsA("Humanoid") == nil then
										for _, v in service.Workspace:GetChildren() do
											if v.Name == plrName and v:IsA("Model") and v:FindFirstChildWhichIsA("Humanoid") ~= nil then
												character = v
												break
											end
										end
									end
									character:Destroy()
								]])
							end
						end)
					end

					local n = 0
					for _, otherPlr: Player in service.Players:GetPlayers(v, if hidefromEveryone then "others" else "nonadmins") do
						if otherPlr == v then continue end
						if hideCharacter then
							Remote.LoadCode(otherPlr, [[
							local plr = service.Players:GetPlayerByUserId(]] .. v.UserId .. [[)
								if plr then
									if not table.find(service.IncognitoPlayers, plr) then
										table.insert(service.IncognitoPlayers, plr)
									end
									if plr.Character then
										plr.Character:Destroy()
									end
									plr:Destroy()
								end
							]])
						else
							Remote.LoadCode(otherPlr, [[
								local plr = service.Players:GetPlayerByUserId(]] .. v.UserId .. [[)
								if plr then
									if not table.find(service.IncognitoPlayers, plr) then
										table.insert(service.IncognitoPlayers, plr)
									end
									plr:Destroy()
								end
							]])
						n += 1
						end
					end

					if n == 0 then
						Functions.Hint(string.format("Placed %s on the incognito list.", service.FormatPlayer(v)), {plr})
					else
						Functions.Hint(string.format("Hidden %s from %d other player%s.", service.FormatPlayer(v), n, n == 1 and "" or "s"), {plr})
					end

					Functions.Notification("Incognito Mode", "You will cease to appear on the player list, on other players' screens.", {v}, 15, "MatIcon://Privacy tip")
				end
			end
		};

		IncognitoPlayerList = {
			Prefix = Settings.Prefix;
			Commands = {"incognitolist", "incognitoplayers"};
			Args = {"autoupdate? (default: true)"};
			Description = "Displays a list of incognito players in the server";
			AdminLevel = 300;
			ListUpdater = function(plr: Player)
				local tab = {}
				for p: Player, t: table in Variables.IncognitoPlayers do
					if p.Parent == service.Players and not t.hide_from_everyone then
						table.insert(tab, {
							Text = service.FormatPlayer(p);
							Desc = string.format("ID: %d | Went incognito at: %s", p.UserId, service.FormatTime(t.time));
						})
					end
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				local autoUpdate = string.lower(args[1] or "false")
				Remote.RemoveGui(plr, "IncognitoPlayerList")
				Remote.MakeGui(plr, "List", {
					Name = "IncognitoPlayerList";
					Title = "Incognito Players";
					Icon = server.MatIcons["Admin panel settings"];
					Tab = Logs.ListUpdaters.IncognitoPlayerList(plr);
					Update = "IncognitoPlayerList";
					AutoUpdate = if not args[1] or (autoUpdate == "true" or autoUpdate == "yes") then 1 else nil;
				})
			end
		};

		InsertClear = {
			Prefix = Settings.Prefix;
			Commands = {"insclear", "clearinserted", "clrins", "insclr"};
			Args = {};
			Description = "Removes inserted objects";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for i, v in Variables.InsertedObjects do
					v:Destroy()
					table.remove(Variables.InsertedObjects, i)
				end
			end
		};

		InsertList = {
			Prefix = Settings.Prefix;
			Commands = {"insertlist", "inserts", "inslist", "modellist", "models"};
			Args = {};
			Description = "Shows you the script's available insert list";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local tab = table.create(#Variables.InsertList + #HTTP.Trello.InsertList)
				for _, v in Variables.InsertList do table.insert(tab, v) end
				for _, v in HTTP.Trello.InsertList do table.insert(tab, v) end
				for i, v in tab do
					tab[i] = {Text = `{v.Name} - {v.ID}`; Desc = v.ID;}
				end
				Remote.MakeGui(plr, "List", {Title = "Insert List", Table = tab; TextSelectable = true})
			end
		};

		ListServers = {
			Prefix = Settings.Prefix;
			Commands = {"privateservers", "createdservers"};
			Args = {};
			Description = "Shows you a list of private servers that were created with :makeserver";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local servers = Core.GetData("PrivateServers") or {}
				local tab = table.create(#servers)
				for i, v in servers do
					table.insert(tab, {Text = i, Desc = `Place: {v.ID} | Code: {v.Code}`})
				end
				Remote.MakeGui(plr, "List", {Title = "Servers"; Table = tab;})
			end
		};

		LoopHeal = {
			Prefix = Settings.Prefix;
			Commands = {"loopheal"};
			Args = {"player"};
			Description = "Continuously heals the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					task.defer(function()
						service.StartLoop(`{v.UserId}LOOPHEAL`, 0.1, function()
							if not v or v.Parent ~= service.Players then
								service.StopLoop(`{v.UserId}LOOPHEAL`)
							end

							local Character = v.Character
							if Character then
								local Humanoid = Character:FindFirstChildOfClass("Humanoid")
								if Humanoid then
									Humanoid.Health = Humanoid.MaxHealth
								end
							end
						end)
					end)
				end
			end
		};

		MakeServer = {
			Prefix = Settings.Prefix;
			Commands = {"makeserver", "reserveserver", "privateserver"};
			Args = {"serverName", "(optional) placeId"};
			Filter = true;
			NoStudio = true; -- TeleportService does not work in Studio
			Description = "Makes a private server that you can teleport yourself and friends to using :place player(s) serverName; Will overwrite servers with the same name; Caps specific";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local place = tonumber(args[2]) or game.PlaceId
				local code, serverId = service.TeleportService:ReserveServer(place)
				local servers = Core.GetData("PrivateServers") or {}
				servers[args[1]] = {Code = code, ID = place, PrivateServerID = serverId}
				Core.SetData("PrivateServers", servers)
				Functions.Hint(`Made server {args[1]} | Place: {place}`, {plr})
			end
		};

		Name = {
			Prefix = Settings.Prefix;
			Commands = {"name", "rename"};
			Args = {"player", "name/hide"};
			Filter = true;
			Description = "Name the target player(s) <name> or say hide to hide their character name";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local name = args[2] == "hide" and " " or args[2]

				for _, v in service.GetPlayers(plr, args[1]) do
					local humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")

					if humanoid then
						humanoid.DisplayName = name
					end
				end
			end
		};

		NewStat = {
			Prefix = Settings.Prefix;
			Commands = {"newstat", "createstat", "cstat"};
			Args = {"statname", "type (string/number [default: number])"};
			Description = "Creates a new stat on the leaderboard";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				local statName = args[1]
				if not statName then
					error("Not statname provided!")
				end
				local statType = if args[2] then args[2]:lower() else "number"
				local FilteredStatName = service.BroadcastFilter(statName, plr)

				if FilteredStatName ~= statName then
					error("Stat name is filtered! Sorry!")
				end

				for _,p in service.GetPlayers() do
					local leaderstats = p:FindFirstChild("leaderstats") or service.New("Folder")
					leaderstats.Name = "leaderstats"
					if statName then
						if not leaderstats:FindFirstChild(FilteredStatName) then
							local newStat = service.New(if statType == "number" then "NumberValue" else "StringValue")
							newStat.Name = FilteredStatName
							if statType ~= "number" then
								newStat.Value = "N/A"
							end
							newStat.Parent = leaderstats
						end
					end
					leaderstats.Parent = p
				end
			end
		};

		Phase = {
			Prefix = Settings.Prefix;
			Commands = {"phase"};
			Args = {"player"};
			Description = "Makes the player(s) character completely local";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.MakeLocal(v, v.Character)
				end
			end
		};

		Place = {
			Prefix = Settings.Prefix;
			Commands = {"place"};
			Args = {"player", "placeID/serverName"};
			NoStudio = true;
			Description = "Teleport the target player(s) to the place belonging to <placeID> or a reserved server";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local reservedServerInfo = (Core.GetData("PrivateServers") or {})[args[2]]
				local placeId = assert(if reservedServerInfo then reservedServerInfo.ID else tonumber(args[2]), "Invalid place ID or server name (argument #2)")
				local teleportOptions = if reservedServerInfo then service.New("TeleportOptions", {
					ReservedServerAccessCode = reservedServerInfo.Code
				}) else nil
				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						if
							Remote.MakeGuiGet(v, "Notification", {
								Title = "Teleport";
								Icon = server.MatIcons["QR code scanner"];
								Text = if reservedServerInfo then string.format("Click to teleport to server %s.", args[2]) else string.format("Click to teleport to place %d.", placeId);
								Time = 30;
								OnClick = Core.Bytecode("return true");
							})
						then
							service.TeleportService:TeleportAsync(placeId, {v}, teleportOptions)
						else
							Functions.Hint(`{service.FormatPlayer(v)} declined to teleport`, {plr})
						end
					end)
				end
			end
		};

		PromptInvite = {
			Prefix = Settings.Prefix;
			Commands = {"promptinvite", "inviteprompt", "forceinvite"};
			Args = {"player"};
			Description = "Opens the friend invitation popup for the target player(s), same as them running !invite";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					service.SocialService:PromptGameInvite(v)
				end
			end
		};

		R15 = {
			Prefix = Settings.Prefix;
			Commands = {"r15", "rthro"};
			Args = {"player"};
			Description = "Converts players' character to R15";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Functions.ConvertPlayerCharacterToRig(v, "R15")
				end
			end
		};

		R6 = {
			Prefix = Settings.Prefix;
			Commands = {"r6", "classicrig"};
			Args = {"player"};
			Description = "Converts players' character to R6";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					task.defer(Functions.ConvertPlayerCharacterToRig, v, "R6")
				end
			end
		};

		RemoveLeaderstat = {
			Prefix = Settings.Prefix;
			Commands = {"removestats", "delstat"};
			Args = {"name"};
			Description = "Removes a leaderstat entirely";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				local statName = assert(args[1], "Missing the stat name!")

				for _, v in service.GetPlayers() do
					local leaderstats = v:FindFirstChild("leaderstats")
					if leaderstats then
						leaderstats.Name = "leaderstats"
						local absoluteMatch = leaderstats:FindFirstChild(statName)
						if absoluteMatch and (absoluteMatch:IsA("IntValue") or absoluteMatch:IsA("NumberValue")) then
							absoluteMatch:Destroy()
						else
							for _, st in leaderstats:GetChildren() do
								if (st:IsA("IntValue") or st:IsA("NumberValue")) and string.match(st.Name:lower(), `^{service.SanitizePattern(statName:lower())}`) then
									st:Destroy()
								end
							end
						end
						if #leaderstats:GetChildren() == 0 then
							leaderstats:Destroy()
						end
					else
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a leaderstats folder`, {plr})
					end
				end
			end
		};

		RemoveLeaderstat = {
			Prefix = Settings.Prefix;
			Commands = {"removestats", "delstat"};
			Args = {"name"};
			Description = "Removes a leaderstat entirely";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				local statName = assert(args[1], "Missing the stat name!")

				for _, v in service.GetPlayers() do
					local leaderstats = v:FindFirstChild("leaderstats")
					if leaderstats then
						leaderstats.Name = "leaderstats"
						local absoluteMatch = leaderstats:FindFirstChild(statName)
						if absoluteMatch and (absoluteMatch:IsA("IntValue") or absoluteMatch:IsA("NumberValue")) then
							absoluteMatch:Destroy()
						else
							for _, st in leaderstats:GetChildren() do
								if (st:IsA("IntValue") or st:IsA("NumberValue")) and string.match(st.Name:lower(), `^{service.SanitizePattern(statName:lower())}`) then
									st:Destroy()
								end
							end
						end
						if #leaderstats:GetChildren() == 0 then
							leaderstats:Destroy()
						end
					else
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a leaderstats folder`, {plr})
					end
				end
			end
		};

		ResetStats = {
			Prefix = Settings.Prefix;
			Commands = {"resetstats", "rs"};
			Args = {"player"};
			Description = "Sets target player(s)'s leader stats to 0 (N/A if it's a string)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, string.lower(args[1])) do
					task.spawn(pcall, function()
						if v and v:FindFirstChild("leaderstats") then
							for a, q in v.leaderstats:GetChildren() do
								if q:IsA("IntValue") or q:IsA("NumberValue") then q.Value = 0 elseif q:IsA("StringValue") then q.Value = "N/A" end
							end
						end
					end)
				end
			end
		};

		Sell = {
			Prefix = Settings.Prefix;
			Commands = {"sell", "promptpurchase"};
			Args = {"player", "id"};
			Description = "Prompts the player(s) to buy the product belonging to the ID you supply";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					service.MarketPlace:PromptPurchase(v, tonumber(args[2]), false)
				end
			end
		};

		ServerPerfStats = {
			Prefix = Settings.Prefix;
			Commands = {"perfstats", "performancestats", "serverstats"};
			Args = {"autoupdate? (default: true)"};
			Description = "Shows you technical server performance statistics";
			AdminLevel = 300;
			ListUpdater = function(plr: Player)
				local perfStats = {
					{"ContactsCount"; "How many parts are currently in contact with one another"},
					{"DataReceiveKbps"; "Roughly how many kB/s of data are being received by the server"},
					{"DataSendKbps"; "Roughly how many kB/s of data are being sent by the server"},
					{"HeartbeatTimeMs"; "The total amount of time in ms it takes long it takes to update all Task Scheduler jobs"},
					{"InstanceCount"; "How many Instances are currently in memory"},
					{"MovingPrimitivesCount"; "How many physically simulated components are currently moving in the game world"},
					{"PhysicsReceiveKbps"; "Roughly how many kB/s of physics data are being received by the server"},
					{"PhysicsSendKbps"; "Roughly how many kB/s of physics data are being sent by the server"},
					{"PhysicsStepTimeMs"; "How long it takes for the physics engine to update its current state, in milliseconds"},
					{"PrimitivesCount"; "How many physically simulated components currently exist in the game world"},
				};
				local tab = table.create(#perfStats)
				for _, v in perfStats do
					table.insert(tab, {Text = `{v[1]}: {tostring(service.Stats[v[1]]):sub(1, 7)}`; Desc = v[2];})
				end
				return tab
			end;
			Function = function(plr: Player, args: {[number]:string})
				Remote.RemoveGui(plr, "ServerPerfStats")
				Remote.MakeGui(plr, "List", {
					Name = "ServerPerfStats";
					Title = "Server Stats";
					Icon = server.MatIcons.Leaderboard;
					Tab = Logs.ListUpdaters.ServerPerfStats(plr);
					AutoUpdate = if not args[1] or args[1]:lower() == "true" or args[1]:lower() == "yes" then 1 else nil;
					Update = "ServerPerfStats";
				})
			end
		};

		SetBanMessage = {
			Prefix = Settings.Prefix;
			Commands = {"setbanmessage", "setbmsg"};
			Args = {"message"};
			Filter = true;
			Description = "Sets the ban message banned players see";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				Variables.BanMessage = assert(args[1], "Missing message (argument #1)")
			end
		};

		ShowClientInstances = {
			Prefix = Settings.Prefix;
			Commands = {"clientinstances"};
			Args = {"player"};
			Description = "Shows all instances created client-side by Adonis";
			AdminLevel = 300;
			ListUpdater = function(plr: Player, target: Player)
				if target then
					local temp = {"Player is currently unreachable"}
					if target then
						temp = Remote.Get(target, "InstanceList") or temp
					end
					return temp
				else
					local objects = service.GetAdonisObjects()
					local temp = table.create(#objects)
					for _, v in objects do
						table.insert(temp, {
							Text = v:GetFullName();
							Desc = v.ClassName;
						})
					end
					return temp
				end
			end;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.MakeGui(plr, "List", {
						Title = `{service.FormatPlayer(v)}'s Client Instances`;
						Table = Logs.ListUpdaters.ShowClientInstances(plr, v);
						Stacking = false;
						Update = "ShowClientInstances";
						UpdateArg = v;
					})
				end
			end
		};

		ShowServerInstances = {
			Prefix = Settings.Prefix;
			Commands = {"serverinstances"};
			Args = {};
			Description = "Shows all instances created server-side by Adonis";
			AdminLevel = 300;
			ListUpdater = function(plr: Player, updateArgs)
				local objects = service.GetAdonisObjects()
				local tab = table.create(#objects)
				for _, v in objects do
					table.insert(tab, {
						Text = v:GetFullName();
						Desc = `Class: {v.ClassName}`;
					})
				end
				return tab
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "List", {
					Title = "Adonis Instances";
					Table = Logs.ListUpdaters.ShowServerInstances(plr);
					Stacking = false;
					Update = "ShowServerInstances";
				})
			end
		};

		StarterGive = {
			Prefix = Settings.Prefix;
			Commands = {"startergive"};
			Args = {"player", "toolname"};
			Description = "Places the desired tool into the target player(s)'s StarterPack";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local found = {}
				local temp = service.New("Folder")
				for _, tool in if Settings.RecursiveTools then Settings.Storage:GetDescendants() else Settings.Storage:GetChildren() do
					if tool:IsA("BackpackItem") then
						if string.lower(args[2]) == "all" or string.sub(string.lower(tool.Name),1, #args[2])==string.lower(args[2]) then
							tool.Archivable = true
							local parent = tool.Parent
							if not parent.Archivable then
								tool.Parent = temp
							end
							table.insert(found, tool:Clone())
							tool.Parent = parent
						end
					end
				end
				if #found > 0 then
					for _, v in service.GetPlayers(plr, args[1]) do
						for k, t in found do
							t:Clone().Parent = v.StarterGear
						end
					end
				else
					error("Couldn't find anything to give")
				end
				if temp then
					temp:Destroy()
				end
			end
		};

		Steal = {
			Prefix = Settings.Prefix;
			Commands = {"steal", "stealtools"};
			Args = {"player1", "player2"};
			Description = "Steals player1's tools and gives them to player2";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local victims = service.GetPlayers(plr, args[1])
				local stealers = service.GetPlayers(plr, args[2])
				for _, victim in victims do
					local backpack = victim:FindFirstChildOfClass("Backpack")
					if not backpack then continue end
					task.defer(function()
						local hum = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
						if hum then hum:UnequipTools() end
						for _, p in stealers do
							local destination = p:FindFirstChildOfClass("Backpack")
							if not destination then continue end
							for _, tool in backpack:GetChildren() do
								if #stealers > 1 then
									tool:Clone().Parent = destination
								else
									tool.Parent = destination
								end
							end
						end
						backpack:ClearAllChildren()
					end)
				end
			end
		};

		SubtractFromStat = {
			Prefix = Settings.Prefix;
			Commands = {"subtract", "minusfromstat", "minusstat", "subtractstat"};
			Args = {"player", "stat", "value"};
			Description = "Subtract <value> from <stat>";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				local statName = assert(args[2], "Missing stat name (argument #2)")
				local valueToSubtract = assert(tonumber(args[3]), "Missing/invalid numerical value to subtract (argument #3)")
				for _, v in service.GetPlayers(plr, args[1]) do
					local leaderstats = v:FindFirstChild("leaderstats")
					if leaderstats then
						local absoluteMatch = leaderstats:FindFirstChild(statName)
						if absoluteMatch and (absoluteMatch:IsA("IntValue") or absoluteMatch:IsA("NumberValue")) then
							absoluteMatch.Value -= valueToSubtract
						else
							for _, st in leaderstats:GetChildren() do
								if (st:IsA("IntValue") or st:IsA("NumberValue")) and string.match(st.Name:lower(), `^{service.SanitizePattern(statName:lower())}`) then
									st.Value -= valueToSubtract
								end
							end
						end
					else
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a leaderstats folder`, {plr})
					end
				end
			end
		};

		SubtractFromStat = {
			Prefix = Settings.Prefix;
			Commands = {"subtract", "minusfromstat", "minusstat", "subtractstat"};
			Args = {"player", "stat", "value"};
			Description = "Subtract <value> from <stat>";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				local statName = assert(args[2], "Missing stat name (argument #2)")
				local valueToSubtract = assert(tonumber(args[3]), "Missing/invalid numerical value to subtract (argument #3)")
				for _, v in service.GetPlayers(plr, args[1]) do
					local leaderstats = v:FindFirstChild("leaderstats")
					if leaderstats then
						local absoluteMatch = leaderstats:FindFirstChild(statName)
						if absoluteMatch and (absoluteMatch:IsA("IntValue") or absoluteMatch:IsA("NumberValue")) then
							absoluteMatch.Value -= valueToSubtract
						else
							for _, st in leaderstats:GetChildren() do
								if (st:IsA("IntValue") or st:IsA("NumberValue")) and string.match(st.Name:lower(), `^{service.SanitizePattern(statName:lower())}`) then
									st.Value -= valueToSubtract
								end
							end
						end
					else
						Functions.Hint(`{service.FormatPlayer(v)} doesn't have a leaderstats folder`, {plr})
					end
				end
			end
		};

		SuperFling = {
			Prefix = Settings.Prefix;
			Commands = {"sfling", "tothemoon", "superfling"};
			Args = {"player", "optional strength"};
			Description = "Super fling the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local strength = tonumber(args[2]) or 5e6
				local scr = Deps.Assets.Sfling:Clone()
				scr.Strength.Value = strength
				scr.Name = "SUPER_FLING"
				for _, v in service.GetPlayers(plr, args[1]) do
					local new = scr:Clone()
					new.Parent = v.Character.HumanoidRootPart
					new.Disabled = false
				end
			end
		};

		TempAdmin = {
			Prefix = Settings.Prefix;
			Commands = {"tempadmin", "tadmin"};
			Args = {"player"};
			Description = "Makes the target player(s) a temporary admin; does not save";
			AdminLevel = 700;
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: any)
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target player (argument #1)"), {UseFakePlayer = true}) do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, "Admins", true)
						Functions.LogAdminAction(plr, "Temporary Admin", v.Name, "Temporary admin granted.")
						Functions.Notification("Notification", "You are a temp administrator. Click to view commands.", {v}, 10, "MatIcon://Admin panel settings", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now a temporary admin`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		TimeBanList = {
			Prefix = Settings.Prefix;
			Commands = {"timebanlist", "timebanned", "timebans"};
			Args = {};
			Description = "Shows you the list of time banned users";
			AdminLevel = 700;
			Hidden = true;
			Function = function(plr: Player, args: {string})
				local variables = Core.Variables
				local timeBans = variables.TimeBans or {}
				local tab = table.create(#timeBans)

				for ind, v in timeBans do
					local timeLeft = v.EndTime - os.time()
					local minutes = Functions.RoundToPlace(timeLeft / 60, 2)

					if timeLeft <= 0 then
						table.remove(variables.TimeBans, ind)
					else
						table.insert(tab, {
							Text = `{v.Name}:{v.UserId}`,
							Desc = string.format("Issued by: %s | Reason: %s | Minutes left: %d", v.Moderator or "%UNKNOWN%", v.Reason, minutes)
						})
					end
				end

				Remote.MakeGui(plr, "List", {Title = "Time Bans", Tab = tab})
			end
		};

		ToolList = {
			Prefix = Settings.Prefix;
			Commands = {"tools", "toollist", "toolcenter", "savedtools", "addedtools", "toolpanel", "toolspanel"};
			Args = {};
			Description = `Shows you a list of tools that can be obtained via the {Settings.Prefix}give command, and other useful utilities`;
			AdminLevel = 300;
			ListUpdater = function(plr: Player)
				local data = {
					Tools = {};
					SavedTools = {};
					Prefix = Functions.GetMainPrefix();
					SplitKey = Settings.SplitKey;
					SpecialPrefix = Settings.SpecialPrefix;
				}
				for _, tool in if Settings.RecursiveTools then Settings.Storage:GetDescendants() else Settings.Storage:GetChildren() do
					if tool:IsA("BackpackItem") and not Variables.SavedTools[tool] then
						table.insert(data.Tools, tool.Name)
					end
				end
				for tool, pName in Variables.SavedTools do
					table.insert(data.SavedTools, {ToolName = tool.Name, AddedBy = pName})
				end
				return data
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "ToolPanel", Logs.ListUpdaters.ToolList(plr))
			end
		};

		ToolList = {
			Prefix = Settings.Prefix;
			Commands = {"tools", "toollist", "toolcenter", "savedtools", "addedtools", "toolpanel", "toolspanel"};
			Args = {};
			Description = `Shows you a list of tools that can be obtained via the {Settings.Prefix}give command, and other useful utilities`;
			AdminLevel = 300;
			ListUpdater = function(plr: Player)
				local data = {
					Tools = {};
					SavedTools = {};
					Prefix = Functions.GetMainPrefix();
					SplitKey = Settings.SplitKey;
					SpecialPrefix = Settings.SpecialPrefix;
				}
				for _, tool in if Settings.RecursiveTools then Settings.Storage:GetDescendants() else Settings.Storage:GetChildren() do
					if tool:IsA("BackpackItem") and not Variables.SavedTools[tool] then
						table.insert(data.Tools, tool.Name)
					end
				end
				for tool, pName in Variables.SavedTools do
					table.insert(data.SavedTools, {ToolName = tool.Name, AddedBy = pName})
				end
				return data
			end;
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "ToolPanel", Logs.ListUpdaters.ToolList(plr))
			end
		};

		Training = {
			Prefix = Settings.Prefix;
			Commands = {"training", "trainmod"};
			Args = {"player", "duration<s/m/h>"};
			Description = "Gives temporary moderator permissions to a player for training purposes with full command logging and monitoring";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player (argument #1)")
				assert(args[2], "Missing duration (argument #2)")
				
				-- Parse duration
				local duration, valid = assert(args[2], "Missing duration (argument #2)"):gsub("^(%d+)([smh])$", function(val, unit)
					return if unit == "s" then val
						elseif unit == "m" then val * 60
						else val * 60 * 60
				end)
				assert(valid > 0, "Invalid duration value (argument #2) - use format like 30s, 15m, or 2h")
				
				-- Initialize training sessions table if it doesn't exist
				if not Variables.TrainingSessions then
					Variables.TrainingSessions = {}
				end
				
				-- Custom webhook for this training session (optional)
				local customWebhook = Variables.TrainingWebhook or Variables.DiscordWebhook
				
				for _, v in service.GetPlayers(plr, args[1]) do
					local currentLevel = Admin.GetLevel(v)
					if currentLevel >= 100 then
						Functions.Hint(`{service.FormatPlayer(v)} is already a moderator or higher`, {plr})
						continue
					end
					
					-- Check if player is already in training
					if Variables.TrainingSessions[v.UserId] then
						Functions.Hint(`{service.FormatPlayer(v)} is already in a training session`, {plr})
						continue
					end
					
					-- Grant temporary moderator permissions
					Admin.AddAdmin(v, "Moderators", true)
					
					-- Create training session data
					local sessionData = {
						Trainee = v,
						Supervisor = plr,
						StartTime = os.time(),
						Duration = tonumber(duration),
						EndTime = os.time() + tonumber(duration),
						Webhook = customWebhook,
						CommandLog = {},
						SessionId = service.HttpService:GenerateGUID(false),
						TimeoutTask = nil -- Will be set after task.delay is created
					}
					
					Variables.TrainingSessions[v.UserId] = sessionData
					
					-- Log the training start
					Functions.LogAdminAction(plr, "Start Training", v.Name, `Duration: {args[2]}, Session ID: {sessionData.SessionId}`)
					
					-- Send webhook notification about training start
					if customWebhook and customWebhook ~= "" then
						task.spawn(function()
							local payload = {
								username = "Adonis Training System",
								embeds = {
									{
										title = "🎓 Training Session Started",
										color = 3447003, -- Blue
										fields = {
											{
												name = "Trainee",
												value = `{v.DisplayName} (@{v.Name})`,
												inline = true
											},
											{
												name = "Supervisor", 
												value = `{plr.DisplayName} (@{plr.Name})`,
												inline = true
											},
											{
												name = "Duration",
												value = args[2],
												inline = true
											},
											{
												name = "Session ID",
												value = sessionData.SessionId,
												inline = false
											}
										},
										timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
									}
								}
							}
							
							pcall(function()
								service.HttpService:PostAsync(customWebhook, service.HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
							end)
						end)
					end
					
					-- Create monitoring GUI for supervisor
					Remote.MakeGui(plr, "TrainingMonitor", {
						TraineeData = sessionData,
						SessionId = sessionData.SessionId
					})
					
					-- Notify trainee
					Functions.Notification("Training Mode", `You are now in training mode for {args[2]}. All commands will be logged.`, {v}, 15, "MatIcon://School")
					Functions.Hint(`Started training session for {service.FormatPlayer(v)} - Duration: {args[2]}`, {plr})
					
					-- Set up timer to remove permissions when session ends
					local timeoutTask = task.delay(tonumber(duration), function()
						if Variables.TrainingSessions and Variables.TrainingSessions[v.UserId] then
							-- Remove training session
							local session = Variables.TrainingSessions[v.UserId]
							Variables.TrainingSessions[v.UserId] = nil
							
							-- Clean up user state (only if player is still in game)
							if v.Parent then -- Check if player is still in game
								-- 1. Remove from shift tracking if they are on shift
								if Variables.shiftPlayers[v.UserId] then
									Variables.shiftPlayers[v.UserId] = nil
									Functions.Notification("Shift Ended", "Your shift has been automatically ended due to training completion.", {v}, 5)
								end
								
								-- 2. Refresh the trainee to reset all states (god, fly, tools, noclip, etc.)
								task.spawn(function()
									v:LoadCharacter()
								end)
								
								-- Remove temporary moderator permissions
								Admin.RemoveAdmin(v, true)
								Functions.Notification("Training Complete", "Your training session has ended.", {v}, 10, "MatIcon://School")
							else
								-- Clean up tracking even if player left
								if Variables.shiftPlayers[v.UserId] then
									Variables.shiftPlayers[v.UserId] = nil
								end
								if Variables.InsertedObjects[v.UserId] then
									Variables.InsertedObjects[v.UserId] = nil
								end
							end
							
							-- Log training completion
							Functions.LogAdminAction(session.Supervisor, "End Training", v.Name, `Training session completed. Commands executed: {#session.CommandLog}`)
							
							-- Send final webhook report
							if session.Webhook and session.Webhook ~= "" then
								task.spawn(function()
									local commandSummary = {}
									for i, cmd in session.CommandLog do
										table.insert(commandSummary, `{i}. {cmd.Command} - {os.date("%H:%M:%S", cmd.Time)}`)
									end
									
									local payload = {
										username = "Adonis Training System",
										embeds = {
											{
												title = "🎓 Training Session Completed",
												color = 65280, -- Green
												fields = {
													{
														name = "Trainee",
														value = `{session.Trainee.DisplayName} (@{session.Trainee.Name})`,
														inline = true
													},
													{
														name = "Supervisor",
														value = `{session.Supervisor.DisplayName} (@{session.Supervisor.Name})`,
														inline = true
													},
													{
														name = "Commands Executed",
														value = tostring(#session.CommandLog),
														inline = true
													},
													{
														name = "Session Duration",
														value = `{math.floor(session.Duration / 60)}m {session.Duration % 60}s`,
														inline = false
													},
													{
														name = "Command Log",
														value = #commandSummary > 0 and table.concat(commandSummary, "\n") or "No commands executed",
														inline = false
													}
												},
												timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
											}
										}
									}
									
									pcall(function()
										service.HttpService:PostAsync(session.Webhook, service.HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
									end)
								end)
							end
							
							-- Close supervisor's monitoring GUI if still open
							Remote.RemoveGui(session.Supervisor, "TrainingMonitor")
							Remote.Send(session.Supervisor, "CloseTrainingMonitor")
						end
					end)
					
					-- Store the timeout task reference so it can be cancelled if training ends early
					if Variables.TrainingSessions[v.UserId] then
						Variables.TrainingSessions[v.UserId].TimeoutTask = timeoutTask
					end
				end
			end
		};

		UnLight = {
			Prefix = Settings.Prefix;
			Commands = {"unlight"};
			Args = {"player"};
			Description = "UnLights the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
						Functions.RemoveParticle(v.Character.HumanoidRootPart, "ADONIS_LIGHT")
					end
				end
			end
		};

		UnPunish = {
			Prefix = Settings.Prefix;
			Commands = {"unpunish"};
			Args = {"player"};
			Description = "UnPunishes the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1])  do
					local char = v.Character
					if char then
						char.Parent = workspace
						char:MakeJoints()
						Remote.LoadCode(v, [[service.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)]])
					end
				end
			end
		};

		UnStarterHealth = {
			Prefix = Settings.Prefix;
			Commands = {"unstarterhealth", "unstarthealth", "resetstarterhealth", "unpersisthealth"};
			Args = {"player"};
			Description = "Removes the target player(s)'s custom starting health";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local plrs = service.GetPlayers(plr, args[1])
				for _, v in plrs do
					server.Variables.Starter.Health[tostring(v.UserId)] = nil
				end
				Functions.Hint(`Your starter health was reset`, plrs)
				if Settings.CommandFeedback then
					Functions.Hint(`You reset {#plrs} players starter health`, {plr})
				end
			end
		};

		UnLightingEffect = {
			Prefix = Settings.Prefix;
			Commands = {"unlightingeffect", "unscreeneffect"};
			Args = {"player"};
			Description = "Remove admin made lighting effects from the target player's screen";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					for _, e in {"BLUR", "BLOOM", "THERMAL", "SUNRAYS", "COLORCORRECTION"} do
						Remote.RemoveLocal(v, `WINDOW_{e}`, "Camera")
					end
				end
			end
		};

		UnStarterSpeed = {
			Prefix = Settings.Prefix;
			Commands = {"unstarterspeed", "unstartspeed", "resetstarterspeed", "unpersistspeed"};
			Args = {"player"};
			Description = "Removes the target player(s)'s custom starting speed";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local plrs = service.GetPlayers(plr, args[1])
				for _, v in plrs do
					server.Variables.Starter.Speed[tostring(v.UserId)] = nil
				end
				Functions.Hint(`Your starter speed was reset`, plrs)
				if Settings.CommandFeedback then
					Functions.Hint(`You reset {#plrs} players starter speed`, {plr})
				end
			end
		};

		UnSunRays = {
			Prefix = Settings.Prefix;
			Commands = {"unsunrays"};
			Args = {"player"};
			Description = "UnSunrays the target player's screen";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.RemoveLocal(v, "WINDOW_SUNRAYS", "Camera")
				end
			end
		};

		Volume = {
			Prefix = Settings.Prefix;
			Commands = {"volume", "vol"};
			Args = {"number"};
			Description = "Change the volume of the currently playing song";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local volume = assert(tonumber(args[1]), "Volume must be a valid number")

				for i, v in service.SoundService:GetChildren() do
					if v.Name=="ADONIS_SOUND" then
						if string.sub(args[1], 1, 1) == "+" then
							v.Volume=v.Volume+tonumber(string.sub(args[1], 2))
						elseif string.sub(args[1], 1, 1) == "-" then
							v.Volume=v.Volume-tonumber(string.sub(args[1], 2))
						else
							v.Volume = volume
						end
					end
				end
			end
		};

		UnTargetAudio = {
			Prefix = Settings.Prefix;
			Commands = {"untaudio", "unlocalsound", "unlocalaudio", "unlsound", "unlaudio"};
			Args = {"player"};
			Description = "Stops audio playing on the specified player's client";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string}, data: {})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.Send(v, "Function", "StopAudio", "all")

				end
			end
		};

		TrainingMonitor = {
			Prefix = Settings.Prefix;
			Commands = {"trainingmonitor", "trainmonitor", "tmonitor"};
			Args = {"player"};
			Description = "Opens the training monitor for an active training session";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player (argument #1)")
				
				if not Variables.TrainingSessions then
					Functions.Hint("No active training sessions found", {plr})
					return
				end
				
				for _, v in service.GetPlayers(plr, args[1]) do
					local session = Variables.TrainingSessions[v.UserId]
					
					if not session then
						Functions.Hint(`{service.FormatPlayer(v)} is not currently in a training session`, {plr})
						continue
					end
					
					-- Check if the executor is the supervisor or has higher authority
					if session.Supervisor ~= plr and Admin.GetLevel(plr) <= Admin.GetLevel(session.Supervisor) then
						Functions.Hint(`You do not have permission to monitor {service.FormatPlayer(v)}'s training session`, {plr})
						continue
					end
					
					-- Open/reopen the TrainingMonitor for the supervisor
					Remote.MakeGui(plr, "TrainingMonitor", {
						TraineeData = session,
						SessionId = session.SessionId,
						UpdateType = "Initial"
					})
					
					Functions.Hint(`Opened training monitor for {service.FormatPlayer(v)}`, {plr})
				end
			end
		};

		UnCape = {
			Prefix = Settings.Prefix;
			Commands = {"uncape", "removecape"};
			Args = {"player"};
			Description = "Removes the target player(s)'s cape";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Functions.UnCape(v)
				end
			end
		};

		UnDisplayName = {
			Prefix = Settings.Prefix;
			Commands = {"undisplayname", "undname"};
			Args = {"player"};
			Description = "Put the target player(s)'s back to normal";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local char = v.Character;
					local human = char and char:FindFirstChildOfClass("Humanoid");
					if human then
						human.DisplayName = v.DisplayName
						Functions.Notification("Notification", "Your character name has been restored", {v}, 10)
					end
				end
			end
		};

		Unban = {
			Prefix = Settings.Prefix;
			Commands = {"unban"};
			Args = {"user/userId"};
			Description = "Unbans the target user(s) from all ban types (server, time, permanent, game bans)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local input = assert(args[1], "Missing user/userId (argument #1)")

				-- Check if input is directly a UserID (number)
				if tonumber(input) then
					local userId = tonumber(input)
					local removedBan = Admin.RemoveBan(userId, true)
					local removedTimeBan = Admin.RemoveTimeBan(userId)

					if removedBan or removedTimeBan then
						-- Successfully removed from ban list
						Functions.LogAdminAction(plr, "Unban", tostring(userId), "UserId has been unbanned from all ban types.")
						Functions.Hint(`UserId {userId} has been unbanned from all ban types`, {plr})
					else
						-- Try direct Roblox unban as backup for game bans
						local config = {
							UserIds = { userId },
							ApplyToUniverse = true,
						}

						local success = pcall(function()
							return service.Players:UnbanAsync(config)
						end)

						if success then
							Functions.LogAdminAction(plr, "Unban", tostring(userId), "UserId has been force-unbanned via Roblox API.")
							Functions.Hint(`UserId {userId} has been force-unbanned from game bans`, {plr})
						else
							Functions.Hint(`UserId {userId} is not currently banned`, {plr})
						end
					end
				else
					-- Handle username(s) through GetPlayers
					for _, v in service.GetPlayers(plr, input, {
						UseFakePlayer = true;
						AllowUnknownUsers = true;
					})
					do
						local removedBan = Admin.RemoveBan(v, true)
						local removedTimeBan = Admin.RemoveTimeBan(v)

						if removedBan or removedTimeBan then
							Functions.LogAdminAction(plr, "Unban", v.Name, "User has been unbanned from all ban types.")
							Functions.Hint(`{service.FormatPlayer(v, true)} has been unbanned from all ban types`, {plr})
						else
							Functions.Hint(`{service.FormatPlayer(v, true)} is not currently banned`, {plr})
						end
					end
				end
			end
		};

		UnLoopHeal = {
			Prefix = Settings.Prefix;
			Commands = {"unloopheal"};
			Args = {"player"};
			Description = `Undoes {Settings.Prefix}loopheal`;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					service.StopLoop(`{v.UserId}LOOPHEAL`)
				end
			end
		};

		UnName = {
			Prefix = Settings.Prefix;
			Commands = {"unname", "fixname"};
			Args = {"player"};
			Description = "Put the target player(s)'s back to normal";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")

					if humanoid then
						humanoid.DisplayName = v.DisplayName
					end
				end
			end
		};

		UnPhase = {
			Prefix = Settings.Prefix;
			Commands = {"unphase"};
			Args = {"player"};
			Description = "UnPhases the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						Remote.MoveLocal(v, v.Character.Name, false, workspace)
						v.Character.Parent = workspace
					end
				end
			end
		};

		UnTraining = {
			Prefix = Settings.Prefix;
			Commands = {"untraining", "untrainmod", "endtraining"};
			Args = {"player"};
			Description = "Ends a training session and removes temporary moderator permissions";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing target player (argument #1)")
				
				if not Variables.TrainingSessions then
					Functions.Hint("No active training sessions found", {plr})
					return
				end
				
				for _, v in service.GetPlayers(plr, args[1]) do
					local session = Variables.TrainingSessions[v.UserId]
					
					if not session then
						Functions.Hint(`{service.FormatPlayer(v)} is not currently in a training session`, {plr})
						continue
					end
					
					-- Check if the executor is the supervisor or has higher authority
					if session.Supervisor ~= plr and Admin.GetLevel(plr) <= Admin.GetLevel(session.Supervisor) then
						Functions.Hint(`You do not have permission to end {service.FormatPlayer(v)}'s training session`, {plr})
						continue
					end
					
					-- Cancel the timeout task if it exists
					if session.TimeoutTask then
						task.cancel(session.TimeoutTask)
					end
					
					-- Remove the training session
					Variables.TrainingSessions[v.UserId] = nil
					
				-- Clean up user state by refreshing them (this resets everything)
				-- 1. Remove from shift tracking if they are on shift
				if Variables.shiftPlayers[v.UserId] then
					Variables.shiftPlayers[v.UserId] = nil
					Functions.Notification("Shift Ended", "Your shift has been automatically ended due to training completion.", {v}, 5)
				end
				
				-- 2. Refresh the trainee to reset all states (god, fly, tools, noclip, etc.)
				task.spawn(function()
					v:LoadCharacter()
				end)

				-- Remove temporary moderator permissions
				Admin.RemoveAdmin(v, true)

				-- Notify trainee
				Functions.Notification("Training Ended", `Your training session has been ended by {plr.DisplayName}. All training effects have been removed.`, {v}, 10, "MatIcon://School")
					Functions.Hint(`Ended training session for {service.FormatPlayer(v)}`, {plr})
					
					-- Show training summary to the executor
					local duration = os.time() - session.StartTime
					local minutes = math.floor(duration / 60)
					local seconds = duration % 60
					
					-- Log the action
					Functions.LogAdminAction(plr, "End Training (Manual)", v.Name, `Commands executed: {#session.CommandLog}, Original supervisor: {session.Supervisor.Name}`)
					
					-- Send webhook notification
					if session.Webhook and session.Webhook ~= "" then
						task.spawn(function()
							local commandSummary = {}
							for i, cmd in session.CommandLog do
								table.insert(commandSummary, `{i}. {cmd.Command} - {os.date("%H:%M:%S", cmd.Time)}`)
							end
							
							local duration = os.time() - session.StartTime
							
							local payload = {
								username = "Adonis Training System",
								embeds = {
									{
										title = "🛑 Training Session Ended Early",
										color = 16711680, -- Red
										fields = {
											{
												name = "Trainee",
												value = `{v.DisplayName} (@{v.Name})`,
												inline = true
											},
											{
												name = "Ended By",
												value = `{plr.DisplayName} (@{plr.Name})`,
												inline = true
											},
											{
												name = "Original Supervisor",
												value = `{session.Supervisor.DisplayName} (@{session.Supervisor.Name})`,
												inline = true
											},
											{
												name = "Commands Executed",
												value = tostring(#session.CommandLog),
												inline = true
											},
											{
												name = "Actual Duration",
												value = `{math.floor(duration / 60)}m {duration % 60}s`,
												inline = false
											},
											{
												name = "Command Log",
												value = #commandSummary > 0 and table.concat(commandSummary, "\n") or "No commands executed",
												inline = false
											}
										},
										timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
									}
								}
							}
							
							pcall(function()
								service.HttpService:PostAsync(session.Webhook, service.HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
							end)
						end)
					end
					
					-- Close supervisor's monitoring GUI if open
					Remote.RemoveGui(session.Supervisor, "TrainingMonitor")
					Remote.Send(session.Supervisor, "CloseTrainingMonitor")

					if (session.Trainee and session.Trainee.Parent) then
						session.Trainee:LoadCharacter()
					end
				end
			end
		};

		ViewShiftStats = {
			Prefix = Settings.Prefix;
			Commands = {"viewshiftstats", "shiftstats", "shiftdata"};
			Args = {"player (optional)"};
			Description = "View shift statistics for yourself or a target player. Shows total shifts, total time, average time, and last shift info.";
			AdminLevel = 700;
			ListUpdater = function(plr: Player, targetUserId: number, targetName: string)
				if not server.ShiftData or not server.ShiftData.GetPlayerData then
					return {{Text = "Shift data not initialized"; Desc = "DataStore may be disabled or unavailable"}}
				end

				local data = server.ShiftData.GetPlayerData(targetUserId)
				local averageTime = server.ShiftData.GetAverageShiftTime(targetUserId)

				if not data then
					return {{
						Text = "Unable to retrieve shift data";
						Desc = "";
					}}
				end

				return {
					{
						Text = `<b><font color='rgb(100, 200, 255)'>{targetName}</font></b>`;
						Desc = "";
					},
					{
						Text = "";
						Desc = "";
					},
					{
						Text = `<b>Total Shifts:</b> {data.TotalShifts}`;
						Desc = `Completed {data.TotalShifts} shift{data.TotalShifts ~= 1 and "s" or ""}`;
					},
					{
						Text = `<b>Total Time on Duty:</b> {server.ShiftData.FormatTime(data.TotalShiftTime)}`;
						Desc = `{data.TotalShiftTime} seconds total`;
					},
					{
						Text = `<b>Average Shift Duration:</b> {server.ShiftData.FormatTime(averageTime)}`;
						Desc = `{averageTime} seconds average`;
					},
					{
						Text = "";
						Desc = "";
					},
					{
						Text = `<b>Last Shift Type:</b> {data.LastShiftType}`;
						Desc = data.LastShiftType;
					},
					{
						Text = `<b>Last Shift Duration:</b> {server.ShiftData.FormatTime(data.LastShiftTime)}`;
						Desc = `{data.LastShiftTime} seconds`;
					},
					{
						Text = `<b>Last Shift Date:</b> {data.LastShiftDate}`;
						Desc = data.LastShiftDate;
					},
				}
			end;
			Function = function(plr: Player, args: {string})
				if not server.ShiftData or not server.ShiftData.GetPlayerData then
					Functions.Hint("Shift data not initialized. Enable API Services in Game Settings or check DataStore availability.", {plr})
					return
				end

				-- If no argument provided, show own stats
				if not args[1] or args[1] == "" or args[1] == "me" then
					Remote.MakeGui(plr, "List", {
						Title = `Shift Statistics - {plr.Name}`;
						Table = Logs.ListUpdaters.ViewShiftStats(plr, plr.UserId, plr.Name);
						TextSelectable = true;
						RichText = true;
						Sanitize = false;
					})
				else
					-- Show stats for target player(s)
					for _, targetPlayer in service.GetPlayers(plr, args[1]) do
						Remote.MakeGui(plr, "List", {
							Title = `Shift Statistics - {targetPlayer.Name}`;
							Table = Logs.ListUpdaters.ViewShiftStats(plr, targetPlayer.UserId, targetPlayer.Name);
							TextSelectable = true;
							RichText = true;
							Sanitize = false;
						})
					end
				end
			end
		};

		AllShiftStats = {
			Prefix = Settings.Prefix;
			Commands = {"allshiftstats", "allshiftdata"};
			Args = {};
			Description = "View shift statistics for all players who have shift data";
			AdminLevel = 700;
			Function = function(plr: Player, args: {string})
				if not server.ShiftData or not server.ShiftData.GetPlayerData then
					Functions.Hint("Shift data not initialized. Enable API Services in Game Settings or check DataStore availability.", {plr})
					return
				end

				local tab = {}
				for _, player in service.Players:GetPlayers() do
					local data = server.ShiftData.GetPlayerData(player.UserId)
					if data and data.TotalShifts > 0 then
						table.insert(tab, {
							Text = `{player.Name}: {data.TotalShifts} shifts`;
							Desc = `Total Time: {server.ShiftData.FormatTime(data.TotalShiftTime)} | Last: {data.LastShiftDate}`;
						})
					end
				end

				if #tab == 0 then
					table.insert(tab, {Text = "No shift data found"; Desc = "No players have recorded shifts"})
				end

				Remote.MakeGui(plr, "List", {
					Title = "All Shift Statistics";
					Table = tab;
					TextSelectable = true;
				})
			end
		};

		ResetShiftData = {
			Prefix = Settings.Prefix;
			Commands = {"resetshiftdata", "clearshiftdata"};
			Args = {"player/all"};
			Description = "Reset shift data for a specific player or all players. Use 'all' to reset everyone's data.";
			AdminLevel = 700;
			Dangerous = true;
			Function = function(plr: Player, args: {string})
				if not server.ShiftData or not server.ShiftData.ResetPlayerData then
					Functions.Hint("Shift data not initialized", {plr})
					return
				end

				if args[1] and args[1]:lower() == "all" then
					if Remote.GetGui(plr, "YesNoPrompt", {Question = "Reset ALL shift data? This cannot be undone!"; Title = "Confirm Reset"}) == "Yes" then
						local count = 0
						for _, player in service.Players:GetPlayers() do
							if server.ShiftData.ResetPlayerData(player.UserId) then
								count += 1
							end
						end
						Functions.Hint(`Reset shift data for {count} player(s)`, {plr})
						Functions.LogAdminAction(plr, "Reset All Shift Data", "All Players", `Reset {count} player records`)
					end
				else
					for _, targetPlayer in service.GetPlayers(plr, args[1]) do
						if server.ShiftData.ResetPlayerData(targetPlayer.UserId) then
							Functions.Hint(`Reset shift data for {service.FormatPlayer(targetPlayer)}`, {plr})
							Functions.LogAdminAction(plr, "Reset Shift Data", targetPlayer.Name, "Shift data reset")
						else
							Functions.Hint(`Failed to reset shift data for {service.FormatPlayer(targetPlayer)}`, {plr})
						end
					end
				end
			end
		};

		ForceView = {
			Prefix = Settings.Prefix;
			Commands = {"fview", "forceview", "forceviewplayer", "fv"};
			Args = {"player1", "player2"};
			Description = "Forces one player to view another";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local targets = service.GetPlayers(plr, args[2])
				for _, viewer in service.GetPlayers(plr, args[1]) do
					for _, target in targets do
						local targetHum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
						if not targetHum then continue end
						local rootPart = target.Character.PrimaryPart
						if not rootPart then continue end
						Functions.ResetReplicationFocus(viewer)
						viewer.ReplicationFocus = rootPart
						Remote.Send(viewer, "Function", "SetView", targetHum)
						Functions.Hint(`{service.FormatPlayer(viewer)} is now viewing {service.FormatPlayer(target)}`, {plr})
					end
				end
			end
		};

		MakeCamera = {
			Prefix = Settings.Prefix;
			Commands = {"makecam", "makecamera", "camera", "newcamera", "newcam"};
			Args = {"name"};
			Filter = true;
			Description = "Makes a camera named whatever you pick";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local head = plr.Character and (plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart"))
				assert(head and head:IsA("BasePart"), "You don't have a character head or root part")
				if not args[1] then return Functions.Hint("A name is required!", {plr}) end

				if workspace:FindFirstChild(`Camera: {args[1]}`) then
					Functions.Hint(`{args[1]} Already Exists!`, {plr})
				else
					local cam = service.New("Part", {
						Parent = workspace;
						Name = `Camera: {args[1]}`;
						Position = head.Position;
						Anchored = true;
						BrickColor = BrickColor.new("Really black");
						CanCollide = false;
						Locked = true;
						Size = Vector3.new(1, 1, 1);
						TopSurface = "Smooth";
						BottomSurface = "Smooth";
						Transparency = 1;--.9
					})
					--service.New("PointLight", cam)
					local mesh = service.New("SpecialMesh", {
						Parent = cam;
						Scale = Vector3.new(1, 1, 1);
						MeshType = "Sphere";
					})
					table.insert(Variables.Cameras, {Brick = cam, Name = args[1]})
					Functions.Hint(`Created camera {args[1]}`, {plr})
				end
			end
		};

		GuiView = {
			Prefix = Settings.Prefix;
			Commands = {"guiview", "showguis", "viewguis"};
			Args = {"player"};
			Description = "Shows you the player's character and any guis in their PlayerGui folder [May take a minute]";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local p
				for _, v in service.GetPlayers(plr, args[1]) do
					p = v
				end
				if p then
					Functions.Hint("Loading GUIs", {plr})
					local guis = Remote.Get(p, "Function", "GetGuiData")
					if guis then
						Remote.Send(plr, "Function", "LoadGuiData", guis)
					end
				end
			end;
		};

		CustomPants = {
			Prefix = Settings.Prefix;
			Commands = {"custompants"};
			Args = {"player", "id"};
			Description = "Give the target player(s) the pants that belongs to <ID>. Supports images and catalog items.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local ClothingId = tonumber(args[2])
				local AssetIdType = service.MarketPlace:GetProductInfo(ClothingId).AssetTypeId
				local Pants = AssetIdType == 12 and service.Insert(ClothingId) or AssetIdType == 1 and Functions.CreateClothingFromImageId("Pants", ClothingId) or error("Item ID passed has invalid item type")
				assert(Pants, "Unexpected error occured; clothing is missing")

				local clothingTemplate = `rbxassetid://{ClothingId}`

				for i, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
						local bCreateNewDefaultClothing = false

						if humanoid then
							local humanoidAppliedDesc = humanoid:GetAppliedDescription()
							if humanoidAppliedDesc then
								-- Check if the player already has a specified clothing instance.
								local prePlayerPants = v.Character:FindFirstChildOfClass("Pants")

								-- If the character has the specified clothing.
								if prePlayerPants then
									-- Check the humanoid description for clothing ID.
									if humanoidAppliedDesc.Pants == 0 then
										-- Remove all the specified clothings, assuming it was manually created.
										for _, v in v.Character:GetChildren() do
											if v:IsA("Pants") then
												v:Destroy()
											end
										end

										bCreateNewDefaultClothing = true
									end
								else -- If the specified clothing was not found.
									bCreateNewDefaultClothing = true
								end


								if bCreateNewDefaultClothing then
									-- Set a new specified clothing.
									local humDescClone = humanoidAppliedDesc:Clone()

									-- Default Pants ID 855782781, given when no valid pants was set with HumanoidDescription
									humDescClone.Pants = 855782781 -- Default pants
									v.Character.Humanoid:ApplyDescription(humDescClone, Enum.AssetTypeVerification.Always)
									humDescClone:Destroy()
								end

								-- Set the specified clothing.
								local playerPantsInstance = v.Character:FindFirstChildOfClass("Pants")

								if playerPantsInstance then
									playerPantsInstance.PantsTemplate = clothingTemplate
								else
									-- Incase something went wrong
									Pants:Clone().Parent = v.Character
								end
							else
								-- If no HumanoidDescription
								Pants:Clone().Parent = v.Character
							end
						end
					end
				end
			end
		};

		CustomShirt = {
			Prefix = Settings.Prefix;
			Commands = {"customshirt"};
			Args = {"player", "ID"};
			Description = "Give the target player(s) the shirt that belongs to <ID>. Supports images and catalog items.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local ClothingId = tonumber(args[2])
				local AssetIdType = service.MarketPlace:GetProductInfo(ClothingId).AssetTypeId
				local Shirt = AssetIdType == 11 and service.Insert(ClothingId) or AssetIdType == 1 and Functions.CreateClothingFromImageId("Shirt", ClothingId) or error("Item ID passed has invalid item type")
				assert(Shirt, "Unexpected error occured; clothing is missing")

				local clothingTemplate = `rbxassetid://{ClothingId}`

				for i, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
						local bCreateNewDefaultClothing = false

						if humanoid then
							local humanoidAppliedDesc = humanoid:GetAppliedDescription()
							if humanoidAppliedDesc then
								-- Check if the player already has a specified clothing instance.
								local prePlayerShirt = v.Character:FindFirstChildOfClass("Shirt")

								-- If the character has the specified clothing.
								if prePlayerShirt then
									-- Check the humanoid description for clothing ID.
									if humanoidAppliedDesc.Shirt == 0 then
										-- Remove all the specified clothings, assuming it was manually created.
										for _, v in v.Character:GetChildren() do
											if v:IsA("Shirt") then
												v:Destroy()
											end
										end

										bCreateNewDefaultClothing = true
									end
								else -- If the specified clothing was not found.
									bCreateNewDefaultClothing = true
								end


								if bCreateNewDefaultClothing then
									-- Set a new specified clothing.
									local humDescClone = humanoidAppliedDesc:Clone()

									-- Default Shirt ID 855777286, given when no valid shirt was set with HumanoidDescription
									humDescClone.Shirt = 855777286 -- Default shirt TODO: You want to change this because the ID put here can't be given with the command if already ran.
									v.Character.Humanoid:ApplyDescription(humDescClone, Enum.AssetTypeVerification.Always)
									humDescClone:Destroy()
								end

								-- Set the specified clothing.
								local playerShirtInstance = v.Character:FindFirstChildOfClass("Shirt")

								if playerShirtInstance then
									playerShirtInstance.ShirtTemplate = clothingTemplate
								else
									-- Incase something went wrong
									Shirt:Clone().Parent = v.Character
								end
							else
								-- If no HumanoidDescription
								Shirt:Clone().Parent = v.Character
							end
						end
					end
				end
			end
		};

				
		Music = {
			Prefix = Settings.Prefix;
			Commands = {"music", "song", "playsong", "sound"};
			Args = {"id", "noloop(true/false)", "pitch", "volume"};
			Description = "Start playing a song";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string}, data: {})
				local id = string.lower(args[1])
				local looped = args[2]
				local pitch = tonumber(args[3]) or 1
				local mp = service.MarketPlace
				local volume = tonumber(args[4]) or 1
				local name = "#Invalid ID"

				if id ~= "0" and id ~= "off" then
					if looped then
						if looped == "true" then
							looped = false
						else
							looped = true
						end
					else
						looped = true
					end

					for i, v in Variables.MusicList do
						if id == string.lower(v.Name) then
							id = v.ID

							if v.Pitch then
								pitch = v.Pitch
							end
							if v.Volume then
								volume = v.Volume
							end
						end
					end

					for i, v in HTTP.Trello.Music do
						if id == string.lower(v.Name) then
							id = v.ID

							if v.Pitch then
								pitch = v.Pitch
							end
							if v.Volume then
								volume = v.Volume
							end
						end
					end

					pcall(function()
						if tonumber(id) and mp:GetProductInfo(id).AssetTypeId == 3 then
							name = `Now playing {mp:GetProductInfo(id).Name}`
						end
					end)

					if name == "#Invalid ID" then
						Functions.Hint("Invalid audio Name/ID", {plr})
						return
					elseif Settings.SongHint then
						Functions.Hint(name, service.GetPlayers())
					end

					for i, v in service.SoundService:GetChildren() do
						if v.ClassName == "Sound" and v.Name == "ADONIS_SOUND" then
							if v.IsPaused == true then
								local ans,event = Remote.GetGui(plr, "YesNoPrompt", {
									Title = "Override paused track?";
									Question = "There is currently a track paused, do you wish to override it?";
								})

								if ans == "No" then
									return
								end
							end

							v:Destroy()
						end
					end

					local s = service.New("Sound")
					s.Name = "ADONIS_SOUND"
					s.SoundId = `http://www.roblox.com/asset/?id={id}`
					s.Volume = volume
					s.Pitch = pitch
					s.Looped = looped
					s.Archivable = false
					s.Parent = service.SoundService
					wait(0.5)
					s:Play()
				elseif id == "off" or id == "0" then
					for i, v in service.SoundService:GetChildren() do
						if v.ClassName == "Sound" and v.Name == "ADONIS_SOUND" then
							v:Destroy()
						end
					end
				end
			end
		};

		MusicList = {
			Prefix = Settings.Prefix;
			Commands = {"musiclist", "listmusic", "songs"};
			Args = {};
			Description = "Shows you the script's available music list";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local tab = table.create(#Variables.MusicList + #HTTP.Trello.Music)
				for _, v in Variables.MusicList do table.insert(tab, v) end
				for _, v in HTTP.Trello.Music do table.insert(tab, v) end
				for i, v in tab do
					tab[i] = {Text = `{v.Name} - {v.ID}`; Desc = v.ID;}
				end
				Remote.MakeGui(plr, "List", {Title = "Music List", Table = tab, TextSelectable = true})
			end
		};

		Resume = {
			Prefix = Settings.Prefix;
			Commands = {"resume", "resumemusic", "rsound", "resumesound"};
			Args = {};
			Description = "Resumes the current playing song";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string}, data: {})
				for i, v in service.SoundService:GetChildren() do
					if v.Name=="ADONIS_SOUND" then
						if v.IsPaused == true then
							v:Resume()
							Functions.Hint("Resuming Playback...", {plr})
						else
							Functions.Hint("Music is not paused", {plr})
						end

					end
				end
			end
		};

		StarterRemove = {
			Prefix = Settings.Prefix;
			Commands = {"starterremove"};
			Args = {"player", "toolname"};
			Description = "Removes the desired tool from the target player(s)'s StarterPack";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, string.lower(args[1])) do
					local StarterGear = v:FindFirstChildOfClass("StarterGear")
					if StarterGear then
						for _, tool in StarterGear:GetChildren() do
							if tool:IsA("BackpackItem") then
								if string.lower(args[2]) == "all" or string.find(string.lower(tool.Name), string.lower(args[2])) == 1 then
									tool:Destroy()
								end
							end
						end
					end
				end
			end
		};

				UnBloom = {
			Prefix = Settings.Prefix;
			Commands = {"unbloom", "unscreenbloom"};
			Args = {"player"};
			Description = "UnBloom the target player's screen";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.RemoveLocal(v, "WINDOW_BLOOM", "Camera")
				end
			end
		};

		UnBlur = {
			Prefix = Settings.Prefix;
			Commands = {"unblur", "unscreenblur"};
			Args = {"player"};
			Description = "UnBlur the target player's screen";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.RemoveLocal(v, "WINDOW_BLUR", "Camera")
				end
			end
		};

		UnChar = {
			Prefix = Settings.Prefix;
			Commands = {"unchar", "uncharacter", "fixappearance"};
			Args = {"player"};
			Description = "Put the target player(s)'s character appearence back to normal";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Routine(function()
						v.CharacterAppearanceId = v.UserId

						local Humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")

						if Humanoid then
							local success, desc = pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, v.UserId)

							if success then
								Humanoid:ApplyDescription(desc, Enum.AssetTypeVerification.Always)
							end
						end
					end)
				end
			end
		};

		UnCharacterAudio = {
			Prefix = Settings.Prefix;
			Commands = {"uncharaudio", "uncharactermusic", "uncharmusic"};
			Args = {"player"};
			Description = `Removes audio placed into character via {Settings.Prefix}charaudio command`;
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for i, v in service.GetPlayers(plr, args[1]) do
					local char = v.Character
					local rootPart = char and char:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local found = rootPart:FindFirstChild("ADONIS_AUDIO")
						if found then
							found:Stop()
							found:Destroy()
						end
					end
				end
			end;
		};

		UnColorCorrection = {
			Prefix = Settings.Prefix;
			Commands = {"uncolorcorrection", "uncorrection", "uncolorcorrectioneffect"};
			Args = {"player"};
			Description = "UnColorCorrection the target player's screen";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, p in service.GetPlayers(plr, args[1]) do
					Remote.RemoveLocal(p, "WINDOW_COLORCORRECTION", "Camera")
				end
			end
		};

		TextToSpeech = {
			Prefix = Settings.Prefix;
			Commands = {"tell", "tts", "texttospeech"};
			Args = {"player", "message"};
			Filter = true;
			Description = "[Experimental] Says aloud the supplied text";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.Send(v, "Function", "TextToSpeech", args[2])
				end
			end
		};

		TargetAudio = {
			Prefix = Settings.Prefix;
			Commands = {"taudio", "localsound", "localaudio", "localsong", "localmusic", "lsound", "laudio", "lsong", "lmusic"};
			Args = {"player", "audioId", "noLoop", "pitch", "volume"};
			Description = "Plays an audio on the specified player's client";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string}, data: {})
				assert(args[1], "Missing player name")
				assert(args[2] and tonumber(args[2]), "Missing or invalid AudioId")

				local id = args[2]
				local volume = 1 --tonumber(args[5]) or 1
				local pitch = 1 --tonumber(args[4]) or 1
				local loop = true

				for i, v in Variables.MusicList do
					if id==string.lower(v.Name) then
						id = v.ID
						if v.Pitch then
							pitch = v.Pitch
						end
						if v.Volume then
							volume=v.Volume
						end
					end
				end

				if #HTTP.Trello.Music ~= 0 then
					for i, v in HTTP.Trello.Music do
						if id==string.lower(v.Name) then
							id = v.ID
							if v.Pitch then
								pitch = v.Pitch
							end
							if v.Volume then
								volume = v.Volume
							end
						end
					end
				end

				if args[3] and args[3] == "true" then loop = false end
				volume = tonumber(args[5]) or volume
				pitch = tonumber(args[4]) or pitch


				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.Send(v, "Function", "PlayAudio", id, volume, pitch, loop)

				end
				Functions.Hint("Playing Audio on Player's Client", {plr})
			end
		};

		StopMusic = {
			Prefix = Settings.Prefix;
			Commands = {"stopmusic", "musicoff", "unmusic"};
			Args = {};
			Description = "Stop the currently playing song";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for i, v in service.SoundService:GetChildren() do
					if v.Name=="ADONIS_SOUND" then
						v:Destroy()
					end
				end
			end
		};

		Pitch = {
			Prefix = Settings.Prefix;
			Commands = {"pitch"};
			Args = {"number"};
			Description = "Change the pitch of the currently playing song";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local pitch = args[1]
				for i, v in service.SoundService:GetChildren() do
					if v.Name=="ADONIS_SOUND" then
						if string.sub(args[1], 1, 1) == "+" then
							v.Pitch=v.Pitch+tonumber(string.sub(args[1], 2))
						elseif string.sub(args[1], 1, 1) == "-" then
							v.Pitch=v.Pitch-tonumber(string.sub(args[1], 2))
						else
							v.Pitch = pitch
						end

					end
				end
			end
		};

		RemoveCamera = {
			Prefix = Settings.Prefix;
			Commands = {"removecam", "delcam", "removecamera", "deletecamera"};
			Args = {"camera"};
			Description = "Deletes the camera if it exists";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for i, v in Variables.Cameras do
					if string.sub(string.lower(v.Name), 1, #args[1]) == string.lower(args[1]) then
						if v.Brick then
							v.Brick:Destroy()
						end

						Functions.Hint(`Deleted camera {v.Name}`, {plr})
						table.remove(Variables.Cameras, i)
					end
				end
			end
		};

		RemoveGuis = {
			Prefix = Settings.Prefix;
			Commands = {"clearscreenguis", "clrscreenguis", "removeguis", "noguis"};
			Args = {"player"};
			Description = "Removes all of the target player(s)'s on-screen GUIs except Adonis GUIs";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					Remote.LoadCode(v, [[for i, v in ipairs(service.PlayerGui:GetChildren()) do if not client.Core.GetGui(v) then pcall(v.Destroy, v) end end]])
				end
			end
		};

		RemoveHat = {
			Prefix = Settings.Prefix;
			Commands = {"removehat", "rhat"};
			Args = {"player", "accessory name"};
			Description = "Removes specific hat(s) the target is currently wearing";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				-- TODO: HumanoidDescription
				assert(args[2], "Argument(s) missing or nil")
				for _, p in service.GetPlayers(plr, args[1]) do
					if not p.Character then continue end
					for _, v in p.Character:GetChildren() do
						if v:IsA("Accessory") and v.Name:lower() == args[2]:lower() then
							v:Destroy()
						end
					end
				end
			end
		};

		RemoveHats = {
			Prefix = Settings.Prefix;
			Commands = {"removehats", "nohats", "clearhats", "rhats"};
			Args = {"player"};
			Description = "Removes any hats the target is currently wearing and from their HumanoidDescription.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, p in service.GetPlayers(plr, args[1]) do
					local humanoid: Humanoid? = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local humanoidDesc: HumanoidDescription = humanoid:GetAppliedDescription()
						local DescsToRemove = {"HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory"}
						for _, prop in DescsToRemove do
							humanoidDesc[prop] = ""
						end
						humanoid:ApplyDescription(humanoidDesc, Enum.AssetTypeVerification.Always)
					end
				end
			end
		};

		RemoveLayeredClothings = {
			Prefix = Settings.Prefix;
			Commands = {"removelayeredclothings"};
			Args = {"player"};
			Description = "Remvoes layered clothings from their HumanoidDescription.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, p in service.GetPlayers(plr, args[1]) do
					local humanoid: Humanoid? = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local humanoidDesc: HumanoidDescription = humanoid:GetAppliedDescription()
						local accessoryBlob = humanoidDesc:GetAccessories(false)

						for i=#accessoryBlob, 1, -1 do -- backwards loop due to table.remove
							local blobItem = accessoryBlob[i]

							if blobItem.IsLayered then
								table.remove(accessoryBlob, i)
							end
						end

						humanoidDesc:SetAccessories(accessoryBlob, false)
						humanoid:ApplyDescription(humanoidDesc, Enum.AssetTypeVerification.Always)
					end
				end
			end
		};

		RemovePants = {
			Prefix = Settings.Prefix;
			Commands = {"removepants"};
			Args = {"player"};
			Description = "Remove any pants(s) worn by the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {[number]:string})
				for _, v: Player in service.GetPlayers(plr, args[1]) do
					local humanoid: Humanoid? = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local humanoidDesc: HumanoidDescription = humanoid:GetAppliedDescription()
						humanoidDesc.Pants = 0
						task.defer(humanoid.ApplyDescription, humanoid, humanoidDesc, Enum.AssetTypeVerification.Always)
					end
				end
			end
		};

		RemoveShirt = {
			Prefix = Settings.Prefix;
			Commands = {"removeshirt", "unshirt", "noshirt"};
			Args = {"player"};
			Description = "Remove any shirt(s) worn by the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {[number]:string})
				for _, v: Player in service.GetPlayers(plr, args[1]) do
					local humanoid: Humanoid? = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local humanoidDesc: HumanoidDescription = humanoid:GetAppliedDescription()
						humanoidDesc.Shirt = 0
						task.defer(humanoid.ApplyDescription, humanoid, humanoidDesc, Enum.AssetTypeVerification.Always)
					end
				end
			end
		};

		RemoveTool = {
			Prefix = Settings.Prefix;
			Commands = {"removetool", "rtool", "deltool"};
			Args = {"player", "tool name"};
			Description = "Remove a specified tool from the target player(s)'s backpack";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						for _, tool in v.Character:GetChildren() do
							if tool:IsA("BackpackItem") and string.sub(tool.Name:lower(), 1, #args[2])== args[2]:lower() then
								local hum = v.Character:FindFirstChildOfClass("Humanoid")
								if hum then hum:UnequipTools() end
								tool:Destroy()
							end
						end
					end
					local backpack = v:FindFirstChildOfClass("Backpack")
					if backpack then
						for _, tool in backpack:GetChildren() do
							if tool:IsA("BackpackItem") and string.sub(tool.Name:lower(), 1, #args[2])== args[2]:lower() then
								tool:Destroy()
							end
						end
					end
				end
			end
		};

		RemoveTools = {
			Prefix = Settings.Prefix;
			Commands = {"removetools", "notools", "rtools", "deltools"};
			Args = {"player"};
			Description = "Remove the target player(s)'s tools";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local hum = v.Character:FindFirstChildOfClass("Humanoid")
						if hum then hum:UnequipTools() end
						for _, tool in v.Character:GetChildren() do
							if tool:IsA("BackpackItem") then tool:Destroy() end
						end
					end
					local backpack = v:FindFirstChildOfClass("Backpack")
					if backpack then
						for _, tool in backpack:GetChildren() do
							if tool:IsA("BackpackItem") then tool:Destroy() end
						end
					end
				end
			end
		};

		RemoveTShirt = {
			Prefix = Settings.Prefix;
			Commands = {"removetshirt", "untshirt", "notshirt"};
			Args = {"player"};
			Description = "Remove any t-shirt(s) worn by the target player(s)";
			AdminLevel = 300;
			Function = function(plr: Player, args: {[number]:string})
				for _, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local humanoid: Humanoid? = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							local humanoidDesc: HumanoidDescription = humanoid:GetAppliedDescription()
							humanoidDesc.GraphicTShirt = 0
							task.defer(humanoid.ApplyDescription, humanoid, humanoidDesc, Enum.AssetTypeVerification.Always)
						end
					end
				end
			end
		};

		Repeat = {
			Prefix = Settings.Prefix;
			Commands = {"repeat", "loop"};
			Args = {"amount", "interval", "command"};
			Description = "Repeats <command> for <amount> of times every <interval> seconds; Amount cannot exceed 50";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string}, data: {any})
				local amount = tonumber(args[1])
				local timer = tonumber(args[2])
				if timer<=0 then timer=0.1 end
				if amount>50 then amount=50 end
				local command = args[3]
				local name = string.lower(plr.Name)
				assert(command, "Missing command name to repeat")
				if string.lower(string.sub(command, 1, #Functions.GetMainPrefix()+string.len("repeat"))) == string.lower(`{Settings.Prefix}repeat`) or string.sub(command, 1, #Functions.GetMainPrefix()+string.len("loop")) == string.lower(`{Settings.Prefix}loop`) or string.find(command, `^{Settings.Prefix}loop`) or string.find(command, `^{Settings.Prefix}repeat`) then
					error("Cannot repeat the loop command in a loop command")
					return
				end

				Variables.CommandLoops[name..command] = true
				Functions.Hint(`Running {command} {amount} times every {timer} seconds.`, {plr})
				for i = 1, amount do
					if not Variables.CommandLoops[name..command] then break end
					Process.Command(plr, command, {Check = false; CrossServer = (data and data.Options.CrossServer);})
					task.wait(timer)
				end
				Variables.CommandLoops[name..command] = nil
			end
		};

		RandomTeam = {
			Prefix = Settings.Prefix;
			Commands = {"rteams", "rteam", "randomizeteams", "randomteams", "randomteam"};
			Args = {"players", "teams"};
			Description = "Randomize teams; :rteams or :rteams all or :rteams nonadmins team1,team2,etc";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				local tArgs = {}
				local teams = {}
				local players = service.GetPlayers(plr, args[1] or "all")
				local cTeam = 1

				local function assign()
					local pIndex = math.random(1, #players)
					local player = players[pIndex]
					local team = teams[cTeam]

					cTeam += 1
					if cTeam > #teams then
						cTeam = 1
					end

					if player and player.Parent then
						player.Team = team
					end

					table.remove(players, pIndex)
					if #players > 0 then
						assign()
					end
				end

				if args[2] then
					for s in string.gmatch(args[2], "(%w+)") do
						table.insert(tArgs, s)
					end
				end


				for i, team in service.Teams:GetChildren() do
					if #tArgs > 0 then
						for ind, check in tArgs do
							if string.sub(string.lower(team.Name), 1, #check) == string.lower(check) then
								table.insert(teams, team)
							end
						end
					else
						table.insert(teams, team)
					end
				end

				cTeam = math.random(1, #teams)
				assign()
			end
		};

		Punish = {
			Prefix = Settings.Prefix;
			Commands = {"punish"};
			Args = {"player"};
			Description = "Removes the target player(s)'s character";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					local char = v.Character
					if char then
						Remote.LoadCode(v, [[service.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)]])
						char.Parent = service.UnWrap(Settings.Storage)
					end
				end
			end
		};

		Outfit = {
			Prefix = Settings.Prefix;
			Commands = {"outfit"};
			Args = {"player", "outfitid"};
			Description = "Changes the target player(s)'s character appearence to a specified OutfitID. You can get OutfitID(s) by using Roblox Avatar API.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Missing player name")
				local success, desc = pcall(service.Players.GetHumanoidDescriptionFromOutfitId, service.Players, assert(tonumber(args[2]), "Missing OutfitId"))

				if success then
					for _, v in service.GetPlayers(plr, args[1]) do
						if v.Character and v.Character:FindFirstChildOfClass("Humanoid") then
							v.Character.Humanoid:ApplyDescription(desc, Enum.AssetTypeVerification.Always)
						end
					end
				else
					error("Unable to get avatar for target user")
				end
			end
		};

		Pause = {
			Prefix = Settings.Prefix;
			Commands = {"pause", "pausemusic", "psound", "pausesound"};
			Args = {};
			Description = "Pauses the current playing song";
			AdminLevel = 300;
			Function = function(plr: Player, args: {string}, data: {})
				for i, v in service.SoundService:GetChildren() do
					if v.Name=="ADONIS_SOUND" then
						if v.IsPaused == false then
							v:Pause()
							Functions.Hint(`Music is now paused | Run {Settings.Prefix}resume to resume playback`, {plr})
						else
							Functions.Hint(`Music is already paused | Run {Settings.Prefix}resume to resume`, {plr})
						end

					end
				end
			end
		};

		CustomTShirt = {
			Prefix = Settings.Prefix;
			Commands = {"customtshirt"};
			Args = {"player", "ID"};
			Description = "Give the target player(s) the t-shirt that belongs to <ID>. Supports images and catalog items.";
			AdminLevel = 300;
			Function = function(plr: Player, args: {[number]:string})
				local ClothingId = tonumber(args[2])
				local AssetIdType = service.MarketPlace:GetProductInfo(ClothingId).AssetTypeId
				local TShirt = ((AssetIdType == 11 or AssetIdType == 2) and service.Insert(ClothingId)) or (AssetIdType == 1 and Functions.CreateClothingFromImageId("ShirtGraphic", ClothingId)) or error("Item ID passed has invalid item type")
				assert(TShirt, "Could not retrieve t-shirt asset for the supplied ID")

				local clothingTemplate = `rbxassetid://{ClothingId}`

				for i, v in service.GetPlayers(plr, args[1]) do
					if v.Character then
						local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
						local bCreateNewDefaultClothing = false

						if humanoid then
							local humanoidAppliedDesc = humanoid:GetAppliedDescription()
							if humanoidAppliedDesc then
								-- Check if the player already has a specified clothing instance.
								local prePlayerShirtGraphic = v.Character:FindFirstChildOfClass("ShirtGraphic")

								-- If the character has the specified clothing.
								if prePlayerShirtGraphic then
									-- Check the humanoid description for clothing ID.
									if humanoidAppliedDesc.GraphicTShirt == 0 then
										-- Remove all the specified clothings, assuming it was manually created.
										for _, v in v.Character:GetChildren() do
											if v:IsA("ShirtGraphic") then
												v:Destroy()
											end
										end
										bCreateNewDefaultClothing = true
									end
								else
									bCreateNewDefaultClothing = true
								end

								if bCreateNewDefaultClothing then
									-- Set a new specified clothing.
									local humDescClone = humanoidAppliedDesc:Clone()

									humDescClone.GraphicTShirt = 6901238398 -- Some template shirt graphic
									v.Character.Humanoid:ApplyDescription(humDescClone, Enum.AssetTypeVerification.Always)
									humDescClone:Destroy()
								end

								-- Set the specified clothing.
								local playerShirtGraphicInstance = v.Character:FindFirstChildOfClass("ShirtGraphic")

								if playerShirtGraphicInstance then
									playerShirtGraphicInstance.Graphic = clothingTemplate
								else
									-- Incase something went wrong
									TShirt:Clone().Parent = v.Character
								end
							else
								-- If no HumanoidDescription
								TShirt:Clone().Parent = v.Character
							end
						end
					end
				end
			end
		};

	}
end
