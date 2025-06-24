--!nonstrict
--[[

	CURRENT LOADER:
	https://www.roblox.com/library/7510622625/Adonis-Admin-Loader-Epix-Incorporated

	CURRENT MODULE:
	https://www.roblox.com/library/7510592873/Adonis-MainModule

	NIGHTLY MODULE:
	https://www.roblox.com/library/8612978896/Nightlies-Adonis-MainModule

--]]

----------------------------------------------------------------------------------
--                                Madonis Loader                                 --
--                            By Epix Incorporated                              --
----------------------------------------------------------------------------------
--          Edit settings using the Settings module in the Config folder        --
----------------------------------------------------------------------------------
--       This script loads the Madonis source (MainModule) into the game.        --
--            Only edit this script if you know what you're doing!              --
----------------------------------------------------------------------------------

local warn = function(...)
	warn(":: Madonis ::", ...)
end

local print = function(...)
	print(":: Madonis ::", ...)
end

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local InsertService = game:GetService("InsertService")

-- Support yieldable xpcall


local mutex = RunService:FindFirstChild("__Madonis_MUTEX")
if mutex then
	if mutex:IsA("StringValue") then
		warn("Madonis is already running! Aborting...; Running Location:", mutex.Value, "This Location:", script:GetFullName())
	else
		warn("Madonis mutex detected but is not a StringValue! Aborting anyway...; This Location:", script:GetFullName())
	end
