local Logic = {
    -- Page State: "editor" (Circle Note Editor) or "effects" (Timeline Effects Editor)
    currentPage = "editor",

    -- Chart Data
    chartData = nil,
    metadata = nil,
    chartPath = nil,
    notes = {},
    chartEffects = {}, -- Array of effect objects: { id, type, lane, beat, time, duration, params }

    -- Camera & Visual FX Instance
    camera = nil,

    -- Audio & Playback
    audioSource = nil,
    audioPath = nil,
    isPlaying = false,
    currentTime = 0,
    currentBeat = 0,
    duration = 180,
    playbackRate = 1.0,
    volume = 0.8,

    -- Endless Step Ring System (Editor Page)
    bpm = 120,
    offset = 0.0,
    beatSnap = 4,               -- 1/4 beat
    angleSteps = 16,            -- 16 angle divisions (clamp)
    centerRadius = 0,           -- Target receptor tepat di pusat layar (screenX/2, screenY/2)
    stepSpacing = 68,           -- Jarak antar ring per 1 beat (dapat di-zoom)
    stepZoom = 1.0,
    selectedNoteType = "basic", -- "basic", "slideup", "slidedown"

    -- Lane Note Timeline Configuration (Lane Editor Page)
    laneSpacing = 120, -- Spacing per beat in Lane Note Editor
    laneZoom = 1.0,
    laneHitLineX = 230,
    laneYStart = 60,
    laneHeight = 32,
    selectedNoteIndices = {}, -- Set of selected note indices: { [i] = true }
    clipboardNotes = {},      -- Notes copied for copy-paste
    laneBoxSelect = { active = false, startX = 0, startY = 0, curX = 0, curY = 0 },
    ghostLaneNotePos = { beat = 0, laneIndex = 1, angle = 0, x = 0, y = 0, valid = false },
    laneScrollY = 0,

    -- Effects Timeline Configuration (Effects Page)
    effectLanes = {
        { id = "shake",    name = "Shake FX",        color = { 0.85, 0.85, 0.85, 1.0 }, icon = "[S]", defaultType = "shake" },
        { id = "zoom",     name = "Zoom FX",         color = { 0.75, 0.75, 0.75, 1.0 }, icon = "[Z]", defaultType = "pulse" },
        { id = "flash",    name = "Flash FX",        color = { 1.00, 1.00, 1.00, 1.0 }, icon = "[F]", defaultType = "flash_in_out" },
        { id = "pendulum", name = "Pendulum / Wave", color = { 0.70, 0.70, 0.70, 1.0 }, icon = "[P]", defaultType = "pendulum" },
        { id = "rotate",   name = "Target Rotate FX", color = { 0.80, 0.80, 0.80, 1.0 }, icon = "[R]", defaultType = "rotate_to" },
    },
    effectsSpacing = 110, -- Spacing per beat di timeline horizontal
    effectsZoom = 1.0,
    selectedEffectIndex = nil,
    hoveredEffectIndex = nil,
    hoveredEffectLane = 1,
    ghostEffectPos = { beat = 0, lane = 1, x = 0, y = 0, valid = false },
    showEffectInspector = false,

    -- Effects Dragging & Timeline Interactions
    effectDrag = {
        active = false,
        dragType = nil, -- "move", "resize_duration", "resize_repeat", "resize_step"
        effectIndex = nil,
        startBeat = 0,
        startMouseX = 0,
        startDuration = 0,
        startRepeatUntilBeat = 0,
        startRepeatStep = 1.0,
        initialLane = nil,
        hasChanged = false
    },
    hoveredEffectElement = nil,

    -- Selection & Cursor
    selectedNoteIndex = nil,
    showNoteGimmickModal = false,
    selectedNoteGimmickTab = "builtin", -- "builtin" or "manual"
    hoveredNoteIndex = nil,
    ghostPos = { x = 0, y = 0, angle = 0, radius = 38, beat = 0, valid = false },

    -- Undo / Redo
    undoStack = {},
    redoStack = {},

    -- Sidebar Active Tab & Minimized state
    activeTab = "editor",
    sidebarMinimized = false,

    -- Settings & Display
    effects = {
        hitsound = true,
        metronome = false,
        showAngleGuides = true,
        showBeatNumbers = true
    },
    settings = {
        hitsound = true,
        metronome = false,
        showAngleGuides = true,
        showBeatNumbers = true
    },

    statusMessage = "Ready",

    -- Standard Flux / Tween Easing Functions & Templates
    easings = {
        linear = function(t) return t end,
        quadin = function(t) return t * t end,
        quadout = function(t) return -t * (t - 2) end,
        quadinout = function(t)
            t = t * 2
            if t < 1 then return 0.5 * t * t end
            t = t - 1
            return -0.5 * (t * (t - 2) - 1)
        end,
        cubicin = function(t) return t * t * t end,
        cubicout = function(t)
            t = t - 1
            return t * t * t + 1
        end,
        cubicinout = function(t)
            t = t * 2
            if t < 1 then return 0.5 * t * t * t end
            t = t - 2
            return 0.5 * (t * t * t + 2)
        end,
        quartin = function(t) return t * t * t * t end,
        quartout = function(t)
            t = t - 1
            return -(t * t * t * t - 1)
        end,
        quartinout = function(t)
            t = t * 2
            if t < 1 then return 0.5 * t * t * t * t end
            t = t - 2
            return -0.5 * (t * t * t * t - 2)
        end,
        sinein = function(t) return -math.cos(t * (math.pi / 2)) + 1 end,
        sineout = function(t) return math.sin(t * (math.pi / 2)) end,
        sineinout = function(t) return -0.5 * (math.cos(math.pi * t) - 1) end,
        expoin = function(t) return (t == 0) and 0 or (2 ^ (10 * (t - 1))) end,
        expoout = function(t) return (t == 1) and 1 or (- (2 ^ (-10 * t)) + 1) end,
        expoinout = function(t)
            if t == 0 then return 0 end
            if t == 1 then return 1 end
            t = t * 2
            if t < 1 then return 0.5 * (2 ^ (10 * (t - 1))) end
            t = t - 1
            return 0.5 * (- (2 ^ (-10 * t)) + 2)
        end,
        backin = function(t)
            local s = 1.70158
            return t * t * ((s + 1) * t - s)
        end,
        backout = function(t)
            local s = 1.70158
            t = t - 1
            return t * t * ((s + 1) * t + s) + 1
        end,
        backinout = function(t)
            local s = 1.70158 * 1.525
            t = t * 2
            if t < 1 then return 0.5 * (t * t * ((s + 1) * t - s)) end
            t = t - 2
            return 0.5 * (t * t * ((s + 1) * t + s) + 2)
        end,
        elasticout = function(t)
            if t == 0 then return 0 end
            if t == 1 then return 1 end
            local p = 0.3
            local s = p / 4
            return (2 ^ (-10 * t)) * math.sin((t - s) * (2 * math.pi) / p) + 1
        end,
        bounceout = function(t)
            if t < (1 / 2.75) then
                return 7.5625 * t * t
            elseif t < (2 / 2.75) then
                t = t - (1.5 / 2.75)
                return 7.5625 * t * t + 0.75
            elseif t < (2.5 / 2.75) then
                t = t - (2.25 / 2.75)
                return 7.5625 * t * t + 0.9375
            else
                t = t - (2.625 / 2.75)
                return 7.5625 * t * t + 0.984375
            end
        end
    },

    easingList = {
        { id = "linear",     name = "Linear (Uniform)" },
        { id = "quadin",     name = "Quad In" },
        { id = "quadout",    name = "Quad Out" },
        { id = "quadinout",  name = "Quad In-Out" },
        { id = "cubicin",    name = "Cubic In" },
        { id = "cubicout",   name = "Cubic Out" },
        { id = "cubicinout", name = "Cubic In-Out" },
        { id = "sinein",     name = "Sine In" },
        { id = "sineout",    name = "Sine Out" },
        { id = "sineinout",  name = "Sine In-Out" },
        { id = "expoin",     name = "Expo In" },
        { id = "expoout",    name = "Expo Out" },
        { id = "expoinout",  name = "Expo In-Out" },
        { id = "backin",     name = "Back In (Overshoot)" },
        { id = "backout",    name = "Back Out (Overshoot)" },
        { id = "backinout",  name = "Back In-Out" },
        { id = "elasticout", name = "Elastic Out" },
        { id = "bounceout",  name = "Bounce Out" },
    }
}

function Logic.initCamera(w, h)
    local winW = w or love.graphics.getWidth()
    local winH = h or love.graphics.getHeight()
    Logic.camera = teffect(winW / 2, winH / 2, winW, winH)
end

