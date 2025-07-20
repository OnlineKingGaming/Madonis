--[[
		- RO SOCKET -
	Module responsible for helping main module to send external API calls
	Be aware of what you modify, and make sure you know what you're doing.
	Running this in studio with a server update rate higher than 50 (per second) will lead in ratelimits.
	
	• Creator: @binarychunk
]]--
-----------------------------------------------
local Reader = {}
local Dictionary = require(script.Parent.Dictionary)
local Errors = require(script.Parent.Errors)
local Signature = require(script.Parent.Signature)
-----------------------------------------------
local HttpService = game:GetService("HttpService")
-----------------------------------------------
export type RequestResponse<T> = {
	Success: boolean?,
	StatusCode: number?,
	StatusMessage: string?,
	Headers: {[string?]: string},
	Body: T
}
export type ConnectionData = {
	UUID: string?,
	Socket: string?,
	Success: boolean?
}
export type DisconnectionData = {
	UUID: string?,
	Socket: string?
}

Reader.Debug = false
function Reader:SetServerIP<T>(ip: string?, ...: any?)
	-- Update the SOCKET_SERVER_URL with the new IP
	SOCKET_SERVER_URL = ip
	if Reader.Debug then print("[DEBUG][SetServerIP] Updated SOCKET_SERVER_URL to:", SOCKET_SERVER_URL) end
end
-----------------------------------------------
local WSS_PATTERN = "^wss://[%w%.]"
-----------------------------------------------
function Reader:FormatText<T>(text: string?, ...: any?): string
	assert(text, Errors.EMPTY_TEXT_TO_FORMAT)
	assert(typeof(text) == "string", string.format(Errors.INVALID_ARGUMENT_TYPE, "text", "string", typeof(text)))
	
	return tostring(`{Signature.Signature} {Signature.Splitter} {text}`)
end
assert(SOCKET_SERVER_URL ~= "", Reader:FormatText("Invalid backend URL. You can use heroku or replit to deploy the node backend!"))
function Reader:ValidateWSSLink<T>(link: string?, ...: any?): boolean
	assert(link, Errors.EMPTY_WSS_LINK_TO_VALIDATE)
	assert(typeof(link) == "string", string.format(Errors.INVALID_ARGUMENT_TYPE, "link", "string", typeof(link)))
	
	return string.match(link, WSS_PATTERN) and true or false
end

function Reader:Connect<T>(socket: string?, ...: any?)
	if Reader.Debug then print("[DEBUG][Connect] Called with socket:", socket) end
	local ValidLink = self:ValidateWSSLink(tostring(socket))
	if Reader.Debug then print("[DEBUG][Connect] ValidLink:", ValidLink) end
	if ValidLink == false then
		if Reader.Debug then warn("[DEBUG][Connect] Invalid socket link:", socket) end
		return error(self:FormatText(`Invalid socket link passed. Their format is: wss://hostname/path.`))
	end
	if Reader.Debug then print("[DEBUG][Connect] Sending RequestAsync to URL:", `{SOCKET_SERVER_URL}{Dictionary.Connection}`) end
	if Reader.Debug then print("[DEBUG][Connect] Request Body:", HttpService:JSONEncode({Socket = tostring(socket)})) end
	local Response : RequestResponse = HttpService:RequestAsync({
		Url = `{SOCKET_SERVER_URL}{Dictionary.Connection}`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({Socket = tostring(socket)})
	})
	if Reader.Debug then print("[DEBUG][Connect] Response:", Response) end

	if Response.Success == true then
		warn(self:FormatText(`Successfully connected!`))
		local DecodedSuccess, DecodedResult : ConnectionData = pcall(function() 
			return HttpService:JSONDecode(Response.Body)
		end)
		if Reader.Debug then print("[DEBUG][Connect] DecodedSuccess:", DecodedSuccess, "DecodedResult:", DecodedResult) end
		if DecodedSuccess == true then
			return DecodedResult
		elseif DecodedSuccess == false then
			if Reader.Debug then warn("[DEBUG][Connect] Failed to decode response:", DecodedResult) end
			return error(self:FormatText(`Failed to decode response | Error {tostring(DecodedResult)}`))
		end
	elseif Response.Success == false then
		if Reader.Debug then warn("[DEBUG][Connect] Failed to connect. Status Code:", Response.StatusCode) end
		return error(self:FormatText(`Failed to connect to socket {tostring(socket)} | Status Code {tostring(Response.StatusCode)}`))
	end
