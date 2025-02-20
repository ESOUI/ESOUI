local SETUP_MODE_NONE = 0
local SETUP_MODE_NEW = 1
local SETUP_MODE_LINK = 2
local SETUP_MODE_ACTIVATE = 3

local COUNTRY_DROPDOWN_STATE =
{
    SHOW = 1,
    HIDE = 2,
    LOADING = 3,
}

local CreateLinkAccount_Keyboard = ZO_LoginBase_Keyboard:Subclass()

function CreateLinkAccount_Keyboard:New(...)
    return ZO_LoginBase_Keyboard.New(self, ...)
end

function CreateLinkAccount_Keyboard:Initialize(control)
    ZO_LoginBase_Keyboard.Initialize(self, control)

    self.accountSetupContainer = control:GetNamedChild("AccountSetup")
    self.createRadio = self.accountSetupContainer:GetNamedChild("CreateRadio")
    self.activateRadio = self.accountSetupContainer:GetNamedChild("ActivateRadio")

    self.radioGroup = ZO_RadioButtonGroup:New()
    self.radioGroup:Add(self.createRadio)
    self.radioGroup:Add(self.activateRadio)

    -- Create Account controls
    self.newAccountContainer = control:GetNamedChild("NewAccount")
    local newAccountScrollChild = self.newAccountContainer:GetNamedChild("ScrollChild")
    self.accountNameEntry = newAccountScrollChild:GetNamedChild("AccountNameEntry")
    self.accountNameEntryEdit = self.accountNameEntry:GetNamedChild("Edit")
    self.accountNameInstructionsControl = self.newAccountContainer:GetNamedChild("Instructions")
    self.accountNameDescriptionLabel = newAccountScrollChild:GetNamedChild("AccountNameDescription")
    self.countryLabel = newAccountScrollChild:GetNamedChild("CountryLabel")
    self.countryDropdown = newAccountScrollChild:GetNamedChild("CountryDropdown")
    self.countryDropdownDefaultText = self.countryDropdown:GetNamedChild("DefaultText")
    self.countryDropdownState = COUNTRY_DROPDOWN_STATE.SHOW
    self.emailLabel = newAccountScrollChild:GetNamedChild("EmailLabel")
    self.emailEntry = newAccountScrollChild:GetNamedChild("EmailEntry")
    self.emailEntryEdit = self.emailEntry:GetNamedChild("Edit")
    self.subscribeCheckbox = newAccountScrollChild:GetNamedChild("Subscribe")
    self.createAccountButton = newAccountScrollChild:GetNamedChild("CreateAccount")

    self.countryComboBox = ZO_ComboBox_ObjectFromContainer(self.countryDropdown)
    self.countryComboBox:SetSortsItems(false)

    self.accountNameEntryEdit:SetMaxInputChars(ACCOUNT_NAME_MAX_LENGTH)
    self.emailEntryEdit:SetMaxInputChars(MAX_EMAIL_LENGTH)

    self:SetupAccountNameInstructions()

    -- Link Account controls
    self.linkAccountContainer = control:GetNamedChild("LinkAccount")
    self.accountName = self.linkAccountContainer:GetNamedChild("AccountName")
    self.accountNameEdit = self.accountName:GetNamedChild("Edit")
    self.password = self.linkAccountContainer:GetNamedChild("Password")
    self.passwordEdit = self.password:GetNamedChild("Edit")
    self.capsLockWarning = self.linkAccountContainer:GetNamedChild("CapsLockWarning")
    self.linkAccountButton = self.linkAccountContainer:GetNamedChild("LinkAccount")

    -- Activate Account controls
    self.activateAccountContainer = control:GetNamedChild("ActivateAccount")
    self.activateAccountInstructionsLabel = self.activateAccountContainer:GetNamedChild("Instructions")
    self.activateAccountCodeLabel = self.activateAccountContainer:GetNamedChild("Code")

    local activationURLText = GetURLTextByType(APPROVED_URL_ESO_ACCOUNT_LINKING)
    local activationLink = ZO_URL_LINK_COLOR:Colorize(ZO_LinkHandler_CreateURLLink(activationURLText, activationURLText))
    self.activateAccountInstructionsLabel:SetText(zo_strformat(SI_LINKACCOUNT_ACTIVATION_MESSAGE, activationLink))

    self.mode = SETUP_MODE_NONE

    self:RefreshCheckboxHiddenStates()

    EVENT_MANAGER:RegisterForEvent("CreateLinkAccount", EVENT_SCREEN_RESIZED, function() self:ResizeControls() end)

    local function UpdateForCaps(capsLockIsOn)
        self.capsLockWarning:SetHidden(not capsLockIsOn)
    end

    self.capsLockWarning:RegisterForEvent(EVENT_CAPS_LOCK_STATE_CHANGED, function(eventCode, capsLockIsOn) UpdateForCaps(capsLockIsOn) end)
    
    self:UpdateCreateAccountButton()
    self:UpdateLinkAccountButton()
    self.capsLockWarning:SetHidden(not IsCapsLockOn())

    CREATE_LINK_ACCOUNT_FRAGMENT = ZO_FadeSceneFragment:New(control)
    CREATE_LINK_ACCOUNT_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            if IsUsingLinkedLogin() then
                self:PopulateCountryDropdown()
            end

            if self.mode == SETUP_MODE_ACTIVATE then
                LOGIN_MANAGER_KEYBOARD:RequestAccountActivationCode()
            end
        end
    end)

     local function OnActivationCodeReceived(eventId, activationCode)
        self.activationCode = activationCode

        local DELIMITER = " "
        local SEGMENT_LENGTH = 4
        local formattedCode = ZO_GenerateDelimiterSegmentedString(activationCode, SEGMENT_LENGTH, DELIMITER)
        self.activateAccountCodeLabel:SetText(formattedCode)

        if CREATE_LINK_ACCOUNT_FRAGMENT:IsShowing() then
            RegisterForLinkAccountActivationProgress()
        end
    end

    self.control:RegisterForEvent(EVENT_ACCOUNT_LINK_ACTIVATION_CODE_RECEIVED, OnActivationCodeReceived)
