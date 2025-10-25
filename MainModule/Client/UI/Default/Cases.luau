local DateTime = DateTime
client, service, Routine = nil, nil, nil

-- Helper function to format timestamp
local function formatTime(timestamp: number): string
	local dateTable = os.date("*t", timestamp)
	return string.format("%02d/%02d/%04d %02d:%02d:%02d",
		dateTable.month, dateTable.day, dateTable.year,
		dateTable.hour, dateTable.min, dateTable.sec)
end

-- Helper function to format time ago
local function formatTimeAgo(timestamp: number): string
	local timeDiff = os.time() - timestamp
	local minutes = math.floor(timeDiff / 60)
	if minutes < 60 then
		return `{minutes}m ago`
	else
		return `{math.floor(minutes/60)}h {minutes%60}m ago`
	end
end

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local client = client
	local service = client.Service
	local Routine = Routine

	local Cases = data.Cases or {}
	local viewingPlayer = service.Players.LocalPlayer
	local cmdPrefix = data.CmdPrefix or ";"
	local Variables = client.Variables

	-- Store current tab and position before removing window
	local previousTab = Variables.CasesActiveTab or "AllCases"
	local previousPosition

	-- Remove existing window if it exists to force refresh
	local existingWindow = client.UI.Get("CaseManagement")
	if existingWindow then
		if existingWindow.Object and existingWindow.Object:FindFirstChild("Drag") then
			previousPosition = existingWindow.Object.Drag.Position
			Variables.CasesWindowPosition = previousPosition
		end
		client.UI.Remove("CaseManagement")
	end

	-- Create new window
	local window = client.UI.Make("Window", {
		Name  = "CaseManagement";
		Title = "Case Management System";
		Icon = client.MatIcons and client.MatIcons["Folder"] or nil;
		Size  = {600, 500};
		AllowMultiple = false;
	})

	-- Restore window position
	if Variables.CasesWindowPosition and window and window.Object and window.Object:FindFirstChild("Drag") then
		window.Object.Drag.Position = Variables.CasesWindowPosition
	end

	if not window then
		warn("Failed to create Cases window")
		return
	end

	local tabFrame = window:Add("TabFrame", {
		Size = UDim2.new(1, -10, 1, -10);
		Position = UDim2.new(0, 5, 0, 5);
	})

	-- Create tabs
	local allCasesTab = tabFrame:NewTab("AllCases", {
		Text = "All Cases"
	})

	local myCasesTab = tabFrame:NewTab("MyCases", {
		Text = "My Cases"
	})

	local statsTab = tabFrame:NewTab("Statistics", {
		Text = "Statistics"
	})

	local helpTab = tabFrame:NewTab("Help", {
		Text = "Help"
	})

	-- Set up tab tracking to remember which tab the user is viewing
	local function setupTabTracking(tab, tabName)
		-- Store the tab name when it becomes visible
		tab:GetPropertyChangedSignal("Visible"):Connect(function()
			if tab.Visible then
				Variables.CasesActiveTab = tabName
			end
		end)
	end

	setupTabTracking(allCasesTab, "AllCases")
	setupTabTracking(myCasesTab, "MyCases")
	setupTabTracking(statsTab, "Statistics")
	setupTabTracking(helpTab, "Help")

	-- Restore the previously active tab
	task.defer(function()
		if previousTab == "AllCases" then
			allCasesTab:FocusTab()
		elseif previousTab == "MyCases" then
			myCasesTab:FocusTab()
		elseif previousTab == "Statistics" then
			statsTab:FocusTab()
		elseif previousTab == "Help" then
			helpTab:FocusTab()
		end
	end)

	-- Add refresh button to title bar
	local refreshButton
	if client.MatIcons and client.MatIcons["Refresh"] then
		refreshButton = window:AddTitleButton({
			Text = "";
			ToolTip = "Refresh cases";
			OnClick = function()
				client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
			end
		})
		refreshButton:Add("ImageLabel", {
			Size = UDim2.new(0, 20, 0, 20);
			Position = UDim2.new(0, 5, 0, 0);
			Image = client.MatIcons["Refresh"];
			BackgroundTransparency = 1;
		})
	else
		-- Fallback: Add text-based refresh button
		refreshButton = window:AddTitleButton({
			Text = "↻";
			ToolTip = "Refresh cases";
			OnClick = function()
				client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
			end
		})
	end

	-- Populate All Cases Tab
	do
		local scrollFrame = allCasesTab:Add("ScrollingFrame", {
			Size = UDim2.new(1, -10, 1, -50);
			Position = UDim2.new(0, 5, 0, 5);
			BackgroundTransparency = 0.8;
			BorderSizePixel = 0;
		})

		local count = 0
		local tempCases = {}

		-- Collect and sort cases
		for username, caseData in pairs(Cases) do
			if caseData and caseData.Pending and caseData.isIngame then
				count += 1
				table.insert(tempCases, {username = username, data = caseData})
			end
		end

		-- Sort by time (oldest first)
		table.sort(tempCases, function(a, b) return a.data.Time < b.data.Time end)

		-- Header
		allCasesTab:Add("TextLabel", {
			Text = `Active Cases: {count}`;
			Size = UDim2.new(1, -10, 0, 30);
			Position = UDim2.new(0, 5, 1, -40);
			BackgroundTransparency = 0.5;
			TextScaled = false;
			TextSize = 18;
			Font = Enum.Font.SourceSansBold;
		})

		if count > 0 then
			local yPos = 5

			for i, case in ipairs(tempCases) do
				local username = case.username
				local caseData = case.data
				local timeStr = formatTime(caseData.Time)
				local reasonStr = caseData.Reason or "No reason provided"
				local claimedBy = caseData.ClaimedBy
				local status = claimedBy and `CLAIMED by {claimedBy}` or "UNCLAIMED"

				local color = claimedBy and Color3.new(0.2, 0.8, 0.2) or Color3.new(1, 1, 0.3)

				-- Case container
				local caseFrame = scrollFrame:Add("Frame", {
					Size = UDim2.new(1, -10, 0, 80);
					Position = UDim2.new(0, 5, 0, yPos);
					BackgroundColor3 = color;
					BackgroundTransparency = 0.7;
					BorderSizePixel = 1;
					BorderColor3 = color;
				})

				-- Username label
				caseFrame:Add("TextLabel", {
					Text = `#{i} - {username}`;
					Size = UDim2.new(1, -10, 0, 20);
					Position = UDim2.new(0, 5, 0, 5);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					Font = Enum.Font.SourceSansBold;
					TextSize = 16;
				})

				-- Status label
				caseFrame:Add("TextLabel", {
					Text = `Status: {status}`;
					Size = UDim2.new(1, -10, 0, 15);
					Position = UDim2.new(0, 5, 0, 25);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 14;
				})

				-- Time label
				caseFrame:Add("TextLabel", {
					Text = `Created: {timeStr}`;
					Size = UDim2.new(1, -10, 0, 15);
					Position = UDim2.new(0, 5, 0, 40);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 14;
				})

				-- Reason label
				caseFrame:Add("TextLabel", {
					Text = `Reason: {reasonStr}`;
					Size = UDim2.new(1, -120, 0, 15);
					Position = UDim2.new(0, 5, 0, 55);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 14;
					TextTruncate = Enum.TextTruncate.AtEnd;
				})

				if claimedBy then
					-- Unclaim button
					local unclaimBtn = caseFrame:Add("TextButton", {
						Text = "Unclaim";
						Size = UDim2.new(0, 100, 0, 25);
						Position = UDim2.new(1, -215, 0, 50);
						BackgroundColor3 = Color3.new(0.2, 0.4, 0.8);
						TextColor3 = Color3.new(1, 1, 1);
						Font = Enum.Font.SourceSansBold;
						TextSize = 14;
					})
					unclaimBtn.MouseButton1Click:Connect(function()
						client.Remote.Send('ProcessCommand', `{cmdPrefix}unclaim {username}`)
						task.wait(0.3)
						client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
					end)

					-- Close Case button
					local closeBtn = caseFrame:Add("TextButton", {
						Text = "Close Case";
						Size = UDim2.new(0, 100, 0, 25);
						Position = UDim2.new(1, -110, 0, 50);
						BackgroundColor3 = Color3.new(0.8, 0.2, 0.2);
						TextColor3 = Color3.new(1, 1, 1);
						Font = Enum.Font.SourceSansBold;
						TextSize = 14;
					})
					closeBtn.MouseButton1Click:Connect(function()
						client.Remote.Send('ProcessCommand', `{cmdPrefix}close {username}`)
						task.wait(0.3)
						client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
					end)
				else
					-- Claim button
					local claimBtn = caseFrame:Add("TextButton", {
						Text = "Claim";
						Size = UDim2.new(0, 100, 0, 25);
						Position = UDim2.new(1, -110, 0, 50);
						BackgroundColor3 = Color3.new(0.2, 0.4, 0.8);
						TextColor3 = Color3.new(1, 1, 1);
						Font = Enum.Font.SourceSansBold;
						TextSize = 14;
					})
					claimBtn.MouseButton1Click:Connect(function()
						client.Remote.Send('ProcessCommand', `{cmdPrefix}claim {username}`)
						task.wait(0.3)
						client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
					end)
				end

				yPos = yPos + 85
			end

			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos)
		else
			scrollFrame:Add("TextLabel", {
				Text = "No active cases found.\n\nCases appear when players use !help";
				Size = UDim2.new(1, -20, 1, -20);
				Position = UDim2.new(0, 10, 0, 10);
				BackgroundTransparency = 1;
				TextSize = 16;
				TextWrapped = true;
			})
		end
	end

	-- Populate My Cases Tab
	do
		local scrollFrame = myCasesTab:Add("ScrollingFrame", {
			Size = UDim2.new(1, -10, 1, -50);
			Position = UDim2.new(0, 5, 0, 5);
			BackgroundTransparency = 0.8;
			BorderSizePixel = 0;
		})

		local count = 0
		local tempCases = {}

		-- Build list of cases claimed by this moderator
		for username, caseData in pairs(Cases) do
			if caseData and caseData.Pending and caseData.isIngame and caseData.ClaimedBy == viewingPlayer.Name then
				count += 1
				table.insert(tempCases, {username = username, data = caseData})
			end
		end

		-- Sort by claim time (most recent first)
		table.sort(tempCases, function(a, b)
			return (a.data.ClaimedTime or 0) > (b.data.ClaimedTime or 0)
		end)

		-- Header
		myCasesTab:Add("TextLabel", {
			Text = `My Cases: {count}`;
			Size = UDim2.new(1, -10, 0, 30);
			Position = UDim2.new(0, 5, 1, -40);
			BackgroundTransparency = 0.5;
			TextScaled = false;
			TextSize = 18;
			Font = Enum.Font.SourceSansBold;
		})

		if count > 0 then
			local yPos = 5

			for i, case in ipairs(tempCases) do
				local username = case.username
				local caseData = case.data
				local timeStr = formatTime(caseData.Time)
				local claimedTimeStr = formatTime(caseData.ClaimedTime or caseData.Time)
				local reasonStr = caseData.Reason or "No reason provided"
				local timeAgo = formatTimeAgo(caseData.ClaimedTime or caseData.Time)

				local color = Color3.new(0.2, 0.8, 0.2)

				-- Case container
				local caseFrame = scrollFrame:Add("Frame", {
					Size = UDim2.new(1, -10, 0, 95);
					Position = UDim2.new(0, 5, 0, yPos);
					BackgroundColor3 = color;
					BackgroundTransparency = 0.7;
					BorderSizePixel = 1;
					BorderColor3 = color;
				})

				-- Username label
				caseFrame:Add("TextLabel", {
					Text = `{username}`;
					Size = UDim2.new(1, -10, 0, 20);
					Position = UDim2.new(0, 5, 0, 5);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					Font = Enum.Font.SourceSansBold;
					TextSize = 16;
				})

				-- Created time label
				caseFrame:Add("TextLabel", {
					Text = `Created: {timeStr}`;
					Size = UDim2.new(1, -10, 0, 15);
					Position = UDim2.new(0, 5, 0, 25);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 14;
				})

				-- Claimed time label
				caseFrame:Add("TextLabel", {
					Text = `Claimed: {claimedTimeStr} ({timeAgo})`;
					Size = UDim2.new(1, -10, 0, 15);
					Position = UDim2.new(0, 5, 0, 40);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 14;
				})

				-- Reason label
				caseFrame:Add("TextLabel", {
					Text = `Reason: {reasonStr}`;
					Size = UDim2.new(1, -120, 0, 30);
					Position = UDim2.new(0, 5, 0, 55);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 14;
					TextWrapped = true;
				})

				-- Close button
				local btn = caseFrame:Add("TextButton", {
					Text = "Close Case";
					Size = UDim2.new(0, 100, 0, 25);
					Position = UDim2.new(1, -110, 0, 65);
					BackgroundColor3 = Color3.new(0.8, 0.2, 0.2);
					TextColor3 = Color3.new(1, 1, 1);
					Font = Enum.Font.SourceSansBold;
					TextSize = 14;
				})

				btn.MouseButton1Click:Connect(function()
					client.Remote.Send('ProcessCommand', `{cmdPrefix}close {username}`)
					task.wait(0.3)
					client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
				end)

				yPos = yPos + 100
			end

			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos)
		else
			scrollFrame:Add("TextLabel", {
				Text = "You have no claimed cases.\n\nGo to 'All Cases' to claim available cases";
				Size = UDim2.new(1, -20, 1, -20);
				Position = UDim2.new(0, 10, 0, 10);
				BackgroundTransparency = 1;
				TextSize = 16;
				TextWrapped = true;
			})
		end
	end

	-- Populate Statistics Tab
	do
		local scrollFrame = statsTab:Add("ScrollingFrame", {
			Size = UDim2.new(1, -10, 1, -10);
			Position = UDim2.new(0, 5, 0, 5);
			BackgroundTransparency = 0.8;
			BorderSizePixel = 0;
		})

		local totalCases = 0
		local claimedCases = 0
		local moderatorStats = {}

		-- Analyze cases
		for username, caseData in pairs(Cases) do
			if caseData and caseData.Pending and caseData.isIngame then
				totalCases += 1
				if caseData.ClaimedBy then
					claimedCases += 1
					moderatorStats[caseData.ClaimedBy] = (moderatorStats[caseData.ClaimedBy] or 0) + 1
				end
			end
		end

		local unclaimedCases = totalCases - claimedCases
		local claimRate = (claimedCases > 0 and totalCases > 0) and math.floor((claimedCases / totalCases) * 100) or 0

		local yPos = 10

		-- Summary section
		scrollFrame:Add("TextLabel", {
			Text = "Case Summary";
			Size = UDim2.new(1, -20, 0, 25);
			Position = UDim2.new(0, 10, 0, yPos);
			BackgroundTransparency = 1;
			Font = Enum.Font.SourceSansBold;
			TextSize = 20;
			TextXAlignment = "Left";
		})
		yPos = yPos + 30

		for i, stat in ipairs({
			{`Total Active Cases: {totalCases}`, Color3.new(0.8, 0.8, 1)},
			{`Claimed Cases: {claimedCases}`, Color3.new(0.4, 1, 0.4)},
			{`Unclaimed Cases: {unclaimedCases}`, Color3.new(1, 1, 0.4)},
			{`Claim Rate: {claimRate}%`, Color3.new(0.8, 0.8, 1)},
		}) do
			local frame = scrollFrame:Add("Frame", {
				Size = UDim2.new(1, -20, 0, 30);
				Position = UDim2.new(0, 10, 0, yPos);
				BackgroundColor3 = stat[2];
				BackgroundTransparency = 0.7;
				BorderSizePixel = 1;
				BorderColor3 = stat[2];
			})

			frame:Add("TextLabel", {
				Text = stat[1];
				Size = UDim2.new(1, -10, 1, 0);
				Position = UDim2.new(0, 5, 0, 0);
				BackgroundTransparency = 1;
				TextXAlignment = "Left";
				TextSize = 16;
			})

			yPos = yPos + 35
		end

		yPos = yPos + 15

		-- Moderator activity section
		scrollFrame:Add("TextLabel", {
			Text = "Moderator Activity";
			Size = UDim2.new(1, -20, 0, 25);
			Position = UDim2.new(0, 10, 0, yPos);
			BackgroundTransparency = 1;
			Font = Enum.Font.SourceSansBold;
			TextSize = 20;
			TextXAlignment = "Left";
		})
		yPos = yPos + 30

		if next(moderatorStats) then
			-- Convert to array and sort by case count
			local modArray = {}
			for modName, count in pairs(moderatorStats) do
				table.insert(modArray, {name = modName, count = count})
			end
			table.sort(modArray, function(a, b) return a.count > b.count end)

			for i, mod in ipairs(modArray) do
				local percentage = math.floor((mod.count / totalCases) * 100)

				local frame = scrollFrame:Add("Frame", {
					Size = UDim2.new(1, -20, 0, 30);
					Position = UDim2.new(0, 10, 0, yPos);
					BackgroundColor3 = Color3.new(0.4, 0.7, 1);
					BackgroundTransparency = 0.7;
					BorderSizePixel = 1;
					BorderColor3 = Color3.new(0.4, 0.7, 1);
				})

				frame:Add("TextLabel", {
					Text = `{i}. {mod.name}: {mod.count} case(s) ({percentage}%)`;
					Size = UDim2.new(1, -10, 1, 0);
					Position = UDim2.new(0, 5, 0, 0);
					BackgroundTransparency = 1;
					TextXAlignment = "Left";
					TextSize = 16;
				})

				yPos = yPos + 35
			end
		else
			scrollFrame:Add("TextLabel", {
				Text = "No moderators currently handling cases.";
				Size = UDim2.new(1, -20, 0, 30);
				Position = UDim2.new(0, 10, 0, yPos);
				BackgroundTransparency = 1;
				TextSize = 16;
			})
			yPos = yPos + 35
		end

		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
	end

	-- Populate Help Tab
	do
		local scrollFrame = helpTab:Add("ScrollingFrame", {
			Size = UDim2.new(1, -10, 1, -10);
			Position = UDim2.new(0, 5, 0, 5);
			BackgroundTransparency = 0.8;
			BorderSizePixel = 0;
		})

		local helpSections = {
			{
				title = "📋 Overview",
				items = {
					"The Case Management System helps moderators efficiently handle player support requests.",
					"When players type !help in chat, a new case is created and appears in this system.",
					"This GUI automatically refreshes every 10 seconds to show the latest cases.",
				}
			},
			{
				title = "🚀 Getting Started",
				items = {
					"1. Browse unclaimed cases in the 'All Cases' tab (shown in yellow)",
					"2. Click the 'Claim' button on a case to take ownership",
					"3. Once claimed, the case turns green and appears in 'My Cases'",
					"4. Help the player with their issue via chat or direct message",
					"5. When resolved, click 'Close Case' to remove it from the system",
				}
			},
			{
				title = "💬 Commands Reference",
				items = {
					`{cmdPrefix}cases - Open this case management window`,
					`{cmdPrefix}cases all - View all active cases`,
					`{cmdPrefix}cases mine - View only your claimed cases`,
					`{cmdPrefix}cases stats - View case statistics`,
					`{cmdPrefix}claim <username> - Claim a player's help request`,
					`{cmdPrefix}unclaim <username> - Close/release a case`,
				}
			},
			{
				title = "🎨 Color System",
				items = {
					"🟡 Yellow Cases - Unclaimed and waiting for a moderator",
					"🟢 Green Cases - Claimed and being handled by a moderator",
					"The case color helps you quickly identify which cases need attention.",
				}
			},
			{
				title = "⚠️ Important Rules",
				items = {
					"• You can only close cases you've personally claimed",
					"• Claiming automatically starts tracking the player for you",
					"• Cases are permanently removed when closed (not just unclaimed)",
					"• Multiple moderators can view cases, but only one can claim each",
					"• Use the ↻ refresh button or wait for auto-refresh to see updates",
				}
			},
			{
				title = "📊 Tabs Explained",
				items = {
					"All Cases - See every pending case from all players currently in-game",
					"My Cases - View only the cases you've claimed with detailed timing info",
					"Statistics - Overview of team performance and moderator activity",
					"Help - You are here! Information about using this system",
				}
			},
		}

		local yPos = 10

		for _, section in ipairs(helpSections) do
			-- Section title
			scrollFrame:Add("TextLabel", {
				Text = section.title;
				Size = UDim2.new(1, -20, 0, 25);
				Position = UDim2.new(0, 10, 0, yPos);
				BackgroundTransparency = 1;
				Font = Enum.Font.SourceSansBold;
				TextSize = 18;
				TextXAlignment = "Left";
			})
			yPos = yPos + 30

			-- Section items
			for _, item in ipairs(section.items) do
				local textLabel = scrollFrame:Add("TextLabel", {
					Text = item;
					Size = UDim2.new(1, -30, 0, 0);
					Position = UDim2.new(0, 20, 0, yPos);
					BackgroundTransparency = 1;
					TextSize = 14;
					TextXAlignment = "Left";
					TextWrapped = true;
					TextYAlignment = "Top";
				})

				-- Calculate text height
				local textBounds = service.TextService:GetTextSize(item, 14, Enum.Font.SourceSans, Vector2.new(scrollFrame.AbsoluteSize.X - 50, 10000))
				local height = math.max(20, textBounds.Y + 5)
				textLabel.Size = UDim2.new(1, -30, 0, height)

				yPos = yPos + height
			end

			yPos = yPos + 15
		end

		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
	end

	-- Auto-update loop (refreshes every 10 seconds)
	task.spawn(function()
		while window and window.Object and window.Object.Parent do
			task.wait(10)
			if window and window.Object and window.Object.Parent then
				client.Remote.Send('ProcessCommand', `{cmdPrefix}cases`)
			end
		end
	end)

	window:Ready()
end