local GetListEntryName = ZO_GetAskForHelpListEntryName

local ZO_Help_Customer_Service_Gamepad = ZO_Help_GenericTicketSubmission_Gamepad:Subclass()

function ZO_Help_Customer_Service_Gamepad:Initialize(control)
    ZO_Help_GenericTicketSubmission_Gamepad.Initialize(self, control)
    HELP_CUSTOMER_SERVICE_GAMEPAD_SCENE = self:GetScene()
    self.itemList = self:GetMainList()

    local headerMessageControl = self.control:GetNamedChild("MaskContainerHeaderContainerHeaderMessage")
    headerMessageControl:SetFont("ZoFontGamepadCondensed42")
end

function ZO_Help_Customer_Service_Gamepad:GenerateSelectKeybindStripDescriptor()
    local keybindDescriptor =
    {
        name = GetString(SI_GAMEPAD_SELECT_OPTION),
        keybind = "UI_SHORTCUT_PRIMARY",
        callback = function()
            local targetData = self.itemList:GetTargetData()
            if targetData.isTextField then
                local editBox = self.itemList:GetTargetControl().editBox
                if editBox:HasFocus() then
                    editBox:LoseFocus()
                else
                    editBox:TakeFocus()
                end
            elseif targetData.isDropdown then
                self:ActivateCurrentDropdown(targetData.fieldType)
            elseif targetData.isSubmit then
                GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
                self:TrySubmitTicket()
                PlaySound(SOUNDS.DIALOG_ACCEPT)
            end
        end,

        enabled = function()
            if self.itemList then
                local selectedData = self.itemList:GetTargetData()
                if selectedData then
                    return not selectedData.isLocked
                end
            end
            return false
        end
    }
    return keybindDescriptor
end

function ZO_Help_Customer_Service_Gamepad:GetSceneName()
    return "helpCustomerServiceGamepad"
end

function ZO_Help_Customer_Service_Gamepad:GetFieldEntryTitle()
    return GetString(SI_GAMEPAD_HELP_CUSTOMER_SERVICE)
end

function ZO_Help_Customer_Service_Gamepad:GetFieldEntryMessage()
    return GetString(SI_GAMEPAD_HELP_CUSTOMER_SERVICE_FIELD_ENTRY_MESSAGE)
end

function ZO_Help_Customer_Service_Gamepad:GetTicketCategoryData()
    local subcategoryData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.SUBCATEGORY)
    if subcategoryData and subcategoryData.ticketCategory then
        return subcategoryData
    end

    local categoryData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.CATEGORY)
    if categoryData and categoryData.ticketCategory then
        return categoryData
    end
    
    local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
    if impactData and impactData.ticketCategory then
        return impactData
    end
end

function ZO_Help_Customer_Service_Gamepad:GetTicketCategoryForSubmission()
    local categoryData = self:GetTicketCategoryData()
    return categoryData and categoryData.ticketCategory or nil
end

function ZO_Help_Customer_Service_Gamepad:ValidateTicketFields()
    local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
    if not impactData or impactData.id == CUSTOMER_SERVICE_ASK_FOR_HELP_IMPACT_NONE then
        return ZO_HELP_TICKET_VALIDATION_STATUS.FAILED_NO_IMPACT
    elseif impactData.externalInfoTitle then
        local externalInfo = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO)
        if externalInfo == nil then
            return ZO_HELP_TICKET_VALIDATION_STATUS.FAILED_NO_EXTERNAL_INFO
        end
    end

    if not self:GetTicketCategoryForSubmission() then
        return ZO_HELP_TICKET_VALIDATION_STATUS.FAILED_NO_CATEGORY
    elseif impactData.detailsTitle then
        local details = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.DETAILS)
        if details == nil or details == "" then
            if impactData.id == CUSTOMER_SERVICE_ASK_FOR_HELP_IMPACT_REPORT_PLAYER then
                return ZO_HELP_TICKET_VALIDATION_STATUS.FAILED_NO_DISPLAY_NAME
            else
                return ZO_HELP_TICKET_VALIDATION_STATUS.FAILED_NO_DETAILS
            end
        end
    end

    return ZO_HELP_TICKET_VALIDATION_STATUS.SUCCESS
end

