-- ============================================================================
-- 1. Datenbank-Initialisierung (Pro Realm)
-- ============================================================================
MyItemTracker = MyItemTracker or {}

local function GetRealmDB()
    local realm = GetRealmName() or "UnknownRealm"
    
    if type(MyItemTrackerDB) ~= "table" then
        MyItemTrackerDB = {}
    end
    
    MyItemTrackerDB[realm] = MyItemTrackerDB[realm] or {}
    local db = MyItemTrackerDB[realm]
    
    db.storage = db.storage or {}
    db.storage.characters = db.storage.characters or {}
    db.storage.realm_bank = db.storage.realm_bank or {}
    db.storage.guild_bank = db.storage.guild_bank or {}
    
    return db
end

-- Hilfsfunktion: Erkennt Banktyp
local function DetectBankCategory()
    local titleText = ""
    if GuildBankFrameTitleText and GuildBankFrameTitleText:GetText() then
        titleText = GuildBankFrameTitleText:GetText()
    elseif GuildBankFrame and GuildBankFrame.TitleText then
        titleText = GuildBankFrame.TitleText:GetText() or ""
    end

    if string.find(titleText, "Personal") then
        return "personal_bank", "Personal Bank"
    elseif string.find(titleText, "Realm") then
        return "realm_bank", "Realm Bank"
    else
        local firstTabName = GetGuildBankTabInfo(1) or ""
        if string.find(firstTabName, "Personal") then
            return "personal_bank", "Personal Bank"
        elseif string.find(firstTabName, "Realm") then
            return "realm_bank", "Realm Bank"
        end

        local guildName = GetGuildInfo("player")
        if guildName and guildName ~= "" then
            return "realm_bank", "Realm Bank"
        else
            return "personal_bank", "Personal Bank"
        end
    end
end

-- ============================================================================
-- 2. Charakter-Scan (Taschen & Standard-Bank)
-- ============================================================================
function MyItemTracker:ScanBags()
    local db = GetRealmDB()
    local charName = UnitName("player")
    
    db.storage.characters[charName] = db.storage.characters[charName] or {}
    local charStorage = db.storage.characters[charName]
    charStorage.bags = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemID = tonumber(link:match("item:(%d+)"))
                    local _, count = GetContainerItemInfo(bag, slot)
                    if itemID then
                        charStorage.bags[itemID] = (charStorage.bags[itemID] or 0) + (count or 1)
                    end
                end
            end
        end
    end

    if MyItemTracker.RefreshUI then MyItemTracker:RefreshUI() end
end

function MyItemTracker:ScanCharacterBank()
    if not (BankFrame and BankFrame:IsVisible()) then return end

    local db = GetRealmDB()
    local charName = UnitName("player")
    db.storage.characters[charName] = db.storage.characters[charName] or {}
    local charStorage = db.storage.characters[charName]
    charStorage.bank = {}

    local function ScanBankContainer(bagID)
        local numSlots = GetContainerNumSlots(bagID)
        if not numSlots or numSlots == 0 then return end
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                local _, count = GetContainerItemInfo(bagID, slot)
                if itemID then
                    charStorage.bank[itemID] = (charStorage.bank[itemID] or 0) + (count or 1)
                end
            end
        end
    end

    ScanBankContainer(-1)
    for bag = 5, 12 do ScanBankContainer(bag) end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MyItemTracker]|r Standard-Bank gescannt.")
    if MyItemTracker.RefreshUI then MyItemTracker:RefreshUI() end
end

-- ============================================================================
-- 3. Einzel-Tab-Scan (Personal Bank isoliert pro Char, Realm Bank global)
-- ============================================================================
function MyItemTracker:ScanSingleGuildTab(tabIndex, storageCategory)
    local db = GetRealmDB()
    local targetTable = nil
    local charName = UnitName("player")

    if storageCategory == "personal_bank" then
        db.storage.characters[charName] = db.storage.characters[charName] or {}
        db.storage.characters[charName].personal_bank = db.storage.characters[charName].personal_bank or {}
        targetTable = db.storage.characters[charName].personal_bank
    else
        targetTable = db.storage[storageCategory]
    end

    if not targetTable then return end

    targetTable[tabIndex] = {}

    local name = GetGuildBankTabInfo(tabIndex) or ("Tab " .. tabIndex)
    local itemCount = 0

    for slot = 1, 98 do
        local link = GetGuildBankItemLink(tabIndex, slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            local _, count = GetGuildBankItemInfo(tabIndex, slot)
            count = (type(count) == "number" and count > 0) and count or 1

            if itemID then
                targetTable[tabIndex][itemID] = (targetTable[tabIndex][itemID] or 0) + count
                itemCount = itemCount + 1
            end
        end
    end

    local label = (storageCategory == "realm_bank" and "Realm Bank") or 
                  (storageCategory == "personal_bank" and ("Personal Bank (" .. charName .. ")")) or "Guild Bank"

    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[MyItemTracker]|r " .. label .. " (Tab " .. tabIndex .. " - " .. name .. "): |cffffffff" .. itemCount .. " Slots gescannt.|r")

    if MyItemTracker.RefreshUI then MyItemTracker:RefreshUI() end
end

-- ============================================================================
-- 4. Automatisierter Tab-Scanner
-- ============================================================================
local gbScanner = {
    active = false,
    totalTabs = 0,
    currentTab = 0,
    category = "guild_bank",
    label = "Gildenbank"
}

local function ResetGuildBankScanner()
    gbScanner.active = false
    gbScanner.totalTabs = 0
    gbScanner.currentTab = 0
end

local function ScanNextTab()
    if not gbScanner.active then return end

    if gbScanner.currentTab > gbScanner.totalTabs then
        gbScanner.active = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MyItemTracker]|r Scan für " .. gbScanner.label .. " komplett abgeschlossen!")
        if MyItemTracker.UpdateStatusText then
            MyItemTracker:UpdateStatusText("Scan abgeschlossen!")
        end
        return
    end

    local tabIndex = gbScanner.currentTab
    
    if MyItemTracker.UpdateStatusText then
        MyItemTracker:UpdateStatusText("Scanne " .. gbScanner.label .. ": Tab " .. tabIndex .. "/" .. gbScanner.totalTabs .. "...")
    end

    SetCurrentGuildBankTab(tabIndex)
    QueryGuildBankTab(tabIndex)

    C_Timer.After(1.2, function()
        if not gbScanner.active then return end
        
        gbScanner.category, gbScanner.label = DetectBankCategory()

        MyItemTracker:ScanSingleGuildTab(tabIndex, gbScanner.category)
        gbScanner.currentTab = gbScanner.currentTab + 1
        ScanNextTab()
    end)
