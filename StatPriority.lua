local addonName, addon = ...
local frame = CreateFrame("Frame", "StatPriorityFrame", UIParent, "BasicFrameTemplateWithInset")

-- Slot names mapping
local slotNames = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist",
    [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1",
    [14] = "Trinket 2", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand"
}

-- Default stat priorities by spec
local defaultPriorities = {
    ["Blood"] = {1, 2, 3}, ["Protection"] = {1, 4, 2}, ["Guardian"] = {1, 2, 4},
    ["Brewmaster"] = {3, 4, 1}, ["Vengeance"] = {1, 4, 2},
    ["Restoration"] = {1, 3, 2}, ["Holy"] = {1, 3, 4}, ["Discipline"] = {1, 3, 2},
    ["Mistweaver"] = {1, 4, 3}, ["Preservation"] = {2, 1, 3},
    ["Arms"] = {1, 3, 2}, ["Fury"] = {1, 3, 2}, ["Retribution"] = {1, 4, 3},
    ["Enhancement"] = {1, 2, 3}, ["Elemental"] = {1, 3, 2}
}

-- Stat names
local statNames = {
    [1] = "Haste", [2] = "Mastery", [3] = "Critical Strike", [4] = "Versatility"
}

-- Stat IDs for tooltip scanning
local statIDs = {
    [1] = 32, -- Haste
    [2] = 49, -- Mastery  
    [3] = 36, -- Crit
    [4] = 40  -- Versatility
}

-- Initialize saved variables
local function InitDB()
    if not StatPriorityDB then
        StatPriorityDB = {}
    end
    if not StatPriorityDB.priority then
        local spec = GetSpecialization()
        local specName = spec and select(2, GetSpecializationInfo(spec)) or "Arms"
        StatPriorityDB.priority = defaultPriorities[specName] or {1, 3, 2}
    end
end

-- Frame setup
frame:SetSize(520, 700)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
frame.title:SetText("Stat Priority Manager")

-- Create scrollable frame for content
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 45)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(480, 1200)
scrollFrame:SetScrollChild(content)

-- Stat display area
local statText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statText:SetPoint("TOPLEFT", 10, -10)
statText:SetJustifyH("LEFT")
statText:SetWidth(460)

-- Item level display
local ilvlText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ilvlText:SetPoint("TOPLEFT", statText, "BOTTOMLEFT", 0, -10)
ilvlText:SetJustifyH("LEFT")
ilvlText:SetWidth(460)

-- Breakpoint info
local breakpointText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
breakpointText:SetPoint("TOPLEFT", ilvlText, "BOTTOMLEFT", 0, -15)
breakpointText:SetJustifyH("LEFT")
breakpointText:SetWidth(460)

-- Weakest slots display
local weakSlotsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
weakSlotsText:SetPoint("TOPLEFT", breakpointText, "BOTTOMLEFT", 0, -15)
weakSlotsText:SetJustifyH("LEFT")
weakSlotsText:SetWidth(460)

-- Upgrade recommendation
local upgradeText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
upgradeText:SetPoint("TOPLEFT", weakSlotsText, "BOTTOMLEFT", 0, -15)
upgradeText:SetJustifyH("LEFT")
upgradeText:SetWidth(460)

-- Bag items display
local bagItemsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bagItemsText:SetPoint("TOPLEFT", upgradeText, "BOTTOMLEFT", 0, -15)
bagItemsText:SetJustifyH("LEFT")
bagItemsText:SetWidth(460)

-- Priority buttons frame (fixed at bottom)
local priorityFrame = CreateFrame("Frame", nil, frame)
priorityFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 10)
priorityFrame:SetSize(490, 30)

