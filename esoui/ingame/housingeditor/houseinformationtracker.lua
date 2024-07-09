ZO_HouseInformationTracker = ZO_HUDTracker_Base:Subclass()

function ZO_HouseInformationTracker:Initialize(control, ...)
    -- Order matters
    self.populationLabel = control:GetNamedChild("ContainerPopulation")
    self.tagsLabel = control:GetNamedChild("ContainerTags")
    ZO_HUDTracker_Base.Initialize(self, control, ...)
end

function ZO_HouseInformationTracker:InitializeSetting()
    self:UpdateVisibility()

    local function OnInterfaceSettingChanged(eventCode, settingType, settingId)
        if settingType == SETTING_TYPE_UI then
            if settingId == UI_SETTING_SHOW_HOUSE_TRACKER then
                self:UpdateVisibility()
            end
        end
    end

    self.control:RegisterForEvent(EVENT_INTERFACE_SETTING_CHANGED, OnInterfaceSettingChanged)
end

function ZO_HouseInformationTracker:InitializeStyles()
    -- ZO_HUDTracker_Base override.
    self.styles =
    {
        keyboard =
        {
            CONTAINER_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT),
            CONTAINER_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT),

            FONT_HEADER = "ZoFontGameShadow",
            FONT_POPULATION = "ZoFontGameShadow",
            FONT_SUBLABEL = "ZoFontGameShadow",
            FONT_TAGS = "ZoFontGameShadow",

            HEADER_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, self.container),
            HEADER_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.container),

            POPULATION_HEADERLABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, self.headerLabel, BOTTOMLEFT, 10, 2),
            POPULATION_HEADERLABEL_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.headerLabel, BOTTOMRIGHT, 0, 2),

            POPULATION_SUBLABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, self.subLabel, BOTTOMLEFT, 0, 0),
            POPULATION_SUBLABEL_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.subLabel, BOTTOMRIGHT, 0, 0),

            SUBLABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, self.headerLabel, BOTTOMLEFT, 10, 2),
            SUBLABEL_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.headerLabel, BOTTOMRIGHT, 0, 2),

            TAGS_LABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, self.populationLabel, BOTTOMLEFT, 0, 0),
            TAGS_LABEL_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.populationLabel, BOTTOMRIGHT, 0, 0),

            TEXT_HORIZONTAL_ALIGNMENT = TEXT_ALIGN_LEFT,
            TEXT_TYPE_HEADER = MODIFY_TEXT_TYPE_NONE,

            TOP_LEVEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, ZO_ZoneStoryTracker, BOTTOMLEFT, 0, 10),
            TOP_LEVEL_SECONDARY_ANCHOR = ZO_Anchor:New(RIGHT, GuiRoot, RIGHT, -15, 10, ANCHOR_CONSTRAINS_X),
        },
        gamepad =
        {
            CONTAINER_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT),
            CONTAINER_SECONDARY_ANCHOR = ZO_Anchor:New(TOPRIGHT),

            FONT_HEADER = "ZoFontGamepadBold27",
            FONT_POPULATION = "ZoFontGamepad34",
            FONT_SUBLABEL = "ZoFontGamepad34",
            FONT_TAGS = "ZoFontGamepad34",

            HEADER_PRIMARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.container),

            POPULATION_HEADERLABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.headerLabel, BOTTOMRIGHT, 0, 10),

            POPULATION_SUBLABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.subLabel, BOTTOMRIGHT, 0, 0),

            SUBLABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.headerLabel, BOTTOMRIGHT, 0, 10),

            TAGS_LABEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPRIGHT, self.populationLabel, BOTTOMRIGHT, 0, 0),

            TEXT_HORIZONTAL_ALIGNMENT = TEXT_ALIGN_RIGHT,
            TEXT_TYPE_HEADER = MODIFY_TEXT_TYPE_UPPERCASE,

            TOP_LEVEL_PRIMARY_ANCHOR = ZO_Anchor:New(TOPLEFT, ZO_ZoneStoryTracker, BOTTOMLEFT, 0, 20),
            TOP_LEVEL_SECONDARY_ANCHOR = ZO_Anchor:New(RIGHT, GuiRoot, RIGHT, -15, 10, ANCHOR_CONSTRAINS_X),
        },
    }

    self.platformStyle = ZO_PlatformStyle:New(function(style)
        self:ApplyPlatformStyle(style)
    end, self.styles.keyboard, self.styles.gamepad)

    self.platformStyle:Apply()
end

function ZO_HouseInformationTracker:ApplyPlatformStyle(style)
    ZO_HUDTracker_Base.ApplyPlatformStyle(self, style)

    self.headerLabel:SetHorizontalAlignment(style.TEXT_HORIZONTAL_ALIGNMENT)
    self.populationLabel:SetFont(style.FONT_POPULATION)
    self.populationLabel:SetHorizontalAlignment(style.TEXT_HORIZONTAL_ALIGNMENT)
    self.subLabel:SetHorizontalAlignment(style.TEXT_HORIZONTAL_ALIGNMENT)
    self.tagsLabel:SetFont(style.FONT_TAGS)
    self.tagsLabel:SetHorizontalAlignment(style.TEXT_HORIZONTAL_ALIGNMENT)
