--[[ UI.lua – Grafikoberfläche für MyItemTracker (überarbeitet) ]]--

local frame = nil
local scrollFrame = nil
local contentFrame = nil
local rows = {}
local searchBox = nil
local currentFilter = ""
local statusText = nil

-- Hilfsfunktion: Label erstellen
local function CreateLabel(parent, text, x, y, width, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text or "")
    label:SetJustifyH(justify or "LEFT")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    if width then
        label:SetWidth(width)
    end
    return label
end

-- Aktualisiert die Liste basierend auf Filter
function MyItemTracker:RefreshUI()
    if not frame or not frame:IsVisible() then return end

    -- Alte Zeilen entfernen
    for _, row in ipairs(rows) do
        row:Hide()
        row:SetParent(nil)
    end
    rows = {}

    -- Daten in flache Liste umwandeln
    local flatList = {}
    for itemID, charData in pairs(MyItemTrackerDB) do
        local itemName = GetItemInfo(itemID)
        if not itemName then
            itemName = "Unbekannt (ID:" .. itemID .. ")"
        end
        for char, count in pairs(charData) do
            table.insert(flatList, {
                itemName = itemName,
                itemID = itemID,
                char = char,
                count = count
            })
        end
    end

    -- Filter anwenden
    if currentFilter ~= "" then
        local filterLower = string.lower(currentFilter)
        local filtered = {}
        for _, entry in ipairs(flatList) do
            if string.find(string.lower(entry.itemName), filterLower, 1, true) or
               string.find(string.lower(entry.char), filterLower, 1, true) then
                table.insert(filtered, entry)
            end
        end
        flatList = filtered
    end

    -- Sortierung
    table.sort(flatList, function(a, b)
        if a.itemName ~= b.itemName then
            return a.itemName < b.itemName
        end
        return a.char < b.char
    end)

    -- Zeilen erstellen
    local yOffset = -5
    local rowHeight = 20
    for _, entry in ipairs(flatList) do
        local row = CreateFrame("Button", nil, contentFrame)
        row:SetSize(contentFrame:GetWidth() - 10, rowHeight)
        row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, yOffset)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. entry.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local nameLabel = CreateLabel(row, entry.itemName, 5, 0, 180)
        nameLabel:SetFontObject("GameFontNormalSmall")
        local charLabel = CreateLabel(row, entry.char, 195, 0, 150)
        charLabel:SetFontObject("GameFontNormalSmall")
        local countLabel = CreateLabel(row, tostring(entry.count), 355, 0, 60, "RIGHT")
        countLabel:SetFontObject("GameFontNormalSmall")

        table.insert(rows, row)
        yOffset = yOffset - rowHeight
    end

    -- Höhe des Inhalts anpassen
    local totalHeight = math.max(0, -yOffset + 10)
    contentFrame:SetHeight(totalHeight)
    scrollFrame:SetScrollChild(contentFrame)

    -- Statuszeile aktualisieren
    if statusText then
        statusText:SetText(string.format("%d Einträge gefunden", #flatList))
    end
end

-- Fenster erstellen
function MyItemTracker:CreateUI()
    if frame then return end

    frame = CreateFrame("Frame", "MyItemTrackerFrame", UIParent, "DialogBoxFrame")
    frame:SetSize(650, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    -- Titel
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText("Charakter-Item-Übersicht")

    -- Schließen-Button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Suchfeld
    searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(250, 25)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -35)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        currentFilter = self:GetText()
        MyItemTracker:RefreshUI()
    end)
    local searchLabel = CreateLabel(frame, "Suche:", 20, -38, 50)
    searchLabel:SetFontObject("GameFontNormalSmall")

    -- Kopfzeile
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -70)
    header:SetSize(620, 20)
    CreateLabel(header, "Item", 5, 0, 180):SetFontObject("GameFontNormalSmall")
    CreateLabel(header, "Charakter", 195, 0, 150):SetFontObject("GameFontNormalSmall")
    CreateLabel(header, "Anzahl", 355, 0, 60, "RIGHT"):SetFontObject("GameFontNormalSmall")

    -- ScrollFrame (mit Abstand nach unten für Button & Status)
    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 50)  -- 50px Platz für Button + Status

    contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(scrollFrame:GetWidth(), 100)
    scrollFrame:SetScrollChild(contentFrame)

    -- Statuszeile (links unten)
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 10)
    statusText:SetText("0 Einträge gefunden")

    -- "Jetzt scannen" Button (rechts unten)
    local scanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanButton:SetSize(120, 28)
    scanButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)
    scanButton:SetText("Jetzt scannen")
    scanButton:SetScript("OnClick", function()
        MyItemTracker:ScanCharacter()
        MyItemTracker:RefreshUI()
    end)

    -- Initiale Liste
    MyItemTracker:RefreshUI()
    frame:Hide()
end

-- Fenster ein-/ausblenden
function MyItemTracker:ToggleUI()
    if not frame then
        MyItemTracker:CreateUI()
    end
    if frame:IsVisible() then
        frame:Hide()
    else
        MyItemTracker:RefreshUI()
        frame:Show()
    end
end
