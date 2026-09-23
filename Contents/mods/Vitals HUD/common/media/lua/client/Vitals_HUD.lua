require "ISUI/ISPanel"
require "ISUI/ISContextMenu"

Vitals_HUD = ISPanel:derive("Vitals_HUD")


-------------------------------------------------------
-- Placement / persistence
-------------------------------------------------------

local RIGHT_MARGIN = 20
local MOODLE_SPACE = 110
local HUD_TOP = 145

local HANDLE_WIDTH = 28
local HANDLE_HEIGHT = 18

local SETTINGS_FILE = "VitalsHUD_settings.txt"


-------------------------------------------------------
-- Size presets
-------------------------------------------------------

local SIZE_PRESETS = {
    small = {
        width = 180,
        font = UIFont.Small,
        labelWidth = 70,
        barWidth = 95,
        barHeight = 7,
        rowSpacing = 16,
        sectionGap = 24,
        headingGap = 18,
        textYOffset = -5,
        conditionEndGap = 20,
        tempColdX = 74,
        tempNormalX = 108,
        tempHotX = 154
    },

    normal = {
        width = 200,
        font = UIFont.Small,
        labelWidth = 82,
        barWidth = 105,
        barHeight = 9,
        rowSpacing = 18,
        sectionGap = 28,
        headingGap = 20,
        textYOffset = -5,
        conditionEndGap = 22,
        tempColdX = 86,
        tempNormalX = 116,
        tempHotX = 168
    },

    large = {
        width = 320,
        font = UIFont.Medium,
        labelWidth = 125,
        barWidth = 180,
        barHeight = 12,
        rowSpacing = 26,
        sectionGap = 38,
        headingGap = 28,
        textYOffset = -7,
        conditionEndGap = 30,
        tempColdX = 130,
        tempNormalX = 185,
        tempHotX = 272
    }
}


-------------------------------------------------------
-- Defaults
-------------------------------------------------------

local function defaultSettings()
    return {
        x = nil,
        y = nil,

        size = "normal",
        display = "bars",

        exactTemperature = false,

        showZombieInfection = false,
        showCalories = false
    }
end


-------------------------------------------------------
-- Helpers
-------------------------------------------------------

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end


local function normaliseStat(stats, stat)

    local value = stats:get(stat)
    local minValue = stat:getMinimumValue()
    local maxValue = stat:getMaximumValue()

    if maxValue == minValue then
        return 0
    end

    return clamp(
        (value - minValue) / (maxValue - minValue),
        0,
        1
    )
end


local function boolToString(value)
    if value then
        return "true"
    end

    return "false"
end


local function stringToBool(value)
    return value == "true"
end


local function marked(label, selected)

    if selected then
        return "[x] " .. label
    end

    return "[ ] " .. label
end


local function getPreset(sizeKey)
    return SIZE_PRESETS[sizeKey] or SIZE_PRESETS.normal
end


local function getDefaultHudPosition(width)

    local x =
        getCore():getScreenWidth()
        - width
        - RIGHT_MARGIN
        - MOODLE_SPACE

    return x, HUD_TOP
end


-------------------------------------------------------
-- Settings persistence
-------------------------------------------------------

local function loadSettings()

    local settings = defaultSettings()
    local reader = getFileReader(SETTINGS_FILE, false)

    if not reader then
        return settings
    end

    while true do

        local line = reader:readLine()

        if not line then
            break
        end

        local key, value =
            string.match(
                line,
                "^([^=]+)=(.*)$"
            )

        if key and value then

            if key == "x" then
                settings.x = tonumber(value)

            elseif key == "y" then
                settings.y = tonumber(value)

            elseif key == "size" then
                if SIZE_PRESETS[value] then
                    settings.size = value
                end

            elseif key == "display" then
                if value == "bars"
                or value == "numeric" then
                    settings.display = value
                end

            elseif key == "exactTemperature" then
                settings.exactTemperature =
                    stringToBool(value)

            elseif key == "showZombieInfection" then
                settings.showZombieInfection =
                    stringToBool(value)

            elseif key == "showCalories" then
                settings.showCalories =
                    stringToBool(value)

            end
        end
    end

    reader:close()

    return settings
end