local priorityButtons = {}
for i = 1, 3 do
    local btn = CreateFrame("Button", nil, priorityFrame, "UIPanelButtonTemplate")
    btn:SetSize(150, 25)
    btn:SetPoint("LEFT", 5 + (i-1) * 160, 0)
    btn:SetText(statNames[i])
    btn.statIndex = i
    btn:SetScript("OnClick", function(self)
        local remaining = {}
        for j = 1, 4 do
            if j ~= self.statIndex then
                table.insert(remaining, j)
            end
        end
        StatPriorityDB.priority = {self.statIndex, remaining[1], remaining[2]}
        addon:UpdateDisplay()
    end)
    priorityButtons[i] = btn
end

-- Get item stats from tooltip
local scanTooltip = CreateFrame("GameTooltip", "StatPriorityScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function GetItemStats(itemLink)
    if not itemLink then return {haste = 0, crit = 0, mastery = 0, vers = 0} end
    
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)
    
    local stats = {haste = 0, crit = 0, mastery = 0, vers = 0}
    
    local numLines = scanTooltip:NumLines()
    if not numLines then return stats end
    
    for i = 2, numLines do
        local line = _G["StatPriorityScanTooltipTextLeft"..i]
        if line then
            local text = line:GetText()
            if text then
                -- Match "+XXX Haste"
                if text:match("Haste") then
                    local val = text:match("%+(%d+)")
                    if val then stats.haste = tonumber(val) or 0 end
                elseif text:match("Critical Strike") then
                    local val = text:match("%+(%d+)")
                    if val then stats.crit = tonumber(val) or 0 end
                elseif text:match("Mastery") then
                    local val = text:match("%+(%d+)")
                    if val then stats.mastery = tonumber(val) or 0 end
                elseif text:match("Versatility") then
                    local val = text:match("%+(%d+)")
                    if val then stats.vers = tonumber(val) or 0 end
                end
            end
        end
    end
    
    return stats
end

-- Calculate stat score based on priority
local function CalculateStatScore(stats, priority)
    local weights = {0, 0, 0, 0}
    weights[priority[1]] = 3
    weights[priority[2]] = 2
    weights[priority[3]] = 1
    
    local score = 0
    score = score + (stats.haste or 0) * weights[1]
    score = score + (stats.mastery or 0) * weights[2]
    score = score + (stats.crit or 0) * weights[3]
    score = score + (stats.vers or 0) * weights[4]
    
    return score
end

-- Get equipped item info
local function GetEquippedItems()
    local items = {}
    local totalIlvl = 0
    local count = 0
    
    for slot = 1, 17 do
        if slot ~= 4 then -- Skip shirt slot
            local itemLink = GetInventoryItemLink("player", slot)
            if itemLink then
                local _, _, _, ilvl = GetItemInfo(itemLink)
                if ilvl then
                    items[slot] = {
                        link = itemLink,
                        ilvl = ilvl,
                        stats = GetItemStats(itemLink)
                    }
                    totalIlvl = totalIlvl + ilvl
                    count = count + 1
                end
            end
        end
    end
    
    local avgIlvl = count > 0 and (totalIlvl / count) or 0
    return items, avgIlvl
end

-- Find weakest slots
local function FindWeakestSlots(equippedItems, avgIlvl)
    local weakSlots = {}
    
    for slot, item in pairs(equippedItems) do
        if item.ilvl < avgIlvl - 5 then
            table.insert(weakSlots, {
                slot = slot,
                name = slotNames[slot],
                ilvl = item.ilvl,
                diff = avgIlvl - item.ilvl
            })
        end
    end
    
    table.sort(weakSlots, function(a, b) return a.diff > b.diff end)
    return weakSlots
end

