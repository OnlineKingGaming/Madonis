client, service = nil, nil

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local TraineeData = data.TraineeData
	local SessionId = data.SessionId
	local UpdateType = data.UpdateType
	local NewCommand = data.NewCommand
	local gIndex = data.gIndex
	local gTable = data.gTable
	
	local window, mainFrame, headerFrame, timerLabel, traineeLabel, commandFrame
	local commandScroller, endButton, refreshButton, statusLabel
	local commandCount, timeRemaining, gTable
	local lastRefreshTime = 0
	
	local function formatTime(seconds)
		if seconds <= 0 then
			return "00:00"
		end
		local minutes = math.floor(seconds / 60)
		local secs = seconds % 60
		return string.format("%02d:%02d", minutes, secs)
	end
	
	local function updateTimer()
		-- Always use the current window's gTable for the most up-to-date data
		local currentGTable = window and window.gTable
		local currentTraineeData = currentGTable and currentGTable.TraineeData
		if currentTraineeData then
			local remaining = currentTraineeData.EndTime - os.time()
			timeRemaining = math.max(0, remaining)
			
			if timerLabel then
				timerLabel.Text = `⏱️ Time Remaining: {formatTime(timeRemaining)}`
				
				-- Change color based on time remaining
				if timeRemaining <= 60 then -- Less than 1 minute
					timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red
				elseif timeRemaining <= 300 then -- Less than 5 minutes  
					timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Orange
				else
					timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
				end
			end
			
			if statusLabel then
				statusLabel.Text = `📊 Commands: {#currentTraineeData.CommandLog} | Status: {timeRemaining > 0 and "Active" or "Expired"}`
			end
		end
	end
	
	local function refreshCommandList()
		-- Debounce to prevent excessive refresh calls
		local now = os.clock()
		if now - lastRefreshTime < 0.1 then -- Only allow refresh every 100ms
			return
		end
		lastRefreshTime = now
		
		-- Always use the current window's gTable for the most up-to-date data
		local currentGTable = window and window.gTable
		local currentTraineeData = currentGTable and currentGTable.TraineeData
		print("[TrainingMonitor] refreshCommandList called")
		print(`[TrainingMonitor] window.gTable exists: {currentGTable and "yes" or "no"}`)
		if currentGTable and currentGTable.TraineeData then
			print(`[TrainingMonitor] window.gTable.TraineeData has {#currentGTable.TraineeData.CommandLog} commands`)
		end
		if currentTraineeData then
			print(`[TrainingMonitor] Using data with {#currentTraineeData.CommandLog} commands`)
		else
			print("[TrainingMonitor] No currentTraineeData found")
		end
		if commandScroller and currentTraineeData then
			commandScroller:ClearAllChildren()
			
			local commandList = {}
			
			-- Add commands in reverse order (newest first)
			for i = #currentTraineeData.CommandLog, 1, -1 do
				local cmd = currentTraineeData.CommandLog[i]
				local timeStr = os.date("%H:%M:%S", cmd.Time)
				local levelColor = ""
				
				-- Color code by admin level
				if cmd.AdminLevel >= 200 then
					levelColor = "🔴 " -- Red for admin+
				elseif cmd.AdminLevel >= 100 then
					levelColor = "🟡 " -- Yellow for moderator
				else
					levelColor = "🟢 " -- Green for player
				end
				
				table.insert(commandList, {
					Text = `{levelColor}[{timeStr}] {cmd.Command}`,
					Desc = `Admin Level: {cmd.AdminLevel}`
				})
			end
			
			if #commandList == 0 then
				table.insert(commandList, {
					Text = "No commands executed yet...",
					Desc = "Waiting for trainee activity"
				})
			end
			
			commandScroller:GenerateList(commandList, {
				RichTextAllowed = false,
				TextSelectable = true
			})
		end
	end
	
	local function endTraining()
		-- Always use the current window's gTable for the most up-to-date data
		local currentGTable = window and window.gTable
		local currentTraineeData = currentGTable and currentGTable.TraineeData
		if currentTraineeData and currentTraineeData.Trainee and client.Remote then
			-- Show training summary before ending
			local commandsExecuted = #currentTraineeData.CommandLog
			local duration = os.time() - currentTraineeData.StartTime
			local minutes = math.floor(duration / 60)
			local seconds = duration % 60
			
			local summaryText = `Training Summary for {currentTraineeData.Trainee.DisplayName}:\n\n` ..
				`• Duration: {minutes}m {seconds}s\n` ..
				`• Commands Executed: {commandsExecuted}\n` ..
				`• Session ID: {currentTraineeData.SessionId}\n\n` ..
				"Are you sure you want to end this training session?"
			
			-- Show confirmation with summary
			local confirm = client.UI.Make("YesNoPrompt", {
				Title = "End Training Session";
				Question = summaryText;
			})
			
			if confirm == "Yes" then
				local success = client.Remote.Send("EndTrainingSession", currentTraineeData.SessionId, currentTraineeData)
				if success then
					window:Close()
				end
			end
		end
	end

	-- Create main window
	window = client.UI.Make("Window", {
		Name = "TrainingMonitor";
		Title = `Training Monitor - {TraineeData and TraineeData.Trainee.DisplayName or "Unknown"}`;
		Icon = "rbxassetid://6022668955"; -- School icon
		Size = {450, 350};
		MinSize = {400, 300};
		OnClose = function()
			-- Optional cleanup when window is closed
		end
	})

	-- Header section
	headerFrame = window:Add("Frame", {
		Size = UDim2.new(1, -10, 0, 80);
		Position = UDim2.new(0, 5, 0, 5);
		BackgroundTransparency = 0.8;
		BackgroundColor3 = Color3.fromRGB(50, 50, 50);
		BorderSizePixel = 0;
	})

	-- Trainee info
	traineeLabel = headerFrame:Add("TextLabel", {
		Size = UDim2.new(1, -10, 0, 25);
		Position = UDim2.new(0, 5, 0, 5);
		BackgroundTransparency = 1;
		TextColor3 = Color3.fromRGB(255, 255, 255);
		TextXAlignment = Enum.TextXAlignment.Left;
		TextScaled = true;
		Font = Enum.Font.SourceSansBold;
		Text = TraineeData and `👤 Trainee: {TraineeData.Trainee.DisplayName} (@{TraineeData.Trainee.Name})` or "Unknown trainee";
	})

	-- Timer display
	timerLabel = headerFrame:Add("TextLabel", {
		Size = UDim2.new(1, -10, 0, 25);
		Position = UDim2.new(0, 5, 0, 30);
		BackgroundTransparency = 1;
		TextColor3 = Color3.fromRGB(255, 255, 255);
		TextXAlignment = Enum.TextXAlignment.Left;
		TextScaled = true;
		Font = Enum.Font.SourceSansBold;
		Text = "⏱️ Time Remaining: 00:00";
	})

	-- Status label
	statusLabel = headerFrame:Add("TextLabel", {
		Size = UDim2.new(1, -10, 0, 20);
		Position = UDim2.new(0, 5, 0, 55);
		BackgroundTransparency = 1;
		TextColor3 = Color3.fromRGB(200, 200, 200);
		TextXAlignment = Enum.TextXAlignment.Left;
		TextScaled = true;
		Font = Enum.Font.SourceSans;
		Text = "📊 Commands: 0 | Status: Active";
	})

	-- Command log section
	commandFrame = window:Add("Frame", {
		Size = UDim2.new(1, -10, 1, -125);
		Position = UDim2.new(0, 5, 0, 90);
		BackgroundTransparency = 0.9;
		BackgroundColor3 = Color3.fromRGB(30, 30, 30);
		BorderSizePixel = 0;
	})

	local commandTitle = commandFrame:Add("TextLabel", {
		Size = UDim2.new(1, -10, 0, 25);
		Position = UDim2.new(0, 5, 0, 5);
		BackgroundTransparency = 1;
		TextColor3 = Color3.fromRGB(255, 255, 255);
		TextXAlignment = Enum.TextXAlignment.Left;
		Font = Enum.Font.SourceSansBold;
		Text = "📝 Command Log (Real-time)";
	})

	commandScroller = commandFrame:Add("ScrollingFrame", {
		Size = UDim2.new(1, -10, 1, -35);
		Position = UDim2.new(0, 5, 0, 30);
		BackgroundTransparency = 0.5;
		BackgroundColor3 = Color3.fromRGB(20, 20, 20);
		BorderSizePixel = 0;
		ScrollBarThickness = 4;
		List = {};
	})

	-- Control buttons
	endButton = window:Add("TextButton", {
		Size = UDim2.new(0, 100, 0, 25);
		Position = UDim2.new(1, -110, 1, -30);
		BackgroundColor3 = Color3.fromRGB(200, 50, 50);
		BorderSizePixel = 0;
		TextColor3 = Color3.fromRGB(255, 255, 255);
		Font = Enum.Font.SourceSansBold;
		Text = "End Training";
		OnClick = endTraining
	})

	refreshButton = window:Add("TextButton", {
		Size = UDim2.new(0, 80, 0, 25);
		Position = UDim2.new(1, -200, 1, -30);
		BackgroundColor3 = Color3.fromRGB(50, 100, 200);
		BorderSizePixel = 0;
		TextColor3 = Color3.fromRGB(255, 255, 255);
		Font = Enum.Font.SourceSans;
		Text = "Refresh";
		OnClick = function()
			updateTimer()
			refreshCommandList()
			
			-- Debug: Print current training data
			local currentGTable = window and window.gTable
			local currentData = currentGTable and currentGTable.TraineeData
			if currentData then
				print(`[TrainingMonitor] Commands in log: {#currentData.CommandLog}`)
				for i, cmd in currentData.CommandLog do
					print(`  {i}: {cmd.Command} (Level: {cmd.AdminLevel}) at {os.date("%H:%M:%S", cmd.Time)}`)
				end
			else
				print("[TrainingMonitor] No training data available")
			end
		end
	})

	-- Store functions in gTable so they can be accessed by the update handler
	gTable = window.gTable
	gTable.TraineeData = TraineeData  -- Initialize with starting data
	gTable.refreshCommandList = refreshCommandList
	gTable.updateTimer = updateTimer
	gTable.commandScroller = commandScroller
	
	-- Initial setup - this will now use gTable.TraineeData
	updateTimer()
	refreshCommandList()
	
	window:Ready()
	
	-- Start timer update loop
	task.spawn(function()
		while window and window.gTable and window.gTable.Active and timeRemaining > 0 do
			task.wait(1)
			updateTimer()
		end
		
		-- Training session ended
		local currentGTable = window and window.gTable
		if currentGTable and currentGTable.Active then
			statusLabel.Text = "📊 Training Session Ended"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			timerLabel.Text = "⏱️ Training Complete"
			timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end)

	-- Start periodic data refresh loop (backup mechanism)
	task.spawn(function()
		local refreshInterval = 10 -- Refresh every 10 seconds as backup
		local lastCommandCount = 0
		
		while window and window.gTable and window.gTable.Active do
			task.wait(refreshInterval)
			
			local currentGTable = window and window.gTable
			if not currentGTable or not currentGTable.Active then
				break
			end
			
			local currentTraineeData = currentGTable.TraineeData
			if currentTraineeData and currentTraineeData.SessionId then
				-- Fetch fresh data from server
				local freshData = client.Remote.Get("GetTrainingSession", currentTraineeData.SessionId)
				if freshData and freshData.CommandLog then
					local newCommandCount = #freshData.CommandLog
					local oldCommandCount = currentTraineeData.CommandLog and #currentTraineeData.CommandLog or 0
					
					-- Only update if we got different data (prevents unnecessary updates)
					if newCommandCount ~= oldCommandCount then
						print(`[TrainingMonitor] Periodic refresh found {newCommandCount - oldCommandCount} new commands`)
						currentGTable.TraineeData = freshData
						refreshCommandList()
						updateTimer()
						
						-- Scroll to bottom if new commands were added
						if newCommandCount > oldCommandCount and commandScroller then
							task.wait(0.1)
							if commandScroller.CanvasSize.Y.Offset > commandScroller.AbsoluteSize.Y then
								commandScroller.CanvasPosition = Vector2.new(0, commandScroller.CanvasSize.Y.Offset)
							end
						end
					end
				else
					print("[TrainingMonitor] Periodic refresh: Failed to get fresh data or session ended")
				end
			end
		end
		
		print("[TrainingMonitor] Periodic refresh loop ended")
	end)	-- Handle updates from server (initial load only)
	if UpdateType == "CommandExecuted" and NewCommand then
		-- Refresh the command list when new command is received
		refreshCommandList()
		
		-- Scroll to bottom to show newest command
		task.wait(0.1)
		if commandScroller.CanvasSize.Y.Offset > commandScroller.AbsoluteSize.Y then
			commandScroller.CanvasPosition = Vector2.new(0, commandScroller.CanvasSize.Y.Offset)
		end
	end
end