local function saveSettings(settings)

    local writer =
        getFileWriter(
            SETTINGS_FILE,
            true,
            false
        )

    if not writer then
        return
    end

    if settings.x ~= nil then
        writer:write(
            "x="
            .. tostring(
                math.floor(
                    settings.x + 0.5
                )
            )
            .. "\n"
        )
    end

    if settings.y ~= nil then
        writer:write(
            "y="
            .. tostring(
                math.floor(
                    settings.y + 0.5
                )
            )
            .. "\n"
        )
    end

    writer:write(
        "size="
        .. tostring(settings.size)
        .. "\n"
    )

    writer:write(
        "display="
        .. tostring(settings.display)
        .. "\n"
    )

    writer:write(
        "exactTemperature="
        .. boolToString(
            settings.exactTemperature
        )
        .. "\n"
    )

    writer:write(
        "showZombieInfection="
        .. boolToString(
            settings.showZombieInfection
        )
        .. "\n"
    )

    writer:write(
        "showCalories="
        .. boolToString(
            settings.showCalories
        )
        .. "\n"
    )

    writer:close()
end


-------------------------------------------------------
-- Layout helpers
-------------------------------------------------------

function Vitals_HUD:getProfile()
    return getPreset(self.settings.size)
end


function Vitals_HUD:clampPositionToScreen()

    local screenWidth =
        getCore():getScreenWidth()

    local screenHeight =
        getCore():getScreenHeight()

    local maxX =
        math.max(
            0,
            screenWidth - self:getWidth()
        )

    local maxY =
        math.max(
            0,
            screenHeight - HANDLE_HEIGHT
        )

    self:setX(
        clamp(
            self:getX(),
            0,
            maxX
        )
    )

    self:setY(
        clamp(
            self:getY(),
            0,
            maxY
        )
    )
end


function Vitals_HUD:rememberPosition()

    self.settings.x =
        self:getX()

    self.settings.y =
        self:getY()

    saveSettings(
        self.settings
    )
end


function Vitals_HUD:applySize()

    local profile =
        self:getProfile()

    self:setWidth(
        profile.width
    )

    self:clampPositionToScreen()
end


-------------------------------------------------------
-- Drag handle
-------------------------------------------------------

function Vitals_HUD:getDragHandleRect()

    local profile =
        self:getProfile()

    -- Align the handle with the right edge of the actual bars,
    -- not the wider invisible panel. This makes it feel attached
    -- to the HUD instead of floating off to the side.
    local contentRight =
        profile.labelWidth
        + 5
        + profile.barWidth

    local left =
        contentRight
        - HANDLE_WIDTH

    return
        left,
        0,
        HANDLE_WIDTH,
        HANDLE_HEIGHT
end


function Vitals_HUD:isOverDragHandle(x, y)

    local left,
          top,
          width,
          height =
        self:getDragHandleRect()

    return x >= left
       and x <= left + width
       and y >= top
       and y <= top + height
end


function Vitals_HUD:drawDragHandle()

    local left,
          top,
          width,
          height =
        self:getDragHandleRect()

    local hovered =
        self:isOverDragHandle(
            self:getMouseX(),
            self:getMouseY()
        )

    local bgAlpha = 0.60
    local borderAlpha = 0.60

    if hovered then
        bgAlpha = 0.82
        borderAlpha = 0.95
    end

    self:drawRect(
        left,
        top,
        width,
        height,
        bgAlpha,
        0.05, 0.05, 0.05
    )

    self:drawRectBorder(
        left,
        top,
        width,
        height,
        borderAlpha,
        0.65, 0.65, 0.65
    )

    local handleText = "::"
    local textManager =
        getTextManager()

    local textWidth =
        textManager:MeasureStringX(
            UIFont.Small,
            handleText
        )

    local textX =
        left
        + math.floor(
            (width - textWidth) / 2
        )

    -- Small-font text sits visually a little low if mathematically
    -- centered, so keep a 1 px optical adjustment upward.
    local textY = top

    self:drawText(
        handleText,
        textX,
        textY,
        1, 1, 1, 1,
        UIFont.Small
    )
end


-------------------------------------------------------
-- Movement
-------------------------------------------------------

function Vitals_HUD:onMouseDown(x, y)

    if not self:isOverDragHandle(x, y) then
        return false
    end

    self.moveWithMouse = true

    ISPanel.onMouseDown(
        self,
        x,
        y
    )

    return true
