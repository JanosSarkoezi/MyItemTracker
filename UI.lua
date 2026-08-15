-- ============================================================
-- MYITEMTRACKER - UI SYSTEM
-- ============================================================
MyItemTrackerUI = MyItemTrackerUI or {}
MyItemTrackerUI.rows = {}

-- ------------------------------------------------------------
-- 1. ZEILEN-FABRIK (Factory Pattern)
-- Erstellt oder wiederverwendet eine Tabellenzeile
-- ------------------------------------------------------------
function MyItemTrackerUI:GetOrCreateRow(index)
    if self.rows[index] then
        return self.rows[index]
    end

    local row = CreateFrame("Button", nil, self.scrollChild)
    row:SetSize(370, 22)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 22)

    -- Hover-Hintergrund für bessere Lesbarkeit
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetTexture(1, 1, 1, 0.05)
    bg:Hide()
    row.bg = bg

    -- Item Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Item Name (mit fester Breite & Qualitätsfarbe)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(170)
    row.name:SetJustifyH("LEFT")

    -- Lagerort (Mitte, dezent deklariert)
    row.location = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.location:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.location:SetWidth(110)
    row.location:SetJustifyH("LEFT")
    row.location:SetTextColor(0.6, 0.6, 0.6)

    -- Anzahl (rechtsbündig)
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -8, 0)
    row.count:SetWidth(45)
    row.count:SetJustifyH("RIGHT")

    -- Hover-Effekte & Tooltip-Support (Kompatibel mit WoW 3.3.5a)
    row:SetScript("OnEnter", function(s)
        s.bg:Show()
        if s.itemID then
            -- SetHyperlink mit item:ID ist in 3.3.5a der beste Standard
            local itemLink = "item:" .. s.itemID .. ":0:0:0:0:0:0:0"
            
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(s)
        s.bg:Hide()
        GameTooltip:Hide()
    end)

    self.rows[index] = row
    return row
end

-- ------------------------------------------------------------
-- 2. DYNAMISCHES BEFÜLLEN DER LISTE
-- ------------------------------------------------------------
function MyItemTrackerUI:UpdateList(searchQuery)
    if not self.scrollChild then return end

    -- Bisherige Zeilen ausblenden
    for _, row in pairs(self.rows) do
        row:Hide()
        row.itemID = nil
    end

    searchQuery = searchQuery and searchQuery:lower():trim() or ""
    local rowIndex = 0
    local realmName = GetRealmName()
    local db = MyItemTrackerDB and MyItemTrackerDB[realmName]

    if not db or not db.storage then
        self.statusText:SetText("Keine Datenbank-Einträge vorhanden.")
        return
    end

    -- Sammeltabelle für Treffer: { itemID, locationName, count }
    local results = {}

    local function AddResult(itemID, location, amount)
        if not itemID or amount <= 0 then return end
        local itemName = GetItemInfo(itemID) or ("Item #" .. itemID)
        
        -- Filter-Check
        if searchQuery == "" or itemName:lower():find(searchQuery, 1, true) then
            table.insert(results, {
                itemID = itemID,
                location = location,
                count = amount
            })
        end
    end

    -- a) Charaktere durchsuchen (Taschen, Bank, Personal Bank)
    if db.storage.characters then
        for charName, charData in pairs(db.storage.characters) do
            -- Taschen
            if charData.bags then
                for itemID, amount in pairs(charData.bags) do
                    AddResult(itemID, charName .. " (Tasche)", amount)
                end
            end
            -- Normale Bank
            if charData.bank then
                for itemID, amount in pairs(charData.bank) do
                    AddResult(itemID, charName .. " (Bank)", amount)
                end
            end
            -- Personal Bank Tabs
            if charData.personal_bank then
                for tabIndex, tabData in pairs(charData.personal_bank) do
                    for itemID, amount in pairs(tabData) do
                        AddResult(itemID, charName .. " (Tab " .. tabIndex .. ")", amount)
                    end
                end
            end
        end
    end

    -- b) Realm Bank durchsuchen
    if db.storage.realm_bank then
        for tabIndex, tabData in pairs(db.storage.realm_bank) do
            for itemID, amount in pairs(tabData) do
                AddResult(itemID, "Realm Bank Tab " .. tabIndex, amount)
            end
        end
    end

    -- c) Zeilen rendern
    for i, data in ipairs(results) do
        rowIndex = rowIndex + 1
        local row = self:GetOrCreateRow(rowIndex)
        
        row.itemID = data.itemID
        local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(data.itemID)

        -- Icon setzen
        row.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Name + Qualitätsfarbe setzen
        if itemName then
            local r, g, b = GetItemQualityColor(itemQuality or 1)
            row.name:SetText(itemName)
            row.name:SetTextColor(r, g, b)
        else
            row.name:SetText("Lade Item " .. data.itemID .. "...")
            row.name:SetTextColor(1, 0.82, 0)
        end

        row.location:SetText(data.location)
        row.count:SetText(data.count)
        row:Show()
    end

    -- ScrollChild-Höhe anpassen, damit Scrollbar exakt berechnet wird
    self.scrollChild:SetHeight(math.max(rowIndex * 22, 10))
    self.statusText:SetText("Treffer: " .. rowIndex)
end

-- ------------------------------------------------------------
-- 3. FENSTER-CREATION & INITIALISIERUNG
-- ------------------------------------------------------------
function MyItemTrackerUI:Toggle()
    if not self.frame then
        self:CreateUI()
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:UpdateList(self.editBox:GetText())
        self.frame:Show()

        -- NEU: Fokus auf das Suchfeld setzen & Text markieren
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end
end

function MyItemTrackerUI:CreateUI()
    if self.frame then return end

    -- 1. Haupt-Rahmen
    local f = CreateFrame("Frame", "MyItemTrackerOverviewFrame", UIParent)
    f:SetSize(420, 380)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Titel
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("MyItemTracker Übersicht")

    -- Schließen-Button oben rechts
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    -- Suchfeld (EditBox)
    local editBox = CreateFrame("EditBox", "MyItemTrackerSearchBox", f, "InputBoxTemplate")
    editBox:SetSize(180, 20)
    editBox:SetPoint("TOPLEFT", 20, -32)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnTextChanged", function(s)
        MyItemTrackerUI:UpdateList(s:GetText())
    end)
    editBox:SetScript("OnEscapePressed", function(s)
        s:ClearFocus()
        MyItemTrackerUI.frame:Hide()
    end)

    -- Bei Enter: Fokus entfernen (damit du wieder deinen Charakter steuern kannst)
    editBox:SetScript("OnEnterPressed", function(s)
        s:ClearFocus()
    end)

    -- Status-Text (unten links)
    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", 15, 12)
    statusText:SetTextColor(0.5, 0.5, 0.5)

    -- 2. ScrollFrame (Standard-WoW-Klasse)
    local scrollFrame = CreateFrame("ScrollFrame", "MyItemTrackerScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 32)

    -- Das innere Container-Frame für alle Zeilen
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(370, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.frame = f
    self.scrollChild = scrollChild
    self.editBox = editBox
    self.statusText = statusText
end

-- Slash-Command Anbindung
SLASH_MYITEMTRACKERUI1 = "/mit"
SLASH_MYITEMTRACKERUI2 = "/itemtracker"
SlashCmdList["MYITEMTRACKERUI"] = function()
    MyItemTrackerUI:Toggle()
end