end

function CreateLinkAccount_Keyboard:GetControl()
    return self.control
end

function CreateLinkAccount_Keyboard:PopulateCountryDropdown()
    if not self.hasPopulatedCountryDropdown then
        local numCountries = GetNumCountries()
        if numCountries == 0 then
            -- Def might not be ready yet, try again in a moment (ESO-856779)
            self:SetCountryDropdownState(COUNTRY_DROPDOWN_STATE.LOADING)
            zo_callLater(function() self:PopulateCountryDropdown() end, 250)
            return
        end

        for i = 1, numCountries do
            local countryName, countryCode, _, isAllowedInAccountCreation, autoEmailSubscribe = GetCountryDataForIndex(i)

            if isAllowedInAccountCreation then
                local entry = self.countryComboBox:CreateItemEntry(countryName, function(...) self:OnCountrySelected(...) end)
                entry.countryName = countryName
                entry.countryCode = countryCode
                entry.autoEmailSubscribe = autoEmailSubscribe
                self.countryComboBox:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
            end
        end

        if numCountries == 1 then
            -- If there's only one choice, select that country immediately and disable the dropdown
            self.countryComboBox:SelectItemByIndex(1)
            self:SetCountryDropdownState(COUNTRY_DROPDOWN_STATE.HIDE)
        else
            self:SetCountryDropdownState(COUNTRY_DROPDOWN_STATE.SHOW)
        end

        self.countryComboBox:UpdateItems()
        self.hasPopulatedCountryDropdown = true
    end
end

function CreateLinkAccount_Keyboard:OnCountrySelected(comboBox, entryText, entry)
    self.selectedCountry = entry
    self.countryDropdownDefaultText:SetHidden(true)
    self:RefreshCheckboxHiddenStates()
    self:UpdateCreateAccountButton()