end


function Vitals_HUD:onMouseMove(dx, dy)

    if not self.moveWithMouse then
        return
    end

    ISPanel.onMouseMove(
        self,
        dx,
        dy
    )

    self:clampPositionToScreen()
end


function Vitals_HUD:onMouseMoveOutside(dx, dy)

    if not self.moveWithMouse then
        return
    end

    ISPanel.onMouseMoveOutside(
        self,
        dx,
        dy
    )

    self:clampPositionToScreen()
end


function Vitals_HUD:onMouseUp(x, y)

    if not self.moveWithMouse then
        return false
    end

    ISPanel.onMouseUp(
        self,
        x,
        y
    )

    self.moveWithMouse = false

    self:clampPositionToScreen()
    self:rememberPosition()

    return true
end


function Vitals_HUD:onMouseUpOutside(x, y)

    if not self.moveWithMouse then
        return false
    end

    ISPanel.onMouseUpOutside(
        self,
        x,
        y
    )

    self.moveWithMouse = false

    self:clampPositionToScreen()
    self:rememberPosition()

    return true
end


-------------------------------------------------------
-- Options menu callbacks
-------------------------------------------------------

function Vitals_HUD:setSizeOption(sizeKey)

    if not SIZE_PRESETS[sizeKey] then
        return
    end

    self.settings.size = sizeKey

    self:applySize()
    self:rememberPosition()
end


function Vitals_HUD:setDisplayOption(displayMode)

    if displayMode ~= "bars"
    and displayMode ~= "numeric" then
        return
    end

    self.settings.display =
        displayMode

    saveSettings(
        self.settings
    )
end


function Vitals_HUD:toggleExactTemperature()

    self.settings.exactTemperature =
        not self.settings.exactTemperature

    saveSettings(
        self.settings
    )
end


function Vitals_HUD:toggleZombieInfection()

    self.settings.showZombieInfection =
        not self.settings.showZombieInfection

    saveSettings(
        self.settings
    )
end


function Vitals_HUD:toggleCalories()

    self.settings.showCalories =
        not self.settings.showCalories

    saveSettings(
        self.settings
    )
end


-------------------------------------------------------
-- Compact options-menu styling
-------------------------------------------------------

local function makeCompactContextMenu(menu)

    if not menu then
        return
    end

    -- Keep the mod's tiny options menu visually consistent with
    -- the compact HUD instead of inheriting a potentially very
    -- large player Context Menu Font setting.
    menu.font = UIFont.Small
    menu.fontHgt =
        getTextManager():getFontHeight(
            UIFont.Small
        )

    menu.itemHgt =
        math.max(
            22,
            menu.fontHgt + 8
        )
end


-------------------------------------------------------
-- Options menu
-------------------------------------------------------

function Vitals_HUD:showOptionsMenu(x, y)

    local player = getPlayer()
    local playerNum = 0

    if player then
        playerNum =
            player:getPlayerNum()
    end

    local screenX =
        self:getAbsoluteX() + x

    local screenY =
        self:getAbsoluteY() + y

    local context =
        ISContextMenu.get(
            playerNum,
            screenX,
            screenY
        )

    makeCompactContextMenu(
        context
    )


    ---------------------------------------------------
    -- Size
    ---------------------------------------------------

    local sizeOption =
        context:addOption(
            "HUD size",
            nil,
            nil
        )

    local sizeMenu =
        ISContextMenu:getNew(
            context
        )

    makeCompactContextMenu(
        sizeMenu
    )

    context:addSubMenu(
        sizeOption,
        sizeMenu
    )

    sizeMenu:addOption(
        marked(
            "Small",
            self.settings.size == "small"
        ),
        self,
        Vitals_HUD.setSizeOption,
        "small"
    )

    sizeMenu:addOption(
        marked(
            "Normal",
            self.settings.size == "normal"
        ),
        self,
        Vitals_HUD.setSizeOption,
        "normal"
    )

    sizeMenu:addOption(
        marked(
            "Large",
            self.settings.size == "large"
        ),
        self,
        Vitals_HUD.setSizeOption,
        "large"
    )


    ---------------------------------------------------
    -- Display
    ---------------------------------------------------

    local displayOption =
        context:addOption(
            "Display",
            nil,
            nil
        )

    local displayMenu =
        ISContextMenu:getNew(
            context
        )

    makeCompactContextMenu(
        displayMenu
    )

    context:addSubMenu(
        displayOption,
        displayMenu
    )

    displayMenu:addOption(
        marked(
            "Bars",
            self.settings.display == "bars"
        ),
        self,
        Vitals_HUD.setDisplayOption,
        "bars"
    )

    displayMenu:addOption(
        marked(
            "Numeric values",
            self.settings.display == "numeric"
        ),
        self,
        Vitals_HUD.setDisplayOption,
        "numeric"
    )


    ---------------------------------------------------
    -- Hidden values
