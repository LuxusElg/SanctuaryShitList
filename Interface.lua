local addonName, _SSL = ...
_SSL.GUI = {}

-- register Interface options page
local panel = CreateFrame("FRAME")
panel.name = "SanctuaryShitList"
InterfaceOptions_AddCategory(panel)

-- add content
childpanel = CreateFrame("FRAME", "Shitlists", panel)
childpanel.name = "Shitlistsss"
childpanel.parent = panel.name
InterfaceOptions_AddCategory(childpanel)


--[ List Interface ]--
function _SSL.GUI:CreateListFrame()
    local f = CreateFrame("Frame", "SSL_GUI_Frame", UIParent, "SSL_GUI_Frame")
    f:Hide()

    f.playerList = SSL_GUI_Frame_PlayerList
    _SSL.GUI:CreateButtons(f.playerList)
    f.playerList.selected = nil

    f.shitList = SSL_GUI_Frame_ShitList
    _SSL.GUI:CreateListEntries(f.shitList)

    return f
end

function _SSL.GUI:CreateButtons(frame)
    local name = frame:GetName()

    local buttons = {}
    local button = CreateFrame("BUTTON", name.."_Button1", frame, "SSL_GUI_ListButtonTemplate")
    button:SetPoint("TOPLEFT", frame, 0, -8)
    frame.buttonHeight = button:GetHeight()
    tinsert(buttons, button)

    local maxButtons = (frame:GetHeight() - 8) / frame.buttonHeight
    for i = 2, maxButtons do
        button = CreateFrame("BUTTON", name.."_Button"..i, frame, "SSL_GUI_ListButtonTemplate")
        button:SetPoint("TOPLEFT", buttons[#buttons], "BOTTOMLEFT")
        tinsert(buttons, button)
    end
    frame.buttons = buttons
end

function _SSL.GUI:CreateListEntries(frame)
    local name = frame:GetName()

    local entries = {}
    local entry = CreateFrame("Frame", name.."_Entry1", frame, "SSL_GUI_ShitListEntryTemplate")
    entry:SetPoint("TOPLEFT", frame, 10, -8)
    frame.entryHeight = entry:GetHeight()
    tinsert(entries, entry)

    local maxEntries = (frame:GetHeight() - 8) / frame.entryHeight
    for i = 2, maxEntries do
        entry = CreateFrame("Frame", name.."_Entry"..i, frame, "SSL_GUI_ShitListEntryTemplate")
        entry:SetPoint("TOPLEFT", entries[#entries], "BOTTOMLEFT")
        tinsert(entries, entry)
    end
    frame.entries = entries
end


_SSL.GUI.listFrame = _SSL.GUI:CreateListFrame()

function _SSL.GUI.listFrame:OnButtonClick(button)
    local target = button.text:GetText()
    _SSL:DebugPrint(2, "Clicked player list entry for "..target)
    _SSL.GUI.listFrame.playerList.selected = target
    _SSL.GUI:showList()
end

function _SSL.GUI:showList()
    _SSL:DebugPrint(2, "Attempting to display the list frame")

    local frame = _SSL.GUI.listFrame
    local playerList = _SSL:GetPlayerList()
    local buttons = frame.playerList.buttons
    for i = 1, #buttons do
        element = playerList[i]
        if element == nil then
            buttons[i]:Hide()
        else
            _SSL.GUI:DisplayButton(buttons[i], element)
        end
    end

    local entryList = {}
    if frame.playerList.selected == nil then
        entryList = { "Select a player to show their list." }
    else
        entryList = _SSL:GetList(frame.playerList.selected)
    end
    local entries = frame.shitList.entries
    for i = 1, #entries do
        element = entryList[i]
        if element == nil then
            entries[i]:Hide()
        else
            _SSL.GUI:DisplayEntry(entries[i], element)
        end
    end

    frame:Show()
end

function _SSL.GUI:DisplayButton(button, element)
    button:Show()
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", 20, 2)
    button.text:SetFontObject(GameFontNormalSmall)
    button:SetWidth(185)
    button.text:SetText(element)
    button.text:Show()
end

function _SSL.GUI:DisplayEntry(entry, element)
    entry:Show()
    entry.text:ClearAllPoints()
    entry.text:SetPoint("LEFT", 8, 2)
    entry.text:SetFontObject(GameFontNormalSmall)
    entry:SetWidth(490)
    entry.text:SetWidth(490)
    entry.text:SetJustifyH("LEFT")
    if not (element.name == nil) then
        entry.text:SetText(element.name .. " - " .. element.reason .. " (" .. element.ts .. ")")
    else
        entry.text:SetText(element)
    end
    entry.text:Show()
end
--[ List Interface End ]--