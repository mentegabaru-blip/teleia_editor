-- tchart.lua
-- Rhytmia / Teleia Chart Parser & Serializer Library
-- Menangani parsing, decoding, encoding, validasi, dan konversi format chart multi-difficulty.

local tchart = {}

tchart.DIFFICULTIES = { "easy", "normal", "hard", "expert", "master" }
tchart.DIFF_STARS = {
    easy = 1,
    normal = 3,
    hard = 6,
    expert = 9,
    master = 12
}

-- Menghitung konversi time (detik) ke beat
function tchart.timeToBeat(time, bpm, offset)
    time = tonumber(time) or 0
    bpm = math.max(1, tonumber(bpm) or 120)
    offset = tonumber(offset) or 0.0
    return (time - offset) * (bpm / 60)
end

-- Menghitung konversi beat ke time (detik)
function tchart.beatToTime(beat, bpm, offset)
    beat = tonumber(beat) or 0
    bpm = math.max(1, tonumber(bpm) or 120)
    offset = tonumber(offset) or 0.0
    return (beat * (60 / bpm)) + offset
end

-- Normalisasi dan validasi data satu Note
function tchart.normalizeNote(rawNote, bpm, offset)
    local note = {
        type = rawNote.type or "basic",
        angle = tonumber(rawNote.angle) or 0
    }

    if rawNote.beat ~= nil then
        note.beat = tonumber(rawNote.beat) or 0
        note.time = tchart.beatToTime(note.beat, bpm, offset)
    elseif rawNote.time ~= nil then
        note.time = tonumber(rawNote.time) or 0
        note.beat = tchart.timeToBeat(note.time, bpm, offset)
    else
        note.beat = 0
        note.time = tchart.beatToTime(0, bpm, offset)
    end

    if rawNote.hold ~= nil then
        note.hold = rawNote.hold
    end

    if rawNote.gimmick ~= nil and type(rawNote.gimmick) == "table" then
        note.gimmick = rawNote.gimmick
    end

    return note
end

-- Normalisasi dan validasi data satu Effect
function tchart.normalizeEffect(rawEff, bpm, offset)
    local eff = {
        id = rawEff.id or string.format("eff_%d", math.random(100000, 999999)),
        lane = rawEff.lane or "shake",
        type = rawEff.type or "shake",
        params = rawEff.params or {}
    }

    if rawEff.beat ~= nil then
        eff.beat = tonumber(rawEff.beat) or 0
        eff.time = tchart.beatToTime(eff.beat, bpm, offset)
    elseif rawEff.time ~= nil then
        eff.time = tonumber(rawEff.time) or 0
        eff.beat = tchart.timeToBeat(eff.time, bpm, offset)
    else
        eff.beat = 0
        eff.time = tchart.beatToTime(0, bpm, offset)
    end

    return eff
end

-- Cari path file chart untuk difficulty tertentu
function tchart.getChartFilePath(folderPath, diff)
    diff = diff and diff:lower() or "normal"
    if not love.filesystem.getInfo(folderPath) then return nil end

    local diffFiles = {
        folderPath .. "/Chart_" .. diff .. ".json",
        folderPath .. "/chart_" .. diff .. ".json",
        folderPath .. "/" .. diff .. ".json",
        folderPath .. "/Chart.json",
        folderPath .. "/chart.json"
    }

    for _, p in ipairs(diffFiles) do
        if love.filesystem.getInfo(p) then
            return p
        end
    end
    return folderPath .. "/Chart_" .. diff .. ".json"
end

-- Ambil statistik / note count per difficulty untuk suatu chart folder
function tchart.getDifficultySummaries(folderPath)
    local summaries = {}
    local metaPath = folderPath .. "/Metadata.json"
    local metaContent = love.filesystem.read(metaPath)
    local metadata = {}
    if metaContent then
        local ok, M = pcall(json.decode, metaContent)
        if ok and M then metadata = M end
    end

    local metaDiffs = metadata.difficulties or {}

    for _, diff in ipairs(tchart.DIFFICULTIES) do
        local dMeta = metaDiffs[diff] or {}
        local starRating = tonumber(dMeta.rating or dMeta.stars or dMeta.level or tchart.DIFF_STARS[diff] or 1)
        local charter = dMeta.charter or (metadata.charter and metadata.charter.text) or "Anonymous"
        
        -- Cek isi chart json untuk difficulty ini
        local cObj = tchart.loadDifficulty(folderPath, diff)
        local count = (cObj and cObj.notes) and #cObj.notes or 0
        local effCount = (cObj and cObj.effects) and #cObj.effects or 0
        local hasContent = (count > 0 or effCount > 0)

        table.insert(summaries, {
            difficulty = diff,
            name = diff:upper(),
            stars = starRating,
            charter = charter,
            noteCount = count,
            effectCount = effCount,
            hasContent = hasContent
        })
    end

    return summaries, metadata