-- Exact temperature is handled in the normal temperature section.
-- This section renders only additional hidden readouts.
    ---------------------------------------------------

    local hiddenOption =
        context:addOption(
            "Hidden values (ruins immersion)",
            nil,
            nil
        )

    local hiddenMenu =
        ISContextMenu:getNew(
            context
        )

    makeCompactContextMenu(
        hiddenMenu
    )

    context:addSubMenu(
        hiddenOption,
        hiddenMenu
    )

    hiddenMenu:addOption(
        marked(
            "Exact temperature",
            self.settings.exactTemperature
        ),
        self,
        Vitals_HUD.toggleExactTemperature
    )

    hiddenMenu:addOption(
        marked(
            "Zombie infection",
            self.settings.showZombieInfection
        ),
        self,
        Vitals_HUD.toggleZombieInfection
    )

    hiddenMenu:addOption(
        marked(
            "Calories",
            self.settings.showCalories
        ),
        self,
        Vitals_HUD.toggleCalories
    )

end


function Vitals_HUD:onRightMouseDown(x, y)

    if self:isOverDragHandle(x, y) then
        return true
    end

    return false
end


function Vitals_HUD:onRightMouseUp(x, y)

    if not self:isOverDragHandle(x, y) then
        return false
    end

    self:showOptionsMenu(
        x,
        y
    )

    return true
end


-------------------------------------------------------
-- Standard stat display
-------------------------------------------------------

function Vitals_HUD:drawStat(
    label,
    value,
    y,
    r,
    g,
    b
)

    local profile =
        self:getProfile()

    local font =
        profile.font

    local labelWidth =
        profile.labelWidth

    local barWidth =
        profile.barWidth

    local barHeight =
        profile.barHeight

    local barX =
        labelWidth + 5

    local textY =
        y + profile.textYOffset


    self:drawText(
        label,
        0,
        textY,
        1, 1, 1, 1,
        font
    )


    ---------------------------------------------------
    -- Numeric mode
    ---------------------------------------------------

    if self.settings.display == "numeric" then

        local percentage =
            math.floor(
                clamp(value, 0, 1)
                * 100
                + 0.5
            )

        self:drawText(
            tostring(percentage) .. "%",
            barX,
            textY,
            r, g, b, 1,
            font
        )

        return
    end


    ---------------------------------------------------
    -- Bar mode
    ---------------------------------------------------

    self:drawRect(
        barX,
        y,
        barWidth,
        barHeight,
        0.65,
        0.08, 0.08, 0.08
    )

    self:drawRect(
        barX,
        y,
        barWidth * clamp(value, 0, 1),
        barHeight,
        0.9,
        r, g, b
    )

    self:drawRectBorder(
        barX,
        y,
        barWidth,
        barHeight,
        0.7,
        0.5, 0.5, 0.5
    )
end


-------------------------------------------------------
-- Temperature gauge
--
-- Cold      Normal       Hot
-- |-----------|-----------|
-------------------------------------------------------

