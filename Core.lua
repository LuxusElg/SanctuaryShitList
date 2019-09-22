
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

-- arguments passed to us, addon name and addon specific scope
local addonName, _SSL = ...

_SSL.version = "0.8.1-classic"
_SSL.debugLevel = 0
_SSL.playerID, _SSL.playerName, _SSL.playerRealm = _SSL:GetPlayerInfo()
_SSL:DebugPrint(1, "Running for " .. _SSL.playerName .. " on " .. _SSL.playerRealm .. " (" .. _SSL.playerID .. ")")

-- table containing our event handlers
_SSL.eventHandlers = _SSL.eventHandlers or {}

_SSL.db = {}
_SSL.chardb = {}

_SSL.offlineFilterTargets = {}

-- setup event handler to register when we are loaded, and add pointer to saved var containing list
_SSL.eventHandlers.ADDON_LOADED = function(self, event, name)
    if name ~= addonName then
        return -- event didn't fire for this addon
    end
    
    -- setup basic saved db structure
    sslDB = sslDB or {}
    _SSL.db = sslDB
    _SSL.db.playerLists = _SSL.db.playerLists or {}
    _SSL.db.playerLists[_SSL.playerID] = _SSL.db.playerLists[_SSL.playerID] or {}
    _SSL.db.settings = _SSL.db.settings or {}

    _SSL.debugLevel = _SSL.db.settings.debugLevel or _SSL.debugLevel

    sslCharDB = sslCharDB or {}
    _SSL.chardb = sslCharDB
    _SSL.chardb.subscribedLists = _SSL.chardb.subscribedLists or {}
    _SSL.chardb.subscribers = _SSL.chardb.subscribers or {}
    _SSL.chardb.subscriptions = _SSL.chardb.subscriptions or {}
    _SSL.chardb.settings = _SSL.chardb.settings or {}

    _SSL:DebugPrint(1, "Saved variables loaded")

    _SSL.GUI.listFrame.playerList.selected = _SSL.playerName or _SSL.GUI.listFrame.playerList.selected
end

-- _SSL.eventHandlers.GROUP_FORMED = function(self, event, ...) end

_SSL.eventHandlers.GROUP_JOINED = function(self, event, ...)
    if IsInGroup() then
        for i = 1, GetNumGroupMembers()-1 do
            local name = UnitName("party" .. i)
            if _SSL:IsSubscription(name) then -- we're subscribed to this person
                _SSL.RequestSyncFromPlayer(name) -- let's request a sync
            end
            if _SSL:IsSubscriber(name) then --they're subscribed to us
                _SSL.InvitePlayerToSync(name) -- let's ask if they want to sync
            end
        end
    end
end

-- _SSL.eventHandlers.GROUP_ROSTER_UPDATE = function(self, event, ...) end

-- set up our main event bus
_SSL.frame = _SSL.frame or CreateFrame("Frame") -- need a frame to register event handlers
_SSL.frame:SetScript("OnEvent", function(self, event, ...)
    if not (_SSL.eventHandlers[event] == nil) then
        _SSL.eventHandlers[event](self, event, ...)
    end
end)