function ZO_Help_Customer_Service_Gamepad:SubmitTicket()
    local ticketCategoryData = self:GetTicketCategoryData()
    local includeScreenshot = ticketCategoryData and ticketCategoryData.includeScreenshot or false
    if includeScreenshot and not ZO_HELP_GENERIC_TICKET_SUBMISSION_MANAGER:CanSubmitFeedbackWithScreenshot() then
        ZO_Dialogs_ShowGamepadDialog("CUSTOMER_SERVICE_TICKET_SCREENSHOT_COOLDOWN")
        return
    end

    local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
    local retainTargetInfo = impactData.externalInfoRegistrationFunction ~= nil
    ResetCustomerServiceTicket(retainTargetInfo)
    SetCustomerServiceTicketCategory(self:GetTicketCategoryForSubmission())
    SetCustomerServiceTicketBody(self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.DESCRIPTION))
    SetCustomerServiceTicketIncludeScreenshot(includeScreenshot)

    if impactData.detailsRegistrationFunction then
        local text = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.DETAILS)
        if impactData.detailsRegistrationFormatText then
            text = impactData.detailsRegistrationFormatText(text)
        end
        impactData.detailsRegistrationFunction(text)
    end

    if impactData.id == CUSTOMER_SERVICE_ASK_FOR_HELP_IMPACT_REPORT_PLAYER then
        local displayName = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.DETAILS)
        ZO_HELP_GENERIC_TICKET_SUBMISSION_MANAGER:MarkAttemptingToSubmitReportPlayerTicket(displayName)
    elseif impactData.id == CUSTOMER_SERVICE_ASK_FOR_HELP_IMPACT_REPORT_GROUP_FINDER_LISTING then
        local externalInfo = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO)
        ZO_HELP_GENERIC_TICKET_SUBMISSION_MANAGER:MarkAttemptingToSubmitReportPlayerTicket(externalInfo.ownerDisplayName)
    end

    SubmitCustomerServiceTicket()
end

function ZO_Help_Customer_Service_Gamepad:SetCategories(impact, category, subcategory)
    for _, impactData in ipairs(ZO_HELP_ASK_FOR_HELP_CATEGORY_INFO.impacts) do
        if impactData.id == impact then
            self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT, impactData)
            
            if category and impactData.categories then
                for _, categoryData in ipairs(impactData.categories) do
                    if categoryData.id == category then
                        self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.CATEGORY, categoryData)
                        
                        if subcategory and categoryData.subcategories then
                            for _, subcategoryData in ipairs(categoryData.subcategories) do
                                if subcategoryData.id == subcategory then
                                    self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.SUBCATEGORY, subcategoryData)
                                    break
                                end
                            end
                        end
                        break
                    end
                end
            end
            break
        end
    end
end

function ZO_Help_Customer_Service_Gamepad:SetRequiredInfoProvidedInternally(isProvidedInternally)
    self.requiredInfoProvidedInternally = isProvidedInternally
end

function ZO_Help_Customer_Service_Gamepad:OnTextFieldFocusLost(control, fieldType)
    if control then
        self:SetSavedField(fieldType, control:GetText())
    end
end

function ZO_Help_Customer_Service_Gamepad:RefreshExternalInfoTooltip()
    if self:IsShowing() then
        local ticketCategoryData = self:GetTicketCategoryData()
        local additionalInstructions = ticketCategoryData and ticketCategoryData.additionalInstructions or nil
        if additionalInstructions == "" then
            additionalInstructions = nil
        end
        local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
        if impactData then
            if self:MeetsExternalInfoRequirements() then
                local externalInfo = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO)
                if externalInfo and impactData.externalInfoGamepadTooltipFunction then
                    impactData.externalInfoGamepadTooltipFunction(additionalInstructions)
                    return
                end
            elseif impactData.externalInfoInstructions then
                local instructions = impactData.externalInfoInstructions
                if additionalInstructions then
                    instructions = string.format("%s\n\n%s", instructions, additionalInstructions)
                end
                GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_LEFT_TOOLTIP, instructions)
                return
            end
        end
        if additionalInstructions then
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_LEFT_TOOLTIP, additionalInstructions)
            return
        end
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
        self.externalInfoTooltipDirty = false
    else
        self.externalInfoTooltipDirty = true
    end
end

function ZO_Help_Customer_Service_Gamepad:ShowGroupFinderListingTooltip()
    local externalInfo = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO)
    GAMEPAD_TOOLTIPS:LayoutReportGroupFinderListingInfo(GAMEPAD_LEFT_TOOLTIP, externalInfo.title, externalInfo.description, externalInfo.ownerDisplayName, externalInfo.ownerCharacterName)
end

function ZO_Help_Customer_Service_Gamepad:ShowHouseTourListingTooltip(additionalInstructions)
    local externalInfo = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO)
    GAMEPAD_TOOLTIPS:LayoutReportHouseTourListingInfo(GAMEPAD_LEFT_TOOLTIP, externalInfo.nickname, externalInfo.collectibleId, externalInfo.ownerDisplayName, additionalInstructions)