end
function Reader:Disconnect<T>(id: string?, ...: any?): boolean
	local ValidID = true
	
	local Response : RequestResponse = HttpService:RequestAsync({
		Url = `{SOCKET_SERVER_URL}{Dictionary.Disconnection}`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({UUID = tostring(id)})
	})
	
	if Response.Success == true then 
		local DecodedSuccess, DecodedResult : DisconnectionData = pcall(function() 
			return HttpService:JSONDecode(Response.Body)
		end)

		if DecodedSuccess == true then
			return DecodedResult
		elseif DecodedSuccess == false then
			return error(self:FormatText(`Failed to decode response | Error {tostring(DecodedResult)}`))
		end
	elseif Response.Success == false then
		return error(self:FormatText(`Failed to disconnect ID {tostring(id)} | Status Code {tostring(Response.StatusCode)}`))
	end
end
function Reader:Send<T>(id: string?, message: string?, ...): boolean
	if Reader.Debug then print("[DEBUG][Send] Called with id:", id, "message:", message, "...:", ...) end
	if typeof(message) == "table" then
		message = ...
	end
	if Reader.Debug then print("[DEBUG][Send] Sending RequestAsync to URL:", `{SOCKET_SERVER_URL}{Dictionary.Send}`) end
	if Reader.Debug then print("[DEBUG][Send] Request Body:", HttpService:JSONEncode({UUID = tostring(id), Message = tostring(message)})) end
	local Response : RequestResponse = HttpService:RequestAsync({
		Url = `{SOCKET_SERVER_URL}{Dictionary.Send}`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({UUID = tostring(id), Message = tostring(message)})
	})
	if Reader.Debug then print("[DEBUG][Send] Response:", Response) end

	if Response.Success == true then 
		local DecodedSuccess, DecodedResult = pcall(function() 
			return HttpService:JSONDecode(Response.Body)
		end)
		if Reader.Debug then print("[DEBUG][Send] DecodedSuccess:", DecodedSuccess, "DecodedResult:", DecodedResult) end
		if DecodedSuccess == true then
			return DecodedResult
		elseif DecodedSuccess == false then
			if Reader.Debug then warn("[DEBUG][Send] Failed to decode response:", DecodedResult) end
			return error(self:FormatText(`Failed to decode response | Error {tostring(DecodedResult)}`))
		end
	elseif Response.Success == false then
		if Reader.Debug then warn("[DEBUG][Send] Failed to send message. Status Code:", Response.StatusCode) end
		return error(self:FormatText(`Failed to send message! This socket is probably disconnected.`))
	end
end
function Reader:Get<T>(id: string?, ...): any
	wait(0.5)
	local Response : RequestResponse = HttpService:RequestAsync({
		Url = `{SOCKET_SERVER_URL}{Dictionary.Get}`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({UUID = tostring(id)})
	})
	if Response.Success == true then 
		local DecodedSuccess, DecodedResult = pcall(function() 
			return HttpService:JSONDecode(Response.Body)
		end)

		if DecodedSuccess == true then
			return DecodedResult
		elseif DecodedSuccess == false then
			return error(self:FormatText(`Failed to decode response | Error {tostring(DecodedResult)}`))
		end
	elseif Response.Success == false then
		return error(self:FormatText(`Failed to get messages! This socket is probably disconnected.`))
	end
end
function Reader:GetErrors<T>(id: string?, ...): any
	local Response : RequestResponse = HttpService:RequestAsync({
		Url = `{SOCKET_SERVER_URL}{Dictionary.GetErrors}`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({UUID = tostring(id)})
	})

	if Response.Success == true then 
		local DecodedSuccess, DecodedResult = pcall(function() 
			return HttpService:JSONDecode(Response.Body)
		end)

		if DecodedSuccess == true then
			return DecodedResult
		elseif DecodedSuccess == false then
			return error(self:FormatText(`Failed to decode response | Error {tostring(DecodedResult)}`))
		end
	elseif Response.Success == false then
		return error(self:FormatText(`Failed to get errors! This socket is probably disconnected.`))
	end
end

return Reader