function Vitals_HUD:drawTemperature(
    player,
    y
)

    local bodyDamage =
        player:getBodyDamage()

    if not bodyDamage then
        return y
    end

    local thermo =
        bodyDamage:getThermoregulator()

    if not thermo then
        return y
    end

    local coreTemp =
        thermo:getCoreCelcius()

    local setPoint =
        thermo:getSetPoint()

    local profile =
        self:getProfile()

    local labelWidth =
        profile.labelWidth

    local barWidth =
        profile.barWidth

    local barHeight =
        profile.barHeight

    local barX =
        labelWidth + 5

    local font =
        profile.font

    local delta =
        coreTemp - setPoint

    -- ±2 C fills the entire gauge.
    local gaugeRange = 2.0

    local position =
        clamp(
            0.5
            + (
                delta
                / (gaugeRange * 2)
            ),
            0,
            1
        )


    ---------------------------------------------------
    -- Label
    ---------------------------------------------------

    local tempTextY =
        y + profile.textYOffset

    self:drawText(
        "Temp",
        0,
        tempTextY,
        1, 1, 1, 1,
        font
    )

    if self.settings.exactTemperature then

        local exactText =
            string.format(
                "%.1f C",
                coreTemp
            )

        local textManager =
            getTextManager()

        local exactFont =
            font

        local exactX

        if self.settings.size == "small" then

            -- Keep the normal "Temp" label, but use Project
            -- Zomboid's smaller NewSmall font for the optional
            -- exact reading so it still fits before the gauge.
            exactFont =
                UIFont.NewSmall

            local tempLabelWidth =
                textManager:MeasureStringX(
                    font,
                    "Temp"
                )

            exactX =
                tempLabelWidth + 3

        else

            local exactWidth =
                textManager:MeasureStringX(
                    exactFont,
                    exactText
                )

            exactX =
                math.max(
                    42,
                    labelWidth
                        - exactWidth
                        - 4
                )
        end

        self:drawText(
            exactText,
            exactX,
            tempTextY,
            0.9, 0.9, 0.9, 1,
            exactFont
        )
    end


    ---------------------------------------------------
    -- Gauge
    ---------------------------------------------------

    self:drawRect(
        barX,
        y,
        barWidth,
        barHeight,
        0.65,
        0.08, 0.08, 0.08
    )

    self:drawRect(
        barX,
        y,
        barWidth / 2,
        barHeight,
        0.55,
        0.25, 0.45, 0.9
    )

    self:drawRect(
        barX + barWidth / 2,
        y,
        barWidth / 2,
        barHeight,
        0.55,
        0.9, 0.3, 0.2
    )

    local centerX =
        barX
        + (
            barWidth / 2
        )

    self:drawRect(
        centerX - 1,
        y - 2,
        2,
        barHeight + 4,
        1,
        0.2, 0.9, 0.2
    )

    local markerX =
        barX
        + (
            barWidth
            * position
        )

    self:drawRect(
        markerX - 2,
        y - 3,
        4,
        barHeight + 6,
        1,
        1, 1, 1
    )

    self:drawRectBorder(
        barX,
        y,
        barWidth,
        barHeight,
        0.8,
        0.6, 0.6, 0.6
    )

    return y
end


-------------------------------------------------------
-- Draw secondary stat only if relevant
-------------------------------------------------------

function Vitals_HUD:drawConditionalStat(
    label,
    stats,
    stat,
    y,
    r,
    g,
    b
)

    local value =
        normaliseStat(
            stats,
            stat
        )

    -- Ignore tiny rounding/noise values.
    if value <= 0.005 then
        return y, false
    end

    self:drawStat(
        label,
        value,
        y,
        r,
        g,
        b
    )

    return
        y + self:getProfile().rowSpacing,
        true
end


-------------------------------------------------------
-- Hidden values
-------------------------------------------------------

function Vitals_HUD:hasHiddenValuesEnabled()

    -- Exact temperature is rendered in the normal BODY TEMPERATURE
    -- section, so it should not create an otherwise-empty
    -- HIDDEN VALUES section by itself.
    return self.settings.showZombieInfection
        or self.settings.showCalories
end


