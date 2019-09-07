
--[[ 
    Sanctuary Shit List
        add dumb people to it, and be notified when you hover over them!

    IDEAS:
    Chat warning when joining a party with a Listed member, or a Listed player joins party?

    Popup for entering reason?
    ref https://wowwiki.fandom.com/wiki/Creating_simple_pop-up_dialog_boxes

    Add button to right-click menu for adding/removing?
    ref https://www.wowinterface.com/forums/showthread.php?t=27044
    or https://www.wowinterface.com/downloads/info13289-AddFriend.html
    note - potentially introduces taint into these menus - ref https://wowwiki.fandom.com/wiki/Secure_Execution_and_Tainting
]] --

-- basic local vars, addon name and anonymous namespace (unused)
local addon, _ns = ...
-- our main table
local SSL = {}
-- the current player (playerRealm might be nil)
local playerName, playerRealm = UnitName("player")

-- saved vars: savedLists, subscribedTo, subChannel, subscribers
-- local copies of saved vars
SSL.shitList = {}
SSL.subscribedTo = {}
SSL.subscribers = {}
SSL.subChannel = {}

-- table containing our event handlers
SSL.eventHandlers = {}

-- other locals
local version = "0.3.0-classic"
local currentlyHandshaking = {}

-- setup event handler to register when we are loaded, and add pointer to saved var containing list
SSL.eventHandlers.ADDON_LOADED = function(self, event, name)
    if name ~= addon then
        return -- event didn't fire for this addon
    end
    if savedLists == nil then
        savedLists = {} -- initialize list if it hasn't been already
    end
    SSL.shitList = savedLists -- set up local reference to saved list
    
    if subscribedTo == nil then
        subscribedTo = {}
    end
    SSL.subscribedTo = subscribedTo

    if subscribers == nil then
        subscribers = {}
    end
    SSL.subscribers = subscribers

    if subChannel == nil then
        subChannel = SSL.GenerateSubChannel()
    end
    SSL.subChannel = subChannel
    
    SSL.Print("Saved variables loaded")
end

function SSL.GenerateSubChannel()
    return "SSL" .. playerName .. "HASH GOES HERE"
end

SSL.eventHandlers.GROUP_FORMED = function(self, event, ...)
    -- print(event)
end
SSL.eventHandlers.GROUP_JOINED = function(self, event, ...)
    -- print(event)
end
SSL.eventHandlers.GROUP_ROSTER_UPDATE = function(self, event, ...)
    -- TODO: this fires multiple times when groups change, unknown what causes this
    SSL.CheckGroupMembers()
end

function SSL.CheckGroupMembers()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers()-1 do
            local name = UnitName("raid" .. i)
            if not (name == nil) and not (SSL.shitList[name] == nil) then
                SSL.ListedPartyMemberFound(name, SSL.shitList[name].reason)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers()-1 do
            local name = UnitName("party" .. i)
            if not (name == nil) and not (SSL.shitList[name] == nil) then
                SSL.ListedPartyMemberFound(name, SSL.shitList[name].reason)
            end
        end
    else
        -- print("not in party or raid")
    end
end

function SSL.ListedPartyMemberFound(name, reason)
    print ("Party member " .. name .. " is on the List!")
    -- funny, but strictly not necessary :)
    -- SendChatMessage(name .. " is on my shitlist because " .. reason .. "!", "PARTY")
end

-- set up our main event bus
SSL.frame = CreateFrame("Frame") -- need a frame to register event handlers
SSL.frame:SetScript("OnEvent", function(self, event, ...)
    if not (SSL.eventHandlers[event] == nil) then
        SSL.eventHandlers[event](self, event, ...)
    end
end)

SSL.frame:RegisterEvent("ADDON_LOADED") -- register event handlers
-- SSL.frame:RegisterEvent("GROUP_FORMED")
-- SSL.frame:RegisterEvent("GROUP_JOINED")
SSL.frame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- add a name to the list, with a given reason (or not)
function SSL.AddName(name, reason)
    if SSL.shitList[name] == nil then
        SSL.Print("Adding " .. name .. " to the List.")
        local newEntry = {}
        newEntry.ts = time() -- we need a timestamp in order to track changes for proper list syncing later
        newEntry.author = playerName
        newEntry.unitName = name
        if reason then
            newEntry.reason = reason
        else
            newEntry.reason = "No reason"
        end
        SSL.shitList[name] = newEntry
    else
        SSL.Print(name .. " is already present in the list, added at " .. SSL.shitList[name].ts)
    end
end