-- Scan bags for upgrades
local function ScanBagsForUpgrades(equippedItems, priority)
    local upgrades = {}
    
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local itemInfo = {GetItemInfo(itemLink)}
                    if itemInfo and itemInfo[1] then
                        local equipSlot = itemInfo[9]
                        local equipSlot = itemInfo[9]
                        
                        if equipSlot and equipSlot ~= "" then
                            -- Find which slot this can be equipped to
                            local targetSlot = nil
                            for invSlot = 1, 17 do
                                local slotName = GetInventorySlotInfo(invSlot)
                                if slotName and equipSlot:upper() == slotName:upper() then
                                    targetSlot = invSlot
                                    break
                                end
                            end
                            
                            if targetSlot and equippedItems[targetSlot] then
                                local bagItemLevel = itemInfo[4]
                                if bagItemLevel then
                                    local bagItemStats = GetItemStats(itemLink)
                                    local equippedItem = equippedItems[targetSlot]
                                    
                                    if bagItemLevel > equippedItem.ilvl then
                                        local statScore = CalculateStatScore(bagItemStats, priority)
                                        local currentScore = CalculateStatScore(equippedItem.stats, priority)
                                        
                                        table.insert(upgrades, {
                                            slot = targetSlot,
                                            slotName = slotNames[targetSlot] or equipSlot,
                                            link = itemLink,
                                            ilvl = bagItemLevel,
                                            currentIlvl = equippedItem.ilvl,
                                            ilvlGain = bagItemLevel - equippedItem.ilvl,
                                            statScore = statScore,
                                            scoreGain = statScore - currentScore,
                                            stats = bagItemStats
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by stat score gain, then ilvl gain
    table.sort(upgrades, function(a, b)
        if a.scoreGain ~= b.scoreGain then
            return a.scoreGain > b.scoreGain
        end
        return a.ilvlGain > b.ilvlGain
    end)
    
    return upgrades
end

-- Calculate stat thresholds
function addon:CalculateThresholds()
    local haste = UnitSpellHaste("player")
    local baseGCD = 1.5
    local hastedGCD = baseGCD / (1 + haste / 100)
    local gcdCap = math.max(0.75, hastedGCD)
    
    local hasteForCap = 0
    if gcdCap > 0.75 then
        hasteForCap = ((baseGCD / 0.75) - 1) * 100
    end
    
    local cr = GetCombatRating
    local hasteRating = cr(18) or 0
    local critRating = cr(9) or 0
    local masteryRating = cr(26) or 0
    local versRating = cr(29) or 0
    
    local critChance = GetCritChance()
    local mastery = GetMasteryEffect()
    local vers = GetCombatRatingBonus(29) or 0
    
    local block = GetBlockChance() or 0
    local parry = GetParryChance() or 0
    local dodge = GetDodgeChance() or 0
    
    return {
        haste = haste, hasteRating = hasteRating, hasteForGCD = hasteForCap, gcd = gcdCap,
        crit = critChance, critRating = critRating,
        mastery = mastery, masteryRating = masteryRating,
        vers = vers, versRating = versRating,
        block = block, parry = parry, dodge = dodge
    }
end

-- Update display
function addon:UpdateDisplay()
    local stats = self:CalculateThresholds()
    local priority = StatPriorityDB.priority
    local equippedItems, avgIlvl = GetEquippedItems()
    local weakSlots = FindWeakestSlots(equippedItems, avgIlvl)
    local bagUpgrades = ScanBagsForUpgrades(equippedItems, priority)
    
    -- Current stats
    local text = string.format(
        "|cFFFFD700Current Stats:|r\n\n" ..
        "|cFF00FF00Haste:|r %.2f%% (%d rating)\n" ..
        "|cFFFF6B6BCritical Strike:|r %.2f%% (%d rating)\n" ..
        "|cFF4FC3F7Mastery:|r %.2f%% (%d rating)\n" ..
        "|cFF9C27B0Versatility:|r %.2f%% (%d rating)\n\n" ..
        "|cFFFFAB00Defensive:|r Block: %.2f%% | Parry: %.2f%% | Dodge: %.2f%%",
        stats.haste, stats.hasteRating,
        stats.crit, stats.critRating,
        stats.mastery, stats.masteryRating,
        stats.vers, stats.versRating,
        stats.block, stats.parry, stats.dodge
    )
    statText:SetText(text)
    
    -- Item level
    local ilvlTxt = string.format(
        "\n|cFFFFD700Item Level:|r %.1f average",
        avgIlvl
    )
    ilvlText:SetText(ilvlTxt)
    
    -- Breakpoints
    local bpText = string.format(
        "\n|cFFFFD700Breakpoints:|r\n\n" ..
        "|cFF00FF00GCD:|r Current: %.3fs | Cap: 0.750s\n" ..
        "Haste for cap: %.2f%% (Have: %.2f%%) %s\n" ..
        "|cFF4FC3F7Auto-Attack:|r %.2f%% faster",
        stats.gcd, stats.hasteForGCD, stats.haste,
        stats.haste >= stats.hasteForGCD and "|cFF00FF00✓|r" or "|cFFFF0000✗|r",
        stats.haste
    )
    breakpointText:SetText(bpText)
    
    -- Weakest slots
    local weakText = "\n|cFFFFD700Weakest Equipped Slots:|r\n\n"
    if #weakSlots > 0 then
        for i = 1, math.min(5, #weakSlots) do
            local slot = weakSlots[i]
            weakText = weakText .. string.format(
                "|cFFFF4444%s:|r ilvl %d (%.1f below average)\n",
                slot.name, slot.ilvl, slot.diff
            )
        end
    else
        weakText = weakText .. "|cFF00FF00All slots within 5 ilvls of average!|r\n"
    end
    weakSlotsText:SetText(weakText)
    
    -- Priority and recommendation
    local priorityText = string.format(
        "\n|cFFFFD700Stat Priority:|r %s > %s > %s\n\n" ..
        "|cFF00FFFFRecommendation:|r Focus on |cFFFFFF00%s|r",
        statNames[priority[1]], statNames[priority[2]], statNames[priority[3]],
        statNames[priority[1]]
    )
    upgradeText:SetText(priorityText)
    
    -- Bag upgrades
    local bagText = "\n|cFFFFD700Available Upgrades in Bags:|r\n\n"
    if #bagUpgrades > 0 then
        for i = 1, math.min(8, #bagUpgrades) do
            local up = bagUpgrades[i]
            local statBreakdown = ""
            if up.stats.haste > 0 then statBreakdown = statBreakdown .. string.format("H:%d ", up.stats.haste) end
            if up.stats.crit > 0 then statBreakdown = statBreakdown .. string.format("C:%d ", up.stats.crit) end
            if up.stats.mastery > 0 then statBreakdown = statBreakdown .. string.format("M:%d ", up.stats.mastery) end
            if up.stats.vers > 0 then statBreakdown = statBreakdown .. string.format("V:%d", up.stats.vers) end
            
            bagText = bagText .. string.format(
                "|cFF00FF00%s:|r %s\n  ilvl %d → %d (+%d) | Score: +%d\n  Stats: %s\n",
                up.slotName, up.link, up.currentIlvl, up.ilvl, up.ilvlGain,
                up.scoreGain, statBreakdown
            )
        end
    else
        bagText = bagText .. "|cFFFFAA00No upgrades found in bags|r\n"
    end
    bagItemsText:SetText(bagText)
    
    -- Update priority buttons
    for i = 1, 3 do
        priorityButtons[i]:SetText(string.format("%d. %s", i, statNames[priority[i]]))
    end
end

-- Slash commands
SLASH_STATPRIORITY1 = "/statpriority"
SLASH_STATPRIORITY2 = "/sp"
SlashCmdList["STATPRIORITY"] = function(msg)
    if frame:IsShown() then
        frame:Hide()
    else
        addon:UpdateDisplay()
        frame:Show()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()
        print("|cFF00FF00Stat Priority Manager loaded!|r Type /sp to open")
    elseif (event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "BAG_UPDATE") and frame:IsShown() then
        C_Timer.After(0.5, function() addon:UpdateDisplay() end)
    end
end)