end

function ZO_Help_Customer_Service_Gamepad:MeetsExternalInfoRequirements()
    local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
    local requiresExternalInfo = impactData and (impactData.externalInfoTitle ~= nil) or false
    if requiresExternalInfo then
        return self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO) ~= nil
    end
    return true
end

function ZO_Help_Customer_Service_Gamepad:SetupList(list)
    ZO_Gamepad_ParametricList_Screen.SetupList(self, list)

    local function SetupTextFieldListEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
        local editContainer = control:GetNamedChild("TextField")
        control.editBox = editContainer:GetNamedChild("Edit")
        control.editBox:SetHandler("OnFocusGained", function(editControl)
                                                        editControl:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_EMAIL)
                                                        self.activeEditBox = editControl
                                                    end)

        control.editBox:SetHandler("OnFocusLost", function(editControl)
                                                        self:OnTextFieldFocusLost(editControl, data.fieldType)
                                                        self.activeEditBox = nil
                                                        list:RefreshVisible()
                                                        SCREEN_NARRATION_MANAGER:QueueParametricListEntry(list)
                                                    end)

        local savedText = self:GetSavedField(data.fieldType)
        if savedText then
            control.editBox:SetText(savedText)
        else
            control.editBox:SetText("")
        end

        if data.isRequired and not self.requiredInfoProvidedInternally then
            local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
            control.editBox:SetDefaultText(impactData.detailsGamepadDefaultText)
        else
            control.editBox:SetDefaultText("")
        end

        control.highlight:SetHidden(not selected)
    end

    local function SetupLockedTextFieldListEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
        local labelContainer = control:GetNamedChild("TextField")
        control.lockedLabel = labelContainer:GetNamedChild("Label")

        local savedText = self:GetSavedField(data.fieldType)
        if savedText then
            control.lockedLabel:SetText(savedText)
            data.editBoxNarration = savedText
        else
            control.lockedLabel:SetText("")
        end

        control.highlight:SetHidden(not selected)
    end

    local function OnDropdownItemSelected(control, data)
        if data.description then
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_LEFT_TOOLTIP, data.description)
        end
    end

    local function OnDropdownItemDeselected(control, data)
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
    end

    local function OnDropdownDeactivated()
        SCREEN_NARRATION_MANAGER:QueueParametricListEntry(list)
        self:RefreshExternalInfoTooltip()
    end

    local function SetupDropdownListEntry(control, data, selected, selectedDuringRebuild, enabled, active)
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, active)
        control.dropdown:SetSortsItems(false)
        control.dropdown:RegisterCallback("OnItemSelected", OnDropdownItemSelected)
        control.dropdown:RegisterCallback("OnItemDeselected", OnDropdownItemDeselected)
        control.dropdown:SetDeactivatedCallback(OnDropdownDeactivated)
        control.dropdown:SetNarrationTooltipType(GAMEPAD_LEFT_TOOLTIP)

        self:BuildDropdownList(control.dropdown, data)
        if selected then
            self:SetCurrentDropdown(control.dropdown)
        end
    end

    list:AddDataTemplateWithHeader("ZO_GamepadTextFieldItem_Multiline", SetupTextFieldListEntry, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryFullWidthHeaderTemplate")
    list:AddDataTemplateWithHeader("ZO_Gamepad_Help_EditLockedEntry_MultiLine", SetupLockedTextFieldListEntry, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryFullWidthHeaderWithLockTemplate")
    list:AddDataTemplateWithHeader("ZO_Gamepad_Help_Dropdown_Item", SetupDropdownListEntry, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryFullWidthHeaderTemplate")
    list:AddDataTemplate("ZO_GamepadTextFieldSubmitItem", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

function ZO_Help_Customer_Service_Gamepad:BuildDropdownList(dropdown, fieldData)
    dropdown:ClearItems()
    local fieldType = fieldData.fieldType
    local function OnSelectionChanged(_, _, entry)
        if self:GetSavedField(fieldType) ~= entry.data then
            self:SetSavedField(fieldType, entry.data)
            if fieldType == ZO_HELP_TICKET_FIELD_TYPE.IMPACT then
                if self.requiredInfoProvidedInternally then
                    self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.DETAILS, nil)
                    self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO, nil)
                end
                self.requiredInfoProvidedInternally = false
                self:RefreshExternalInfoTooltip()
                ZO_HELP_GENERIC_TICKET_SUBMISSION_MANAGER:SetReportPlayerTicketSubmittedCallback(nil)
            end
            self:BuildList()
        end
    end

    for index, listEntry in ipairs(fieldData.list) do
        local entry = dropdown:CreateItemEntry(GetListEntryName(fieldData.listStringName, listEntry), OnSelectionChanged)
        entry.index = index
        entry.data = listEntry
        entry.description = ZO_GetAskForHelpListEntryDescription(fieldData.listDescriptionStringName, listEntry)
        dropdown:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    end

    dropdown:UpdateItems()
    self:UpdateDropdownSelection(dropdown, fieldType)
end

function ZO_Help_Customer_Service_Gamepad:SetSavedField(fieldType, fieldValue, refreshVisible)
    local oldFieldValue = self:GetSavedField(fieldType)
    if oldFieldValue ~= fieldValue then
        ZO_Help_GenericTicketSubmission_Gamepad.SetSavedField(self, fieldType, fieldValue, refreshVisible)

        if fieldType == ZO_HELP_TICKET_FIELD_TYPE.IMPACT then
            local categoryData = fieldValue and fieldValue.categories and fieldValue.categories[1]
            self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.CATEGORY, categoryData)
        elseif fieldType == ZO_HELP_TICKET_FIELD_TYPE.CATEGORY then
            local subcategoryData = fieldValue and fieldValue.subcategories and fieldValue.subcategories[1]
            self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.SUBCATEGORY, subcategoryData)
        end
    end