end

-- Membaca data chart spesifik satu difficulty
function tchart.loadDifficulty(folderPath, diff)
    diff = diff and diff:lower() or "normal"
    if not love.filesystem.getInfo(folderPath) then
        return nil, "Directory not found: " .. tostring(folderPath)
    end

    local metaPath = folderPath .. "/Metadata.json"
    local metaContent = love.filesystem.read(metaPath)
    local metadata = {}
    if metaContent then
        local ok, M = pcall(json.decode, metaContent)
        if ok and M then metadata = M end
    end

    local bpm = tonumber(metadata.bpm and metadata.bpm.text or metadata.bpm) or 120
    local offset = tonumber(metadata.offset and metadata.offset.text or metadata.offset) or 0.0

    -- Cari file chart spesifik
    local targetChartPath = nil
    local candidates = {
        folderPath .. "/Chart_" .. diff .. ".json",
        folderPath .. "/chart_" .. diff .. ".json",
        folderPath .. "/" .. diff .. ".json"
    }
    for _, p in ipairs(candidates) do
        if love.filesystem.getInfo(p) then
            targetChartPath = p
            break
        end
    end

    -- Fallback ke Chart.json lama jika ada
    if not targetChartPath then
        if love.filesystem.getInfo(folderPath .. "/Chart.json") then
            targetChartPath = folderPath .. "/Chart.json"
        elseif love.filesystem.getInfo(folderPath .. "/chart.json") then
            targetChartPath = folderPath .. "/chart.json"
        end
    end

    local notes = {}
    local effects = {}

    if targetChartPath and love.filesystem.getInfo(targetChartPath) then
        local chartContent = love.filesystem.read(targetChartPath)
        if chartContent then
            local ok, C = pcall(json.decode, chartContent)
            if ok and C then
                if type(C.notes) == "table" then
                    for _, rawNote in ipairs(C.notes) do
                        table.insert(notes, tchart.normalizeNote(rawNote, bpm, offset))
                    end
                end
                if type(C.effects) == "table" then
                    for _, rawEff in ipairs(C.effects) do
                        table.insert(effects, tchart.normalizeEffect(rawEff, bpm, offset))
                    end
                end
            end
        end
    end

    table.sort(notes, function(a, b) return (a.time or 0) < (b.time or 0) end)
    table.sort(effects, function(a, b) return (a.time or 0) < (b.time or 0) end)

    return {
        path = folderPath,
        difficulty = diff,
        bpm = bpm,
        offset = offset,
        metadata = metadata,
        notes = notes,
        effects = effects
    }
end

-- Backward compatibility load (default ke difficulty yang dipilih atau "normal")
function tchart.load(folderPath, diff)
    return tchart.loadDifficulty(folderPath, diff or "normal")
end

-- Menyimpan chart spesifik satu difficulty
function tchart.saveDifficulty(folderPath, chartData, diff)
    if not folderPath then return false, "No folder path provided" end
    diff = (diff or chartData.difficulty or "normal"):lower()
    love.filesystem.createDirectory(folderPath)

    local notes = chartData.notes or {}
    local effects = chartData.effects or {}
    local metadata = chartData.metadata or {}
    local bpm = chartData.bpm or 120
    local offset = chartData.offset or 0.0

    table.sort(notes, function(a, b) return (a.time or 0) < (b.time or 0) end)
    table.sort(effects, function(a, b) return (a.time or 0) < (b.time or 0) end)

    metadata.bpm = { text = tostring(bpm) }
    metadata.offset = { text = tostring(offset) }
    metadata.difficulties = metadata.difficulties or {}

    -- Update metadata rating/charter untuk difficulty ini
    if not metadata.difficulties[diff] then
        metadata.difficulties[diff] = {
            rating = tchart.DIFF_STARS[diff] or 1,
            charter = (metadata.charter and metadata.charter.text) or "Anonymous"
        }
    end

    local chartJson = {
        difficulty = diff,
        notes = notes,
        effects = effects
    }

    local metaPath = folderPath .. "/Metadata.json"
    local chartPath = folderPath .. "/Chart_" .. diff .. ".json"

    local okMeta = love.filesystem.write(metaPath, json.encode(metadata))
    local okChart = love.filesystem.write(chartPath, json.encode(chartJson))

    -- Update legacy Chart.json jika difficulty adalah normal (agar tetap kompatibel)
    if diff == "normal" then
        love.filesystem.write(folderPath .. "/Chart.json", json.encode(chartJson))
    end

    return (okMeta and okChart), "Saved successfully"
end

function tchart.save(folderPath, chartData)
    return tchart.saveDifficulty(folderPath, chartData, chartData.difficulty or "normal")
end

return tchart
