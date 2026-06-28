-- Price Favorites (v0.4.0)
--
-- Adds a "Favoriten" segment to the top of the in-game Prices list, plus a
-- "Favorit" button in the prices button-bar that favorites / unfavorites the
-- highlighted fill type. Favorites are saved per player (modSettings) and shared
-- across all savegames.
--
-- Approach: the prices page (InGameMenuStatisticsFrame) builds its whole view
-- from self.fillTypes (an array of sections). We add a favorites section to
-- self.fillTypes at the moment the frame rebuilds its table (updateStationData /
-- rebuildTable), so the frame builds rows, price cells and its update() state
-- all consistently from the augmented data. The favorite rows are real fill type
-- references, rendered by the game's own code - so they stay clickable and show
-- correct prices, and remain in their original segment too.

PriceFavorites = {}

local LOG = "[PriceFav] "
local FAV_TITLE = "Favoriten"
local TOGGLE_TEXT = "Favorit"
local FAV_MARKER = "__priceFavSection"

PriceFavorites.favorites = {}    -- set of favorited fill type names

--------------------------------------------------------------------------------
-- Persistence (per player, modSettings, shared across savegames)
--------------------------------------------------------------------------------

local function getSaveDir()
    return getUserProfileAppPath() .. "modSettings/FS25_PriceFavorites/"
end

function PriceFavorites.load()
    PriceFavorites.favorites = {}
    local path = getSaveDir() .. "favorites.xml"
    if not fileExists(path) then
        return
    end
    local xmlFile = XMLFile.load("priceFavLoad", path)
    if xmlFile == nil then
        return
    end
    local i = 0
    while true do
        local key = string.format("priceFavorites.fillType(%d)", i)
        if not xmlFile:hasProperty(key) then
            break
        end
        local name = xmlFile:getString(key .. "#name")
        if name ~= nil and name ~= "" then
            PriceFavorites.favorites[name] = true
        end
        i = i + 1
    end
    xmlFile:delete()
    print(LOG .. "loaded " .. i .. " favorite(s)")
end

function PriceFavorites.save()
    createFolder(getUserProfileAppPath() .. "modSettings/")
    createFolder(getSaveDir())
    local xmlFile = XMLFile.create("priceFavSave", getSaveDir() .. "favorites.xml", "priceFavorites")
    if xmlFile == nil then
        print(LOG .. "ERROR: could not create save file")
        return
    end
    local i = 0
    for name in pairs(PriceFavorites.favorites) do
        xmlFile:setString(string.format("priceFavorites.fillType(%d)#name", i), name)
        i = i + 1
    end
    xmlFile:save()
    xmlFile:delete()
end

--------------------------------------------------------------------------------
-- Favorites section (mutate self.fillTypes consistently at rebuild time)
--------------------------------------------------------------------------------

local function isStatsFrame(o)
    return type(o) == "table" and rawget(o, "fillTypes") ~= nil and rawget(o, "currentStationData") ~= nil
end

local function hasAnyFavorite()
    return next(PriceFavorites.favorites) ~= nil
end