end


function ZO_Help_Customer_Service_Gamepad:UpdateDropdownSelection(dropdown, fieldType)
    local savedFieldData = self:GetSavedField(fieldType)
    if not (savedFieldData and dropdown:SetSelectedItemByEval(function(entry) return entry.data == savedFieldData end)) then
        local IGNORE_CALLBACK = true
        dropdown:SelectFirstItem(IGNORE_CALLBACK)
    end
end

function ZO_Help_Customer_Service_Gamepad:SetCurrentDropdown(dropdown)
    self.currentDropdown = dropdown
end

function ZO_Help_Customer_Service_Gamepad:ActivateCurrentDropdown(fieldType)
    local currentDropdown = self.currentDropdown
    if currentDropdown then
        currentDropdown:Activate()
        local savedFieldData = self:GetSavedField(fieldType)
        local entryIndex = savedFieldData and currentDropdown:GetIndexByEval(function(entry) return entry.data == savedFieldData end) or 1
        currentDropdown:SetHighlightedItem(entryIndex)
    end
end

function ZO_Help_Customer_Service_Gamepad:AddTextFieldEntry(fieldType, header, required, locked)
    local entryData = ZO_GamepadEntryData:New(header)
    entryData.fieldType = fieldType
    entryData.header = header
    entryData.isTextField = true
    entryData.isRequired = required
    entryData.isLocked = locked
    -- This will get set in the setup function if applicable
    entryData.editBoxNarration = nil

    if locked then
        local function narrationFunction(entryData, entryControl)
            local narrations = {}
            ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(GetString(SI_SCREEN_NARRATION_LOCKED_ICON_NARRATION)))
            ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(entryData.editBoxNarration))
            return narrations
        end
        entryData.narrationText = narrationFunction
        self.itemList:AddEntryWithHeader("ZO_Gamepad_Help_EditLockedEntry_MultiLine", entryData)
    else
        entryData.narrationText = ZO_GetDefaultParametricListEditBoxNarrationText
        self.itemList:AddEntryWithHeader("ZO_GamepadTextFieldItem_Multiline", entryData)
    end
end

function ZO_Help_Customer_Service_Gamepad:AddDropdownEntry(fieldType, header, list, listStringName, listDescriptionStringName)
    local entryData = ZO_GamepadEntryData:New("Dropdown")
    entryData.list = list
    entryData.listStringName = listStringName
    entryData.listDescriptionStringName = listDescriptionStringName
    entryData.fieldType = fieldType
    entryData.header = header
    entryData.isDropdown = true
    entryData.narrationText = ZO_GetDefaultParametricListDropdownNarrationText

    self.itemList:AddEntryWithHeader("ZO_Gamepad_Help_Dropdown_Item", entryData)
end

function ZO_Help_Customer_Service_Gamepad:AddSubmitEntry()
    local entryData = ZO_GamepadEntryData:New(GetString(SI_GAMEPAD_HELP_SUBMIT_TICKET), ZO_GAMEPAD_SUBMIT_ENTRY_ICON)
    entryData.isSubmit = true

    self.itemList:AddEntry("ZO_GamepadTextFieldSubmitItem", entryData)
end