end

function CreateLinkAccount_Keyboard:SetRadioFromMode(mode)
    if mode ~= self.mode then
        if mode == SETUP_MODE_NEW then
            self.radioGroup:SetClickedButton(self.createRadio)
        elseif mode == SETUP_MODE_ACTIVATE then
            self.radioGroup:SetClickedButton(self.activateRadio)
        end
    end
end

function CreateLinkAccount_Keyboard:ChangeMode(newMode)
    self.mode = newMode

    if self.mode == SETUP_MODE_ACTIVATE then
        LOGIN_MANAGER_KEYBOARD:RequestAccountActivationCode()
    end

    self.newAccountContainer:SetHidden(newMode ~= SETUP_MODE_NEW)
    self.activateAccountContainer:SetHidden(newMode ~= SETUP_MODE_ACTIVATE)
end

function CreateLinkAccount_Keyboard:IsRequestedAccountNameValid()
    return self.accountNameValid
end

function CreateLinkAccount_Keyboard:CanCreateAccount()
    return self.emailEntryEdit:GetText() ~= "" and self.selectedCountry ~= nil and self:IsRequestedAccountNameValid()
end

function CreateLinkAccount_Keyboard:CanLinkAccount()
    return self.accountNameEdit:GetText() ~= "" and self.passwordEdit:GetText() ~= ""
end

function CreateLinkAccount_Keyboard:AttemptCreateAccount()
    if self:CanCreateAccount() then
        local email = self.emailEntryEdit:GetText()
        -- Auto subscribe never sees an option
        local emailSignup = self.selectedCountry.autoEmailSubscribe or ZO_CheckButton_IsChecked(self.subscribeCheckbox)
        local country = self.selectedCountry.countryCode
        local requestedAccountName = self.accountNameEntryEdit:GetText()

        LOGIN_MANAGER_KEYBOARD:AttemptCreateAccount(email, emailSignup, country, requestedAccountName)
    end
end

function CreateLinkAccount_Keyboard:AttemptLinkAccount()
    if self:CanLinkAccount() then
        local dialogData = { 
                                partnerAccount = GetExternalName(),
                                esoAccount = self.accountNameEdit:GetText(),
                                password = self.passwordEdit:GetText(),
                           }
        ZO_Dialogs_ShowDialog("LINK_ACCOUNT_KEYBOARD", dialogData)
    end
end

function CreateLinkAccount_Keyboard:UpdateCreateAccountButton()
    self.createAccountButton:SetEnabled(self:CanCreateAccount())
end

function CreateLinkAccount_Keyboard:UpdateLinkAccountButton()
    self.linkAccountButton:SetEnabled(self:CanLinkAccount())
end

function CreateLinkAccount_Keyboard:GetAccountNameEdit()
    return self.accountNameEdit
end

function CreateLinkAccount_Keyboard:GetPasswordEdit()
    return self.passwordEdit
end

function CreateLinkAccount_Keyboard:GetAccountNameEntryEdit()
    return self.accountNameEntryEdit
end

function CreateLinkAccount_Keyboard:GetEmailEntryEdit()
    return self.emailEntryEdit
end

function CreateLinkAccount_Keyboard:RefreshCheckboxHiddenStates()
    local platformDisablesSubscription = not DoesPlatformAllowForEmailSubscription()
    local noRegionOrAutoSubscription = not self.selectedCountry or self.selectedCountry.autoEmailSubscribe
    local subscriptionShouldBeHidden = platformDisablesSubscription or noRegionOrAutoSubscription
    if subscriptionShouldBeHidden ~= self.subscribeCheckbox:IsControlHidden() then
        if subscriptionShouldBeHidden then
            -- Email subscription isn't allowed, so remove the checkbox
            ZO_CheckButton_SetUnchecked(self.subscribeCheckbox)
            self:HideEmailSubscriptionCheckbox()
        else
            self:ShowEmailSubscriptionCheckbox()
        end
    end
end

