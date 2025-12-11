-- SenseiCastBar.lua
-- Full integration of Cast Bar with Sensei Class Resource Bar framework
-- Updated with Latency, Light Overlay, Advanced Config, and Animated Preview

local addonName, addonTable = ...

-- Get Sensei's addon table
local function GetSensei()
    return _G["SenseiClassResourceBar"] and _G["SenseiClassResourceBar"].addonTable
end

local SENSEI = GetSensei()
if not SENSEI then
    -- Defer initialization until Sensei is loaded
    local deferFrame = CreateFrame("Frame")
    deferFrame:RegisterEvent("ADDON_LOADED")
    deferFrame:SetScript("OnEvent", function(self, event, name)
        if name == "SenseiClassResourceBar" then
            SENSEI = GetSensei()
            self:UnregisterEvent("ADDON_LOADED")
            self:SetScript("OnEvent", nil)
            InitializeSenseiCastBar()
        end
    end)
    return
end

-- ============================================================================
-- CAST BAR MIXIN
-- ============================================================================

local CastBarMixin = Mixin({}, SENSEI.BarMixin)

function CastBarMixin:Init(config, parent, frameLevel)
    -- Call parent Init
    SENSEI.BarMixin.Init(self, config, parent, frameLevel)
    
    -- Cast/channel state
    self.casting = false
    self.channeling = false
    self.startTime = 0
    self.endTime = 0
    self.maxValue = 0
    self.castName = ""
    self.castIcon = nil
    self.notInterruptible = false
    self.duration = 0
    
    local frame = self:GetFrame()
    
    -- 1. Create Light Overlay (Brillo Progresivo)
    if not self.LightOverlay then
        self.LightOverlay = frame:CreateTexture(nil, "ARTWORK") -- Encima del background, debajo del border
        self.LightOverlay:SetColorTexture(1, 1, 1, 1)
        self.LightOverlay:SetBlendMode("ADD")
        self.LightOverlay:SetAlpha(0)
        self.LightOverlay:SetAllPoints(frame)
        self.LightOverlay:Hide()
    end

    -- 2. Create Icon texture
    if not self.Icon then
        self.Icon = frame:CreateTexture(nil, "OVERLAY")
        self.Icon:SetSize(config.defaultValues.iconSize, config.defaultValues.iconSize)
        self.Icon:SetPoint("LEFT", frame, "LEFT", config.defaultValues.iconX, config.defaultValues.iconY)
        self.Icon:Hide()
    end
    
    -- 3. Create Spell Name text
    if not self.SpellNameText then
        self.SpellNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.SpellNameText:SetJustifyH("LEFT")
        self.SpellNameText:SetPoint("LEFT", frame, "LEFT", config.defaultValues.textX, config.defaultValues.textY)
        self.SpellNameText:SetText("")
        self.SpellNameText:Hide()
    end

    -- 4. Create Latency Indicator (Safe Zone)
    if not self.LatencyBar then
        self.LatencyBar = frame:CreateTexture(nil, "OVERLAY")
        self.LatencyBar:SetColorTexture(1, 0, 0, 0.35) -- Rojo semi-transparente
        self.LatencyBar:Hide()
    end
    
    -- 5. Visual effects (Spark only, NO tails)
    self:InitSparkVisuals()
    
    -- Register events
    frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    frame:SetScript("OnEvent", function(f, event, ...) self:OnEvent(event, ...) end)
    frame:SetScript("OnUpdate", function(f, elapsed) self:OnUpdate(elapsed) end)
end

function CastBarMixin:InitSparkVisuals()
    local frame = self:GetFrame()
    
    -- Spark head (bright center)
    if not self.SparkHead then
        self.SparkHead = frame:CreateTexture(nil, "OVERLAY")
        self.SparkHead:SetAtlas("pvpscoreboard-header-glow", true)
        self.SparkHead:SetBlendMode("ADD")
        if self.SparkHead.SetRotation then
            self.SparkHead:SetRotation(math.rad(90))
        end
        self.SparkHead:SetVertexColor(1, 1, 1, 1)
        self.SparkHead:Hide()
    end
    
    -- Spark glow
    if not self.SparkGlow then
        self.SparkGlow = frame:CreateTexture(nil, "OVERLAY")
        self.SparkGlow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Pushback")
        self.SparkGlow:SetBlendMode("ADD")
        self.SparkGlow:SetAlpha(0.25)
        self.SparkGlow:Hide()
    end
end

