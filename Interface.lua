local addonName, _SSL = ...
_SSL.GUI = {}

--[ Addon Options Panel ]--

-- register Interface options page
local panel = CreateFrame("FRAME")
panel.name = "SanctuaryShitList"
InterfaceOptions_AddCategory(panel)

-- add content
childpanel = CreateFrame("FRAME", "Shitlists", panel)
childpanel.name = "Shitlistsss"
childpanel.parent = panel.name
InterfaceOptions_AddCategory(childpanel)

--[ Addon Options Panel End ]--

--[ List Interface ]--

function _SSL.GUI:CreateListFrame()
    local f = CreateFrame("Frame", "SSL_GUI_Frame", UIParent, "SSL_GUI_Frame")
    f:Hide()

    f.playerList = SSL_GUI_Frame_PlayerList
    _SSL.GUI:CreateButtons(f.playerList)
    f.playerList.selected = _SSL.playerName or nil

    f.shitList = SSL_GUI_Frame_ShitList
    -- scrollframe is the mousewheel'able area where buttons will be drawn
    f.scrollFrame = CreateFrame("ScrollFrame","SSL_GUI_ScrollFrame",f.shitList,"HybridScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f.shitList, "TOPLEFT", 0, 0)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f.shitList, "BOTTOMRIGHT", 0, 10)
    -- scrollbar is just to the right of the scrollframe
    f.scrollBar = CreateFrame("Slider","SSL_GUI_ScrollBar",f.scrollFrame,"HybridScrollBarTemplate")
    f.scrollBar:SetPoint("TOPLEFT",f.shitList,"TOPRIGHT",1,-20)
    f.scrollBar:SetPoint("BOTTOMRIGHT",f.shitList,"BOTTOMRIGHT", -20, 40)

    -- HybridScrollFrame creation
    f.scrollFrame.stepSize = 36 -- jump by 2 buttons on mousewheel
    function f.Update(...)
        local frame = _SSL.GUI.listFrame
        local offset = HybridScrollFrame_GetOffset(frame.scrollFrame)
        local entries = frame.scrollFrame.buttons

        local entryList = {}
        if frame.playerList.selected == nil then
            entryList = { "Select a player to show their list." }
            _SSL.GUI:SetFrameText(frame.shitListHeader, "No list selected")
        else
            entryList = _SSL:GetList(frame.playerList.selected)
        end
        
        local displayed = 0
        for i = 1, #entries do
            element = entryList[i + offset]
            if element == nil then
                entries[i]:Hide()
            else
                _SSL.GUI:DisplayEntry(entries[i], element)
                displayed = displayed + 1
            end
        end

        local numDisplayed = math.min(displayed, #entries);
        local buttonHeight = entries[1]:GetHeight();
        local displayedHeight = numDisplayed * buttonHeight;
        local totalHeight = (#entryList + 1) * buttonHeight;
        HybridScrollFrame_Update(frame.scrollFrame, totalHeight, displayedHeight);
    
    end
    f.scrollFrame.update = f.Update

    _SSL.GUI:CreateListEntries(f.scrollFrame)

    f.shitListHeader = SSL_GUI_Frame_ShitListHeader

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
    local entry = CreateFrame("BUTTON", name.."_Entry1", frame, "SSL_GUI_ShitListEntryTemplate")
    entry:SetPoint("TOPLEFT", frame, 8, -8)
    frame.entryHeight = entry:GetHeight()
    tinsert(entries, entry)

    local maxEntries = (frame:GetHeight() - 8) / frame.entryHeight
    for i = 2, maxEntries do
        entry = CreateFrame("BUTTON", name.."_Entry"..i, frame, "SSL_GUI_ShitListEntryTemplate")
        entry:SetPoint("TOPLEFT", entries[#entries], "BOTTOMLEFT")
        tinsert(entries, entry)
    end
    frame.entries = entries
    frame.buttons = entries
    frame.scrollBar:SetValue(0)
	HybridScrollFrame_CreateButtons(frame, "SSL_GUI_ShitListEntryTemplate", 0, 0);
	HybridScrollFrame_SetDoNotHideScrollBar(frame, true);
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
    HybridScrollFrame_SetOffset(frame.scrollFrame, 0);

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
        _SSL.GUI:SetFrameText(frame.shitListHeader, "No list selected")
    else
        entryList = _SSL:GetList(frame.playerList.selected)
        _SSL.GUI:SetFrameText(frame.shitListHeader, frame.playerList.selected.."'s List")
    end
    local entries = frame.scrollFrame.entries
    for i = 1, #entries do
        element = entryList[i]
        if element == nil then
            entries[i]:Hide()
        else
            _SSL.GUI:DisplayEntry(entries[i], element)
        end
    end

    frame:Show()

    local numDisplayed = math.min(#entryList, #entries);
	local buttonHeight = entries[1]:GetHeight();
	local displayedHeight = numDisplayed * buttonHeight;
    local totalHeight = (#entryList + 1) * buttonHeight;
	HybridScrollFrame_Update(frame.scrollFrame, totalHeight, displayedHeight);
end

function _SSL.GUI:SetFrameText(frame, text)
    frame:Show()
    frame.text:ClearAllPoints()
    frame.text:SetPoint("LEFT", 0, 0)
    frame.text:SetFontObject(GameFontNormal)
    frame.text:SetText(text)
    frame.text:Show()
end

function _SSL.GUI:DisplayButton(button, element)
    button:Show()
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", 8, 2)
    button.text:SetFontObject(GameFontNormalSmall)
    button:SetWidth(120)
    button.text:SetText(element)
    button.text:Show()
end

function _SSL.GUI:DisplayEntry(entry, element)
    entry:Show()
    entry.text:ClearAllPoints()
    entry.text:SetPoint("LEFT", 0, 2)
    entry.text:SetFontObject(GameFontNormalSmall)
    entry:SetWidth(598)
    entry.text:SetWidth(598)
    entry.text:SetJustifyH("LEFT")
    if not (element.name == nil) then
        entry.text:SetText(element.name .. " - " .. element.reason .. " (" .. element.ts .. ")")
    else
        entry.text:SetText(element)
    end
    entry.text:Show()
end

--[ List Interface End ]--
