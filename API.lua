local addonName, _SSL = ...
local currentlyHandshaking = {}
local syncData = {}
_SSL.eventHandlers = _SSL.eventHandlers or {}

function _SSL:OutgoingHandshake(player, callback)
    if currentlyHandshaking[player] == nil then
        _SSL:DebugPrint(1, "Initiating handshake with " .. player)
        currentlyHandshaking[player] = {
            ts = time(), -- we are initiating the hs
            cb = callback
        }
        _SSL:AddonMsg("HSINIT", currentlyHandshaking[player].ts, player)
    end
    -- else handshake is being initiated against us
end

function _SSL:IncomingHandshake(player, timestamp)
    if currentlyHandshaking[player] == nil then
        currentlyHandshaking[player] = { ts = timestamp }-- they are initiating the hs
    elseif timestamp < currentlyHandshaking[player].ts then
        currentlyHandshaking[player].ts = timestamp -- we have initiated, but they were faster
    else
        return -- we've already initiated, they ought to respond to us
    end
    _SSL:AddonMsg("HSREPLY", time(), player)
    _SSL:DebugPrint(1, "Received handshake from " .. player)
end

function _SSL:ConfirmOutgoingHandshake(player, timestamp)
    _SSL:AddonMsg("HSCONFIRM", time(), player)
    if not (currentlyHandshaking[player].cb == nil) then
        currentlyHandshaking[player].cb()
    end
    currentlyHandshaking[player] = nil
    _SSL:DebugPrint(1, "Handshake reciprocated by " .. player)
end

function _SSL:ConfirmIncomingHandshake(player, timestamp)
    currentlyHandshaking[player] = nil
    _SSL:DebugPrint(1, "Handshake reciprocation confirmed by " .. player)
end

-- END HANDSHAKE
-- START SUBSCRIPTION

function _SSL:SubscribeTo(player)
    _SSL:DebugPrint(1, "Attempting to subscribe to " .. player)
    _SSL:AddonMsg("SUBREQ", time(), player)
end

function _SSL:SubscriptionRequestReceived(player)
    _SSL:DebugPrint(1, "Received subscription request from " .. player)
    -- this is where logic for displaying a dialog to the user should go
    _SSL:ApproveSubscriptionRequest(player) -- for now, we just accept
end

function _SSL:ApproveSubscriptionRequest(player)
    -- the request was approved
    _SSL:AddSubscriber(player)
    _SSL:AddonMsg("SUBAPPROVE", time(), player)
    _SSL:DebugPrint(1, "Subscription request by " .. player .. " approved")
end

function _SSL:SubscriptionApproved(player, channel)
    -- the player approved our request, add the subscription
    _SSL:AddSubscription(player)
    _SSL:DebugPrint(1, "Subscription to " .. player .. " approved.")
end

--END SUBSCRIPTION
-- START SUB SYNC

function _SSL:RequestSyncFromPlayer(player)
    if not _SSL:IsSubscription(player) then
        _SSL:Print(player .. " is not in the list of subscriptions.")
        return
    end
    _SSL:DebugPrint(1, "Attempting to sync subscription to " .. player)
    _SSL:AddonMsg("SYNCREQ", _SSL:GetSubscriptionDetails(player).lastSync or 0, player)
end

function _SSL:SyncRequestReceived(player, lastSync)
    -- is this player an approved subscriber?
    if not _SSL:IsSubscriber(player) then
        _SSL:Print("Received unauthorized request for sync from " .. player)
        return -- they are not, fail without responding
    end
    _SSL:DebugPrint(1, "Received sync request from " .. player)
    _SSL:SyncListWithPlayer(player, lastSync) -- if lastSync is nil, this is the first time we are syncing
end

function _SSL:SyncListWithPlayer(player, timestamp)
    if next(_SSL.db.savedLists[_SSL.playerID]) == nil then -- our list is empty
        _SSL:DebugPrint(1, "Unable to sync, list is empty")
        return
    end
    _SSL:DebugPrint(1, "Syncing list with " .. player)
    -- send starting message
    _SSL:AddonMsg("SYNCSTART", time(), player)
    -- loop through own list and send all entries newer than timestamp
    for key, value in pairs(_SSL.db.savedLists[_SSL.playerID]) do
        if value.ts > timestamp then
            _SSL:AddonMsg("SYNCDATA", _SSL:SerializeEntry(value), player)
        end
    end
    -- we're done
    _SSL:AddonMsg("SYNCDONE", time(), player)
    _SSL:GetSubscriberDetails(player).lastSync = time()
    _SSL:DebugPrint(1, "Syncing with " .. player .. " complete")