function CastBarMixin:UpdateSparkPosition(barValue, barMax)
    if not self.SparkHead or barMax <= 0 then return end
    
    local frame = self:GetFrame()
    local barWidth = frame:GetWidth() or 250
    local barHeight = frame:GetHeight() or 25
    
    local progress = barValue / barMax
    
    local sparkX = barWidth * progress
    if sparkX < 0 then sparkX = 0 end
    if sparkX > barWidth then sparkX = barWidth end
    
    -- Spark head
    self.SparkHead:ClearAllPoints()
    local scale = 1.8 
    self.SparkHead:SetSize(32 * scale, barHeight * 2 * scale)
    self.SparkHead:SetPoint("CENTER", frame, "LEFT", sparkX, 0)
    self.SparkHead:Show()

    -- Glow
    if self.SparkGlow then
        self.SparkGlow:ClearAllPoints()
        self.SparkGlow:SetSize(32, barHeight * 2)
        self.SparkGlow:SetPoint("CENTER", self.SparkHead, "CENTER", 0, 0)
        self.SparkGlow:Show()
    end
end

function CastBarMixin:HideSparks()
    if self.SparkHead then self.SparkHead:Hide() end
    if self.SparkGlow then self.SparkGlow:Hide() end
end

-- Logic for Light Overlay (Brillo Progresivo)
function CastBarMixin:UpdateOverlayEffect(current, max)
    if not self.LightOverlay then return end
    
    -- Obtener configuración con fallback
    local config = self:GetConfig()
    local db = SenseiClassResourceBarDB[config.dbName][self.layoutName or "Default"] or config.defaultValues
    
    local showOverlay = true
    if db.showOverlay ~= nil then showOverlay = db.showOverlay else showOverlay = config.defaultValues.showOverlay end

    if not showOverlay then 
        self.LightOverlay:Hide()
        return 
    end

    local progress = 0
    if max > 0 then progress = current / max end
    
    local maxAlpha = 0.5
    local alpha = maxAlpha * progress
    
    self.LightOverlay:SetAlpha(alpha)
    self.LightOverlay:Show()
end

-- Logic for Latency Indicator
function CastBarMixin:UpdateLatency()
    if not self.LatencyBar then return end
    
    -- Obtener configuración con fallback
    local config = self:GetConfig()
    local db = SenseiClassResourceBarDB[config.dbName][self.layoutName or "Default"] or config.defaultValues
    
    local showLatency = true
    if db.showLatency ~= nil then showLatency = db.showLatency else showLatency = config.defaultValues.showLatency end
    
    if not showLatency then 
        self.LatencyBar:Hide()
        return 
    end

    -- Solo mostrar si hay cast activo
    if not (self.casting or self.channeling) then
        self.LatencyBar:Hide()
        return
    end

    local _, _, _, worldMS = GetNetStats()
    local latencySec = (worldMS or 0) / 1000
    if latencySec <= 0 then 
        self.LatencyBar:Hide()
        return 
    end
    
    local maxDuration = self.maxValue
    if maxDuration <= 0 then return end
    
    -- Calcular ancho relativo
    local frame = self:GetFrame()
    local width = frame:GetWidth()
    local pct = latencySec / maxDuration
    
    -- Cap de seguridad visual (no mostrar más del 50% de la barra como lag)
    if pct > 0.5 then pct = 0.5 end
    
    local barWidth = width * pct
    
    self.LatencyBar:ClearAllPoints()
    self.LatencyBar:SetWidth(barWidth)
    self.LatencyBar:SetHeight(frame:GetHeight())
    
    if self.channeling then
        self.LatencyBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
    else
        self.LatencyBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    end
    self.LatencyBar:Show()
end

function CastBarMixin:GetResource()
    if self.casting or self.channeling then
        return "CAST"
    end
    local LEM = SENSEI.LEM or LibStub("LibEQOLEditMode-1.0")
    if LEM and LEM:IsInEditMode() then
        return "CAST"
    end
    return nil
end

function CastBarMixin:GetResourceValue(resource)
    local LEM = SENSEI.LEM or LibStub("LibEQOLEditMode-1.0")
    
    -- ANIMATED PREVIEW MODE
    if LEM and LEM:IsInEditMode() then
        -- Simular un casteo de 3 segundos que se repite
        local simDuration = 3
        local time = GetTime()
        local simCurrent = time % simDuration
        local remaining = simDuration - simCurrent
        
        -- Devolver valores dinámicos
        return simDuration, simDuration, simCurrent, tonumber(string.format("%.1f", remaining)), "number"
    end
    
    if not (self.casting or self.channeling) then
        return nil
    end
    
    local time = GetTime()
    local max = tonumber(self.maxValue) or 0
    if max <= 0 then return nil end
    
    local elapsed = time - (self.startTime or 0)
    if elapsed < 0 then elapsed = 0 end
    if elapsed > max then elapsed = max end
    
    local remaining = max - elapsed
    
    return max, max, elapsed, tonumber(string.format("%.1f", remaining)), "number"