function CreateLinkAccount_Keyboard:ShowEmailSubscriptionCheckbox()
    -- Show the email subscription checkbox, and reanchor the Create Account button
    self.subscribeCheckbox:SetHidden(false)

    -- use the Create Account button's current anchors, but use the subscribe checkbox as the relative point
    local _, point, _, relPoint, offsetX, offsetY = self.createAccountButton:GetAnchor(0)

    self.createAccountButton:ClearAnchors()
    self.createAccountButton:SetAnchor(point, self.subscribeCheckbox, relPoint, offsetX, offsetY)
end

function CreateLinkAccount_Keyboard:HideEmailSubscriptionCheckbox()
    -- Hide the email subscription checkbox, and reanchor the Create Account button
    self.subscribeCheckbox:SetHidden(true)

    -- use the Create Account button's current anchors, but use the subscribe checkbox's relative point
    local _, _, relTo = self.subscribeCheckbox:GetAnchor(0)
    local _, point, _, relPoint, offsetX, offsetY = self.createAccountButton:GetAnchor(0)

    self.createAccountButton:ClearAnchors()
    self.createAccountButton:SetAnchor(point, relTo, relPoint, offsetX, offsetY)
end

function CreateLinkAccount_Keyboard:SetCountryDropdownState(state)
    if self.countryDropdownState ~= state then
        self.countryDropdownState = state
        local emailLabelRelativeControl
        if self.countryDropdownState == COUNTRY_DROPDOWN_STATE.SHOW then
            self.countryLabel:SetHidden(false)
            self.countryLabel:SetText(GetString(SI_CREATEACCOUNT_REGION))
            self.countryDropdown:SetHidden(false)
            emailLabelRelativeControl = self.countryDropdown
        elseif self.countryDropdownState == COUNTRY_DROPDOWN_STATE.HIDE then
            self.countryLabel:SetHidden(true)
            self.countryDropdown:SetHidden(true)
            emailLabelRelativeControl = self.accountNameDescriptionLabel
        else -- COUNTRY_DROPDOWN_STATE.LOADING
            self.countryLabel:SetHidden(false)
            self.countryLabel:SetText(GetString(SI_CREATEACCOUNT_SELECT_REGIONS_LOADING))
            self.countryDropdown:SetHidden(true)
            emailLabelRelativeControl = self.countryLabel
        end

        self.emailLabel:ClearAnchors()
        self.emailLabel:SetAnchor(TOPLEFT, emailLabelRelativeControl, BOTTOMLEFT, 0, 15)
    end
end

function CreateLinkAccount_Keyboard:SetupAccountNameInstructions()
    if not self.accountNameInstructions then
        local ACCOUNT_NAME_INSTRUCTIONS_OFFSET_X = 15
        local ACCOUNT_NAME_INSTRUCTIONS_OFFSET_Y = 0

        self.accountNameInstructions = ZO_ValidAccountNameInstructions:New(self.accountNameInstructionsControl)
        self.accountNameInstructions:SetPreferredAnchor(LEFT, self.accountNameEntryEdit, RIGHT, ACCOUNT_NAME_INSTRUCTIONS_OFFSET_X, ACCOUNT_NAME_INSTRUCTIONS_OFFSET_Y)
    end
end

function CreateLinkAccount_Keyboard:ValidateAccountName()
    local requestedAccountName = self.accountNameEntryEdit:GetText()
    local accountNameViolations = { IsValidAccountName(requestedAccountName) }
    
    self.accountNameValid = #accountNameViolations == 0

    if self.accountNameValid then
        self:HideAccountNameInstructions()
    else
        self.accountNameInstructions:Show(self.accountNameEntryEdit, accountNameViolations)
    end

    self:UpdateCreateAccountButton()
end

function CreateLinkAccount_Keyboard:HideAccountNameInstructions()
    self.accountNameInstructions:Hide()
end

function CreateLinkAccount_Keyboard:CopyActivationCodeToClipboard()
    if self.activationCode then
        CopyToClipboard(self.activationCode)
    end
