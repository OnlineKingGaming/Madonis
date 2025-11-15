return function(Vargs, env)
	local server = Vargs.Server;
	local service = Vargs.Service;

	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	if env then setfenv(1, env) end


	return {

		Freecam = {
			Prefix = Settings.Prefix;
			Commands = {"freecam"};
			Args = {};
			Description = "Makes it so the target player(s)'s cam can move around freely (Press Shift+P, F, or DPadLeft to toggle freecam)";
			AdminLevel = "Tester";
			Function = function(plr: Player, args: {string})
				local plrgui = plr:FindFirstChildOfClass("PlayerGui")

				if not plrgui or plrgui:FindFirstChild("Freecam") then
					return
				end

				local freecam = Deps.Assets.Freecam:Clone()
				freecam.Enabled = true
				freecam.ResetOnSpawn = false
				freecam.Freecam.Disabled = false
				freecam.Parent = plrgui
				Functions.Notification("Notification", "Freecam has been enabled. Press Shift+P, F, or DPadLeft to toggle freecam on or off.", {plr}, 15)
			end
		};
	}
end