function SSL.RemoveName(name)
    if not (SSL.shitList[name] == nil) then
        SSL.shitList[name] = nil
        SSL.Print(name .. " has been removed from the list.")
    else
        SSL.Print(name .. " is not present in the list.")
    end
end

function SSL.AddTarget(reason)
    local name,realm = UnitName("target")
    if not (name == nil) then
        SSL.AddName(name, reason)
    else
        SSL.Print("No target found")
    end
end

function SSL.RemoveTarget()
    local name,realm = UnitName("target")
    if not (name == nil) then
        SSL.RemoveName(name)
    else
        SSL.Print("No target found")
    end
end

function SSL.PrintList()
    if not (next(SSL.shitList) == nil) then
        for key, value in pairs(SSL.shitList) do
            print(value.ts, value.unitName, value.author, value.reason)
        end
    else
        SSL.Print("List is empty")
    end
end

function SSL.ClearList()
    if not (next(SSL.shitList) == nil) then
        for k,v in pairs(SSL.shitList) do SSL.shitList[k]=nil end
        SSL.Print("List emptied")
    else
        SSL.Print("List is already empty")
    end
end

--[[
    Syncing list across players
        - cycle party members
        - determine if selected member has SSL installed (handshake)
        - establish sending/receiving order
        - proceed with either method A or method B in syncing list(s) with the selected party member

        METHOD A - one list, synced between all
            -- sending
            - check when last we synced with selected party member
            - send all changes that are more recent than last sync
            -- receiving
            - delay until all sending between both players has finished
            - check timestamp on all incoming changes, apply changes that are more recent
            -- after
            - update last synced timestamp with selected player

        METHOD B - to each player, their own list
            -- sending 
            - check when last we synced with selected party member
            - send all changes that are more recent than last sync
            -- receiving
            - apply all incoming changes, as they should automatically be more recent
            -- after
            - update last synced timestamp with selected player
]]--

function SSL.OutgoingHandshake(player, callback)
    if currentlyHandshaking[player] == nil then
        SSL.Print("Initiating handshake with " .. player)
        currentlyHandshaking[player] = {
            ts = time(), -- we are initiating the hs
            cb = callback
        }
        SSL.AddonMsg("HSINIT", currentlyHandshaking[player].ts, player)
    end
    -- else handshake is being initiated against us
end

function SSL.IncomingHandshake(player, timestamp)
    if currentlyHandshaking[player] == nil then
        currentlyHandshaking[player] = { ts = timestamp }-- they are initiating the hs
    elseif timestamp < currentlyHandshaking[player].ts then
        currentlyHandshaking[player].ts = timestamp -- we have initiated, but they were faster
    else
        return -- we've already initiated, they ought to respond to us
    end
    SSL.AddonMsg("HSREPLY", time(), player)
    SSL.Print("Received handshake from " .. player)
end

function SSL.ConfirmOutgoingHandshake(player, timestamp)
    SSL.AddonMsg("HSCONFIRM", time(), player)
    if not (currentlyHandshaking[player].cb == nil) then
        currentlyHandshaking[player].cb()
    end
    currentlyHandshaking[player] = nil
    SSL.Print("Handshake reciprocated by " .. player)
end

function SSL.ConfirmIncomingHandshake(player, timestamp)
    currentlyHandshaking[player] = nil
    SSL.Print("Handshake reciprocation confirmed by " .. player)
end

function SSL.SubscribeTo(player)
    SSL.Print("Attempting to subscribe to " .. player)
    SSL.AddonMsg("SUBREQ", time(), player)
end

function SSL.SubscriptionRequestReceived(player)
    SSL.Print("Received subscription request from " .. player)
    SSL.AcceptSubscriptionRequest(player)
end

function SSL.AcceptSubscriptionRequest(player)

end

function SSL.AddonMsg(messagePrefix, data, target)
    C_ChatInfo.SendAddonMessage("SSLSYNC", messagePrefix .. "|" .. data, "WHISPER", target)
end

