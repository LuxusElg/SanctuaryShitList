local addonName, _SSL = ...

function _SSL:IsSubscriber(player)
    return not (_SSL.chardb.subscribers[player] == nil)
end

function _SSL:IsSubscription(player)
    return not (_SSL.chardb.subscriptions[player] == nil)
end

function _SSL:AddSubscriber(player)
    if _SSL:IsSubscriber(player) then return false end
    _SSL.chardb.subscribers[player] = { added = time(), lastSync = 0 }
    return true
end

function _SSL:RemoveSubscriber(player)
    if not _SSL:IsSubscriber(player) then return false end
    _SSL.chardb.subscribers[player] = nil
    return true
end

function _SSL:AddSubscription(player)
    if _SSL:IsSubscription(player) then return false end
    _SSL.chardb.subscriptions[player] = { added = time(), lastSync = 0 }
    _SSL.chardb.subscribedLists[player] = {}
    return true
end

function _SSL:RemoveSubscription(player)
    if not _SSL:IsSubscription(player) then return false end
    _SSL.chardb.subscriptions[player] = nil
    _SSL.chardb.subscribedLists[player] = nil
    return true
end

function _SSL:GetSubscriptionDetails(player)
    if not _SSL:IsSubscription(player) then return {} end
    return _SSL.chardb.subscriptions[player]
end

function _SSL:GetSubscriberDetails(player)
    if not _SSL:IsSubscriber(player) then return {} end
    return _SSL.chardb.subscribers[player]
end

function _SSL:AddToSubscribedList(player, entry)
    if not _SSL:IsSubscription(player) then return false end
    if _SSL.chardb.subscribedLists[player][entry.unitName] == nil then -- not present
        _SSL.chardb.subscribedLists[player][entry.unitName] = entry
    elseif not (_SSL.chardb.subscribedLists[player][entry.unitName] == nil) and (_SSL.chardb.subscribedLists[player][entry.unitName].deletedAt or 0) > 0 then -- already present, but deleted, check timestamps
        if entry.ts > _SSL.chardb.subscribedLists[player][entry.unitName].deletedAt then -- go ahead and add
            _SSL.chardb.subscribedLists[player][entry.unitName] = entry
        end
    end
    return true
end

function _SSL:RemoveFromSubscribedList(player, entry)
    if not _SSL:IsSubscription(player) then return false end
    if not (_SSL.chardb.subscribedLists[player][entry.unitName] == nil) then
        if entry.deletedAt > _SSL.chardb.subscribedLists[player][entry.unitName].ts then -- deletion is newer, safe to remove
            _SSL.chardb.subscribedLists[player][entry.unitName] = nil -- we don't really need to softdelete in "remote" lists, even though adding checks for it
        end
    end -- it's not in the list
    return true
end