end

local function StartGuildBankScanner()
    local numTabs = GetNumGuildBankTabs()
    if not numTabs or numTabs == 0 then return end

    ResetGuildBankScanner()
    gbScanner.active = true
    gbScanner.totalTabs = numTabs
    gbScanner.currentTab = 1

    gbScanner.category, gbScanner.label = DetectBankCategory()

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MyItemTracker]|r Starte Scan der |cffffffff" .. gbScanner.label .. "|r (" .. numTabs .. " Tabs gefunden)...")
    ScanNextTab()
end

-- ============================================================================
-- 5. Events
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")

local isBagUpdatePending = false

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MyItemTracker" then
        GetRealmDB()

    elseif event == "PLAYER_LOGIN" then
        MyItemTracker:ScanBags()

    elseif event == "BAG_UPDATE" then
        if not isBagUpdatePending then
            isBagUpdatePending = true
            C_Timer.After(0.5, function()
                MyItemTracker:ScanBags()
                isBagUpdatePending = false
            end)
        end

    elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
        MyItemTracker:ScanCharacterBank()

    elseif event == "GUILDBANKFRAME_OPENED" then
        C_Timer.After(0.5, StartGuildBankScanner)

    elseif event == "GUILDBANKFRAME_CLOSED" then
        if gbScanner.active then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[MyItemTracker]|r Scan abgebrochen.")
        end
        ResetGuildBankScanner()
        if MyItemTracker.RefreshUI then MyItemTracker:RefreshUI() end
    end
end)

-- ============================================================================
-- 6. Slash-Befehle
-- ============================================================================
SLASH_MYTRACKER1 = "/mytracker"
SLASH_MYTRACKER2 = "/items"
SlashCmdList["MYTRACKER"] = function(cmd)
    if cmd == "scan" then
        MyItemTracker:ScanBags()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MyItemTracker]|r Taschen gescannt.")
    else
        MyItemTracker:ToggleUI()
    end
end

-- ============================================================================
-- 7. Tooltip-Erweiterung
-- ============================================================================
local function OnTooltipSetItem(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local db = GetRealmDB()
    local grandTotal = 0
    local lines = {}

    -- 1. Charaktere durchsuchen (Taschen, Std-Bank, Personal Bank)
    if db.storage.characters then
        for charName, charData in pairs(db.storage.characters) do
            local charTotal = 0
            
            if charData.bags and charData.bags[itemID] then
                charTotal = charTotal + charData.bags[itemID]
            end
            if charData.bank and charData.bank[itemID] then
                charTotal = charTotal + charData.bank[itemID]
            end
            if charData.personal_bank then
                for tabIndex, tabData in pairs(charData.personal_bank) do
                    if tabData[itemID] then
                        charTotal = charTotal + tabData[itemID]
                    end
                end
            end

            if charTotal > 0 then
                table.insert(lines, { label = charName, count = charTotal })
                grandTotal = grandTotal + charTotal
            end
        end
    end

    -- 2. Realm Bank durchsuchen
    if db.storage.realm_bank then
        local realmTotal = 0
        for tabIndex, tabData in pairs(db.storage.realm_bank) do
            if tabData[itemID] then
                realmTotal = realmTotal + tabData[itemID]
            end
        end
        if realmTotal > 0 then
            table.insert(lines, { label = "Realm Bank", count = realmTotal })
            grandTotal = grandTotal + realmTotal
        end
    end

    -- 3. Tooltip-Zeilen rendern
    if grandTotal > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff00ff00MyItemTracker:|r", 1, 1, 1)
        for _, entry in ipairs(lines) do
            tooltip:AddDoubleLine("  " .. entry.label .. ":", entry.count, 1, 0.82, 0, 1, 1, 1)
        end
        if #lines > 1 then
            tooltip:AddDoubleLine("  Gesamt:", grandTotal, 0, 1, 0, 0, 1, 0)
        end
        tooltip:Show()
    end
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
