-- This file outlines the core dependencies and their expected locations within the Adonis project structure.
-- It is intended for informational, organizational, and potentially for build/verification purposes.

local Dependencies = {
    -- Roblox services utilized by the project
    RobloxServices = {
        "Workspace", "Players", "Lighting", "ServerStorage", "ReplicatedStorage",
        "ServerScriptService", "ReplicatedFirst", "ScriptContext", "LogService",
        "Teams", "SoundService", "StarterGui", "StarterPack", "StarterPlayer",
        "GroupService", "MarketplaceService", "TestService", "HttpService",
        "RunService", "InsertService", "NetworkServer", "TeleportService",
        "Debris", "ChatService", "GamePassService", "DataStoreService",
        "JointsService", -- Less common, but listed in Server.luau
    },

    -- Key Asset IDs for Adonis components
    AssetIDs = {
        MainModule_Release = 7510592873,
        MainModule_Nightly = 8612978896,
        MainModule_Backup = 17438792001,
        Loader = 7510622625,
    },

    -- General project files (typically in the root of the repository)
    ProjectFiles = {
        RojoProject = "default.project.json", -- Rojo build configuration
        License = "LICENSE.md",               -- Project license
        Readme = "README.md",                 -- Main documentation
        SecurityPolicy = "SECURITY.md",       -- Security reporting guidelines
    },

    -- Adonis Loader component
    Loader = {
        Path = "Loader/", -- Root path for Loader components, relative to Adonis_Loader model
        EntryPoint = "Loader/Loader/Loader.server.luau", -- Main script for the loader
        ConfigPath = "Loader/Config/",                 -- Path to configuration files
        Settings = "Loader/Config/Settings.luau",      -- Main settings module for the loader
        PluginsPath = "Loader/Config/Plugins/",        -- Folder for loader-time plugins (e.g., custom commands defined in Config)
        ThemesPath = "Loader/Config/Themes/",          -- Folder for loader-time themes
    },

    -- Adonis MainModule component
    MainModule = {
        Path = "MainModule/", -- Root path for MainModule components

        Server = {
            Path = "MainModule/Server/",
            EntryPoint = "MainModule/Server/Server.luau", -- Main server-side entry script
            CoreModulesPath = "MainModule/Server/Core/",  -- Location of core server modules
            CoreModules = { -- Key modules within MainModule/Server/Core/
                "Admin.luau", "Anti.luau", "Commands.luau", "Core.luau",
                "Functions.luau", "HTTP.luau", "Logs.luau", "Process.luau",
                "Remote.luau", "Socket.luau", "Variables.luau",
            },
            DependenciesPath = "MainModule/Server/Dependencies/", -- Location for server-specific dependencies
            PluginsPath = "MainModule/Server/Plugins/", -- Location for server-side plugins
            Plugins = { -- Examples of server-side plugins
                "Misc_Features.luau", -- Existing example for features like AutoClean
                -- Note: Some features like Weather and detailed lighting are integrated into Command modules (e.g., Admins.luau, Moderators.luau)
                -- and may rely on assets in ReplicatedStorage.
                -- Common custom feature plugins (examples if you were to build them, actual names may vary):
                -- "EconomyService.luau",  -- For handling player currency/money (if a custom system exists)
                "NotificationService.luau", -- For custom game notifications
                "PlayerStats.luau",     -- For tracking custom player statistics
                "InventorySystem.luau", -- For custom inventory items
                -- Add other server-side plugins here
            },
        },

        Client = {
            Path = "MainModule/Client/",
            EntryPoint = "MainModule/Client/Client.luau", -- Assumed main client-side entry script
            CoreModulesPath = "MainModule/Client/Core/",  -- Location of core client modules
            CoreModules = { -- Key modules within MainModule/Client/Core/
                "Anti.luau", "Core.luau", "Functions.luau", "Process.luau",
                "Remote.luau", "UI.luau", "Variables.luau",
            },
            UIPath = "MainModule/Client/UI/", -- General path for UI scripts and assets
            UI_Rbxmx_Path = "MainModule/Client/UI/BasicAdmin/", -- Specific path for common .rbxmx UI files
            UI_Rbxmx_Components = { -- Examples of .rbxmx UI files
                "Hint.rbxmx", "Message.rbxmx", "YesNoPrompt.rbxmx",
            },
            PluginsPath = "MainModule/Client/Plugins/", -- Folder for client-side plugins loaded by MainModule
            Plugins = { -- Examples of client-side plugins (often UI for server features)
                -- "WeatherUI.luau",       -- UI for weather information (if custom UI exists)
                -- "MoneyDisplay.luau",    -- UI for showing player balance (if custom economy UI exists)
                -- "CustomNotificationUI.luau", -- Client-side handling for custom notifications
                -- Add other client-side plugins here
            },
        },

        Shared = {
            Path = "MainModule/Shared/", -- Location for modules shared between server and client
            Modules = {
                "Service.luau", "Typechecker.luau", "Changelog.luau", "Credits.luau",
                "DLL.luau", "FiOne.luau", "KeycodeNames.luau",
            },
        },

        -- Important specific dependencies, mostly located in the server's dependency tree
        ImportantDependenciesInServerTree = {
            DataStoreServiceWrapper = "MainModule/Server/Dependencies/DataStoreService/", -- Folder containing DataStore logic (mock or actual)
            MockDataStoreService = "MainModule/Server/Dependencies/DataStoreService/MockDataStoreService/", -- Specific path to mock DS
            LoadstringModule = "MainModule/Server/Dependencies/Loadstring.luau",       -- Custom loadstring implementation
            FastNukeModule = "MainModule/Server/Dependencies/FastNuke.luau",           -- Dependency for nuke command
            ClientMoverScript = "MainModule/Server/Dependencies/ClientMover.client.luau", -- Client script, stored in server dependencies
            ClientLoaderScript = "MainModule/Server/Dependencies/ClientLoader.client.luau", -- Client script, stored in server dependencies
            DefaultSettings = "MainModule/Server/Dependencies/DefaultSettings.luau", -- Default settings if loader's settings fail
        },

        -- Assets in ReplicatedStorage often used by features
        ReplicatedStorageAssets = {
            WeatherResources = "ReplicatedStorage/WeatherResources", -- Folder for weather system assets
            TornadoModel = "ReplicatedStorage/Tornado",           -- Specific model for tornado/hurricane weather
            -- Add other key ReplicatedStorage assets here
        },
    },
}

return Dependencies
