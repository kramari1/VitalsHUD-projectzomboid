require "ISUI/ISPanel"
require "ISUI/ISButton"

Vitals_HUD = ISPanel:derive("Vitals_HUD")

-- HUD placement
-- Reserve room for the watch/time controls above and moodles on the right.
local RIGHT_MARGIN = 20
local MOODLE_SPACE = 110
local HUD_TOP = 145


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


-------------------------------------------------------
-- Standard stat bar
-------------------------------------------------------

function Vitals_HUD:drawBar(label, value, y, r, g, b)

    local labelWidth = 82
    local barWidth = 105
    local barHeight = 9
    local barX = labelWidth + 5

    self:drawText(
        label,
        0,
        y - 5,
        1, 1, 1, 1,
        UIFont.Small
    )

    -- Empty bar
    self:drawRect(
        barX,
        y,
        barWidth,
        barHeight,
        0.65,
        0.08, 0.08, 0.08
    )

    -- Filled portion
    self:drawRect(
        barX,
        y,
        barWidth * value,
        barHeight,
        0.9,
        r, g, b
    )

    -- Border
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

function Vitals_HUD:drawTemperature(player, y)

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then
        return y
    end

    local thermo = bodyDamage:getThermoregulator()
    if not thermo then
        return y
    end

    local coreTemp = thermo:getCoreCelcius()
    local setPoint = thermo:getSetPoint()

    local labelWidth = 82
    local barWidth = 105
    local barHeight = 9
    local barX = labelWidth + 5

    ---------------------------------------------------
    -- Difference from ideal temperature
    ---------------------------------------------------

    local delta = coreTemp - setPoint

    -- ±2 C fills the entire gauge.
    -- Anything beyond that stays pinned to an end.
    local gaugeRange = 2.0

    local position =
        clamp(
            0.5 + (delta / (gaugeRange * 2)),
            0,
            1
        )

    ---------------------------------------------------
    -- Label
    ---------------------------------------------------

    self:drawText(
        string.format("Temp %.1f C", coreTemp),
        0,
        y - 5,
        1, 1, 1, 1,
        UIFont.Small
    )

    ---------------------------------------------------
    -- Background
    ---------------------------------------------------

    self:drawRect(
        barX,
        y,
        barWidth,
        barHeight,
        0.65,
        0.08, 0.08, 0.08
    )

    ---------------------------------------------------
    -- Cold half
    ---------------------------------------------------

    self:drawRect(
        barX,
        y,
        barWidth / 2,
        barHeight,
        0.55,
        0.25, 0.45, 0.9
    )

    ---------------------------------------------------
    -- Hot half
    ---------------------------------------------------

    self:drawRect(
        barX + barWidth / 2,
        y,
        barWidth / 2,
        barHeight,
        0.55,
        0.9, 0.3, 0.2
    )

    ---------------------------------------------------
    -- Ideal center marker
    ---------------------------------------------------

    local centerX = barX + (barWidth / 2)

    self:drawRect(
        centerX - 1,
        y - 2,
        2,
        barHeight + 4,
        1,
        0.2, 0.9, 0.2
    )

    ---------------------------------------------------
    -- Current temperature marker
    ---------------------------------------------------

    local markerX =
        barX + (barWidth * position)

    self:drawRect(
        markerX - 2,
        y - 3,
        4,
        barHeight + 6,
        1,
        1, 1, 1
    )

    ---------------------------------------------------
    -- Border
    ---------------------------------------------------

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

    local value = normaliseStat(stats, stat)

    -- Ignore tiny rounding/noise values.
    if value <= 0.005 then
        return y, false
    end

    self:drawBar(
        label,
        value,
        y,
        r, g, b
    )

    return y + 18, true
end


-------------------------------------------------------
-- Toggle expanded panel
-------------------------------------------------------

function Vitals_HUD:onToggleDetails()

    self.expanded = not self.expanded

    if self.expanded then
        self.detailsButton:setTitle("Less")
    else
        self.detailsButton:setTitle("Details")
        self:setHeight(132)
    end
end


-------------------------------------------------------
-- Button
-------------------------------------------------------

function Vitals_HUD:createChildren()

    ISPanel.createChildren(self)

    self.detailsButton =
        ISButton:new(
            125,
            101,
            67,
            22,
            "Details",
            self,
            Vitals_HUD.onToggleDetails
        )

    self.detailsButton:initialise()
    self.detailsButton:instantiate()

    self:addChild(self.detailsButton)
end


-------------------------------------------------------
-- Main rendering
-------------------------------------------------------