function _SSL:GetListed(player)
    local entries = {}
    for key, value in pairs(_SSL.db.playerLists) do
        local realm = _SSL:strsplit("-", key)[2]
        if realm == _SSL.playerRealm and not (value[player] == nil) and (value[player].deletedAt == nil or value[player].deletedAt == 0) then
            entries[#entries+1] = value[player]
        end
    end
    for key, value in pairs(_SSL.chardb.subscribedLists) do
        if not (value[player] == nil) then
            entries[#entries+1] = value[player]
        end
    end
    return entries
end

function _SSL:CheckGroupMembers()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers()-1 do
            local name = UnitName("raid" .. i)
            local entries = _SSL:GetListed(name)
            if not (name == nil) and #entries > 0 then
                _SSL:ListedPartyMemberFound(name, entries[1].reason)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers()-1 do
            local name = UnitName("party" .. i)
            local entries = _SSL:GetListed(name)
            if not (name == nil) and #entries > 0 then
                _SSL:ListedPartyMemberFound(name, entries[1].reason)
            end
        end
    end
end

function _SSL:ListedPartyMemberFound(name, reason)
    _SSL:Print("Party member " .. name .. " is on the List!")
    -- funny, but strictly not necessary :)
    -- SendChatMessage(name .. " is on my shitlist because " .. reason .. "!", "PARTY")
end
-- add a name to the list, with a given reason (or not)
function _SSL:AddName(name, reason)
    if _SSL.db.playerLists[_SSL.playerID][name] == nil then
        _SSL:Print("Adding " .. name .. " to the List.")
        local newEntry = {}
        newEntry.ts = time()
        newEntry.author = _SSL.playerName
        newEntry.unitName = name
        newEntry.deletedAt = 0
        if reason and string.len(reason) > 0 then
            newEntry.reason = reason
        else
            newEntry.reason = "No reason"
        end
        _SSL.db.playerLists[_SSL.playerID][name] = newEntry
    elseif not (_SSL.db.playerLists[_SSL.playerID][name] == nil) and not (_SSL.db.playerLists[_SSL.playerID][name].deletedAt == nil) and _SSL.db.playerLists[_SSL.playerID][name].deletedAt > 0 then
        -- in the list but softdeleted
        _SSL:Print("Adding " .. name .. " to the List.")
        _SSL.db.playerLists[_SSL.playerID][name].deletedAt = 0
        _SSL.db.playerLists[_SSL.playerID][name].ts = time()
        if reason and string.len(reason) > 0 then
            _SSL.db.playerLists[_SSL.playerID][name].reason = reason
        else
            _SSL.db.playerLists[_SSL.playerID][name].reason = "No reason"
        end
    else
        _SSL:Print(name .. " is already present in the list, added at " .. date("%d/%m/%y %H:%M:%S", _SSL.db.playerLists[_SSL.playerID][name].ts))
    end
end

function _SSL:RemoveName(name)
    if not (_SSL.db.playerLists[_SSL.playerID][name] == nil) and (_SSL.db.playerLists[_SSL.playerID][name].deletedAt == nil or _SSL.db.playerLists[_SSL.playerID][name].deletedAt == 0) then
        _SSL.db.playerLists[_SSL.playerID][name].deletedAt = time()
        _SSL.db.playerLists[_SSL.playerID][name].ts = time()
        _SSL:Print(name .. " has been removed from the list.")
    else
        _SSL:Print(name .. " is not present in the list.")
    end
end

function _SSL:AddTarget(reason)
    local name,realm = UnitName("target")
    if not (name == nil) then
        _SSL:AddName(name, reason)
    else
        _SSL:Print("No target found")
    end
end

function _SSL:RemoveTarget()
    local name,realm = UnitName("target")
    if not (name == nil) then
        _SSL:RemoveName(name)
    else
        _SSL:Print("No target found")
    end
end

function _SSL:PrintList()
    for key, value in pairs(_SSL.db.playerLists) do
        local name, realm = unpack(_SSL:strsplit("-", key))
        if realm == _SSL.playerRealm then
            _SSL:Print("-- " .. name .. "'s List --")
            for k, v in pairs(value) do
                if v.deletedAt == nil or v.deletedAt == 0 then
                    _SSL:Print(v.unitName .. " - because " ..v.reason .. " (" .. date("%d/%m/%y", v.ts) ..")")
                end
            end
        end
    end
    for key, value in pairs(_SSL.chardb.subscribedLists) do
        _SSL:Print("-- " .. key .. "'s List --")
        for k, v in pairs(value) do
            _SSL:Print(v.unitName .. " - because " ..v.reason .. " (" .. date("%d/%m/%y", v.ts) ..")")
        end
    end
end

function _SSL:ClearList()
    if not (next(_SSL.db.playerLists[_SSL.playerID]) == nil) then
        for k,v in pairs(_SSL.db.playerLists[_SSL.playerID]) do _SSL.db.playerLists[_SSL.playerID][k]=nil end
        _SSL:Print("List emptied")
    else
        _SSL:Print("List is already empty")
    end
end