else
	mutex = Instance.new("StringValue")
	mutex.Name = "__Madonis_MUTEX"
	mutex.Archivable = false
	mutex.Value = script:GetFullName()
	mutex.Parent = RunService

	local model = script.Parent.Parent
	local configFolder = model.Config
	local loaderFolder = model.Loader

	local loader = loaderFolder.Loader
	local runner = script

	local settingsModule = configFolder.Settings
	local pluginsFolder = configFolder.Plugins
	local themesFolder = configFolder.Themes

	local backup = model:Clone()

	local data = {
		Settings = {} :: {[string]: any};
		Descriptions = {} :: {[string]: string};
		Messages = {} :: {string|{[string]: any}};
		ServerPlugins = {} :: {ModuleScript|string};
		ClientPlugins = {} :: {ModuleScript|string};
		Packages = {} :: {Folder};
		Themes = {} :: {Instance};

		ModelParent = model.Parent;
		Model = model;
		Config = configFolder;
		Core = loaderFolder;

		Loader = loader;
		Runner = runner;
		LoaderVersion = (model and model:FindFirstChild("Version")) and tonumber(model.Version.Value);

		ModuleID = 127565279595626;  		--// https://www.roblox.com/library/7510592873/Adonis-MainModule
		LoaderID = 101304990290204;			--// https://www.roblox.com/library/7510622625/Adonis-Loader-Sceleratis-Davey-Bones-Epix
		
		--// Note: The nightly module is updated frequently with every commit merged to the master branch on the Adonis repo.
		--// It is prone to breaking, unstable, untested, and should not be used for anything other than testing/feature preview.
		NightlyMode = false;			--// If true, uses the nightly module instead of the current release module.
		NightlyModuleID = 8612978896; 	--// https://www.roblox.com/library/8612978896/Nightlies-Adonis-MainModule

		--// Module used in case MainModule is unavailable, containing only essential commands
		Backup = 17438792001; 	--// https://create.roblox.com/store/asset/17438792001/

		DebugMode = false;
		SilentStartup = false;
	}

	--// Init

	if not data.SilentStartup then
		print("Loading...")
	end

	-- selene: allow(incorrect_standard_library_use)
	script.Parent = nil

	if not data.DebugMode then
		model.Name = math.random()
	end

	local moduleId = if data.NightlyMode then data.NightlyModuleID else data.ModuleID

	--if data.DebugMode then
		local found = false
		for _, v in model.Parent:GetChildren() do
			if v.Name == "MainModule" and v:IsA("ModuleScript") then
				print("Found Madonis MainModule in", v:GetFullName())
				moduleId, found = v, true
				break
			end
		end

		if not found and not data.NightlyMode then
			warn(`Madonis DebugMode is enabled but no ModuleScript named 'MainModule' is found in {model.Parent and model.Parent:GetFullName()}`)
		end
	--end

	local success, setTab = pcall(require, settingsModule)
	if success then
		data.Messages = setTab.Settings.Messages
	else
		warn("[DEVELOPER ERROR] Settings module errored while loading; Using defaults; Error Message: ", setTab)
		table.insert(data.Messages, {
			Title = "Warning!";
			Icon = "maticon://Dangerous";
			Message = "Settings module error detected; using default settings.";
			Time = 15;
		})
		setTab = {}
	end

	data.Settings = setTab.Settings
	data.Descriptions = setTab.Description
	data.Order = setTab.Order

	for _, module in pluginsFolder:GetChildren() do
		local name = string.lower(module.Name)

		if module:IsA("Folder") then
			table.insert(data.Packages, module)
		elseif string.match(name, "^client[%-:]") then
			table.insert(data.ClientPlugins, module)
		elseif string.match(name, "^server[%-:]") then
			table.insert(data.ServerPlugins, module)
		else
			warn(`[DEVELOPER ERROR] Unknown Plugin Type for {module:GetFullName()}; Plugin name should either start with 'Server:', 'Server-', 'Client:' or 'Client-'`)
		end
	end

	for _, theme in themesFolder:GetChildren() do
		table.insert(data.Themes, theme)
	end

	if tonumber(moduleId) and not data.SilentStartup then
		print(`Requiring Madonis MainModule; Model URL: https://www.roblox.com/library/{moduleId}`)
	end

	local success, module = pcall(require, moduleId)

	--// Backup method for loading Madonis
	--if not success and type(moduleId) == "number" then -- ccuser44 was here
	--	warn(`Failed to load Madonis MainModule {moduleId} due to {module}! If this does not work please purchase the Madonis MainModule to your inventory. Using backup method...`)
	--	yxpcall(function()
	--		module = loadModuleAsset(moduleId)
	--	end, function(reason)
	--		warn(`Failed to load Madonis mainmodule {moduleId} via :LoadAsset() method due to {reason}! Loading the backup MainModule...`)
	--		yxpcall(function()
	--			module = assert(require(data.Backup), "Backup module returned invalid values!")
	--		end, function(reason)
	--			warn(`Failed to load Madonis backup MainModule {data.Backup} due to {reason}! If this does not work please purchase the Madonis backup MainModule to your inventory. Using backup method...`)
	--			yxpcall(function()
	--				module = loadModuleAsset(data.Backup)
	--			end, function(reason)
	--				module = nil
	--				warn(`FATAL ERROR! Failed to load Madonis backup MainModule {moduleId} via :LoadAsset() method due to {reason}! Madonis can't be booted up! Please contact the Madonis helpers immediately and add both the regular MainModule and the backup MainModule to your user&group inventory!`)
	--			end)
	--		end)
	--	end)
	--end
	local response = assert(success and module, "FATAL ERROR! Madonis bootstrap function is missing!")(data)

	if response == "SUCCESS" then
		if data.Settings and data.Settings.HideScript and not data.DebugMode and not RunService:IsStudio() then
			model.Parent = nil
			game:BindToClose(function()
				local oldArchivable = script.Archivable
				script.Archivable = true
				local clone = script:Clone()
				clone.Archivable = oldArchivable
				clone.Parent = loaderFolder
				model.Name = "Madonis_Loader"
				model.Parent = ServerScriptService
			end)
		end

		model.Name = "Madonis_Loader"
	else
		error(" !! Madonis MainModule failed to load !! ")
	end
end

																																																							--[[
--___________________________________________________________________________________________--
--___________________________________________________________________________________________--
--___________________________________________________________________________________________--
--___________________________________________________________________________________________--

					___________      .__         .___
					\_   _____/_____ |__|__  ___ |   | ____   ____
					 |    __)_\____ \|  \  \/  / |   |/    \_/ ___\
					 |        \  |_> >  |>    <  |   |   |  \  \___
					/_______  /   __/|__/__/\_ \ |___|___|  /\___  > /\
					        \/|__|            \/          \/     \/  \/
				  --------------------------------------------------------
				  Epix Incorporated. Not Everything is so Black and White.
				  --------------------------------------------------------

--___________________________________________________________________________________________--
--___________________________________________________________________________________________--
--___________________________________________________________________________________________--
--___________________________________________________________________________________________--
																																																							--]]