function Logic.timeToBeat(time)
    time = tonumber(time) or 0
    local bpm = math.max(1, tonumber(Logic.bpm) or 120)
    local offset = tonumber(Logic.offset) or 0.0
    return (time - offset) * (bpm / 60)
end

function Logic.beatToTime(beat)
    beat = tonumber(beat) or 0
    local bpm = math.max(1, tonumber(Logic.bpm) or 120)
    local offset = tonumber(Logic.offset) or 0.0
    return (beat * (60 / bpm)) + offset
end

function Logic.recalculateNoteTimes()
    for _, note in ipairs(Logic.notes) do
        if note.beat ~= nil then
            note.time = Logic.beatToTime(note.beat)
        elseif note.time ~= nil then
            note.beat = Logic.timeToBeat(note.time)
        end
    end
    for _, eff in ipairs(Logic.chartEffects) do
        if eff.beat ~= nil then
            eff.time = Logic.beatToTime(eff.beat)
        elseif eff.time ~= nil then
            eff.beat = Logic.timeToBeat(eff.time)
        end
    end
    Logic.currentBeat = Logic.timeToBeat(Logic.currentTime)
end

function Logic.loadChart(chartInfo)
    Logic.chartPath = chartInfo.path or ("charts/" .. (chartInfo.folder or "default"))
    Logic.currentDifficulty = (chartInfo.difficulty or "normal"):lower()
    Logic.notes = {}
    Logic.chartEffects = {}
    Logic.undoStack = {}
    Logic.redoStack = {}
    Logic.selectedNoteIndex = nil
    Logic.selectedNoteIndices = {}
    Logic.showNoteGimmickModal = false
    Logic.selectedEffectIndex = nil
    Logic.currentTime = 0
    Logic.currentBeat = 0
    Logic.isPlaying = false

    Logic.initCamera()

    local loaded, err = tchart.loadDifficulty(Logic.chartPath, Logic.currentDifficulty)
    if loaded then
        Logic.metadata = loaded.metadata or {}
        Logic.bpm = loaded.bpm
        Logic.offset = loaded.offset
        Logic.notes = loaded.notes or {}
        Logic.chartEffects = loaded.effects or {}
    else
        Logic.metadata = {
            name = { text = chartInfo.title or "Untitled" },
            charter = { text = chartInfo.charter or "Unknown" },
            music = { title = { text = chartInfo.title or "Untitled" }, by = { text = "Artist" } },
            bpm = { text = "120" },
            offset = { text = "0.0" }
        }
        Logic.bpm = 120
        Logic.offset = 0.0
        Logic.notes = {}
        Logic.chartEffects = {}
    end

    if Logic.audioSource then
        Logic.audioSource:stop()
        Logic.audioSource = nil
        Logic.audioPath = nil
        Logic.audioWarning = nil
        Logic.availableAudioFiles = {}
    end

    local foundAudio = {}
    if love.filesystem.getInfo(Logic.chartPath) then
        for _, file in ipairs(love.filesystem.getDirectoryItems(Logic.chartPath)) do
            if file:match("%.ogg$") or file:match("%.mp3$") or file:match("%.wav$") then
                table.insert(foundAudio, file)
            end
        end
    end
    Logic.availableAudioFiles = foundAudio

    if #foundAudio > 0 then
        local activeFile = foundAudio[1]
        local audioFullPath = Logic.chartPath .. "/" .. activeFile
        local ok, src = pcall(love.audio.newSource, audioFullPath, "stream")
        if ok and src then
            Logic.audioSource = src
            Logic.audioPath = audioFullPath
            Logic.duration = src:getDuration()
        end

        if #foundAudio > 1 then
            Logic.audioWarning = string.format(
            "[Warning] Detected %d audio files! Using '%s'. Remove other audio files from chart folder to avoid conflicts.",
                #foundAudio, activeFile)
            Logic.statusMessage = string.format("Audio loaded: %s (1 of %d files)", activeFile, #foundAudio)
        else
            Logic.audioWarning = nil
            Logic.statusMessage = "Audio loaded: " .. activeFile
        end
    else
        Logic.audioWarning = nil
        Logic.statusMessage = "Chart loaded: " .. (Logic.metadata.name and Logic.metadata.name.text or "Song")
    end

    -- Pastikan playback dan cursor waktu benar-benar direset ke 0 detik & beat yang sesuai
    Logic.isPlaying = false
    Logic.seekTime(0)
end

function Logic.reloadAudio()
    if Logic.audioSource then
        Logic.audioSource:stop()
        Logic.audioSource = nil
        Logic.audioPath = nil
        Logic.duration = 180
        Logic.audioWarning = nil
        Logic.availableAudioFiles = {}
    end

    local foundAudio = {}
    if Logic.chartPath and love.filesystem.getInfo(Logic.chartPath) then
        for _, file in ipairs(love.filesystem.getDirectoryItems(Logic.chartPath)) do
            if file:match("%.ogg$") or file:match("%.mp3$") or file:match("%.wav$") then
                table.insert(foundAudio, file)
            end
        end
    end
    Logic.availableAudioFiles = foundAudio

    if #foundAudio > 0 then
        local activeFile = foundAudio[1]
        local audioFullPath = Logic.chartPath .. "/" .. activeFile
        local ok, src = pcall(love.audio.newSource, audioFullPath, "stream")
        if ok and src then
            Logic.audioSource = src
            Logic.audioPath = audioFullPath
            Logic.duration = src:getDuration()

            if #foundAudio > 1 then
                Logic.audioWarning = string.format(
                "[Warning] Detected %d audio files! Using '%s'. Remove other audio files from chart folder to avoid conflicts.",
                    #foundAudio, activeFile)
                Logic.statusMessage = string.format("Audio loaded: %s (1 of %d files)", activeFile, #foundAudio)
            else
                Logic.audioWarning = nil
                Logic.statusMessage = "Audio loaded: " .. activeFile
            end

            Logic.isPlaying = false
            Logic.seekTime(0)
            return true
        end
    end

    Logic.audioWarning = nil
    Logic.statusMessage = "No audio file (.ogg/.mp3/.wav) found"
    Logic.isPlaying = false
    Logic.seekTime(0)
    return false
end

function Logic.openChartFolder()
    if not Logic.chartPath then return end
    local saveDir = love.filesystem.getSaveDirectory()
    love.system.openURL("file://" .. saveDir .. "/" .. Logic.chartPath)
end

function Logic.saveChart()
    if not Logic.chartPath then return false end

    local chartData = {
        difficulty = Logic.currentDifficulty or "normal",
        bpm = Logic.bpm,
        offset = Logic.offset,
        metadata = Logic.metadata,
        notes = Logic.notes,
        effects = Logic.chartEffects
    }

    local ok, msg = tchart.saveDifficulty(Logic.chartPath, chartData, Logic.currentDifficulty or "normal")
    if ok then
        Logic.statusMessage = string.format("Chart saved! [%s] (%d notes, %d effects)",
            (Logic.currentDifficulty or "normal"):upper(), #Logic.notes, #Logic.chartEffects)
        return true
    else
        Logic.statusMessage = "Save failed: " .. tostring(msg)
        return false
    end
end

local function deepCopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = (type(v) == "table") and deepCopyTable(v) or v
    end
    return copy
end

function Logic.pushUndo()
    local stateSnapshot = {
        notes = deepCopyTable(Logic.notes),
        effects = deepCopyTable(Logic.chartEffects)
    }
    table.insert(Logic.undoStack, stateSnapshot)
    if #Logic.undoStack > 50 then table.remove(Logic.undoStack, 1) end
    Logic.redoStack = {}
end

function Logic.undo()
    if #Logic.undoStack == 0 then return end
    local currentState = {
        notes = deepCopyTable(Logic.notes),
        effects = deepCopyTable(Logic.chartEffects)
    }
    table.insert(Logic.redoStack, currentState)

    local prev = table.remove(Logic.undoStack)
    Logic.notes = prev.notes or {}
    Logic.chartEffects = prev.effects or {}
    Logic.selectedNoteIndex = nil
    Logic.selectedNoteIndices = {}
    Logic.showNoteGimmickModal = false
    Logic.selectedEffectIndex = nil
    Logic.statusMessage = "Undo"
end

function Logic.redo()
    if #Logic.redoStack == 0 then return end
    local currentState = {
        notes = deepCopyTable(Logic.notes),
        effects = deepCopyTable(Logic.chartEffects)
    }
    table.insert(Logic.undoStack, currentState)

    local nxt = table.remove(Logic.redoStack)
    Logic.notes = nxt.notes or {}
    Logic.chartEffects = nxt.effects or {}
    Logic.selectedNoteIndex = nil
    Logic.selectedNoteIndices = {}
    Logic.showNoteGimmickModal = false
    Logic.selectedEffectIndex = nil
    Logic.statusMessage = "Redo"
end

function Logic.getMinTime()
    local offsetVal = tonumber(Logic.offset) or 0.0
    return math.min(-2.0, offsetVal - 2.0)
end

function Logic.getMinBeat()
    return Logic.timeToBeat(Logic.getMinTime())
end

function Logic.togglePlay()
    Logic.isPlaying = not Logic.isPlaying
    if Logic.audioSource then
        if Logic.isPlaying then
            if Logic.currentTime >= 0 then
                Logic.audioSource:seek(math.min(Logic.currentTime, math.max(0, Logic.duration - 0.001)))
                Logic.audioSource:setPitch(Logic.playbackRate)
                Logic.audioSource:setVolume(Logic.volume)
                Logic.audioSource:play()
            else
                Logic.audioSource:seek(0)
                Logic.audioSource:pause()
            end
        else
            Logic.audioSource:pause()
            Logic.evaluateContinuousFX(0, false)
            if Logic.camera then
                Logic.camera:update(0)
            end
        end
    else
        if not Logic.isPlaying then
            Logic.evaluateContinuousFX(0, false)
            if Logic.camera then
                Logic.camera:update(0)
            end
        end
    end
end

function Logic.evaluateContinuousFX(dt, isPlaying)
    if not Logic.camera then return end

    -- Continuous visual effects (Rotate, Pendulum, Wave, Zoom) ONLY apply visually on the Radial editor page ("editor")
    if Logic.currentPage ~= "editor" then
        Logic.camera.pendulum_enabled = false
        Logic.camera.pendulum_angle_override = 0
        Logic.camera.wave_enabled = false
        Logic.camera.wave_offset_override = nil
        Logic.camera.rotation_override = 0
        Logic.camera.zoom_scale_override = nil
        Logic.camera.scale = Logic.camera.base_scale or 1.0
        Logic.camera.cur_scale = Logic.camera.base_scale or 1.0
        Logic.camera.target_scale = Logic.camera.base_scale or 1.0
        Logic.camera.horizontal_shakes = {}
        Logic.camera.vertical_shakes = {}
        Logic.camera.rotational_shakes = {}
        Logic.camera.trauma_value = 0
        Logic.camera.last_horizontal_shake_amount = 0
        Logic.camera.last_vertical_shake_amount = 0
        Logic.camera.flashing = false
        Logic.camera.flash_in_out = false
        return
    end

    if not isPlaying and not Logic.snippetTimer then
        Logic.camera.horizontal_shakes = {}
        Logic.camera.vertical_shakes = {}
        Logic.camera.rotational_shakes = {}
        Logic.camera.trauma_value = 0
        Logic.camera.last_horizontal_shake_amount = 0
        Logic.camera.last_vertical_shake_amount = 0
    end

    local curBeat = Logic.currentBeat
    local bpm = math.max(1, tonumber(Logic.bpm) or 120)

    local activePendulumEff = nil
    local activeWaveEff = nil
    local activeZoomEff = nil
    local activeRotateEff = nil

    for _, eff in ipairs(Logic.chartEffects) do
        local effBeat = eff.beat or Logic.timeToBeat(eff.time or 0)
        local p = eff.params or {}
        local durSec = p.duration or ((eff.lane == "zoom") and 0.25 or 0.8)
        local durBeats = durSec * (bpm / 60)
        local endBeat = effBeat + durBeats

        if p.repeatEnabled and p.repeatUntilBeat and p.repeatUntilBeat > effBeat then
            endBeat = p.repeatUntilBeat + durBeats
        end

        if curBeat >= effBeat and curBeat <= endBeat then
            if eff.lane == "pendulum" then
                if eff.type == "pendulum" or not eff.type then
                    activePendulumEff = eff
                elseif eff.type == "wave" then
                    activeWaveEff = eff
                end
            elseif eff.lane == "zoom" then
                activeZoomEff = eff
            elseif eff.lane == "rotate" then
                activeRotateEff = eff
            end
        end
    end

    -- 1. Pendulum Evaluation
    if activePendulumEff then
        local p = activePendulumEff.params or {}
        local effBeat = activePendulumEff.beat or Logic.timeToBeat(activePendulumEff.time or 0)
        local freq = p.frequency or 2.5
        local maxAngle = p.maxAngle or 0.08
        local durSec = p.duration or 0.8

        local elapsedBeats = curBeat - effBeat
        local cycleElapsedBeats = elapsedBeats
        if p.repeatEnabled and p.repeatStep and p.repeatStep > 0 then
            cycleElapsedBeats = elapsedBeats % p.repeatStep
        end

        local cycleElapsedTime = cycleElapsedBeats * (60 / bpm)
        local decay = 1.0
        if durSec > 0 and cycleElapsedTime <= durSec then
            decay = math.max(0, 1.0 - (cycleElapsedTime / durSec))
        elseif cycleElapsedTime > durSec then
            decay = 0
        end

        local angle = math.sin(cycleElapsedTime * freq * math.pi * 2) * maxAngle * decay
        Logic.camera.pendulum_enabled = true
        Logic.camera.pendulum_angle_override = angle
    else
        Logic.camera.pendulum_enabled = false
        Logic.camera.pendulum_angle_override = 0
    end

    -- 2. Wave Evaluation
    if activeWaveEff then
        local p = activeWaveEff.params or {}
        local effBeat = activeWaveEff.beat or Logic.timeToBeat(activeWaveEff.time or 0)
        local elapsedBeats = curBeat - effBeat
        local elapsedTime = elapsedBeats * (60 / bpm)
        local waveX = math.sin(elapsedTime * (p.freqX or 1.5) * math.pi * 2) * (p.ampX or 8)
        local waveY = math.cos(elapsedTime * (p.freqY or 2.0) * math.pi * 2) * (p.ampY or 6)
        Logic.camera.wave_enabled = true
        Logic.camera.wave_offset_override = { waveX, waveY }
    else
        Logic.camera.wave_enabled = false
        Logic.camera.wave_offset_override = nil
    end

    -- 3. Absolute Target Rotation Evaluation
    -- Finds the latest rotate event before/at curBeat and smoothly rotates previousRotation -> targetRotation over duration, staying at targetRotation afterwards.
    local currentRotation = 0 -- starts at 0 deg
    for _, eff in ipairs(Logic.chartEffects) do
        if eff.lane == "rotate" then
            local effBeat = eff.beat or Logic.timeToBeat(eff.time or 0)
            if curBeat >= effBeat then
                local p = eff.params or {}
                local targetDeg = p.targetAngle or 90
                local durSec = p.duration or 0.8
                local durBeats = durSec * (bpm / 60)
                local elapsedBeats = curBeat - effBeat

                local fromDeg = currentRotation
                local toDeg = targetDeg

                if durBeats > 0 and elapsedBeats < durBeats then
                    local rawProg = math.max(0, math.min(1, elapsedBeats / durBeats))
                    local easingName = p.easing or "linear"
                    local easeFunc = Logic.easings and Logic.easings[easingName] or Logic.easings.linear
                    local prog = easeFunc and easeFunc(rawProg) or rawProg
                    currentRotation = fromDeg + (toDeg - fromDeg) * prog
                else
                    currentRotation = toDeg
                end
            end
        end
    end

    Logic.camera.rotation_override = math.rad(currentRotation)

    -- 4. Zoom Evaluation
    if activeZoomEff then
        local p = activeZoomEff.params or {}
        local effBeat = activeZoomEff.beat or Logic.timeToBeat(activeZoomEff.time or 0)
        local durSec = p.duration or 0.25
        local durBeats = durSec * (bpm / 60)
        local elapsedBeats = curBeat - effBeat
        local cycleElapsedBeats = elapsedBeats
        if p.repeatEnabled and p.repeatStep and p.repeatStep > 0 then
            cycleElapsedBeats = elapsedBeats % p.repeatStep
        end
        local cycleElapsedTime = cycleElapsedBeats * (60 / bpm)

        local zoomScale = 1.0
        local effType = activeZoomEff.type or "pulse"

        if effType == "pulse" then
            if durSec > 0 and cycleElapsedTime >= 0 and cycleElapsedTime <= durSec then
                local prog = math.max(0, math.min(1, cycleElapsedTime / durSec))
                local offset = math.sin(prog * math.pi) * (p.amount or 0.15)
                zoomScale = 1.0 + offset
            end
        elseif effType == "bounce" then
            if durSec > 0 and cycleElapsedTime >= 0 and cycleElapsedTime <= durSec then
                local decay = math.max(0, (durSec - cycleElapsedTime) / durSec)
                local offset = math.sin(cycleElapsedTime * (p.frequency or 12) * math.pi * 2) * (p.amount or 0.15) *
                decay
                zoomScale = 1.0 + offset
            end
        elseif effType == "zoom_to" then
            if durSec > 0 and cycleElapsedBeats >= 0 and cycleElapsedBeats <= durBeats then
                local prog = math.max(0, math.min(1, cycleElapsedBeats / durBeats))
                zoomScale = 1.0 + ((p.targetScale or 1.25) - 1.0) * prog
            elseif cycleElapsedBeats > durBeats then
                zoomScale = p.targetScale or 1.25
            end
        end

        Logic.camera.zoom_scale_override = zoomScale
        Logic.camera.scale = zoomScale
        Logic.camera.cur_scale = zoomScale
    else
        Logic.camera.zoom_scale_override = nil
        if not isPlaying and not Logic.snippetTimer then
            Logic.camera.scale = Logic.camera.base_scale or 1.0
            Logic.camera.cur_scale = Logic.camera.base_scale or 1.0
            Logic.camera.target_scale = Logic.camera.base_scale or 1.0
            Logic.camera.zoom_pulse_timer = 0
            Logic.camera.zoom_bounces = {}
        end
    end
end

function Logic.getEffectHitInfo(eff, effIndex, hitLineX, spacing, laneYStart, laneH, mx, my)
    local effBeat = eff.beat or Logic.timeToBeat(eff.time or 0)
    local effX = hitLineX + (effBeat - Logic.currentBeat) * spacing
    local laneIndex = 1
    for lIdx, l in ipairs(Logic.effectLanes) do
        if l.id == eff.lane then
            laneIndex = lIdx
            break
        end
    end
    local effY = laneYStart + (laneIndex - 1) * laneH + (laneH / 2)

    local p = eff.params or {}
    local bpm = math.max(1, tonumber(Logic.bpm) or 120)
    local durSec = p.duration or ((eff.lane == "zoom") and 0.25 or 0.8)
    local durBeats = durSec * (bpm / 60)
    local isRepeat = (p.repeatEnabled and p.repeatUntilBeat and p.repeatUntilBeat > effBeat)
    local spanEndBeat = isRepeat and p.repeatUntilBeat or (effBeat + durBeats)
    local endX = hitLineX + (spanEndBeat - Logic.currentBeat) * spacing

    -- 1. End Resize Handle (Bisa ditarik: ubah duration jika single, ubah repeatUntilBeat jika repeat)
    if mx >= endX - 16 and mx <= endX + 20 and my >= effY - 22 and my <= effY + 22 then
        return {
            hitType = isRepeat and "handle_repeat" or "handle_duration",
            effectIndex = effIndex,
            eff = eff,
            effX = effX,
            effY = effY,
            endX = endX
        }
    end

    -- 2. Step Handle (if repeat enabled)
    if isRepeat and p.repeatStep and p.repeatStep > 0 then
        local step1X = hitLineX + ((effBeat + p.repeatStep) - Logic.currentBeat) * spacing
        if math.abs(step1X - endX) > 12 and mx >= step1X - 12 and mx <= step1X + 12 and my >= effY - 20 and my <= effY + 20 then
            return {
                hitType = "handle_step",
                effectIndex = effIndex,
                eff = eff,
                effX = effX,
                effY = effY,
                stepX = step1X
            }
        end
    end

    -- 3. Main Body Block [ ] (Digeser)
    local blockW = 34
    local blockH = 28
    if mx >= effX - blockW / 2 - 4 and mx <= effX + blockW / 2 + 4 and my >= effY - blockH / 2 - 4 and my <= effY + blockH / 2 + 4 then
        return {
            hitType = "body",
            effectIndex = effIndex,
            eff = eff,
            effX = effX,
            effY = effY
        }
    end

    -- 4. Span Bar body (between effX and endX)
    if endX > effX and mx >= effX and mx <= endX and my >= effY - 16 and my <= effY + 16 then
        return {
            hitType = "span_bar",
            effectIndex = effIndex,
            eff = eff,
            effX = effX,
            effY = effY
        }
    end

    return nil
end

function Logic.seekTime(newTime)
    local minTime = Logic.getMinTime()
    Logic.currentTime = math.max(minTime, math.min(newTime, Logic.duration))
    Logic.currentBeat = Logic.timeToBeat(Logic.currentTime)
    if Logic.audioSource then
        if Logic.currentTime >= 0 then
            Logic.audioSource:seek(math.min(Logic.currentTime, math.max(0, Logic.duration - 0.001)))
        else
            Logic.audioSource:seek(0)
            if Logic.audioSource:isPlaying() then
                Logic.audioSource:pause()
            end
        end
    end
    Logic.evaluateContinuousFX(0, Logic.isPlaying)
    if Logic.camera then
        Logic.camera:update(0)
    end
end

function Logic.seekBeat(newBeat)
    local minBeat = Logic.getMinBeat()
    newBeat = math.max(minBeat, newBeat)
    Logic.seekTime(Logic.beatToTime(newBeat))
end

function Logic.stepBeat(deltaSteps)
    local stepSize = 1 / Logic.beatSnap
    local targetBeat = Logic.currentBeat + deltaSteps * stepSize
    local snappedBeat = math.floor((targetBeat / stepSize) + 0.5) * stepSize
    Logic.seekBeat(snappedBeat)
end

function Logic.getNoteRenderPos(note, centerX, centerY, spacing, minR)
    local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
    local rawRadius = minR + (nBeat - Logic.currentBeat) * spacing
    local nRadius = rawRadius
    local nAngle = note.angle or 0
    local targetX = centerX + math.cos(nAngle) * nRadius
    local targetY = centerY + math.sin(nAngle) * nRadius
    local noteAlpha = 1.0
    local isVisible = true

    if note.gimmick ~= nil and note.gimmick.type ~= nil and note.gimmick.type ~= "none" then
        local g = note.gimmick
        local p = g.params or {}
        local m = g.manual or {}
        local distToBeats = (nBeat - Logic.currentBeat)

        if g.type == "speed" then
            local spd = p.speed or 1.0
            nRadius = minR + (distToBeats * spd) * spacing
            targetX = centerX + math.cos(nAngle) * nRadius
            targetY = centerY + math.sin(nAngle) * nRadius
        elseif g.type == "spiral_in" then
            local rots = p.rotations or 1.0
            nAngle = nAngle + (distToBeats * rots * (math.pi / 2))
            targetX = centerX + math.cos(nAngle) * nRadius
            targetY = centerY + math.sin(nAngle) * nRadius
        elseif g.type == "sudden_in" then
            local fadeRatio = p.fadeDistance or 0.5
            if distToBeats > (fadeRatio * 4.0) then
                isVisible = false
            else
                noteAlpha = math.min(1.0, 1.0 - (distToBeats / (fadeRatio * 4.0)) * 0.5)
            end
        elseif g.type == "hidden_out" then
            local fadeRatio = p.fadeDistance or 0.5
            if distToBeats < (fadeRatio * 3.0) then
                noteAlpha = math.max(0.0, distToBeats / (fadeRatio * 3.0))
            end
        elseif g.type == "accel_rush" then
            local factor = p.speedMultiplier or 2.0
            if distToBeats > 0 then
                nRadius = minR + (distToBeats ^ (1.0 / factor)) * spacing
                targetX = centerX + math.cos(nAngle) * nRadius
                targetY = centerY + math.sin(nAngle) * nRadius
            end
        elseif g.type == "decel_brake" then
            local factor = p.speedMultiplier or 2.0
            if distToBeats > 0 then
                nRadius = minR +
                ((distToBeats * factor) / (1 + (factor - 1) * math.max(0, 1.0 - distToBeats / 4.0))) * spacing
                targetX = centerX + math.cos(nAngle) * nRadius
                targetY = centerY + math.sin(nAngle) * nRadius
            end
        elseif g.type == "zigzag_wave" then
            local freq = p.waveFreq or 3.0
            local amp = p.waveAmp or 0.25
            nAngle = nAngle + math.sin(distToBeats * freq) * amp
            targetX = centerX + math.cos(nAngle) * nRadius
            targetY = centerY + math.sin(nAngle) * nRadius
        elseif g.type == "blink_strobe" then
            local rate = p.blinkRate or 4.0
            if math.sin(love.timer.getTime() * rate * math.pi * 2) < 0 then
                noteAlpha = 0.2
            end
        elseif g.type == "teleport" then
            if distToBeats > 1.5 then
                nRadius = minR + (distToBeats + 2.0) * spacing
                targetX = centerX + math.cos(nAngle) * nRadius
                targetY = centerY + math.sin(nAngle) * nRadius
            end
        elseif g.type == "manual" then
            local spd = m.speed or 1.0
            nRadius = minR + (distToBeats * spd) * spacing
            local angDeg = math.deg(nAngle) + (m.angleOffset or 0) * math.min(1.0, math.max(0, distToBeats / 4.0))
            nAngle = math.rad(angDeg)
            local curX = centerX + math.cos(nAngle) * nRadius
            local curY = centerY + math.sin(nAngle) * nRadius
            local progress = math.max(0, math.min(1.0, 1.0 - (distToBeats / 4.0)))
            targetX = curX + (m.targetOffsetX or 0) * progress
            targetY = curY + (m.targetOffsetY or 0) * progress
            local startA = m.startAlpha or 1.0
            local hitA = m.hitAlpha or 1.0
            noteAlpha = startA + (hitA - startA) * progress
        end
    end

    return targetX, targetY, nRadius, nAngle, noteAlpha, isVisible
end

-- Snap Calculation untuk Endless Concentric Beat Steps (Editor Page)
function Logic.calculateSnap(centerScreenX, centerScreenY, mouseX, mouseY)
    local dx = mouseX - centerScreenX
    local dy = mouseY - centerScreenY
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    if angle < 0 then angle = angle + math.pi * 2 end

    local snappedAngle = angle
    if Logic.angleSteps > 0 then
        local stepAngle = (math.pi * 2) / Logic.angleSteps
        local stepIndex = math.floor((angle / stepAngle) + 0.5)
        snappedAngle = stepIndex * stepAngle
    end

    local effectiveSpacing = Logic.stepSpacing * Logic.stepZoom
    local beatOffset = (dist - Logic.centerRadius) / effectiveSpacing
    local targetBeat = Logic.currentBeat + beatOffset

    local stepSize = 1 / Logic.beatSnap
    local minBeat = Logic.getMinBeat()
    local snappedBeat = math.max(minBeat, math.floor((targetBeat / stepSize) + 0.5) * stepSize)

    local snappedRadius = Logic.centerRadius + (snappedBeat - Logic.currentBeat) * effectiveSpacing

    local finalX = centerScreenX + math.cos(snappedAngle) * snappedRadius
    local finalY = centerScreenY + math.sin(snappedAngle) * snappedRadius

    return {
        x = finalX,
        y = finalY,
        angle = snappedAngle,
        radius = snappedRadius,
        beat = snappedBeat,
        dist = dist,
        valid = true
    }
end

-- Snap Calculation untuk Multi-Lane Horizontal Timeline (Effects Page: Right to Left)
function Logic.calculateEffectsSnap(hitLineX, mouseX, mouseY, laneYStart, laneHeight, totalLanes)
    local effectiveSpacing = Logic.effectsSpacing * Logic.effectsZoom
    local beatOffset = (mouseX - hitLineX) / effectiveSpacing
    local targetBeat = Logic.currentBeat + beatOffset

    local stepSize = 1 / Logic.beatSnap
    local minBeat = Logic.getMinBeat()
    local snappedBeat = math.max(minBeat, math.floor((targetBeat / stepSize) + 0.5) * stepSize)

    local snappedX = hitLineX + (snappedBeat - Logic.currentBeat) * effectiveSpacing

    local laneIndex = math.floor((mouseY - laneYStart) / laneHeight) + 1
    laneIndex = math.max(1, math.min(totalLanes or #Logic.effectLanes, laneIndex))
    local laneObj = Logic.effectLanes[laneIndex] or Logic.effectLanes[1]

    local laneY = laneYStart + (laneIndex - 1) * laneHeight + laneHeight * 0.5

    return {
        x = snappedX,
        y = laneY,
        laneIndex = laneIndex,
        laneId = laneObj.id,
        beat = snappedBeat,
        valid = true
    }
end

-- ==========================================
-- LANE NOTE EDITOR: ANGLE & LANE HELPERS
-- ==========================================

function Logic.angleToLane(angle, totalLanes)
    totalLanes = totalLanes or Logic.angleSteps or 16
    if totalLanes <= 0 then totalLanes = 16 end
    local step = (math.pi * 2) / totalLanes
    local normAngle = (angle or 0) % (math.pi * 2)
    if normAngle < 0 then normAngle = normAngle + math.pi * 2 end
    local laneIdx = math.floor((normAngle / step) + 0.5) % totalLanes + 1
    return laneIdx
end

function Logic.laneToAngle(laneIndex, totalLanes)
    totalLanes = totalLanes or Logic.angleSteps or 16
    if totalLanes <= 0 then totalLanes = 16 end
    local step = (math.pi * 2) / totalLanes
    return ((laneIndex - 1) % totalLanes) * step
end

-- Snap Calculation untuk Multi-Lane Note Timeline (Lane Editor Page)
function Logic.calculateLaneSnap(hitLineX, mouseX, mouseY, laneYStart, laneHeight, totalLanes)
    totalLanes = totalLanes or Logic.angleSteps or 16
    local effectiveSpacing = Logic.laneSpacing * Logic.laneZoom
    local beatOffset = (mouseX - hitLineX) / effectiveSpacing
    local targetBeat = Logic.currentBeat + beatOffset

    local stepSize = 1 / Logic.beatSnap
    local minBeat = Logic.getMinBeat()
    local snappedBeat = math.max(minBeat, math.floor((targetBeat / stepSize) + 0.5) * stepSize)

    local snappedX = hitLineX + (snappedBeat - Logic.currentBeat) * effectiveSpacing

    local laneIndex = math.floor((mouseY - laneYStart) / laneHeight) + 1
    laneIndex = math.max(1, math.min(totalLanes, laneIndex))

    local laneY = laneYStart + (laneIndex - 1) * laneHeight + laneHeight * 0.5
    local snappedAngle = Logic.laneToAngle(laneIndex, totalLanes)

    return {
        x = snappedX,
        y = laneY,
        laneIndex = laneIndex,
        angle = snappedAngle,
        beat = snappedBeat,
        valid = true
    }
end

function Logic.getLaneNoteHitInfo(hitLineX, spacing, laneYStart, laneHeight, totalLanes, mx, my)
    totalLanes = totalLanes or Logic.angleSteps or 16
    for i, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local nx = hitLineX + (nBeat - Logic.currentBeat) * spacing
        local laneIdx = Logic.angleToLane(note.angle or 0, totalLanes)
        local ny = laneYStart + (laneIdx - 1) * laneHeight + laneHeight * 0.5

        if math.abs(mx - nx) <= 16 and math.abs(my - ny) <= (laneHeight * 0.5 + 3) then
            return {
                noteIndex = i,
                note = note,
                x = nx,
                y = ny,
                laneIndex = laneIdx,
                beat = nBeat
            }
        end
    end
    return nil
end

-- ==========================================
-- EFFECT CREATION, TRIGGERING & INSPECTION
-- ==========================================

function Logic.createDefaultEffect(laneId, beat)
    local effTime = Logic.beatToTime(beat)
    local eff = {
        id = tostring(love.timer.getTime()) .. "_" .. tostring(love.math.random(1000, 9999)),
        lane = laneId or "shake",
        beat = beat or 0,
        time = effTime,
        duration = 0.3,
        durationBeats = 1.0,
        params = {}
    }

    if laneId == "shake" then
        eff.type = "shake" -- "shake", "shake_rot", "trauma"
        eff.params = {
            intensity = 10,
            duration = 0.25,
            frequency = 50,
            axes = "XY",
            rotIntensity = 0.05,
            traumaAmount = 0.6
        }
    elseif laneId == "zoom" then
        eff.type = "pulse" -- "pulse", "bounce", "zoom_to"
        eff.params = {
            amount = 0.15,
            duration = 0.25,
            frequency = 12,
            targetScale = 1.25,
            lerpSpeed = 7
        }
    elseif laneId == "flash" then
        eff.type = "flash_in_out" -- "flash_in_out", "flash"
        eff.params = {
            fadeIn = 0.05,
            fadeOut = 0.25,
            color = { 1.0, 1.0, 1.0 },
            peakAlpha = 0.85,
            duration = 0.3
        }
    elseif laneId == "pendulum" then
        eff.type = "pendulum" -- "pendulum", "wave", "wobble"
        eff.params = {
            maxAngle = 0.08,
            frequency = 2.5,
            duration = 0.8,
            ampX = 8,
            ampY = 6,
            freqX = 1.5,
            freqY = 2.0,
            wobbleAmount = 8
        }
    elseif laneId == "rotate" then
        eff.type = "rotate_to"
        eff.params = {
            duration = 0.8,
            targetAngle = 90, -- in degrees, absolute target rotation (e.g. 120, 90, -20)
            easing = "linear" -- easing template (linear, quadout, sineinout, backout, etc.)
        }
    end

    return eff
end

function Logic.addEffect(laneId, beat)
    Logic.pushUndo()
    local eff = Logic.createDefaultEffect(laneId, beat)
    table.insert(Logic.chartEffects, eff)
    table.sort(Logic.chartEffects, function(a, b) return (a.beat or 0) < (b.beat or 0) end)
    for idx, e in ipairs(Logic.chartEffects) do
        if e.id == eff.id then
            Logic.selectedEffectIndex = idx
            break
        end
    end
    Logic.statusMessage = string.format("Added %s effect at Beat %.2f", (laneId or ""):upper(), beat or 0)

    -- Bunyikan cue hitsound pada timing efek
    Logic.playHitsound("slideup")
end

function Logic.deleteSelectedEffect()
    if Logic.selectedEffectIndex and Logic.chartEffects[Logic.selectedEffectIndex] then
        Logic.pushUndo()
        table.remove(Logic.chartEffects, Logic.selectedEffectIndex)
        Logic.selectedEffectIndex = nil
        Logic.showEffectInspector = false
        Logic.statusMessage = "Effect deleted"
    end
end

function Logic.triggerEffect(eff)
    if not Logic.camera or not eff then return end
    local p = eff.params or {}
    local lane = eff.lane or eff.type

    if lane == "shake" then
        if eff.type == "shake" then
            Logic.camera:shake(p.intensity or 10, p.duration or 0.25, p.frequency or 50, p.axes or "XY")
        elseif eff.type == "shake_rot" then
            Logic.camera:shakeRot(p.rotIntensity or 0.05, p.duration or 0.25, p.frequency or 50)
        elseif eff.type == "trauma" then
            Logic.camera:addTrauma(p.traumaAmount or 0.6)
        end
    elseif lane == "zoom" then
        if eff.type == "pulse" then
            Logic.camera:zoomPulse(p.amount or 0.15, p.duration or 0.25)
        elseif eff.type == "bounce" then
            Logic.camera:zoomBounce(p.amount or 0.15, p.duration or 0.35, p.frequency or 12)
        elseif eff.type == "zoom_to" then
            Logic.camera:zoomTo(p.targetScale or 1.25, p.lerpSpeed or 7)
        end
    elseif lane == "flash" then
        if eff.type == "flash_in_out" then
            Logic.camera:flashInOut(p.fadeIn or 0.05, p.fadeOut or 0.25, p.color or { 1, 1, 1 }, p.peakAlpha or 0.85)
        elseif eff.type == "flash" then
            local c = p.color or { 1, 1, 1 }
            Logic.camera:flash(p.duration or 0.3, { c[1] or 1, c[2] or 1, c[3] or 1, p.peakAlpha or 0.85 })
        end
    elseif lane == "pendulum" then
        if eff.type == "pendulum" then
            Logic.camera:pendulumSwing(p.maxAngle or 0.08, p.duration or 0.8, p.frequency or 2.5)
        elseif eff.type == "wave" then
            Logic.camera:setWave(true, p.ampX or 8, p.ampY or 6, p.freqX or 1.5, p.freqY or 2.0)
        elseif eff.type == "wobble" then
            Logic.camera:wobble(p.wobbleAmount or 8, p.duration or 0.3, p.frequency or 35)
        end
    elseif lane == "rotate" then
        local p = eff.params or {}
        local toDeg = p.targetAngle or 90
        Logic.camera.rotation_override = math.rad(toDeg)
    end
end

local hitsoundPool = {}
local hitsoundIndex = {}
local POOL_SIZE = 8

local function initHitsounds()
    if hitsoundPool.basic then return end

    local function loadAssetSoundPool(filePath, fallbackPitch)
        if love.filesystem.getInfo(filePath) then
            local ok, data = pcall(love.sound.newSoundData, filePath)
            if ok and data then
                local pool = {}
                for _ = 1, POOL_SIZE do
                    local src = love.audio.newSource(data, "static")
                    if fallbackPitch then src:setPitch(fallbackPitch) end
                    table.insert(pool, src)
                end
                return pool
            end
        end
        return nil
    end

    local sampleRate = 44100
    local function makeTone(freq, duration, decay)
        local samples = math.floor(sampleRate * duration)
        local data = love.sound.newSoundData(samples, sampleRate, 16, 2)
        for i = 0, samples - 1 do
            local t = i / sampleRate
            local env = math.exp(-t * decay)
            local s = (math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(4 * math.pi * freq * t)) * env * 0.8
            local clamped = math.max(-1, math.min(1, s))
            data:setSample(i * 2, clamped)
            data:setSample(i * 2 + 1, clamped)
        end
        local pool = {}
        for _ = 1, POOL_SIZE do
            local src = love.audio.newSource(data, "static")
            table.insert(pool, src)
        end
        return pool
    end

    -- 1. Load dari assets/sounds jika ada
    hitsoundPool.basic = loadAssetSoundPool("assets/sounds/note_hit_basic.wav") or makeTone(850, 0.08, 45)
    hitsoundPool.slideup = loadAssetSoundPool("assets/sounds/note_hit_slide.wav", 1.15) or makeTone(1100, 0.09, 38)
    hitsoundPool.slidedown = loadAssetSoundPool("assets/sounds/note_hit_slide.wav", 0.85) or makeTone(650, 0.09, 38)
    hitsoundPool.combo = loadAssetSoundPool("assets/sounds/combo.wav")

    hitsoundIndex.basic = 1
    hitsoundIndex.slideup = 1
    hitsoundIndex.slidedown = 1
    hitsoundIndex.combo = 1
end

function Logic.playHitsound(noteType)
    if not Logic.effects.hitsound then return end
    initHitsounds()
    local pool = hitsoundPool[noteType] or hitsoundPool.basic
    local key = hitsoundPool[noteType] and noteType or "basic"
    if pool and #pool > 0 then
        local idx = hitsoundIndex[key] or 1
        local sound = pool[idx]
        hitsoundIndex[key] = (idx % #pool) + 1
        if sound then
            sound:stop()
            sound:setVolume(Logic.volume)
            sound:play()
        end
    end
end

function Logic.playAudioSnippet(noteTime, duration)
    duration = duration or 0.25
    if Logic.audioSource and not Logic.isPlaying then
        Logic.audioSource:seek(math.max(0, noteTime))
        Logic.audioSource:setVolume(Logic.volume)
        Logic.audioSource:setPitch(Logic.playbackRate)
        Logic.audioSource:play()
        Logic.snippetTimer = duration
    end
end

function Logic.canPlaceNote(angle, beat, noteType)
    noteType = noteType or Logic.selectedNoteType or "basic"
    local newSide = (math.cos(angle) < 0) and "left" or "right"
    local count = 0
    local sideUsed = false
    local slideConflict = false
    local existingType = nil
    local isReplace = false

    local isNewSlide = (noteType == "slideup" or noteType == "slidedown")

    for _, n in ipairs(Logic.notes) do
        if math.abs((n.beat or 0) - beat) < 0.001 then
            count = count + 1
            local nSide = (math.cos(n.angle or 0) < 0) and "left" or "right"
            local nType = n.type or "basic"
            local isExistingSlide = (nType == "slideup" or nType == "slidedown")

            if math.abs((n.angle or 0) - angle) < 0.05 then
                isReplace = true
            else
                if nSide == newSide then
                    sideUsed = true
                end
                -- Cek konflik slide: tidak boleh ada 2 slide (slideup/slidedown) pada beat bersamaan
                if isNewSlide and isExistingSlide then
                    slideConflict = true
                    existingType = nType
                end
            end
        end
    end

    if isReplace then
        return true, "update", newSide
    end
    if sideUsed then
        return false, "blocked_side", newSide
    end
    if slideConflict then
        return false, "blocked_slide_conflict", newSide, existingType
    end
    if count >= 2 then
        return false, "blocked_max", newSide
    end
    return true, "ok", newSide
end

function Logic.addNote(angle, beat)
    local noteType = Logic.selectedNoteType or "basic"
    local canPlace, reason, side, extra = Logic.canPlaceNote(angle, beat, noteType)

    if not canPlace then
        if reason == "blocked_side" then
            Logic.statusMessage = string.format("[Blocked] Only 1 note allowed on %s screen side on Beat %.2f!",
                side:upper(), beat)
        elseif reason == "blocked_slide_conflict" then
            Logic.statusMessage = string.format(
            "[Blocked] Cannot place two Slide notes on Beat %.2f! (Already has '%s')", beat, (extra or "SLIDE"):upper())
        elseif reason == "blocked_max" then
            Logic.statusMessage = string.format("[Blocked] Max 2 simultaneous notes allowed on Beat %.2f!", beat)
        end
        return false
    end

    local samePosIndex = nil
    for i, n in ipairs(Logic.notes) do
        if math.abs((n.beat or 0) - beat) < 0.001 and math.abs((n.angle or 0) - angle) < 0.05 then
            samePosIndex = i
            break
        end
    end

    -- Jika klik di posisi note yang sudah ada, update / ganti tipenya
    if samePosIndex then
        Logic.pushUndo()
        Logic.notes[samePosIndex] = {
            time = Logic.beatToTime(beat),
            beat = beat,
            type = Logic.selectedNoteType,
            angle = angle
        }
        Logic.statusMessage = string.format("Updated %s note at Beat %.2f", Logic.selectedNoteType, beat)
        Logic.playHitsound(Logic.selectedNoteType)
        Logic.playAudioSnippet(Logic.beatToTime(beat), 0.25)
        return true
    end

    Logic.pushUndo()
    local noteTime = Logic.beatToTime(beat)
    local newNote = {
        time = noteTime,
        beat = beat,
        type = Logic.selectedNoteType,
        angle = angle
    }
    table.insert(Logic.notes, newNote)
    table.sort(Logic.notes, function(a, b) return (a.time or 0) < (b.time or 0) end)
    Logic.statusMessage = string.format("Placed %s note at Beat %.2f (%s side)", newNote.type, beat, side)

    Logic.playHitsound(newNote.type)
    Logic.playAudioSnippet(noteTime, 0.25)
    return true
end

function Logic.deleteSelectedNote()
    if Logic.selectedNoteIndex and Logic.notes[Logic.selectedNoteIndex] then
        Logic.pushUndo()
        table.remove(Logic.notes, Logic.selectedNoteIndex)
        Logic.selectedNoteIndex = nil
        Logic.showNoteGimmickModal = false
        Logic.statusMessage = "Note deleted"
    end
end

function Logic.previewNoteGimmick()
    if not Logic.selectedNoteIndex or not Logic.notes[Logic.selectedNoteIndex] then return end
    local note = Logic.notes[Logic.selectedNoteIndex]
    local targetBeat = note.beat or Logic.timeToBeat(note.time or 0)
    local targetTime = note.time or Logic.beatToTime(targetBeat)

    local leadBeats = 3.0
    local startBeat = math.max(Logic.getMinBeat(), targetBeat - leadBeats)
    local startTime = Logic.beatToTime(startBeat)
    local previewDur = (targetTime - startTime) + 0.35

    Logic.seekTime(startTime)
    if not Logic.isPlaying then
        if Logic.audioSource then
            Logic.audioSource:seek(math.max(0, startTime))
            Logic.audioSource:setVolume(Logic.volume)
            Logic.audioSource:setPitch(Logic.playbackRate)
            Logic.audioSource:play()
        end
        Logic.previewTimer = previewDur
        Logic.previewActive = true
    end
    Logic.statusMessage = string.format("Previewing Gimmick Note #%d (from Beat %.2f -> %.2f)", Logic.selectedNoteIndex,
        startBeat, targetBeat)
end

-- ==========================================
-- LANE NOTE EDITOR: MULTI-SELECTION & CLIPBOARD
-- ==========================================

function Logic.selectNote(index, additive, toggle)
    if not additive then
        Logic.selectedNoteIndices = {}
    end
    if toggle and Logic.selectedNoteIndices[index] then
        Logic.selectedNoteIndices[index] = nil
        if Logic.selectedNoteIndex == index then
            Logic.selectedNoteIndex = nil
            for idx in pairs(Logic.selectedNoteIndices) do
                Logic.selectedNoteIndex = idx
                break
            end
        end
    else
        Logic.selectedNoteIndices[index] = true
        Logic.selectedNoteIndex = index
    end
    local count = Logic.getSelectedNotesCount()
    if count == 1 then
        Logic.statusMessage = string.format("Selected Note #%d", Logic.selectedNoteIndex or index)
    elseif count > 1 then
        Logic.statusMessage = string.format("Selected %d notes", count)
    else
        Logic.statusMessage = "No notes selected"
    end
end

function Logic.selectNotesInBeatLaneRange(minBeat, maxBeat, minLane, maxLane, totalLanes, additive)
    totalLanes = totalLanes or Logic.angleSteps or 16
    if not additive then
        Logic.selectedNoteIndices = {}
    end

    local newlySelected = 0
    for i, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local laneIdx = Logic.angleToLane(note.angle or 0, totalLanes)

        if nBeat >= minBeat - 0.01 and nBeat <= maxBeat + 0.01 and laneIdx >= minLane and laneIdx <= maxLane then
            Logic.selectedNoteIndices[i] = true
            Logic.selectedNoteIndex = i
            newlySelected = newlySelected + 1
        end
    end

    local total = Logic.getSelectedNotesCount()
    Logic.statusMessage = string.format("Box selected %d notes (Total: %d)", newlySelected, total)
end

function Logic.selectNotesInRect(x1, y1, x2, y2, hitLineX, spacing, laneYStart, laneHeight, totalLanes, additive)
    totalLanes = totalLanes or Logic.angleSteps or 16
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    local minY = math.min(y1, y2)
    local maxY = math.max(y1, y2)

    if not additive then
        Logic.selectedNoteIndices = {}
    end

    local newlySelected = 0
    for i, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local nx = hitLineX + (nBeat - Logic.currentBeat) * spacing
        local laneIdx = Logic.angleToLane(note.angle or 0, totalLanes)
        local ny = laneYStart + (laneIdx - 1) * laneHeight + laneHeight * 0.5

        if nx >= minX - 10 and nx <= maxX + 10 and ny >= minY - 10 and ny <= maxY + 10 then
            Logic.selectedNoteIndices[i] = true
            Logic.selectedNoteIndex = i
            newlySelected = newlySelected + 1
        end
    end

    local total = Logic.getSelectedNotesCount()
    Logic.statusMessage = string.format("Box selected %d notes (Total: %d)", newlySelected, total)
end

function Logic.selectAllNotes()
    Logic.selectedNoteIndices = {}
    for i = 1, #Logic.notes do
        Logic.selectedNoteIndices[i] = true
    end
    Logic.selectedNoteIndex = #Logic.notes > 0 and 1 or nil
    Logic.statusMessage = string.format("Selected all %d notes", #Logic.notes)
end

function Logic.clearNoteSelection()
    Logic.selectedNoteIndices = {}
    Logic.selectedNoteIndex = nil
    Logic.showNoteGimmickModal = false
    Logic.statusMessage = "Cleared selection"
end

function Logic.isNoteSelected(index)
    return (Logic.selectedNoteIndices[index] == true) or (Logic.selectedNoteIndex == index)
end

function Logic.getSelectedNotesCount()
    local count = 0
    for _ in pairs(Logic.selectedNoteIndices) do
        count = count + 1
    end
    if count == 0 and Logic.selectedNoteIndex and Logic.notes[Logic.selectedNoteIndex] then
        return 1
    end
    return count
end

function Logic.getSelectedNoteIndices()
    local indices = {}
    for idx in pairs(Logic.selectedNoteIndices) do
        if Logic.notes[idx] then
            table.insert(indices, idx)
        end
    end
    if #indices == 0 and Logic.selectedNoteIndex and Logic.notes[Logic.selectedNoteIndex] then
        table.insert(indices, Logic.selectedNoteIndex)
    end
    table.sort(indices)
    return indices
end

function Logic.copySelectedNotes()
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then
        Logic.statusMessage = "No notes selected to copy"
        return
    end

    local minBeat = 9999999
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        local b = n.beat or Logic.timeToBeat(n.time or 0)
        if b < minBeat then minBeat = b end
    end

    Logic.clipboardNotes = {}
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        local b = n.beat or Logic.timeToBeat(n.time or 0)
        table.insert(Logic.clipboardNotes, {
            offsetBeat = b - minBeat,
            angle = n.angle or 0,
            type = n.type or "basic",
            gimmick = deepCopyTable(n.gimmick)
        })
    end

    Logic.statusMessage = string.format("Copied %d note(s) to clipboard", #Logic.clipboardNotes)
end

function Logic.pasteNotes(targetBeat)
    if not Logic.clipboardNotes or #Logic.clipboardNotes == 0 then
        Logic.statusMessage = "Clipboard is empty"
        return
    end

    targetBeat = targetBeat or Logic.currentBeat
    Logic.pushUndo()
    Logic.selectedNoteIndices = {}

    local pastedKeys = {}
    for _, item in ipairs(Logic.clipboardNotes) do
        local nBeat = targetBeat + (item.offsetBeat or 0)
        local nTime = Logic.beatToTime(nBeat)
        local newNote = {
            beat = nBeat,
            time = nTime,
            angle = item.angle or 0,
            type = item.type or "basic",
            gimmick = deepCopyTable(item.gimmick)
        }
        table.insert(Logic.notes, newNote)
        pastedKeys[string.format("%.4f_%.4f", nBeat, item.angle or 0)] = true
    end

    table.sort(Logic.notes, function(a, b) return (a.time or 0) < (b.time or 0) end)

    -- Select the newly pasted notes
    for i, n in ipairs(Logic.notes) do
        local nBeat = n.beat or Logic.timeToBeat(n.time or 0)
        local key = string.format("%.4f_%.4f", nBeat, n.angle or 0)
        if pastedKeys[key] then
            Logic.selectedNoteIndices[i] = true
            Logic.selectedNoteIndex = i
        end
    end

    Logic.statusMessage = string.format("Pasted %d note(s) at Beat %.2f", #Logic.clipboardNotes, targetBeat)
    Logic.playHitsound("slideup")
    Logic.playAudioSnippet(Logic.beatToTime(targetBeat), 0.25)
end

function Logic.duplicateSelectedNotes(deltaBeats)
    deltaBeats = deltaBeats or 1.0
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end

    Logic.copySelectedNotes()
    local minBeat = 9999999
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        local b = n.beat or Logic.timeToBeat(n.time or 0)
        if b < minBeat then minBeat = b end
    end

    if minBeat < 9999990 then
        Logic.pasteNotes(minBeat + deltaBeats)
    end
end

function Logic.deleteSelectedNotes()
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then
        Logic.deleteSelectedNote()
        return
    end

    Logic.pushUndo()
    for i = #indices, 1, -1 do
        table.remove(Logic.notes, indices[i])
    end
    Logic.selectedNoteIndices = {}
    Logic.selectedNoteIndex = nil
    Logic.showNoteGimmickModal = false
    Logic.statusMessage = string.format("Deleted %d note(s)", #indices)
end

-- ==========================================
-- LANE NOTE EDITOR: BATCH SETTINGS & MIXED SUMMARY
-- ==========================================

function Logic.getSelectedNotesSummary()
    local indices = Logic.getSelectedNoteIndices()
    local count = #indices
    if count == 0 then
        return { count = 0 }
    end

    local first = Logic.notes[indices[1]]
    local firstType = first.type or "basic"
    local firstLane = Logic.angleToLane(first.angle or 0, Logic.angleSteps or 16)
    local firstGimmickType = (first.gimmick and first.gimmick.type and first.gimmick.type ~= "") and first.gimmick.type or
    "none"
    local isFirstManual = (first.gimmick and first.gimmick.isManual == true)

    local typeMixed = false
    local laneMixed = false
    local gimmickMixed = false
    local manualMixed = false

    local minBeat = first.beat or Logic.timeToBeat(first.time or 0)
    local maxBeat = minBeat

    for i = 2, count do
        local n = Logic.notes[indices[i]]
        local b = n.beat or Logic.timeToBeat(n.time or 0)
        if b < minBeat then minBeat = b end
        if b > maxBeat then maxBeat = b end

        if (n.type or "basic") ~= firstType then typeMixed = true end
        if Logic.angleToLane(n.angle or 0, Logic.angleSteps or 16) ~= firstLane then laneMixed = true end

        local gType = (n.gimmick and n.gimmick.type and n.gimmick.type ~= "") and n.gimmick.type or "none"
        if gType ~= firstGimmickType then gimmickMixed = true end

        local isMan = (n.gimmick and n.gimmick.isManual == true)
        if isMan ~= isFirstManual then manualMixed = true end
    end

    return {
        count = count,
        indices = indices,
        minBeat = minBeat,
        maxBeat = maxBeat,
        noteType = typeMixed and "Mixed" or firstType,
        typeMixed = typeMixed,
        laneIndex = laneMixed and "Mixed" or firstLane,
        laneMixed = laneMixed,
        gimmickType = gimmickMixed and "Mixed" or firstGimmickType,
        gimmickMixed = gimmickMixed,
        isManual = manualMixed and "Mixed" or isFirstManual,
        firstNote = first
    }
end

function Logic.batchSetNoteType(newType)
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    Logic.pushUndo()
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n then n.type = newType end
    end
    Logic.selectedNoteType = newType
    Logic.statusMessage = string.format("Set type to %s for %d notes", newType:upper(), #indices)
    Logic.playHitsound(newType)
end

function Logic.batchSetLane(newLaneIndex)
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    Logic.pushUndo()
    local newAngle = Logic.laneToAngle(newLaneIndex, Logic.angleSteps or 16)
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n then n.angle = newAngle end
    end
    Logic.statusMessage = string.format("Moved %d notes to Lane #%d", #indices, newLaneIndex)
end

function Logic.batchShiftBeat(deltaBeat)
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    Logic.pushUndo()
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n then
            local curB = n.beat or Logic.timeToBeat(n.time or 0)
            n.beat = math.max(Logic.getMinBeat(), curB + deltaBeat)
            n.time = Logic.beatToTime(n.beat)
        end
    end
    table.sort(Logic.notes, function(a, b) return (a.time or 0) < (b.time or 0) end)
    Logic.statusMessage = string.format("Shifted %d notes by %+.2f beats", #indices, deltaBeat)
end

function Logic.batchSetGimmick(gimmickType, defaultParams)
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    Logic.pushUndo()
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n then
            n.gimmick = n.gimmick or {}
            n.gimmick.type = gimmickType
            n.gimmick.isManual = false
            n.gimmick.params = n.gimmick.params or {}
            if defaultParams then
                for k, v in pairs(defaultParams) do
                    n.gimmick.params[k] = v
                end
            end
        end
    end
    Logic.statusMessage = string.format("Applied gimmick '%s' to %d notes", gimmickType, #indices)
end

function Logic.batchSetGimmickParam(paramKey, paramVal)
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n and n.gimmick then
            n.gimmick.params = n.gimmick.params or {}
            n.gimmick.params[paramKey] = paramVal
        end
    end
end

function Logic.batchSetManualGimmickParam(paramKey, paramVal)
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n then
            n.gimmick = n.gimmick or {}
            n.gimmick.type = "manual"
            n.gimmick.isManual = true
            n.gimmick.manual = n.gimmick.manual or {}
            n.gimmick.manual[paramKey] = paramVal
        end
    end
end

function Logic.batchClearGimmick()
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then return end
    Logic.pushUndo()
    for _, idx in ipairs(indices) do
        local n = Logic.notes[idx]
        if n then n.gimmick = nil end
    end
    Logic.statusMessage = string.format("Cleared gimmick for %d notes", #indices)
end

function Logic.shuffleSelectedNotes()
    local indices = Logic.getSelectedNoteIndices()
    if #indices == 0 then
        Logic.statusMessage = "No notes selected to shuffle"
        return
    end

    Logic.pushUndo()
    local totalLanes = Logic.angleSteps or 16
    if totalLanes <= 0 then totalLanes = 16 end

    if #indices == 1 then
        -- Single note: pick a random different lane
        local n = Logic.notes[indices[1]]
        if n then
            local currentLane = Logic.angleToLane(n.angle or 0, totalLanes)
            local newLane = math.random(1, totalLanes)
            if totalLanes > 1 and newLane == currentLane then
                newLane = (currentLane % totalLanes) + 1
            end
            n.angle = Logic.laneToAngle(newLane, totalLanes)
            Logic.statusMessage = string.format("Shuffled Note #%d to Track #%d", indices[1], newLane)
        end
    else
        -- Multiple notes: group by beat/time or shuffle lane/angle distribution
        -- We extract existing angles/lanes or assign randomized valid lanes
        local lanes = {}
        for _, idx in ipairs(indices) do
            local n = Logic.notes[idx]
            local l = Logic.angleToLane(n.angle or 0, totalLanes)
            table.insert(lanes, l)
        end

        -- Fisher-Yates shuffle algorithm on extracted lanes
        for i = #lanes, 2, -1 do
            local j = math.random(1, i)
            lanes[i], lanes[j] = lanes[j], lanes[i]
        end

        -- In case all notes were originally in the same lane, randomize them across totalLanes
        local allSame = true
        for i = 2, #lanes do
            if lanes[i] ~= lanes[1] then
                allSame = false
                break
            end
        end

        if allSame then
            for i = 1, #lanes do
                lanes[i] = math.random(1, totalLanes)
            end
        end

        for i, idx in ipairs(indices) do
            local n = Logic.notes[idx]
            if n then
                n.angle = Logic.laneToAngle(lanes[i], totalLanes)
            end
        end

        Logic.statusMessage = string.format("Shuffled positions/lanes of %d notes", #indices)
    end

    Logic.playHitsound(Logic.selectedNoteType or "basic")
end

return Logic
