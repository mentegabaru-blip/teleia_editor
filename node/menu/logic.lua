local Logic = {
    searchQuery = "",
    recentCharts = {},
    showNewModal = false,
    showLoadModal = false,
    selectedChart = nil, -- chart yang sedang diklik untuk melihat detail difficulty

    -- Form data untuk chart baru (Nama Lagu + Default Difficulty pilihan awal)
    newForm = {
        title = "New Song",
        initialDifficulty = "normal"
    }
}

-- Pastikan direktori chart ada
local function ensureChartDirectory()
    love.filesystem.createDirectory("charts")
    love.filesystem.createDirectory("assets/official_chart")
end

-- Refresh / Load daftar chart yang tersimpan
function Logic.loadRecentCharts()
    ensureChartDirectory()
    local charts = {}

    local scanDirs = { "charts", "assets/official_chart" }
    for _, basePath in ipairs(scanDirs) do
        local items = love.filesystem.getDirectoryItems(basePath)
        for _, folder in ipairs(items) do
            local chartFolderPath = basePath .. "/" .. folder
            local info = love.filesystem.getInfo(chartFolderPath)
            if info and info.type == "directory" then
                local summaries, metadata = tchart.getDifficultySummaries(chartFolderPath)
                local M = metadata or {}
                local totalNotes = 0
                for _, s in ipairs(summaries) do
                    totalNotes = totalNotes + (s.noteCount or 0)
                end

                table.insert(charts, {
                    folder = folder,
                    path = chartFolderPath,
                    title = (M.name and M.name.text) or (M.music and M.music.title and M.music.title.text) or folder,
                    charter = (M.charter and M.charter.text) or "Unknown",
                    musicBy = (M.music and M.music.by and M.music.by.text) or "Unknown",
                    bpm = tostring((M.bpm and M.bpm.text) or M.bpm or 120),
                    offset = tostring((M.offset and M.offset.text) or M.offset or 0),
                    difficulties = summaries,
                    metadata = M,
                    totalNotes = totalNotes,
                    lastModified = info.modtime or 0
                })
            end
        end
    end

    table.sort(charts, function(a, b) return a.lastModified > b.lastModified end)
    Logic.recentCharts = charts
end

-- Filter pencarian chart
function Logic.getFilteredCharts()
    if Logic.searchQuery == "" then
        return Logic.recentCharts
    end

    local filtered = {}
    local query = Logic.searchQuery:lower()
    for _, c in ipairs(Logic.recentCharts) do
        if c.title:lower():find(query, 1, true)
        or c.charter:lower():find(query, 1, true)
        or c.musicBy:lower():find(query, 1, true)
        or c.folder:lower():find(query, 1, true) then
            table.insert(filtered, c)
        end
    end
    return filtered
end

-- Bikin chart baru dengan Metadata berisi semua difficulty (Easy, Normal, Hard, Expert, Master)
function Logic.createNewChart()
    ensureChartDirectory()
    local chartTitle = (Logic.newForm.title and Logic.newForm.title ~= "") and Logic.newForm.title or "New Song"
    local folderName = chartTitle:gsub("[^%w%-_]", "_"):lower()
    if folderName == "" then folderName = "chart_" .. tostring(os.time()) end
    
    local targetFolder = "charts/" .. folderName
    local count = 1
    while love.filesystem.getInfo(targetFolder) do
        targetFolder = "charts/" .. folderName .. "_" .. count
        count = count + 1
    end

    love.filesystem.createDirectory(targetFolder)

    -- Format Metadata.json
    local metadata = {
        name = { text = chartTitle },
        charter = { text = "Anonymous" },
        music = {
            title = { text = chartTitle },
            by = { text = "Artist" }
        },
        bpm = { text = "120" },
        offset = { text = "0.0" },
        difficulties = {
            easy = { rating = 1, charter = "Anonymous" },
            normal = { rating = 3, charter = "Anonymous" },
            hard = { rating = 6, charter = "Anonymous" },
            expert = { rating = 9, charter = "Anonymous" },
            master = { rating = 12, charter = "Anonymous" }
        },
        created_at = os.time()
    }

    local initDiff = (Logic.newForm.initialDifficulty or "normal"):lower()

    -- Buat file Chart_<diff>.json untuk difficulty awal
    local chartData = {
        difficulty = initDiff,
        notes = {},
        effects = {}
    }

    love.filesystem.write(targetFolder .. "/Metadata.json", json.encode(metadata))
    love.filesystem.write(targetFolder .. "/Chart_" .. initDiff .. ".json", json.encode(chartData))
    if initDiff == "normal" then
        love.filesystem.write(targetFolder .. "/Chart.json", json.encode(chartData))
    end

    local saveDir = love.filesystem.getSaveDirectory()
    love.system.openURL("file://" .. saveDir .. "/" .. targetFolder)

    Logic.loadRecentCharts()
    Logic.showNewModal = false

    return targetFolder, initDiff
end

return Logic
