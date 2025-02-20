local GAMEPAD_CREATE_ACCOUNT_ERROR_DIALOG = "GAMEPAD_CREATE_ACCOUNT_ERROR_DIALOG"

-- Main class.
local ZO_CreateAccount_Gamepad = ZO_InitializingObject:Subclass()

function ZO_CreateAccount_Gamepad:Initialize(control)
    self.control = control
    self.entryByCountry = {}

    self:ResetAccountData()

    local createAccount_Gamepad_Fragment = ZO_FadeSceneFragment:New(self.control)
    CREATE_ACCOUNT_GAMEPAD_SCENE = ZO_Scene:New("CreateAccount_Gamepad", SCENE_MANAGER)
    CREATE_ACCOUNT_GAMEPAD_SCENE:AddFragment(createAccount_Gamepad_Fragment)

    CREATE_ACCOUNT_GAMEPAD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            self:PerformDeferredInitialize()

            self:ResetMainList()
            KEYBIND_STRIP:RemoveDefaultExit()
            self:SwitchToMainList()
        elseif newState == SCENE_HIDDEN then
            self:ResetScreen()
            self:SwitchToKeybind(nil)
            KEYBIND_STRIP:RestoreDefaultExit()
        end
    end)
end

function ZO_CreateAccount_Gamepad:ResetScreen()
    self.optionsControl:SetHidden(true)
    self.header:SetHidden(false)

    self.optionsList:Deactivate()

    if self.countriesList then
        self.countriesList:Deactivate()
    end
end

function ZO_CreateAccount_Gamepad:ResetAccountData()
    self.enteredAccountName = ""
    self.selectedCountry = ""
    self.enteredEmail = ""
    self.emailSignup = false
    self.lastErrorMessage = ""
    self.secondaryEntriesDirty = true
    self.creatingAccount = false
end

function ZO_CreateAccount_Gamepad:PerformDeferredInitialize()
    if not self.initialized then 
        self.initialized = true

        self.header = self.control:GetNamedChild("Container"):GetNamedChild("Header")

        self:SetupOptionsList()
        self:InitKeybindingDescriptors()

        self:InitializeErrorDialog()
    end
end

do
    local g_lastErrorString = nil

    function ZO_CreateAccount_Gamepad:InitializeErrorDialog()
        ZO_Dialogs_RegisterCustomDialog(GAMEPAD_CREATE_ACCOUNT_ERROR_DIALOG,
        {
            gamepadInfo =
            {
                dialogType = GAMEPAD_DIALOGS.BASIC,
            },

            mustChoose = true,

            title =
            {
                text = SI_CREATEACCOUNT_ERROR_HEADER,
            },

            mainText =
            {
                text = function() return g_lastErrorString end,
            },

            buttons =
            {
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = SI_DIALOG_EXIT,
                },
            }
        })
    end

    function ZO_CreateAccount_Gamepad:ShowError(message)
        g_lastErrorString = message
        ZO_Dialogs_ShowGamepadDialog(GAMEPAD_CREATE_ACCOUNT_ERROR_DIALOG)
    end

    function ZO_CreateAccount_Gamepad:ClearError()
        g_lastErrorString = ""
    end
end

function ZO_CreateAccount_Gamepad:HasValidCountrySelected()
    return self.selectedCountry ~= nil and self.selectedCountry ~= ""
end

function ZO_CreateAccount_Gamepad:CreateAccountSelected()
    if not self:HasValidCountrySelected() then
        self:ShowError(GetString(SI_CONSOLE_CREATEACCOUNT_NOREGION))
    elseif self.enteredEmail == nil or self.enteredEmail == "" then
        self:ShowError(GetString(SI_CONSOLE_CREATEACCOUNT_NOEMAIL))
    elseif not self.creatingAccount then
        self:ClearError()
        PregameStateManager_AdvanceState()
        self.creatingAccount = true
    end
end

function ZO_CreateAccount_Gamepad:InitKeybindingDescriptors()
    self.mainKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Select Control
        {    
            name = GetString(SI_GAMEPAD_SELECT_OPTION),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local data = self.optionsList:GetTargetData()
                local control = self.optionsList:GetTargetControl()
                if data ~= nil and data.selectedCallback ~= nil and control ~= nil then
                    data.selectedCallback(control, data)
                end
            end,
        },
        -- Back
        KEYBIND_STRIP:GenerateGamepadBackButtonDescriptor(function()
                PlaySound(SOUNDS.NEGATIVE_CLICK)
                PregameStateManager_SetState("CreateLinkAccount")
            end)
    }
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.mainKeybindStripDescriptor, self.optionsList)
end

function ZO_CreateAccount_Gamepad:SwitchToKeybind(keybindStripDescriptor)
    if self.keybindStripDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    end
    self.keybindStripDescriptor = keybindStripDescriptor
    if keybindStripDescriptor then
        KEYBIND_STRIP:AddKeybindButtonGroup(keybindStripDescriptor)
    end