_SSL.frame:RegisterEvent("ADDON_LOADED") -- register event handlers
-- _SSL.frame:RegisterEvent("GROUP_FORMED")
_SSL.frame:RegisterEvent("GROUP_JOINED")
-- _SSL.frame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Fires on map change, login and ui reload
-- decent place to try to sync to our subscriptions
_SSL.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
_SSL.eventHandlers.PLAYER_ENTERING_WORLD = function(self, event, isInitialLogin, isReloadingUi)
    _SSL:DebugPrint(1, "Attempting to sync all subscriptions...")
    for k,v in pairs(_SSL.chardb.subscriptions) do
        _SSL.offlineFilterTargets[#_SSL.offlineFilterTargets+1] = k
        _SSL:RequestSyncFromPlayer(k)
    end
    _SSL:CleanFilterList();
end

function _SSL:CleanFilterList()
    local hash = {}
    local res = {}

    for _,v in ipairs(_SSL.offlineFilterTargets) do
        if (not hash[v]) then
            res[#res+1] = v
            hash[v] = true
        end
    end
    _SSL.offlineFilterTargets = res
end

-- for intercepting "player offline" warnings
--_SSL.eventHandlers.CHAT_MSG_SYSTEM = function(self, event, text, ...) end
--_SSL.frame:RegisterEvent("CHAT_MSG_SYSTEM")
local function OfflineMessageFilter(chatFrame, event, arg1, arg2, arg3, ...)
    if #_SSL.offlineFilterTargets == 0 then return false end -- filter inactive
    for i,v in ipairs(_SSL.offlineFilterTargets) do
        _SSL:DebugPrint(5,"Offline message check vs filter: "..v)
        local pattern = format(ERR_CHAT_PLAYER_NOT_FOUND_S, v)
        if arg1 == pattern then 
            _SSL:DebugPrint(1, "Offline warning for target " .. v .. " intercepted! Resetting filter.")
            _SSL:ClearFilterForPlayer(v)
            return true
        end
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OfflineMessageFilter)
function _SSL:ClearFilterForPlayer(name)
    for i,v in ipairs(_SSL.offlineFilterTargets) do
        if v == name then _SSL.offlineFilterTargets[i] = nil end
    end
end
-- end offline message filtering

-- API event registering
_SSL.frame:RegisterEvent("CHAT_MSG_ADDON")
if not C_ChatInfo.RegisterAddonMessagePrefix("SSLSYNC") then
    _SSL:DebugPrint(1, "Unable to register message prefix for syncing")
end
-- end API events

function _SSL.Slash(arg)
    if #arg == 0 then
        _SSL:Help("No command given.")
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
        _SSL:AddName(name, reason)
    elseif cmd == "add" then -- add current target to list
        _SSL:AddTarget(rest) -- rest contains reason
    elseif cmd == "remove" then -- remove current target from list
        _SSL:RemoveTarget()
    elseif cmd == "list" then -- print the list to chat
        _SSL:PrintList()
    elseif cmd == "removename" then -- remove a name from the list
        _SSL:RemoveName(rest)
    elseif cmd == "clear" then -- clear the list completely
        _SSL:ClearList()

    -- DEBUGGING
    elseif cmd == "hsend" then
        if #rest > 0 then
            _SSL:OutgoingHandshake(rest)
        else
            _SSL:OutgoingHandshake(playerName)
        end
    elseif cmd == "subscribe" or cmd == "sub" then
        if #rest > 0 then
            _SSL:SubscribeTo(rest)
        end

    elseif cmd == "syncto" then
        if #rest > 0 then
            _SSL:RequestSyncFromPlayer(rest)
        end
        
    elseif cmd == "unsub" then
        if #rest > 0 then
            _SSL:RemoveSubscription(rest)
        end

    -- END DEBUGGING
    elseif cmd == "debug" then
        if tonumber(rest) >= 0 and tonumber(rest) <= 5 then
            _SSL.db.settings.debugLevel = tonumber(rest)
            _SSL.debugLevel = tonumber(rest)
            _SSL:Print("Debug level set to "..rest)
        end
    elseif cmd == "show" then
        _SSL.GUI:showList()
    elseif cmd == "version" then
        _SSL:Print("Currently running version " .. _SSL.version)
    else
        _SSL:Help("Unrecognized command.")
    end
end

-- register our slash command /ssl
SlashCmdList["SanctuaryShitList_Slash_Command"] = _SSL.Slash
SLASH_SanctuaryShitList_Slash_Command1 = "/ssl"

-- create our tooltip hook
function _SSL.TooltipHook(t)
    local name, unit = t:GetUnit() -- unit here contains target ID, e.g. "mouseover", "target", "party1", etc. in this case it will always contain "mouseover"
    if (name) and (unit) then -- this is a valid target
        local entries = _SSL:GetListed(name)
        if #entries > 0 then -- and it's on the List
            GameTooltip:AddLine("WARNING: " .. name .. " is present in the Shit List!")
            for k,v in pairs(entries) do
                GameTooltip:AddLine(v.reason .. " (" .. v.author .. " " .. date("%d/%m/%y", v.ts) .. ")")
            end
            GameTooltip:Show() -- if Show() is not called, the tooltip will not resize to fit the new lines added
        end
    end
end

-- register our custom tooltip hook
GameTooltip:HookScript("OnTooltipSetUnit", _SSL.TooltipHook)

-- we done
_SSL:Print("Version " .. _SSL.version .. " loaded!")