SSL.eventHandlers.CHAT_MSG_ADDON = function(self, event, prefix, text, channel, sender, target, ...)
    if not (prefix == "SSLSYNC") then
        return -- this isnt about us
    end
    -- determine message type
    local posPrefix = string.find(text, "|")
    if not (posPrefix == nil) then
        local messagePrefix = string.sub(text, 1, posPrefix - 1) -- get message prefix
        local messagePayload = string.sub(text, posPrefix + 1) -- get payload
        if messagePrefix == "HSINIT" then -- incoming handshake
            SSL.IncomingHandshake(SSL.NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "HSREPLY" then -- response to outgoing handshake
            SSL.ConfirmOutgoingHandshake(SSL.NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "HSCONFIRM" then -- confirmation of handshake response
            SSL.ConfirmIncomingHandshake(SSL.NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "SYNCSTART" then
            -- clear sync data table for this sender
        elseif messagePrefix == "SYNCDATA" then
            -- append data to sync table for this sender
        elseif messagePrefix == "SYNCEOF" then
            -- if we are done sending our own data, send SYNCDONE and apply changes, else wait for their signal
        elseif messagePrefix == "SYNCDONE" then
            -- we're done syncing here, apply changes
        end
    else
        -- invalid message prefix
    end
end
SSL.frame:RegisterEvent("CHAT_MSG_ADDON")
if not C_ChatInfo.RegisterAddonMessagePrefix("SSLSYNC") then
    SSL.Print("Unable to register message prefix for syncing")
end

--[[
    end sync functions
]]--

function SSL.Help(msg)
    SSL.Print(msg .. " Use one of the following:\n/ssl add <reason>\n/ssl remove\n/ssl addname <name> <reason>\n/ssl removename <name>\n/ssl list\n/ssl clear")
end

function SSL.Slash(arg)
    if #arg == 0 then
        SSL.Help("No command given.")
        return
    end
    local posRest = string.find(arg, " ")
    local rest, cmd = ""
    if not (posRest == nil) then
        cmd = string.sub(arg, 1, posRest - 1) -- grab first argument
        rest = string.sub(arg, posRest + 1) -- there was at least one more argument, save it in rest
    else
        cmd = arg
    end
    if cmd == "addname" then -- add a name to the list
        local name, reason = ""
        local posRest2 = string.find(rest, " ") -- check for more arguments (reason)
        if not (posRest2 == nil) then -- more arguments found, split into proper variables
            name = string.sub(rest, 1, posRest2 - 1)
            reason = string.sub(rest, posRest2 + 1)
        else
            name = rest -- no further arguments, rest only contains the name to be added
        end
        SSL.AddName(name, reason)
    elseif cmd == "add" then -- add current target to list
        SSL.AddTarget(rest) -- rest contains reason
    elseif cmd == "remove" then -- remove current target from list
        SSL.RemoveTarget()
    elseif cmd == "list" then -- print the list to chat
        SSL.PrintList()
    elseif cmd == "removename" then -- remove a name from the list
        SSL.RemoveName(rest)
    elseif cmd == "clear" then -- clear the list completely
        SSL.ClearList()

    -- DEBUGGING
    elseif cmd == "hsend" then
        if #rest > 0 then
            SSL.OutgoingHandshake(rest)
        else
            SSL.OutgoingHandshake(playerName)
        end
    elseif cmd == "subscribe" then
        if #rest > 0 then
            SSL.OutgoingHandshake(rest, function() SSL.SubscribeTo(rest) end)
        end
    -- END DEBUGGING
    elseif cmd == "version" then
        SSL.Print("version " .. version)
    else
        SSL.Help("Unrecognized command.")
    end
end

-- register our slash command /ssl
SlashCmdList["SanctuaryShitList_Slash_Command"] = SSL.Slash
SLASH_SanctuaryShitList_Slash_Command1 = "/ssl"

-- create our tooltip hook
function SSL.TooltipHook(t)
    local name, unit = t:GetUnit() -- unit here contains target ID, e.g. "mouseover", "target", "party1", etc. in this case it will always contain "mouseover"
    if (name) and (unit) then -- this is a valid target
        if not (SSL.shitList[name] == nil) then -- and it's on the List
            GameTooltip:AddLine("WARNING: " .. name .. " is present in the Shit List!")
            GameTooltip:AddLine("Reason: " .. SSL.shitList[name].reason)
            GameTooltip:AddLine("Added by " .. SSL.shitList[name].author)
            GameTooltip:Show() -- if Show() is not called, the tooltip will not resize to fit the new lines added
        end
    end
end

-- basic output to chat
function SSL.Print(msg, ...)
    DEFAULT_CHAT_FRAME:AddMessage("[SSL] " .. msg, ...)
end

-- register our custom tooltip hook
GameTooltip:HookScript("OnTooltipSetUnit", SSL.TooltipHook)

function SSL.NameStrip(name)
    local posDash = string.find(name, "-")
    if not (posDash == nil) then
        return string.sub(name, 1, posDash - 1)
    end
    return name
end

-- we done
SSL.Print("Loading complete")