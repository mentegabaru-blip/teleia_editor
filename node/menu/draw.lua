local Logic = require("node.menu.logic")

local Draw = {}

function Draw.drawTopNav()
    local winW = love.graphics.getWidth()

    -- Navigation Bar di paling atas (clean studio dock header)
    if Slab.BeginWindow('TopNavBar', {
        X = 0,
        Y = 0,
        W = winW,
        H = 44,
        NoSavedSettings = true,
        AllowResize = false,
        AllowMove = false,
        Border = 1,
        BgColor = { 0.07, 0.07, 0.07, 1.0 }
    }) then
        -- Title Brand
        Slab.Text("RHYTHMIA", { Color = { 0.95, 0.95, 0.95, 1.0 } })
        Slab.SameLine({ Pad = 6 })
        Slab.Text("STUDIO", { Color = { 0.50, 0.50, 0.50, 1.0 } })

        Slab.SameLine({ Pad = 28 })
        if Slab.Button("+ New Chart", { W = 100, H = 26 }) then
            Logic.newForm.title = "New Song"
            Logic.newForm.initialDifficulty = "normal"
            Logic.showNewModal = true
        end

        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Open Folder", { W = 95, H = 26 }) then
            Logic.loadRecentCharts()
            Logic.showLoadModal = true
        end

        -- Search Bar di sebelah kanan
        local leftControlsWidth = 350
        local filterTotalWidth = 220
        local padToRight = math.max(10, winW - leftControlsWidth - filterTotalWidth - 30)

        Slab.SameLine({ Pad = padToRight })
        Slab.Text("Filter:", { Color = { 0.55, 0.55, 0.55, 1.0 } })
        Slab.SameLine({ Pad = 6 })
        if Slab.Input('SearchInput', { Text = Logic.searchQuery, W = 160, Tooltip = "Filter charts by title, charter, or artist" }) then
            Logic.searchQuery = Slab.GetInputText()
        end

        Slab.EndWindow()
    end
end