-- Ensure self.fillTypes starts with an up-to-date favorites section (or none).
local function syncFavSection(frame)
    local sections = frame.fillTypes
    if type(sections) ~= "table" then
        return
    end
    -- Drop any existing favorites section first.
    if type(sections[1]) == "table" and sections[1][FAV_MARKER] then
        table.remove(sections, 1)
    end
    if not hasAnyFavorite() then
        return
    end
    local favs = { [FAV_MARKER] = true }
    for _, section in ipairs(sections) do
        for _, ft in ipairs(section) do
            if type(ft) == "table" and ft.name ~= nil and PriceFavorites.favorites[ft.name] then
                favs[#favs + 1] = ft
            end
        end
    end
    if #favs > 0 then
        table.insert(sections, 1, favs)
    end
end

-- Add the section right after the frame (re)builds fillTypes, and right before
-- it rebuilds the table cells - so every structure is built consistently.
function PriceFavorites.afterUpdateStationData(frame)
    pcall(syncFavSection, frame)
end

function PriceFavorites.beforeRebuildTable(frame)
    pcall(syncFavSection, frame)
end

-- The original section-title lookup is index-based, so hand it the un-shifted
-- index for the sections that follow our injected one.
function PriceFavorites.getTitleForSectionHeader(frame, superFunc, list, section, ...)
    local sections = frame.fillTypes
    local hasFav = type(sections) == "table" and type(sections[1]) == "table"
        and sections[1][FAV_MARKER]
    if hasFav then
        if section == 1 then
            return FAV_TITLE
        end
        return superFunc(frame, list, section - 1, ...)
    end
    return superFunc(frame, list, section, ...)
end

-- Track the highlighted fill type (favorite rows are real fill types, so the
-- section/index map directly into self.fillTypes - no remapping needed).
function PriceFavorites.afterSelectionChanged(frame, list, section, index)
    pcall(function()
        if not isStatsFrame(frame) then
            return
        end
        local sections = frame.fillTypes
        local item = type(sections) == "table" and sections[section] and sections[section][index]
        if type(item) == "table" and item.name ~= nil and item.pricePerLiter ~= nil then
            frame.__pfSelected = item
        end
    end)
end

-- Remember the fill-types row list so we can refresh it after a toggle.
function PriceFavorites.beforeReloadData(list)
    pcall(function()
        local frame = list.dataSource
        if isStatsFrame(frame) and type(frame.fillTypes) == "table" then
            -- The row list is the one whose section count tracks #fillTypes.
            local ok, n = pcall(frame.getNumberOfSections, frame, list)
            if ok and n == #frame.fillTypes then
                frame.__pfRowList = list
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Toggle button
--------------------------------------------------------------------------------

function PriceFavorites.onToggle(frame)
    local item = frame.__pfSelected
    if type(item) ~= "table" or item.name == nil then
        return
    end

    local hadFavorites = hasAnyFavorite()
    if PriceFavorites.favorites[item.name] then
        PriceFavorites.favorites[item.name] = nil
    else
        PriceFavorites.favorites[item.name] = true
    end
    PriceFavorites.save()

    -- Adding the first favorite prepends a section (shift +1); removing the last
    -- removes it (shift -1). Keep the cursor on the same item across that shift.
    local hasFavorites = hasAnyFavorite()
    local delta = (hasFavorites and not hadFavorites) and 1
        or (hadFavorites and not hasFavorites) and -1 or 0

    local list = frame.__pfRowList
    local selSection = list ~= nil and list.selectedSectionIndex or nil
    local selIndex = list ~= nil and list.selectedIndex or nil

    -- Rebuild the whole prices table so rows, cells and update() state stay in
    -- sync (syncFavSection runs inside rebuildTable via our prepend hook).
    if type(frame.rebuildTable) == "function" then
        pcall(function() frame:rebuildTable() end)
    end
    if list ~= nil then
        pcall(function() list:reloadData() end)
        if delta ~= 0 and selSection ~= nil then
            pcall(function() list:setSelectedItem(math.max(1, selSection + delta), selIndex or 1) end)
        end
    end
end

function PriceFavorites.getMenuButtonInfo(frame, superFunc, ...)
    local info = superFunc(frame, ...)
    if info ~= nil and (info == frame.menuButtonInfoPrices
        or info == frame.menuButtonInfoPricesWithHotspot) then
        local newInfo = {}
        for i = 1, #info do
            newInfo[i] = info[i]
        end
        newInfo[#newInfo + 1] = {
            inputAction = InputAction.PRICEFAV_TOGGLE,
            text = TOGGLE_TEXT,
            callback = function()
                PriceFavorites.onToggle(frame)
            end,
        }
        return newInfo
    end
    return info
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function PriceFavorites:loadMap(name)
    PriceFavorites.load()

    if SmoothListElement ~= nil and type(SmoothListElement.reloadData) == "function" then
        SmoothListElement.reloadData = Utils.prependedFunction(
            SmoothListElement.reloadData, PriceFavorites.beforeReloadData)
    end

    local fc = _G["InGameMenuStatisticsFrame"]
    if type(fc) ~= "table" then
        print(LOG .. "ERROR: InGameMenuStatisticsFrame not found")
        return
    end

    if type(fc.updateStationData) == "function" then
        fc.updateStationData = Utils.appendedFunction(fc.updateStationData, PriceFavorites.afterUpdateStationData)
    end
    if type(fc.rebuildTable) == "function" then
        fc.rebuildTable = Utils.prependedFunction(fc.rebuildTable, PriceFavorites.beforeRebuildTable)
    end
    if type(fc.getTitleForSectionHeader) == "function" then
        fc.getTitleForSectionHeader = Utils.overwrittenFunction(fc.getTitleForSectionHeader, PriceFavorites.getTitleForSectionHeader)
    end
    if type(fc.onListSelectionChanged) == "function" then
        fc.onListSelectionChanged = Utils.appendedFunction(fc.onListSelectionChanged, PriceFavorites.afterSelectionChanged)
    end
    if type(fc.getMenuButtonInfo) == "function" then
        fc.getMenuButtonInfo = Utils.overwrittenFunction(fc.getMenuButtonInfo, PriceFavorites.getMenuButtonInfo)
    end

    print(LOG .. "v0.4.3 installed")
end

addModEventListener(PriceFavorites)