end

function ZO_CreateAccount_Gamepad:SwitchToMainList()
    self:ResetScreen()

    self:AddSecondaryListEntries()

    self:SwitchToKeybind(self.mainKeybindStripDescriptor)

    self.optionsList:Activate()
    self.optionsList:RefreshVisible()
    self.optionsControl:SetHidden(false)
    self.defaultTextLabel:SetHidden(self:HasValidCountrySelected())
end

function ZO_CreateAccount_Gamepad:SwitchToCountryList()
    if self.countriesList:GetNumItems() == 0 then
        return
    end
    self:ResetScreen()

    self:SwitchToKeybind(self.countriesKeybindStripDescriptor)

    self.optionsControl:SetHidden(false)
    self.countriesList:Activate()
    self.countriesList:HighlightSelectedItem()
    self.defaultTextLabel:SetHidden(true)
end

function ZO_CreateAccount_Gamepad:AddComboBox(text, contents, selectedCallback, editedCallback)
    local option = ZO_GamepadEntryData:New()
    option:SetHeader(text)
    option.contents = contents
    option.selectedCallback = selectedCallback
    option.contentsChangedCallback = editedCallback
    option:SetFontScaleOnSelection(false)
    self.optionsList:AddEntryWithHeader("ZO_GamepadCountrySelectorTemplate", option)
end

function ZO_CreateAccount_Gamepad:AddTextEdit(text, contents, selectedCallback, editedCallback)
    local option = ZO_GamepadEntryData:New() -- No text to populate - it uses a header instead.
    option:SetHeader(text)
    option.contents = contents
    option.selectedCallback = selectedCallback
    option.contentsChangedCallback = editedCallback
    option:SetFontScaleOnSelection(true)
    self.optionsList:AddEntry("ZO_PregameGamepadTextEditTemplateWithHeader", option)
end

function ZO_CreateAccount_Gamepad:AddCheckbox(text, checked, callback)
    local option = self:CreateCheckboxData(text, checked, callback)
    self.optionsList:AddEntry("ZO_CheckBoxTemplate_Pregame_Gamepad", option)
end

function ZO_CreateAccount_Gamepad:CreateCheckboxData(text, checked, callback)
    local option = ZO_GamepadEntryData:New(text)
    option.checked = checked
    option.setChecked = callback
    option.selectedCallback = ZO_GamepadCheckBoxTemplate_OnClicked
    option:SetFontScaleOnSelection(true)
    option.list = self.optionsList
    return option
end

function ZO_CreateAccount_Gamepad:AddButton(text, callback)
    local option = self:CreateButtonData(text, callback)
    self.optionsList:AddEntry("ZO_PregameGamepadButtonWithTextTemplate", option)
end

function ZO_CreateAccount_Gamepad:CreateButtonData(text, callback)
    local option = ZO_GamepadEntryData:New(text)
    option.selectedCallback = callback
    option:SetFontScaleOnSelection(true)
    return option
end

function ZO_CreateAccount_Gamepad:ActivateEditbox(edit, isEmailBox)
    if isEmailBox == true then
        edit:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_EMAIL)
    else
        edit:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_DEFAULT)
    end
    edit:TakeFocus()
end