function Vitals_HUD:render()

    ---------------------------------------------------
    -- Hide while hovering vanilla moodles
    --
    -- Moodle tooltips extend left into the same area as
    -- this HUD. While the mouse is over the moodle UI,
    -- stop drawing the HUD and hide its Details button.
    ---------------------------------------------------

    local moodlesUI = nil

    if MoodlesUI then
        moodlesUI = MoodlesUI.getInstance()
    end

    if moodlesUI and moodlesUI:isMouseOver() then

        if self.detailsButton then
            self.detailsButton:setVisible(false)
        end

        return
    end

    if self.detailsButton then
        self.detailsButton:setVisible(true)
    end

    ISPanel.render(self)

    local player = getPlayer()

    if not player then
        return
    end

    ---------------------------------------------------
    -- Stay pinned to right side
    ---------------------------------------------------

    self:setX(
        getCore():getScreenWidth()
        - self.width
        - RIGHT_MARGIN
        - MOODLE_SPACE
    )

    local stats = player:getStats()

    ---------------------------------------------------
    -- PRIMARY
    ---------------------------------------------------

    local health =
        clamp(
            player:getBodyDamage()
                :getOverallBodyHealth() / 100,
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


    local y = 6
    local spacing = 18


    ---------------------------------------------------
    -- GOOD when full
    ---------------------------------------------------

    self:drawBar(
        "Health",
        health,
        y,
        0.2, 0.8, 0.2
    )

    y = y + spacing


    self:drawBar(
        "Endurance",
        endurance,
        y,
        0.2, 0.8, 0.2
    )

    y = y + spacing


    ---------------------------------------------------
    -- BAD when full
    ---------------------------------------------------

    self:drawBar(
        "Fatigue",
        fatigue,
        y,
        0.9, 0.55, 0.1
    )

    y = y + spacing


    self:drawBar(
        "Hunger",
        hunger,
        y,
        0.9, 0.55, 0.1
    )

    y = y + spacing


    self:drawBar(
        "Thirst",
        thirst,
        y,
        0.9, 0.55, 0.1
    )


    ---------------------------------------------------
    -- COLLAPSED
    ---------------------------------------------------

    if not self.expanded then
        return
    end


    ---------------------------------------------------
    -- EXTENDED
    ---------------------------------------------------

    y = 137

    self:drawText(
        "CURRENT CONDITIONS",
        0,
        y,
        0.75, 0.75, 0.75, 1,
        UIFont.Small
    )

    y = y + 20


    ---------------------------------------------------
    -- Only visible when active
    ---------------------------------------------------

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


    ---------------------------------------------------
    -- Nothing wrong
    ---------------------------------------------------

    if not anythingActive then

        self:drawText(
            "No active conditions",
            0,
            y,
            0.4, 0.85, 0.4, 1,
            UIFont.Small
        )

        y = y + 22
    else
        y = y + 6
    end


    ---------------------------------------------------
    -- TEMPERATURE
    ---------------------------------------------------

    self:drawText(
        "BODY TEMPERATURE",
        0,
        y,
        0.75, 0.75, 0.75, 1,
        UIFont.Small
    )

    y = y + 20

    self:drawTemperature(
        player,
        y
    )

    y = y + 24


    ---------------------------------------------------
    -- Cold / normal / hot labels
    ---------------------------------------------------

    self:drawText(
        "cold",
        86,
        y,
        0.55, 0.7, 1, 1,
        UIFont.Small
    )

    self:drawText(
        "normal",
        116,
        y,
        0.5, 0.9, 0.5, 1,
        UIFont.Small
    )

    self:drawText(
        "hot",
        168,
        y,
        1, 0.55, 0.45, 1,
        UIFont.Small
    )

    y = y + 24


    ---------------------------------------------------
    -- End of expanded content
    ---------------------------------------------------

    ---------------------------------------------------
    -- Dynamically resize panel
    ---------------------------------------------------

    self:setHeight(y + 8)
end


-------------------------------------------------------
-- Constructor
-------------------------------------------------------

function Vitals_HUD:new()

    local width = 200
    local height = 132

    local x =
        getCore():getScreenWidth()
        - width
        - RIGHT_MARGIN
        - MOODLE_SPACE

    local y = HUD_TOP

    local o =
        ISPanel:new(
            x,
            y,
            width,
            height
        )

    setmetatable(o, self)

    self.__index = self

    o.expanded = false

    o.background = false
    o.border = false

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
    hud:createChildren()
    hud:addToUIManager()

    Vitals_HUD.instance = hud
end


Events.OnGameStart.Add(
    createVitals_HUD
)