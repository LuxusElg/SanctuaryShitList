-- register Interface options page
local panel = CreateFrame("FRAME")
panel.name = "SanctuaryShitList"
InterfaceOptions_AddCategory(panel)

-- add content
childpanel = CrateFrame("FRAME", "Shitlists", panel)
childpanel.name = "Shitlistsss"
childpanel.parent = panel.name
InterfaceOptions_AddCategory(childpanel)