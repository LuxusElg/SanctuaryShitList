local addonName, _SSL = ...

--[[ General helper functions ]]--

function _SSL:strsplit(delimiter, text)
    local list = {}
    local pos = 1
    if strfind("", delimiter, 1) then -- this would result in endless loops
       error("delimiter matches empty string!")
    end
    while 1 do
       local first, last = strfind(text, delimiter, pos)
       if first then -- found?
          tinsert(list, strsub(text, pos, first-1))
          pos = last+1
       else
          tinsert(list, strsub(text, pos))
          break
       end
    end
    return list
end

function _SSL:randomNumber()
    return math.random(100000, 1000000)
end

--[[ Addon-specific helper functions ]]--

function _SSL:GetPlayerInfo()
    local name, fakeRealm = UnitName("player")
    local realRealm = GetRealmName()
    return name .. "-" .. realRealm, name, realRealm
end

function _SSL:NameStrip(name)
    local posDash = string.find(name, "-")
    if not (posDash == nil) then
        return string.sub(name, 1, posDash - 1)
    end
    return name
end

function _SSL:GenerateSubChannel()
    return "SSL" .. playerName .. _SSL:randomNumber() .. _SSL:randomNumber()
end

function _SSL:Help(msg)
    _SSL:Print(msg .. " Use one of the following:\n/ssl add <reason>\n/ssl remove\n/ssl addname <name> <reason>\n/ssl removename <name>\n/ssl list\n/ssl clear")
end

function _SSL:Print(msg, ...)
    DEFAULT_CHAT_FRAME:AddMessage("[SSL] " .. msg, ...)
end

function _SSL:DebugPrint(level, msg, ...)
    if level >= _SSL.debugLevel then
        _SSL:Print("[v" .. _SSL.version .. " (debug)] " .. msg)
    end
end