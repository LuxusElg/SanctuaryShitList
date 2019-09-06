
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
-- local copy of the List
SSL.shitList = {}

-- setup event handler to register when we are loaded, and add pointer to saved var containing list
SSL.frame = CreateFrame("Frame") -- need a frame to register event handlers
SSL.frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addon then
        return -- event didn't fire for this addon
    end
    if shitlistSaved == nil then
        shitlistSaved = {} -- initialize list if it hasn't been already
    end
    SSL.shitList = shitlistSaved -- set up local reference to saved list
    SSL.Print("Saved SSL list loaded")
end)
SSL.frame:RegisterEvent("ADDON_LOADED") -- register event handler

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

function SSL.AddTarget(reason)
    -- TODO
end

function SSL.RemoveTarget()
    -- TODO
end

function SSL.RemoveName(name)
    if not (SSL.shitList[name] == nil) then
        SSL.shitList[name] = nil
        SSL.Print(name .. " has been removed from the list.")
    else
        SSL.Print(name .. " is not present in the list.")
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

function SSL.Slash(arg)
    if #arg == 0 then
        SSL.Print("No command given. Use one of the following: /ssl add <name> <reason>, /ssl list, /ssl remove <name>, /ssl clear")
        return
    end
    local cmd = string.lower(string.sub(arg, 1, 1)) -- grab first letter of first argument
    local posRest = string.find(arg, " ")
    local rest = ""
    if not (posRest == nil) then
        rest = string.sub(arg, posRest + 1) -- there was at least one more argument, save it in rest
    end
    if cmd == "a" then -- add a name to the list
        local name, reason = ""
        local posRest2 = string.find(rest, " ") -- check for more arguments (reason)
        if not (posRest2 == nil) then -- more arguments found, split into proper variables
            name = string.sub(rest, 1, posRest2 - 1)
            reason = string.sub(rest, posRest2 + 1)
        else
            name = rest -- no further arguments, rest only contains the name to be added
        end
        SSL.AddName(name, reason)
    elseif cmd == "l" then -- print the list to chat
        SSL.PrintList()
    elseif cmd == "r" then -- remove a name from the list
        SSL.RemoveName(rest)
    elseif cmd == "c" then -- clear the list completely
        SSL.ClearList()
    else
        SSL.Print("Command unknown. Use one of the following: /ssl add <name> <reason>, /ssl list, /ssl remove <name>, /ssl clear")
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
    DEFAULT_CHAT_FRAME:AddMessage(msg, ...)
end

-- register our custom tooltip hook
GameTooltip:HookScript("OnTooltipSetUnit", SSL.TooltipHook)

-- we done
SSL.Print("SSL Loaded")