end

function ZO_HouseInformationTracker:GetPrimaryAnchor()
    return self.currentStyle.TOP_LEVEL_PRIMARY_ANCHOR
end

function ZO_HouseInformationTracker:GetSecondaryAnchor()
    return self.currentStyle.TOP_LEVEL_SECONDARY_ANCHOR
end

function ZO_HouseInformationTracker:RegisterEvents()
    ZO_HUDTracker_Base.RegisterEvents(self)
    self:InitializeSetting()

    EVENT_MANAGER:RegisterForEvent("HouseInformationTracker", EVENT_PLAYER_ACTIVATED, ZO_GetEventForwardingFunction(self, self.Refresh))
    EVENT_MANAGER:RegisterForEvent("HouseInformationTracker", EVENT_HOUSE_TOURS_CURRENT_HOUSE_LISTING_UPDATED, ZO_GetEventForwardingFunction(self, self.Refresh))
    HOUSING_EDITOR_STATE:RegisterCallback("HouseSettingsChanged", self.Refresh, self)
    HOUSING_EDITOR_STATE:RegisterCallback("HouseChanged", self.Refresh, self)
    HOUSE_TOURS_PLAYER_LISTINGS_MANAGER:RegisterCallback("ListingOperationCompleted", function(operationType, houseId, result)
        if result == HOUSE_TOURS_LISTING_RESULT_SUCCESS and houseId == HOUSING_EDITOR_STATE:GetHouseId() and HOUSING_EDITOR_STATE:IsLocalPlayerHouseOwner() then
            -- The listing for the current house was updated.
            self:RefreshListingTags()
        end
    end)
end

function ZO_HouseInformationTracker:Refresh()
    local housingEditorState = HOUSING_EDITOR_STATE
    local houseInstance = housingEditorState:IsHouseInstance()
    self:GetFragment():SetHiddenForReason("NonHouseZone", not houseInstance, DEFAULT_HUD_DURATION, DEFAULT_HUD_DURATION)
    if not houseInstance then
        return
    end

    local houseName = housingEditorState:GetHouseName()
    local headerText = zo_strformat(SI_HOUSING_INFORMATION_TRACKER_HOUSE_NAME, houseName)
    self:SetHeaderText(headerText)

    local ownerName = housingEditorState:GetOwnerName()
    if ownerName and not housingEditorState:IsLocalPlayerHouseOwner() then
        local sublabelText = zo_strformat(SI_HOUSING_INFORMATION_TRACKER_OWNER_NAME, ownerName)
        self:SetSubLabelText(sublabelText)
        self.subLabel:SetHidden(false)
    else
        self:SetSubLabelText("")
        self.subLabel:SetHidden(true)
    end

    local SUPPRESS_ANCHOR_REFRESH = true
    self:RefreshListingTags(SUPPRESS_ANCHOR_REFRESH)

    local population = housingEditorState:GetPopulation()
    local maxPopulation = housingEditorState:GetMaxPopulation()
    local populationText = zo_strformat(SI_HOUSING_INFORMATION_TRACKER_POPULATION, population, maxPopulation)
    self.populationLabel:SetText(populationText)

    self:RefreshAnchors()
end

function ZO_HouseInformationTracker:RefreshListingTags(suppressAnchorRefresh)
    local tagValues = {GetCurrentHouseTourListingTags()}
    if #tagValues == 0 then
        self.tagsLabel:SetText("")
    else
        local tags = ZO_FormatHouseToursTagsText({GetCurrentHouseTourListingTags()})
        self.tagsLabel:SetText(tags)
    end

    if not suppressAnchorRefresh then
        self:RefreshAnchors()
    end
end

function ZO_HouseInformationTracker:RefreshAnchors()
    -- ZO_HUDTracker_Base override.
    ZO_HUDTracker_Base.RefreshAnchors(self)

    local style = self.currentStyle
    if self.subLabel:IsControlHidden() then
        self:RefreshAnchorSetOnControl(self.populationLabel, style.POPULATION_HEADERLABEL_PRIMARY_ANCHOR, style.POPULATION_HEADERLABEL_SECONDARY_ANCHOR)
    else
        self:RefreshAnchorSetOnControl(self.populationLabel, style.POPULATION_SUBLABEL_PRIMARY_ANCHOR, style.POPULATION_SUBLABEL_SECONDARY_ANCHOR)
    end
    self:RefreshAnchorSetOnControl(self.tagsLabel, style.TAGS_LABEL_PRIMARY_ANCHOR, style.TAGS_LABEL_SECONDARY_ANCHOR)
end

function ZO_HouseInformationTracker:Update()
    -- ZO_HUDTracker_Base override.
    self:Refresh()
end

function ZO_HouseInformationTracker:UpdateVisibility()
    local fragment = self:GetFragment()
    local enabled = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_HOUSE_TRACKER)
    fragment:SetHiddenForReason("DisabledBySetting", not enabled, 0, 0)
end

function ZO_HouseInformationTracker_OnInitialized(control)
    local tracker = ZO_HouseInformationTracker:New(control)
    HOUSE_INFORMATION_TRACKER = tracker
    HOUSE_INFORMATION_TRACKER_FRAGMENT = tracker:GetFragment()
end