function Vitals_HUD:drawHiddenValues(
    player,
    stats,
    y
)

    local profile =
        self:getProfile()

    local font =
        profile.font

    local textManager =
        getTextManager()

    local hiddenLabelWidth =
        math.max(
            textManager:MeasureStringX(
                font,
                "Zombie infection"
            ),
            textManager:MeasureStringX(
                font,
                "Calories"
            )
        )

    local valueX =
        hiddenLabelWidth + 12


    self:drawText(
        "HIDDEN VALUES",
        0,
        y,
        0.75, 0.75, 0.75, 1,
        font
    )

    y =
        y + profile.headingGap


    ---------------------------------------------------
    -- Zombie infection
    ---------------------------------------------------

    if self.settings.showZombieInfection then

        local infected = false

        local bodyDamage =
            player:getBodyDamage()

        if bodyDamage then
            infected =
                bodyDamage:isInfected()
        end

        self:drawText(
            "Zombie infection",
            0,
            y,
            1, 1, 1, 1,
            font
        )

        if infected then

            self:drawText(
                "YES",
                valueX,
                y,
                0.95, 0.25, 0.2, 1,
                font
            )

        else

            self:drawText(
                "NO",
                valueX,
                y,
                0.35, 0.85, 0.35, 1,
                font
            )
        end

        y =
            y + profile.rowSpacing
    end


    ---------------------------------------------------
    -- Calories
    ---------------------------------------------------

    if self.settings.showCalories then

        local calories = 0
        local nutrition =
            player:getNutrition()

        if nutrition then
            calories =
                nutrition:getCalories()
        end

        self:drawText(
            "Calories",
            0,
            y,
            1, 1, 1, 1,
            font
        )

        self:drawText(
            tostring(
                math.floor(
                    calories + 0.5
                )
            ),
            valueX,
            y,
            0.9, 0.9, 0.9, 1,
            font
        )

        y =
            y + profile.rowSpacing
    end


    return y
end


-------------------------------------------------------
-- Main rendering
-------------------------------------------------------

function Vitals_HUD:render()

    ISPanel.render(self)

    local player =
        getPlayer()

    if not player then
        return
    end

    local profile =
        self:getProfile()

    local stats =
        player:getStats()


    ---------------------------------------------------
    -- Handle
    ---------------------------------------------------

    self:drawDragHandle()


    ---------------------------------------------------
    -- Primary values
    ---------------------------------------------------

    local health =
        clamp(
            player:getBodyDamage()
                :getOverallBodyHealth()
                / 100,
            0,
            1
        )

    local endurance =
        normaliseStat(
            stats,
            CharacterStat.ENDURANCE
        )

    local fatigue =
        normaliseStat(
            stats,
            CharacterStat.FATIGUE
        )

    local hunger =
        normaliseStat(
            stats,
            CharacterStat.HUNGER
        )

    local thirst =
        normaliseStat(
            stats,
            CharacterStat.THIRST
        )


    local y =
        HANDLE_HEIGHT + 6


    self:drawStat(
        "Health",
        health,
        y,
        0.2, 0.8, 0.2
    )

    y =
        y + profile.rowSpacing


    self:drawStat(
        "Endurance",
        endurance,
        y,
        0.2, 0.8, 0.2
    )

    y =
        y + profile.rowSpacing


    self:drawStat(
        "Fatigue",
        fatigue,
        y,
        0.9, 0.55, 0.1
    )

    y =
        y + profile.rowSpacing


    self:drawStat(
        "Hunger",
        hunger,
        y,
        0.9, 0.55, 0.1
    )

    y =
        y + profile.rowSpacing


    self:drawStat(
        "Thirst",
        thirst,
        y,
        0.9, 0.55, 0.1
    )


    ---------------------------------------------------
    -- Current conditions
    ---------------------------------------------------

    y =
        y + profile.sectionGap

    self:drawText(
        "CURRENT CONDITIONS",
        0,
        y,
        0.75, 0.75, 0.75, 1,
        profile.font
    )

    y =
        y + profile.headingGap


    local anythingActive = false
    local shown


    y, shown =
        self:drawConditionalStat(
            "Pain",
            stats,
            CharacterStat.PAIN,
            y,
            0.9, 0.25, 0.2
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Stress",
            stats,
            CharacterStat.STRESS,
            y,
            0.9, 0.35, 0.2
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Panic",
            stats,
            CharacterStat.PANIC,
            y,
            0.9, 0.25, 0.2
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Sickness",
            stats,
            CharacterStat.SICKNESS,
            y,
            0.75, 0.25, 0.45
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Food sick",
            stats,
            CharacterStat.FOOD_SICKNESS,
            y,
            0.65, 0.25, 0.65
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Wetness",
            stats,
            CharacterStat.WETNESS,
            y,
            0.25, 0.55, 0.9
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Discomfort",
            stats,
            CharacterStat.DISCOMFORT,
            y,
            0.9, 0.45, 0.2
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Unhappy",
            stats,
            CharacterStat.UNHAPPINESS,
            y,
            0.8, 0.4, 0.2
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Boredom",
            stats,
            CharacterStat.BOREDOM,
            y,
            0.75, 0.55, 0.2
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Drunk",
            stats,
            CharacterStat.INTOXICATION,
            y,
            0.6, 0.35, 0.8
        )

    anythingActive =
        anythingActive or shown


    y, shown =
        self:drawConditionalStat(
            "Poison",
            stats,
            CharacterStat.POISON,
            y,
            0.55, 0.75, 0.25
        )

    anythingActive =
        anythingActive or shown


    if not anythingActive then

        self:drawText(
            "No active conditions",
            0,
            y,
            0.4, 0.85, 0.4, 1,
            profile.font
        )

        y =
            y + profile.conditionEndGap

    else

        y =
            y + 6
    end


    ---------------------------------------------------
    -- Temperature
    ---------------------------------------------------

    self:drawText(
        "BODY TEMPERATURE",
        0,
        y,
        0.75, 0.75, 0.75, 1,
        profile.font
    )

    y =
        y + profile.headingGap

    self:drawTemperature(
        player,
        y
    )

    y =
        y + profile.rowSpacing + 6


    ---------------------------------------------------
    -- Cold / normal / hot labels
    ---------------------------------------------------

    local tempBarX =
        profile.labelWidth + 5

    local labelY =
        y

    -- Keep these labels on the small font for every HUD size.
    -- The original fixed positions looked good at Normal size,
    -- so each preset now has tuned positions rather than trying
    -- to infer spacing from measured font widths.
    local scaleFont = UIFont.Small

    self:drawText(
        "cold",
        profile.tempColdX,
        labelY,
        0.55, 0.7, 1, 1,
        scaleFont
    )

    self:drawText(
        "normal",
        profile.tempNormalX,
        labelY,
        0.5, 0.9, 0.5, 1,
        scaleFont
    )

    self:drawText(
        "hot",
        profile.tempHotX,
        labelY,
        1, 0.55, 0.45, 1,
        scaleFont
    )

    y =
        y + profile.rowSpacing + 6


    ---------------------------------------------------
    -- Optional hidden-value readouts
    ---------------------------------------------------

    if self:hasHiddenValuesEnabled() then

        y =
            y + 4

        y =
            self:drawHiddenValues(
                player,
                stats,
                y
            )
    end


    ---------------------------------------------------
    -- Dynamic panel size
    ---------------------------------------------------

    self:setHeight(
        y + 8
    )
