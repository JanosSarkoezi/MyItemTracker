-- MyItemTracker Core
-- Accountweite Item-Übersicht aller Charaktere

-- 1. Globale Datenbank (accountweit) initialisieren
MyItemTrackerDB = MyItemTrackerDB or {}

-- 2. Haupttabelle für das Addon
MyItemTracker = MyItemTracker or {}

-- 3. Hilfsfunktion: Item zur Datenbank hinzufügen
function MyItemTracker:AddItem(itemID, charName, amount)
    if not MyItemTrackerDB[itemID] then
        MyItemTrackerDB[itemID] = {}
    end
    MyItemTrackerDB[itemID][charName] = (MyItemTrackerDB[itemID][charName] or 0) + (amount or 1)
end

-- 4. Scan-Funktion: Sammelt alle Items des aktuellen Chars
function MyItemTracker:ScanCharacter()
    local charName = UnitName("player")
    local realm = GetRealmName()
    local fullName = charName .. "-" .. realm

    -- Normale Taschen (0 = Rucksack, 1-4 = Taschen)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
                if link then
                    local itemID = tonumber(link:match("item:(%d+)"))
                    if itemID then
                        self:AddItem(itemID, fullName, count or 1)
                    end
                end
            end
        end
    end

    -- Bank – nur wenn geöffnet
    if BankFrame and BankFrame:IsVisible() then
        for bag = -1, -6, -1 do
            local numSlots = GetContainerNumSlots(bag)
            if numSlots and numSlots > 0 then
                for slot = 1, numSlots do
                    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
                    if link then
                        local itemID = tonumber(link:match("item:(%d+)"))
                        if itemID then
                            self:AddItem(itemID, fullName, count or 1)
                        end
                    end
                end
            end
        end
    end

    -- Gildenbank (gemeinsame Bank)
    local numTabs = GetNumGuildBankTabs()
    if numTabs and numTabs > 0 then
        for tab = 1, numTabs do
            local tabInfo = { GetGuildBankTabInfo(tab) }
            local numSlots = tabInfo[3] or 0  -- Anzahl Slots in diesem Tab
            for slot = 1, numSlots do
                local link = GetGuildBankItemLink(tab, slot)
                if link then
                    local itemID = tonumber(link:match("item:(%d+)"))
                    if itemID then
                        local _, count = GetGuildBankItemInfo(tab, slot)
                        self:AddItem(itemID, fullName, count or 1)
                    end
                end
            end
        end
    end

    print("Scan von " .. fullName .. " abgeschlossen.")
end

-- 5. Übersicht im Chat anzeigen
function MyItemTracker:ShowOverview()
    MyItemTracker:ToggleUI()
end

-- 6. Automatischer Scan beim Einloggen
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    MyItemTracker:ScanCharacter()
end)

-- 7. Scan bei Bank-Öffnung
local bankFrame = CreateFrame("Frame")
bankFrame:RegisterEvent("BANKFRAME_OPENED")
bankFrame:SetScript("OnEvent", function()
    MyItemTracker:ScanCharacter()
end)

-- 8. Slash-Befehle
SLASH_MYTRACKER1 = "/mytracker"
SLASH_MYTRACKER2 = "/items"

SlashCmdList["MYTRACKER"] = function(cmd)
    if cmd == "" or cmd == "show" then
        MyItemTracker:ShowOverview()
    elseif cmd == "scan" then
        MyItemTracker:ScanCharacter()
    else
        print("Verfügbare Befehle:")
        print("  /mytracker          - Zeige Übersicht")
        print("  /mytracker scan     - Manueller Scan")
        print("  /items              - Kurzform")
    end
end