end

function CastBarMixin:GetBarColor(resource)
    if self.notInterruptible then
        return { r = 0.5, g = 0.5, b = 0.5 }
    end
    return { r = 1.0, g = 0.7, b = 0.0 }
end

function CastBarMixin:OnEvent(event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self.casting = false; self.channeling = false;
        self:ApplyVisibilitySettings()
        return
    end
    
    if unit and unit ~= "player" then return end
    
    if event == "UNIT_SPELLCAST_START" then
        local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("player")
        if not name then self.casting = false; self:ApplyVisibilitySettings(); return end
        
        self.castName = name
        self.castIcon = texture
        self.startTime = startTime / 1000
        self.endTime = endTime / 1000
        self.maxValue = self.endTime - self.startTime
        self.notInterruptible = notInterruptible
        self.casting = true
        self.channeling = false
        self:ApplyVisibilitySettings()
        self:UpdateDisplay()
        self:UpdateLatency() 
        
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo("player")
        if name then
            self.castName = name
            self.castIcon = texture
            self.startTime = startTime / 1000
            self.endTime = endTime / 1000
            self.maxValue = self.endTime - self.startTime
            self.notInterruptible = notInterruptible
            self.casting = false
            self.channeling = true
            self:ApplyVisibilitySettings()
            self:UpdateDisplay()
            self:UpdateLatency()
        else
            self.casting = false; self.channeling = false; self:ApplyVisibilitySettings()
        end
        
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        self.casting = false
        self:ApplyVisibilitySettings()
        
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        self.channeling = false
        self:ApplyVisibilitySettings()
        
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if self.casting then
            local name, _, _, startTime, endTime = UnitCastingInfo("player")
            if name then
                self.startTime = startTime / 1000; self.endTime = endTime / 1000; self.maxValue = self.endTime - self.startTime
            end
        elseif self.channeling then
            local name, _, _, startTime, endTime = UnitChannelInfo("player")
            if name then
                self.startTime = startTime / 1000; self.endTime = endTime / 1000; self.maxValue = self.endTime - self.startTime
            end
        end
        self:UpdateLatency()
    end
end

function CastBarMixin:OnUpdate(elapsed)
    local LEM = SENSEI.LEM or LibStub("LibEQOLEditMode-1.0")
    
    -- Timeout check
    if self.casting or self.channeling then
        local time = GetTime()
        if time > (self.endTime or 0) then
            self.casting = false
            self.channeling = false
            self:ApplyVisibilitySettings()
        end
    end
    
    -- Always update display if casting OR in edit mode (for animation)
    if self.casting or self.channeling or (LEM and LEM:IsInEditMode()) then
        self:UpdateDisplay()
    end
end

function CastBarMixin:ApplyVisibilitySettings(layoutName)
    local frame = self:GetFrame()
    if not frame then return end
    local LEM = SENSEI.LEM or LibStub("LibEQOLEditMode-1.0")
    
    if LEM and LEM:IsInEditMode() then
        frame:Show()
        return
    end
    
    if self.casting or self.channeling then frame:Show() else frame:Hide() end
end

function CastBarMixin:UpdateDisplay(layoutName, force)
    -- Parent update
    if SENSEI.BarMixin.UpdateDisplay then
        SENSEI.BarMixin.UpdateDisplay(self, layoutName, force)
    end
    
    local data = self:GetData(layoutName)
    if not data then return end
    self.layoutName = layoutName
    
    local LEM = SENSEI.LEM or LibStub("LibEQOLEditMode-1.0")
    local inEditMode = (LEM and LEM:IsInEditMode())
    local defaults = self:GetConfig().defaultValues 
    
    -- =========================================================================
    -- CONFIGURACION CON VALIDACIÓN DE CEROS (SOLUCIÓN)
    -- =========================================================================
    
    -- VALIDAR ICON SIZE (> 0)
    local iconSize = data.iconSize
    if not iconSize or iconSize <= 0 then iconSize = defaults.iconSize end

    local iconX = data.iconX or defaults.iconX
    local iconY = data.iconY or defaults.iconY
    local showIcon = (data.showIcon ~= nil) and data.showIcon or defaults.showIcon
    
    local showText = (data.showText ~= nil) and data.showText or defaults.showText

    -- VALIDAR TEXT FONT SIZE (> 0) - Aquí estaba el error del crash
    local textFontSize = data.textFontSize
    if not textFontSize or textFontSize <= 0 then textFontSize = defaults.textFontSize end

    local textX = data.textX or defaults.textX
    local textY = data.textY or defaults.textY
    
    local showSpark = (data.showSpark ~= nil) and data.showSpark or defaults.showSpark
    local showOverlay = (data.showOverlay ~= nil) and data.showOverlay or defaults.showOverlay
    
    -- 1. Icon Customization
    if showIcon and (self.castIcon or inEditMode) then
        if inEditMode and not self.castIcon then
             self.Icon:SetTexture(136243) -- Interface\Icons\Trade_Engineering
        else
             self.Icon:SetTexture(self.castIcon)
        end
        
        self.Icon:SetSize(iconSize, iconSize) 
        self.Icon:ClearAllPoints()
        self.Icon:SetPoint("LEFT", self:GetFrame(), "LEFT", iconX, iconY)
        self.Icon:Show()
    else
        if self.Icon then self.Icon:Hide() end
    end
    
    -- 2. Spell Name Text Customization
    local shouldShowSpellName = showText and (self.castName ~= "" or inEditMode)
    
    if shouldShowSpellName and self.SpellNameText then
        local text = self.castName
        if inEditMode and text == "" then text = "Flash Heal" end
        
        self.SpellNameText:SetText(text)
        
        -- Configurar fuente/tamaño
        -- Usar la fuente del layout si existe, sino la standard, sino fallback hardcoded
        local fontPath = data.font or standardFont or "Fonts\\FRIZQT__.TTF"
        self.SpellNameText:SetFont(fontPath, textFontSize, "OUTLINE")
        
        self.SpellNameText:ClearAllPoints()
        self.SpellNameText:SetPoint("LEFT", self:GetFrame(), "LEFT", textX, textY)
        self.SpellNameText:Show()
    elseif self.SpellNameText then
        self.SpellNameText:Hide()
    end
    
    -- 3. Update Visuals
    local resource = self:GetResource()
    if resource then
        local max, maxDisplay, current, display, valueType = self:GetResourceValue(resource)
        if max and current then
            if showSpark then self:UpdateSparkPosition(current, max) else self:HideSparks() end
            if showOverlay then self:UpdateOverlayEffect(current, max) end
        else
            self:HideSparks()
        end
    else
        self:HideSparks()
    end
end


-- ============================================================================
-- CONFIGURATION & REGISTRATION
-- ============================================================================

local CastBarConfig = {
    frameName = "SenseiCastBar_Frame",
    dbName = "SenseiCastBarDB",
    editModeName = "Cast Bar",
    mixin = CastBarMixin,
    defaultValues = {
        point = "CENTER",
        x = 0,
        y = -150,
        barWidth = 250,
        barHeight = 25,
        barVisible = "Always Visible",
        
        -- Custom Defaults
        showText = true,
        textX = 30,
        textY = 0,
        textFontSize = 11,
        
        showIcon = true,
        iconSize = 20,
        iconX = -25,
        iconY = 0,
        
        showSpark = true,
        showLatency = true,
        showOverlay = true,
        
        -- Colors
        barForeground = "SCRB FG Solid",
        barBackground = { r = 0, g = 0, b = 0, a = 0.5 },
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
    },
    lemSettings = function(bar, defaults)
        local function GetSet(key, isColor)
             return {
                get = function(layoutName)
                    local data = SenseiClassResourceBarDB[bar:GetConfig().dbName][layoutName]
                    if data and data[key] ~= nil then return data[key] end
                    return defaults[key]
                end,
                set = function(layoutName, value)
                    SenseiClassResourceBarDB[bar:GetConfig().dbName][layoutName] = SenseiClassResourceBarDB[bar:GetConfig().dbName][layoutName] or CopyTable(defaults)
                    SenseiClassResourceBarDB[bar:GetConfig().dbName][layoutName][key] = value
                    bar:UpdateDisplay(layoutName)
                end,
            }
        end

        return {
            {
                parentId = "Bar Visibility",
                order = 90,
                name = "Show Spark (Head)",
                kind = SENSEI.LEM.SettingType.Checkbox,
                default = defaults.showSpark,
                get = GetSet("showSpark").get,
                set = GetSet("showSpark").set,
            },
            {
                parentId = "Bar Visibility",
                order = 91,
                name = "Show Light Overlay",
                kind = SENSEI.LEM.SettingType.Checkbox,
                default = defaults.showOverlay,
                get = GetSet("showOverlay").get,
                set = GetSet("showOverlay").set,
            },
            {
                parentId = "Bar Visibility",
                order = 92,
                name = "Show Latency Indicator",
                kind = SENSEI.LEM.SettingType.Checkbox,
                default = defaults.showLatency,
                get = GetSet("showLatency").get,
                set = GetSet("showLatency").set,
            },
            -- ICON SETTINGS
            {
                parentId = "Bar Visibility",
                order = 100,
                name = "Show Icon",
                kind = SENSEI.LEM.SettingType.Checkbox,
                default = defaults.showIcon,
                get = GetSet("showIcon").get,
                set = GetSet("showIcon").set,
            },
            {
                parentId = "Bar Visibility",
                order = 101,
                name = "Icon Size",
                kind = SENSEI.LEM.SettingType.Slider,
                min = 10, max = 64, step = 1,
                default = defaults.iconSize,
                get = GetSet("iconSize").get,
                set = GetSet("iconSize").set,
            },
            {
                parentId = "Bar Visibility",
                order = 102,
                name = "Icon X Offset",
                kind = SENSEI.LEM.SettingType.Slider,
                min = -100, max = 100, step = 1,
                default = defaults.iconX,
                get = GetSet("iconX").get,
                set = GetSet("iconX").set,
            },
            {
                parentId = "Bar Visibility",
                order = 103,
                name = "Icon Y Offset",
                kind = SENSEI.LEM.SettingType.Slider,
                min = -50, max = 50, step = 1,
                default = defaults.iconY,
                get = GetSet("iconY").get,
                set = GetSet("iconY").set,
            },
            -- TEXT SETTINGS
            {
                parentId = "Bar Visibility",
                order = 110,
                name = "Show Spell Name",
                kind = SENSEI.LEM.SettingType.Checkbox,
                default = defaults.showText,
                get = GetSet("showText").get,
                set = GetSet("showText").set,
            },
            {
                parentId = "Bar Visibility",
                order = 111,
                name = "Text Size",
                kind = SENSEI.LEM.SettingType.Slider,
                min = 8, max = 32, step = 1,
                default = defaults.textFontSize,
                get = GetSet("textFontSize").get,
                set = GetSet("textFontSize").set,
            },
            {
                parentId = "Bar Visibility",
                order = 112,
                name = "Text X Offset",
                kind = SENSEI.LEM.SettingType.Slider,
                min = -100, max = 100, step = 1,
                default = defaults.textX,
                get = GetSet("textX").get,
                set = GetSet("textX").set,
            },
            {
                parentId = "Bar Visibility",
                order = 113,
                name = "Text Y Offset",
                kind = SENSEI.LEM.SettingType.Slider,
                min = -50, max = 50, step = 1,
                default = defaults.textY,
                get = GetSet("textY").get,
                set = GetSet("textY").set,
            },
        }
    end,
}

function InitializeSenseiCastBar()
    SENSEI = GetSensei()
    if not SENSEI then print("SenseiCastBar: SenseiClassResourceBar not found!"); return end
    
    if not _G["SenseiClassResourceBarDB"] then _G["SenseiClassResourceBarDB"] = {} end
    local db = _G["SenseiClassResourceBarDB"]
    if not db[CastBarConfig.dbName] then db[CastBarConfig.dbName] = {} end
    
    local bar = CreateFromMixins(CastBarConfig.mixin)
    bar:Init(CastBarConfig, UIParent, 5)
    
    SENSEI.barInstances = SENSEI.barInstances or {}
    SENSEI.barInstances.CastBar = bar
    SENSEI.RegistereredBar = SENSEI.RegistereredBar or {}
    SENSEI.RegistereredBar.CastBar = CastBarConfig
    
    local defaults = CopyTable(SENSEI.commonDefaults or {})
    for k, v in pairs(CastBarConfig.defaultValues) do defaults[k] = v end
    
    if SENSEI.LEMSettingsLoaderMixin then
        local loader = CreateFromMixins(SENSEI.LEMSettingsLoaderMixin)
        loader:Init(bar, defaults)
        loader:LoadSettings()
    end
    
    bar:ApplyLayout()
    bar:UpdateDisplay()
    
    print("SenseiCastBar: Initialized successfully with Latency & Overlay")
end

if SENSEI then InitializeSenseiCastBar() end