end

function _SSL:SyncStart(player)
    -- sync went through, we can at least remove the filter
    _SSL:ClearFilterForPlayer(player)
end

function _SSL:SyncDone(player)
    _SSL:DebugPrint(1, "Subscription to " .. player .. " is now synchronized")
    _SSL:GetSubscriptionDetails(player).lastSync = time()
end

function _SSL:ReceiveSyncData(player, serializedEntry)
    local unserialized = _SSL:UnserializeEntry(serializedEntry)
    if unserialized.deletedAt > 0 then -- we are removing
        _SSL:RemoveFromSubscribedList(player, unserialized)
    else
        _SSL:AddToSubscribedList(player, unserialized)
    end
    _SSL:DebugPrint(1, "Received " .. unserialized.unitName .. " (" .. unserialized.reason .. ") from " .. player)
end

function _SSL:InvitePlayerToSync(player)
    -- double-check that they are in our subscriber list
    if not _SSL:IsSubscriber(player) then
        _SSL:Print(player .. " is currently not subscribed to us")
        return
    end
    _SSL:DebugPrint(1, "Asking " .. player .. " if they want to sync to us")
    _SSL:AddonMsg("SYNCINV", _SSL:GetSubscriberDetails(player).lastSync or 0, player)
end

function _SSL:SyncInvitationReceived(player, lastSync)
    if not _SSL:IsSubscription(player) then -- we're not subscribed to them
        _SSL:Print("Received unauthorized invitation to sync from " .. player)
        return -- fail without response
    end
    _SSL:DebugPrint(1, player .. " would like us to sync to them")
    _SSL:RequestSyncFromPlayer(player)
end

-- END SUB SYNC

function _SSL:AddonMsg(messagePrefix, data, target)
    C_ChatInfo.SendAddonMessage("SSLSYNC", messagePrefix .. "|" .. data, "WHISPER", target)
end

function _SSL:SerializeEntry(listEntry)
    return listEntry.ts .. "|" .. listEntry.unitName .. "|" .. listEntry.reason:gsub("|", "") .. "|" .. listEntry.author
end

function _SSL:UnserializeEntry(listEntry)
    local unserialized = _SSL:strsplit("|", listEntry)
    if #unserialized ~= 4 then
        _SSL:DebugPrint(1, "List entry \"" .. listEntry .. "\" is malformed!")
        return
    end
    return { ts = tonumber(unserialized[1]), unitName = unserialized[2], reason = unserialized[3], author = unserialized[4] }
end

_SSL.eventHandlers.CHAT_MSG_ADDON = function(self, event, prefix, text, channel, sender, target, ...)
    if not (prefix == "SSLSYNC") then
        return -- this isnt about us
    end
    -- determine message type
    local posPrefix = string.find(text, "|")
    if not (posPrefix == nil) then
        local messagePrefix = string.sub(text, 1, posPrefix - 1) -- get message prefix
        local messagePayload = string.sub(text, posPrefix + 1) -- get payload
        if messagePrefix == "HSINIT" then -- incoming handshake
            _SSL:IncomingHandshake(_SSL:NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "HSREPLY" then -- response to outgoing handshake
            _SSL:ConfirmOutgoingHandshake(_SSL:NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "HSCONFIRM" then -- confirmation of handshake response
            _SSL:ConfirmIncomingHandshake(_SSL:NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "SUBREQ" then
            _SSL:SubscriptionRequestReceived(_SSL:NameStrip(sender))
        elseif messagePrefix == "SUBAPPROVE" then
            _SSL:SubscriptionApproved(_SSL:NameStrip(sender), messagePayload)
        elseif messagePrefix == "SUBDENY" then
            -- sadface
        elseif messagePrefix == "SYNCINV" then
            _SSL:SyncInvitationReceived(_SSL:NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "SYNCREQ" then
            _SSL:SyncRequestReceived(_SSL:NameStrip(sender), tonumber(messagePayload))
        elseif messagePrefix == "SYNCSTART" then
            _SSL:SyncStart(_SSL:NameStrip(sender))
        elseif messagePrefix == "SYNCDATA" then
            _SSL:ReceiveSyncData(_SSL:NameStrip(sender), messagePayload)
        elseif messagePrefix == "SYNCDONE" then
            _SSL:SyncDone(_SSL:NameStrip(sender))
        end
    else
        -- invalid message prefix
    end
end

--[[
    end sync functions
]]--