end


-------------------------------------------------------
-- Constructor
-------------------------------------------------------

function Vitals_HUD:new()

    local settings =
        loadSettings()

    local profile =
        getPreset(
            settings.size
        )

    local width =
        profile.width

    local height = 300

    local defaultX,
          defaultY =
        getDefaultHudPosition(
            width
        )

    local x =
        settings.x
        or defaultX

    local y =
        settings.y
        or defaultY

    local screenWidth =
        getCore():getScreenWidth()

    local screenHeight =
        getCore():getScreenHeight()

    x =
        clamp(
            x,
            0,
            math.max(
                0,
                screenWidth - width
            )
        )

    y =
        clamp(
            y,
            0,
            math.max(
                0,
                screenHeight - HANDLE_HEIGHT
            )
        )

    settings.x = x
    settings.y = y


    local o =
        ISPanel:new(
            x,
            y,
            width,
            height
        )

    setmetatable(
        o,
        self
    )

    self.__index = self

    o.background = false
    o.border = false

    o.moveWithMouse = false
    o.settings = settings

    return o
end


-------------------------------------------------------
-- Create HUD
-------------------------------------------------------

local function createVitals_HUD()

    if Vitals_HUD.instance then

        Vitals_HUD.instance:
            removeFromUIManager()
    end

    local hud =
        Vitals_HUD:new()

    hud:initialise()
    hud:addToUIManager()

    Vitals_HUD.instance =
        hud

    saveSettings(
        hud.settings
    )
end


-------------------------------------------------------
-- Resolution change
-------------------------------------------------------

local function onVitalsResolutionChange()

    if not Vitals_HUD.instance then
        return
    end

    Vitals_HUD.instance:
        clampPositionToScreen()

    Vitals_HUD.instance:
        rememberPosition()
end


Events.OnGameStart.Add(
    createVitals_HUD
)

Events.OnResolutionChange.Add(
    onVitalsResolutionChange
)