function Draw.drawMainContent()
    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()

    -- Main Content Area
    if Slab.BeginWindow('MainContentArea', {
        X = 0,
        Y = 44,
        W = winW,
        H = winH - 44,
        NoSavedSettings = true,
        AllowResize = false,
        AllowMove = false,
        Border = 0,
        BgColor = { 0.03, 0.03, 0.03, 1.0 }
    }) then
        Slab.Text("PROJECT LIBRARY", { Color = { 0.85, 0.85, 0.85, 1.0 } })
        Slab.Separator()
        Slab.NewLine()

        -- Action row: New Project trigger
        if Slab.Button("+ Create New Chart", { W = 160, H = 30, Tooltip = "Create a new rhythm chart" }) then
            Logic.newForm.title = "New Song"
            Logic.newForm.initialDifficulty = "normal"
            Logic.showNewModal = true
        end

        Slab.SameLine({ Pad = 10 })
        if Slab.Button("Refresh Library", { W = 120, H = 30 }) then
            Logic.loadRecentCharts()
        end

        Slab.NewLine()
        Slab.Separator()

        -- Daftar Chart yang tersimpan
        local charts = Logic.getFilteredCharts()

        if #charts == 0 then
            Slab.NewLine()
            if Logic.searchQuery ~= "" then
                Slab.Text("No charts found matching: \"" .. Logic.searchQuery .. "\"", { Color = { 0.50, 0.50, 0.50, 1.0 } })
            else
                Slab.Text("No saved charts detected. Click [+ Create New Chart] to begin.", { Color = { 0.45, 0.45, 0.45, 1.0 } })
            end
        else
            Slab.Text(string.format("AVAILABLE CHARTS (%d) - Select a chart to choose difficulty:", #charts), { Color = { 0.55, 0.55, 0.55, 1.0 } })
            Slab.NewLine()

            for _, c in ipairs(charts) do
                local isSelected = (Logic.selectedChart and Logic.selectedChart.path == c.path)

                -- Main Chart Card Header
                local selectIcon = isSelected and "[-] " or "[+] "
                local itemLabel = string.format("%s %-24s   |   BPM %-5s   |   Charter: %-14s   |   Total Notes: %d",
                    selectIcon, c.title, c.bpm, c.charter, c.totalNotes or 0)

                local cardBtnId = 'ChartCard_' .. c.folder
                if Slab.Button(itemLabel, { W = math.max(600, winW - 40), H = 34, Active = isSelected }) then
                    if isSelected then
                        Logic.selectedChart = nil
                    else
                        Logic.selectedChart = c
                    end
                end

                -- Difficulty selector HANYA muncul jika chart ini sedang di-select
                if isSelected then
                    local diffs = c.difficulties or {}
                    Slab.NewLine()

                    for _, d in ipairs(diffs) do
                        Slab.Text("    > ")
                        Slab.SameLine({ Pad = 4 })

                        -- Difficulty Button untuk masuk ke editor
                        local noteCount = (d.hasContent and d.noteCount) or 0
                        local btnLabel = string.format(" %-7s  |  Rating: %02d*  |  [%d notes] ", d.name, d.stars, noteCount)
                        
                        local diffBtnId = 'DiffBtn_' .. c.folder .. '_' .. d.difficulty
                        if Slab.Button(btnLabel, { W = 320, H = 28 }) then
                            local chartLaunchInfo = {
                                path = c.path,
                                folder = c.folder,
                                title = c.title,
                                charter = d.charter or c.charter,
                                bpm = c.bpm,
                                offset = c.offset,
                                difficulty = d.difficulty
                            }
                            _G.Gamestate.switch(require("node.editor"), chartLaunchInfo)
                        end

                        -- Editable Star Rating for this difficulty
                        Slab.SameLine({ Pad = 14 })
                        Slab.Text("Rating:", { Color = { 0.6, 0.6, 0.6, 1 } })
                        Slab.SameLine({ Pad = 6 })

                        local sliderKey = 'StarSlider_' .. c.folder .. '_' .. d.difficulty
                        if Slab.InputNumberSlider(sliderKey, d.stars, 1, 15) then
                            local newRating = math.floor(Slab.GetInputNumber())
                            d.stars = newRating
                            -- Simpan perubahan rating langsung ke Metadata.json
                            local metaPath = c.path .. "/Metadata.json"
                            local metaContent = love.filesystem.read(metaPath)
                            if metaContent then
                                local ok, M = pcall(json.decode, metaContent)
                                if ok and M then
                                    M.difficulties = M.difficulties or {}
                                    M.difficulties[d.difficulty] = M.difficulties[d.difficulty] or {}
                                    M.difficulties[d.difficulty].rating = newRating
                                    love.filesystem.write(metaPath, json.encode(M))
                                end
                            end
                        end

                        Slab.NewLine()
                    end
                    Slab.Separator()
                end

                Slab.NewLine()
            end
        end

        Slab.EndWindow()
    end
end

function Draw.drawNewModal()
    if not Logic.showNewModal then return end

    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local modalW = 420
    local modalH = 220

    if Slab.BeginWindow('NewChartModalWindow', {
        Title = "Create New Chart Project",
        X = (winW - modalW) / 2,
        Y = (winH - modalH) / 2,
        W = modalW,
        H = modalH,
        AllowResize = false,
        AllowMove = true,
        NoSavedSettings = true,
        Border = 1,
        BgColor = { 0.09, 0.09, 0.09, 0.98 }
    }) then
        Slab.Text("Song / Chart Title:", { Color = { 0.75, 0.75, 0.75, 1.0 } })
        if Slab.Input('NewTitleInput', { Text = Logic.newForm.title, W = 385 }) then
            Logic.newForm.title = Slab.GetInputText()
        end

        Slab.NewLine()
        Slab.Text("Initial Difficulty to Edit:", { Color = { 0.75, 0.75, 0.75, 1.0 } })
        local diffOptions = { "easy", "normal", "hard", "expert", "master" }
        for _, dName in ipairs(diffOptions) do
            local isSelected = (Logic.newForm.initialDifficulty == dName)
            if Slab.Button(dName:upper(), { W = 70, H = 24, Active = isSelected }) then
                Logic.newForm.initialDifficulty = dName
            end
            Slab.SameLine({ Pad = 6 })
        end

        Slab.NewLine()
        Slab.Separator()
        Slab.NewLine()

        if Slab.Button("Create Project", { W = 120, H = 28 }) then
            local createdPath, initDiff = Logic.createNewChart()
            local newChartInfo = {
                path = createdPath,
                title = Logic.newForm.title,
                charter = "Anonymous",
                bpm = "120",
                offset = "0.0",
                difficulty = initDiff
            }
            _G.Gamestate.switch(require("node.editor"), newChartInfo)
        end

        Slab.SameLine({ Pad = 10 })
        if Slab.Button("Cancel", { W = 80, H = 28 }) then
            Logic.showNewModal = false
        end

        Slab.EndWindow()
    end
end

function Draw.drawLoadModal()
    if not Logic.showLoadModal then return end

    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local modalW = 480
    local modalH = 320

    if Slab.BeginWindow('LoadChartModalWindow', {
        Title = "Open Chart Directory",
        X = (winW - modalW) / 2,
        Y = (winH - modalH) / 2,
        W = modalW,
        H = modalH,
        AllowResize = false,
        AllowMove = true,
        NoSavedSettings = true,
        Border = 1,
        BgColor = { 0.09, 0.09, 0.09, 0.98 }
    }) then
        Slab.Text("Chart Folders:", { Color = { 0.75, 0.75, 0.75, 1.0 } })
        Slab.Separator()

        local charts = Logic.recentCharts
        if #charts == 0 then
            Slab.Text("No charts found in 'charts/' or 'assets/official_chart/'.", { Color = { 0.45, 0.45, 0.45, 1.0 } })
        else
            for _, c in ipairs(charts) do
                if Slab.Button(string.format("[DIR] %s  (%s)", c.folder, c.title), { W = 445, H = 28 }) then
                    Logic.selectedChart = c
                    Logic.showLoadModal = false
                end
                Slab.NewLine()
            end
        end

        Slab.NewLine()
        Slab.Separator()
        if Slab.Button("Close", { W = 75, H = 24 }) then
            Logic.showLoadModal = false
        end

        Slab.EndWindow()
    end
end

function Draw.all()
    Draw.drawTopNav()
    Draw.drawMainContent()
    Draw.drawNewModal()
    Draw.drawLoadModal()
end

return Draw