end

-- XML Handlers --

function ZO_CreateLinkAccount_Initialize(control)
    CREATE_LINK_ACCOUNT_KEYBOARD = CreateLinkAccount_Keyboard:New(control)
end

function ZO_CreateLinkAccount_SetNewAccountMode()
    CREATE_LINK_ACCOUNT_KEYBOARD:ChangeMode(SETUP_MODE_NEW)
end

function ZO_CreateLinkAccount_SetNewAccountModeFromLabel()
    CREATE_LINK_ACCOUNT_KEYBOARD:SetRadioFromMode(SETUP_MODE_NEW)
end

function ZO_CreateLinkAccount_SetActivateAccountMode()
    CREATE_LINK_ACCOUNT_KEYBOARD:ChangeMode(SETUP_MODE_ACTIVATE)
end

function ZO_CreateLinkAccount_SetActivateAccountModeFromLabel()
    CREATE_LINK_ACCOUNT_KEYBOARD:SetRadioFromMode(SETUP_MODE_ACTIVATE)
end

function ZO_CreateLinkAccount_AttemptCreateAccount()
    CREATE_LINK_ACCOUNT_KEYBOARD:AttemptCreateAccount()
end

function ZO_CreateLinkAccount_AttemptLinkAccount()
    CREATE_LINK_ACCOUNT_KEYBOARD:AttemptLinkAccount()
end

function ZO_CreateLinkAccount_PasswordEdit_TakeFocus()
    CREATE_LINK_ACCOUNT_KEYBOARD:GetPasswordEdit():TakeFocus()
end

function ZO_CreateLinkAccount_AccountNameEdit_TakeFocus()
    CREATE_LINK_ACCOUNT_KEYBOARD:GetAccountNameEdit():TakeFocus()
end

function ZO_CreateLinkAccount_AccountNameEdit_TakeFocus()
    CREATE_LINK_ACCOUNT_KEYBOARD:GetAccountNameEntryEdit():TakeFocus()
end

function ZO_CreateLinkAccount_EmailEdit_TakeFocus()
    CREATE_LINK_ACCOUNT_KEYBOARD:GetEmailEntryEdit():TakeFocus()
end

function ZO_CreateLinkAccount_UpdateCreateAccountButton()
    CREATE_LINK_ACCOUNT_KEYBOARD:UpdateCreateAccountButton()
end

function ZO_CreateLinkAccount_UpdateLinkAccountButton()
    CREATE_LINK_ACCOUNT_KEYBOARD:UpdateLinkAccountButton()
end

function ZO_CreateLinkAccount_ToggleCheckButtonFromLabel(labelControl)
    -- Assumes that the check button is the parent of the label
    local checkButton = labelControl:GetParent()

    ZO_CheckButton_SetCheckState(checkButton, not ZO_CheckButton_IsChecked(checkButton))
    CREATE_LINK_ACCOUNT_KEYBOARD:UpdateCreateAccountButton()
end

function ZO_CreateLinkAccount_CheckAccountNameValidity()
    CREATE_LINK_ACCOUNT_KEYBOARD:ValidateAccountName()
end

function ZO_CreateLinkAccount_OnAccountNameFocusLost()
    CREATE_LINK_ACCOUNT_KEYBOARD:HideAccountNameInstructions()
end

function ZO_CreateLinkAccount_OnCopyActivationCodeEnter(control)
    InitializeTooltip(InformationTooltip, control, LEFT, 0, 0, RIGHT)
    SetTooltipText(InformationTooltip, GetString(SI_KEYBOARD_LINKACCOUNT_ACTIVATION_COPY_ACTIVATION_CODE_TOOLTIP))
end

function ZO_CreateLinkAccount_OnCopyActivationCodeExit(control)
    ClearTooltip(InformationTooltip)
end

function ZO_CreateLinkAccount_CopyActivationCode()
    CREATE_LINK_ACCOUNT_KEYBOARD:CopyActivationCodeToClipboard()
end