function ZO_CreateAccount_Gamepad:SetupOptionsList()
    -- Setup the actual list.
    self.optionsControl = self.control:GetNamedChild("Container"):GetNamedChild("Options")
    self.optionsList = ZO_GamepadVerticalParametricScrollList:New(self.optionsControl:GetNamedChild("List"))

    self.optionsList:SetAlignToScreenCenter(true)

    self.optionsList:AddDataTemplateWithHeader("ZO_PregameGamepadTextEditTemplate", ZO_PregameGamepadTextEditTemplate_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_PregameGamepadTextEditHeaderTemplate")
    self.optionsList:AddDataTemplate("ZO_CheckBoxTemplate_Pregame_Gamepad", ZO_GamepadCheckBoxListEntryTemplate_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    self.optionsList:AddDataTemplate("ZO_PregameGamepadButtonWithTextTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)

    local function SetupCountrySelector(control, data, selected, reselectingDuringRebuild, enabled, active)
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
        if self.comboControl ~= control then
            self.comboControl = control
            self.countriesList = control.dropdown
            self.countriesList:SetDeactivatedCallback(function() self:SwitchToMainList() end)
            self.countriesList:SetSortsItems(false)
            self.defaultTextLabel = control:GetNamedChild("DefaultText")
            self.defaultTextLabel:SetText(GetString(SI_CREATEACCOUNT_SELECT_REGION))
        end
    end

    self.optionsList:AddDataTemplateWithHeader("ZO_GamepadCountrySelectorTemplate", SetupCountrySelector, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_PregameGamepadTextEditHeaderTemplate")

    -- Populate the main list.
    self:ResetMainList()
end

function ZO_CreateAccount_Gamepad:ResetMainList()
    self:ResetAccountData()

    self.optionsList:Clear()

    if ZO_IsPCUI() then
        self:AddTextEdit(GetString(SI_KEYBOARD_CREATEACCOUNT_ACCOUNT_NAME_LABEL), function(data) return self.enteredAccountName end, function(control, data) self:ActivateEditbox(control.edit, true) end, function(newText) self.enteredAccountName = newText end)
    end

    self:AddComboBox(GetString(SI_CREATEACCOUNT_REGION), function(data) return self.selectedCountry end, function(control, data)
                self:SwitchToCountryList()
            end)

    self:AddTextEdit(GetString(SI_CREATEACCOUNT_EMAIL), function(data) return self.enteredEmail end, function(control, data) self:ActivateEditbox(control.edit, true) end, function(newText) self.enteredEmail = newText end)

    self.optionsList:Commit()
    self.countriesList:ClearItems()
    self:PopulateCountriesDropdownList()
end

function ZO_CreateAccount_Gamepad:AddSecondaryListEntries()
    if self.selectedCountry ~= "" and self.secondaryEntriesDirty then
        if self.emailSignupOptionData then
            self.optionsList:RemoveEntry("ZO_CheckBoxTemplate_Pregame_Gamepad", self.emailSignupOptionData)
        end
        if self.createButtonOptionData then
            self.optionsList:RemoveEntry("ZO_PregameGamepadButtonWithTextTemplate", self.createButtonOptionData)
        end

        if not self.autoEmailSubscribe then
            if not self.emailSignupOptionData then
                local function IsChecked(data)
                    return self.emailSignup
                end
                local function SetCheckedCallback(data, checked)
                    self.emailSignup = checked
                end
                self.emailSignupOptionData = self:CreateCheckboxData(GetString(SI_CREATEACCOUNT_EMAIL_SIGNUP), IsChecked, SetCheckedCallback)
            end
            self.optionsList:AddEntry("ZO_CheckBoxTemplate_Pregame_Gamepad", self.emailSignupOptionData)
        end

        if not self.createButtonOptionData then
            local function ButtonSelectedCallback(control, data)
                PlaySound(SOUNDS.POSITIVE_CLICK)
                self:CreateAccountSelected()
            end
            self.createButtonOptionData = self:CreateButtonData(GetString(SI_CREATEACCOUNT_CREATE_ACCOUNT_BUTTON), ButtonSelectedCallback)
        end
        self.optionsList:AddEntry("ZO_PregameGamepadButtonWithTextTemplate", self.createButtonOptionData)

        self.secondaryEntriesDirty = false

        self.optionsList:Commit()
    end
end

function ZO_CreateAccount_Gamepad:PopulateCountriesDropdownList()
    -- Checking for 0 to ensure we only setup the country list once
    if self.countriesList:GetNumItems() == 0 then
        local numCountries = GetNumCountries()
        if numCountries == 0 then
            -- Def might not be ready yet, try again in a moment (ESO-856779)
            self.defaultTextLabel:SetText(GetString(SI_CREATEACCOUNT_SELECT_REGIONS_LOADING))
            zo_callLater(function() self:PopulateCountriesDropdownList() end, 250)
            return
        end
        
        self.defaultTextLabel:SetText(GetString(SI_CREATEACCOUNT_SELECT_REGION))

        -- Populate the combobox list.
        self.countriesList:ClearItems()

        local function OnCountrySelected(comboBox, entryText, entry)
            self.selectedCountry = entryText 
            self.countryCode = entry.countryCode
            if self.autoEmailSubscribe ~= entry.autoEmailSubscribe then
                self.autoEmailSubscribe = entry.autoEmailSubscribe
                self.secondaryEntriesDirty = true
            end
        end

        for i = 1, numCountries do
            local countryName, countryCode, _, isAllowedInAccountCreation, autoEmailSubscribe = GetCountryDataForIndex(i)
            if isAllowedInAccountCreation then
                local option = self.countriesList:CreateItemEntry(countryName, OnCountrySelected)
                option.countryCode = countryCode
                option.autoEmailSubscribe = autoEmailSubscribe
                self.countriesList:AddItem(option)
            end
        end

        self.countriesList:HighlightSelectedItem()
        self.optionsList:Commit()
    end
end

function ZO_CreateAccount_Gamepad:GetEnteredEmail()
    return self.enteredEmail
end

function ZO_CreateAccount_Gamepad:ShouldReceiveNewsEmail()
    -- Auto subscribe never sees an option
    return self.autoEmailSubscribe or self.emailSignup
end

function ZO_CreateAccount_Gamepad:GetCountryCode()
    return self.countryCode
end

function ZO_CreateAccount_Gamepad:GetEnteredAccountName()
    return self.enteredAccountName
end

function ZO_CreateAccount_Gamepad_Initialize(self)
    CREATE_ACCOUNT_GAMEPAD = ZO_CreateAccount_Gamepad:New(self)
end