function ZO_Help_Customer_Service_Gamepad:BuildList()
    self.itemList:Clear()

    -- impacts
    self:AddDropdownEntry(ZO_HELP_TICKET_FIELD_TYPE.IMPACT, GetString(SI_GAMEPAD_HELP_FIELD_TITLE_IMPACT), ZO_HELP_ASK_FOR_HELP_CATEGORY_INFO.impacts, ZO_HELP_ASK_FOR_HELP_CATEGORY_INFO.impactStringName)
    local omitOtherFields = false

    local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
    if impactData then
        omitOtherFields = not self:MeetsExternalInfoRequirements() and impactData.externalInfoInstructions

        if not omitOtherFields then
            if impactData.categories then
                -- contextual categories
                self:AddDropdownEntry(ZO_HELP_TICKET_FIELD_TYPE.CATEGORY, GetString(SI_GAMEPAD_HELP_FIELD_TITLE_CATEGORY), impactData.categories, impactData.categoryStringName, impactData.categoryDescriptionStringName)

                local categoryData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.CATEGORY)
                if categoryData and categoryData.subcategories then
                    -- contextual subcategories
                    self:AddDropdownEntry(ZO_HELP_TICKET_FIELD_TYPE.SUBCATEGORY, GetString(SI_GAMEPAD_HELP_FIELD_TITLE_SUBCATEGORY), categoryData.subcategories, categoryData.subcategoryStringName, categoryData.subcategoryDescriptionStringName)
                end
            end

            -- required details
            if impactData.detailsTitle then
                local FIELD_IS_REQUIRED = true
                self:AddTextFieldEntry(ZO_HELP_TICKET_FIELD_TYPE.DETAILS, GetString(SI_GAMEPAD_HELP_FIELD_TITLE_REQUIRED_DETAILS), FIELD_IS_REQUIRED, self.requiredInfoProvidedInternally)
            end
        end
    end

    if not omitOtherFields then
        -- additional details
        self:AddTextFieldEntry(ZO_HELP_TICKET_FIELD_TYPE.DESCRIPTION, GetString(SI_CUSTOMER_SERVICE_ASK_FOR_HELP_ADDITIONAL_DETAILS))
    end
    
    self:AddSubmitEntry()

    self.itemList:Commit()
    self.dirty = false
end

-- Customer Service has dynamic categories, which means it's not always enough to just refresh what's visible.
-- We need to rebuild the list when we reset in case the controls have changed.
function ZO_Help_Customer_Service_Gamepad:ResetTicket()
    ZO_ClearTable(self.savedFields)
    self:BuildList()
    self.requiredInfoProvidedInternally = false
    ZO_HELP_GENERIC_TICKET_SUBMISSION_MANAGER:SetReportPlayerTicketSubmittedCallback(nil)
end

function ZO_Help_Customer_Service_Gamepad:OnShow()
    ZO_Help_GenericTicketSubmission_Gamepad.OnShow(self)
    self:RefreshExternalInfoTooltip()
end

function ZO_Help_Customer_Service_Gamepad:OnHiding()
    ZO_Help_GenericTicketSubmission_Gamepad.OnHiding(self)

    local targetData = self.itemList:GetTargetData()
    if targetData and targetData.isDropdown then
        local targetControl = self.itemList:GetTargetControl()
        local dropdown = targetControl.dropdown
        dropdown:Deactivate()
    end
end

function ZO_Help_Customer_Service_Gamepad:SetupTicket(impact, category, subcategory, externalInfo)
    self:ResetTicket()
    self:SetCategories(impact, category, subcategory)

    if externalInfo then
        local externalInfoType = type(externalInfo)
        if externalInfoType == "function" then
            externalInfo()
        else
            local impactData = self:GetSavedField(ZO_HELP_TICKET_FIELD_TYPE.IMPACT)
            if impactData then
                if impactData.externalInfoRegistrationFunction then
                    impactData.externalInfoRegistrationFunction(externalInfo)
                end
                if impactData.externalInfoTitle then
                    self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.EXTERNAL_INFO, externalInfo)
                else
                    self:SetSavedField(ZO_HELP_TICKET_FIELD_TYPE.DETAILS, externalInfo)
                end
            end
        end
        self:RefreshExternalInfoTooltip()
    end

    self:SetRequiredInfoProvidedInternally(true)
    self:ChangeTicketState(ZO_HELP_TICKET_STATE.FIELD_ENTRY)
    self:BuildList()
end

function ZO_Help_Customer_Service_Gamepad:OnSelectionChanged()
    if self.activeEditBox then
        self.activeEditBox:LoseFocus()
    end
end

function ZO_Help_Customer_Service_Gamepad_OnInitialize(control)
    HELP_CUSTOMER_SERVICE_GAMEPAD = ZO_Help_Customer_Service_Gamepad:New(control)
end