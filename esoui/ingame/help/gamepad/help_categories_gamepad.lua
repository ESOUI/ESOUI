ZO_HelpTutorialsCategories_Gamepad = ZO_HelpTutorialsGamepad:Subclass()

function ZO_HelpTutorialsCategories_Gamepad:Initialize(control)
    HELP_TUTORIAL_CATEGORIES_SCENE_GAMEPAD = ZO_Scene:New("helpTutorialsCategoriesGamepad", SCENE_MANAGER)

    local ACTIVATE_ON_SHOW = true
    ZO_HelpTutorialsGamepad.Initialize(self, control, ACTIVATE_ON_SHOW, HELP_TUTORIAL_CATEGORIES_SCENE_GAMEPAD)

    local helpTutorialsFragment = ZO_FadeSceneFragment:New(control)
    HELP_TUTORIAL_CATEGORIES_SCENE_GAMEPAD:AddFragment(helpTutorialsFragment)
    self:SetScene(HELP_TUTORIAL_CATEGORIES_SCENE_GAMEPAD)
end

function ZO_HelpTutorialsCategories_Gamepad:InitializeKeybindStripDescriptors()
    ZO_HelpTutorialsGamepad.InitializeKeybindStripDescriptors(self)

    self.keybindStripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Back
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
        -- Show Category or filter
        {
            name = function ()
                return GetString(SI_GAMEPAD_HELP_DETAILS)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local targetData = self.itemList:GetTargetData()
                HELP_TUTORIALS_ENTRIES_GAMEPAD:Push(targetData.categoryIndex)
            end,
        },
    }
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, function() return self.itemList end )
end

function ZO_HelpTutorialsCategories_Gamepad:AddListEntry(categoryIndex)
    local name, description, _, _, _, gamepadIcon, gamepadName = GetHelpCategoryInfo(categoryIndex)
    local categoryName = gamepadName ~= "" and gamepadName or name
    local entryData = ZO_GamepadEntryData:New(categoryName, gamepadIcon)
    entryData:SetIconTintOnSelection(true)
    entryData.categoryIndex = categoryIndex
    entryData.name = categoryName

    self.itemList:AddEntry("ZO_GamepadMenuEntryTemplate", entryData)
end

function ZO_HelpTutorialsCategories_Gamepad:IsCategoryEmpty(categoryIndex)
    local numEntries = GetNumHelpEntriesWithinCategory(categoryIndex)
    for helpIndex = 1, numEntries do
        local showOption = select(7, GetHelpInfo(categoryIndex, helpIndex))
        if IsGamepadHelpOption(showOption) then
            return false
        end
    end
    return true
end

function ZO_HelpTutorialsCategories_Gamepad:IsCategoryVisibleInSearch(categoryIndex) 
    for helpIndex = 1, GetNumHelpEntriesWithinCategory(categoryIndex) do
        local helpId = GetHelpId(categoryIndex, helpIndex)
        if TEXT_SEARCH_MANAGER:IsDataInSearchTextResults(self.searchContext, BACKGROUND_LIST_FILTER_TARGET_HELP_ID, helpId) then
            return true
        end
    end

    return false
end

function ZO_HelpTutorialsCategories_Gamepad:PerformUpdate()
    self.dirty = false

    self.itemList:Clear()

    -- Get the list of categoires we need to show.
    for categoryIndex = 1, GetNumHelpCategories() do
        if not self:IsCategoryEmpty(categoryIndex) and self:IsCategoryVisibleInSearch(categoryIndex) then
            self:AddListEntry(categoryIndex)
        end
    end

    self.itemList:Commit()

    -- Update the key bindings.
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)

    -- Update the header.
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
end

function ZO_Gamepad_Tutorials_Categories_OnInitialize(control)
    HELP_TUTORIALS_CATEGORIES = ZO_HelpTutorialsCategories_Gamepad:New(control)
end
