local Logic = require("node.editor.logic")

local Update = {}

function Update.update(dt)
    -- 1. Continuous FX evaluation (Pendulum Sway, Wave Float)
    Logic.evaluateContinuousFX(dt, Logic.isPlaying)

    -- 2. Update Camera FX System (Shakes, Zooms, Flashes, Pendulums)
    if Logic.camera then
        if Logic.isPlaying or Logic.snippetTimer then
            Logic.camera:update(dt)
        else
            Logic.camera:update(0) -- Do not advance real-time timers when paused
        end
    end

    -- 3. Update Audio & Playback Time
    if Logic.isPlaying then
        local prevBeat = Logic.currentBeat
        if Logic.audioSource and Logic.currentTime >= 0 and Logic.audioSource:isPlaying() then
            Logic.currentTime = Logic.audioSource:tell()
            if Logic.currentTime >= Logic.duration then
                Logic.currentTime = Logic.getMinTime()
                Logic.togglePlay()
            end
        else
            Logic.currentTime = Logic.currentTime + dt * Logic.playbackRate
            if Logic.currentTime >= 0 and Logic.audioSource and not Logic.audioSource:isPlaying() then
                Logic.audioSource:seek(math.min(Logic.currentTime, math.max(0, Logic.duration - 0.001)))
                Logic.audioSource:setPitch(Logic.playbackRate)
                Logic.audioSource:setVolume(Logic.volume)
                Logic.audioSource:play()
            end
            if Logic.currentTime >= Logic.duration then
                Logic.currentTime = Logic.getMinTime()
                Logic.togglePlay()
            end
        end
        Logic.currentBeat = Logic.timeToBeat(Logic.currentTime)

        -- 4. Trigger Hitsounds / Metronome when passing beat
        if (Logic.currentBeat - prevBeat) > 0 and (Logic.currentBeat - prevBeat) < 4 then
            if Logic.effects.hitsound then
                for _, note in ipairs(Logic.notes) do
                    local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
                    if prevBeat < nBeat and Logic.currentBeat >= nBeat then
                        Logic.playHitsound(note.type)
                    end
                end
            end

            if Logic.effects.metronome and math.floor(Logic.currentBeat) > math.floor(prevBeat) then
                Logic.playHitsound("basic")
            end
        end

        -- 5. Trigger Instant Camera FX when effects pass current beat (Radial page only)
        if Logic.currentPage == "editor" and (Logic.currentBeat - prevBeat) > 0 and (Logic.currentBeat - prevBeat) < 4 then
            for _, eff in ipairs(Logic.chartEffects) do
                local effBeat = eff.beat or Logic.timeToBeat(eff.time or 0)
                local p = eff.params or {}
                if p.repeatEnabled and p.repeatStep and p.repeatStep > 0 and p.repeatUntilBeat and p.repeatUntilBeat >= effBeat then
                    local maxStep = math.floor(((p.repeatUntilBeat - effBeat) + 0.0001) / p.repeatStep)
                    local startStep = math.max(0, math.floor(((prevBeat - effBeat) + 0.0001) / p.repeatStep) + 1)
                    local endStep = math.floor(((Logic.currentBeat - effBeat) + 0.0001) / p.repeatStep)
                    endStep = math.min(endStep, maxStep)
                    if startStep <= endStep then
                        for sIdx = startStep, endStep do
                            Logic.triggerEffect(eff)
                        end
                    end
                else
                    if prevBeat < effBeat and Logic.currentBeat >= effBeat then
                        Logic.triggerEffect(eff)
                    end
                end
            end
        end
    elseif Logic.previewTimer then
        local prevBeat = Logic.currentBeat
        if Logic.audioSource and Logic.currentTime >= 0 and Logic.audioSource:isPlaying() then
            Logic.currentTime = Logic.audioSource:tell()
        else
            Logic.currentTime = Logic.currentTime + dt * Logic.playbackRate
        end
        Logic.currentBeat = Logic.timeToBeat(Logic.currentTime)

        -- Trigger note hitsound during preview
        if Logic.effects.hitsound and (Logic.currentBeat - prevBeat) > 0 and (Logic.currentBeat - prevBeat) < 4 then
            for _, note in ipairs(Logic.notes) do
                local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
                if prevBeat < nBeat and Logic.currentBeat >= nBeat then
                    Logic.playHitsound(note.type)
                end
            end
        end

        Logic.previewTimer = Logic.previewTimer - dt
        if Logic.previewTimer <= 0 then
            Logic.previewTimer = nil
            Logic.previewActive = false
            if Logic.audioSource and not Logic.isPlaying then
                Logic.audioSource:pause()
            end
        end
    elseif Logic.snippetTimer then
        Logic.snippetTimer = Logic.snippetTimer - dt
        if Logic.snippetTimer <= 0 then
            Logic.snippetTimer = nil
            if Logic.audioSource and not Logic.isPlaying then
                Logic.audioSource:pause()
            end
            Logic.evaluateContinuousFX(0, false)
            if Logic.camera then
                Logic.camera:update(0)
            end
        end
    end
end

function Update.mousepressed(x, y, button, istouch, presses)
    local Draw = require("node.editor.draw")
    -- Blokir input playfield jika mouse di atas Slab UI
    if Draw.isPointerOverUI() then
        return
    end

    -- ==========================================
    -- PAGE 3: LANE NOTE EDITOR INPUT
    -- ==========================================
    if Logic.currentPage == "lane_editor" then
        local hitLineX = Draw.laneHitLineX or 230
        local totalLanes = Logic.angleSteps or 16
        if totalLanes <= 0 then totalLanes = 16 end
        local laneYStart = 55
        local laneH = math.max(22, math.min(38, math.floor((love.graphics.getHeight() - laneYStart - 55) / totalLanes)))
        local spacing = Logic.laneSpacing * Logic.laneZoom
        local headerW = 150

        local hit = Logic.getLaneNoteHitInfo(hitLineX, spacing, laneYStart, laneH, totalLanes, x, y)
        local isShift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        local isCtrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

        if button == 1 then -- Left Click: Select Note or Start Box Select / Place Note
            if hit then
                Logic.selectNote(hit.noteIndex, isShift or isCtrl, isShift or isCtrl)
                Logic.playHitsound(hit.note.type)
                Logic.playAudioSnippet(hit.note.time or Logic.beatToTime(hit.beat), 0.25)
            else
                if x >= headerW + 15 and y >= laneYStart and y <= laneYStart + totalLanes * laneH then
                    local startBeat = Logic.currentBeat + (x - hitLineX) / spacing
                    Logic.laneBoxSelect = {
                        active = true,
                        startX = x,
                        startY = y,
                        curX = x,
                        curY = y,
                        startBeat = startBeat,
                        additive = (isShift or isCtrl),
                        isClick = true
                    }
                else
                    Logic.clearNoteSelection()
                end
            end
        elseif button == 2 then -- Right Click: Delete Hit Note or Selection
            if hit then
                if Logic.isNoteSelected(hit.noteIndex) and Logic.getSelectedNotesCount() > 1 then
                    Logic.deleteSelectedNotes()
                else
                    Logic.selectedNoteIndex = hit.noteIndex
                    Logic.deleteSelectedNote()
                end
            else
                if x >= headerW + 15 and y >= laneYStart and y <= laneYStart + totalLanes * laneH then
                    local snap = Logic.calculateLaneSnap(hitLineX, x, y, laneYStart, laneH, totalLanes)
                    for i, n in ipairs(Logic.notes) do
                        if math.abs((n.beat or 0) - snap.beat) < 0.001 and math.abs((n.angle or 0) - snap.angle) < 0.05 then
                            Logic.selectedNoteIndex = i
                            Logic.deleteSelectedNote()
                            break
                        end
                    end
                end
            end
        end
        return
    end

    -- ==========================================
    -- PAGE 2: EFFECTS TIMELINE INPUT
    -- ==========================================
    if Logic.currentPage == "effects" then
        local hitLineX = Draw.effectsHitLineX
        local laneYStart = Draw.effectsLaneYStart
        local laneH = Draw.effectsLaneHeight
        local lanes = Logic.effectLanes
        local spacing = Logic.effectsSpacing * Logic.effectsZoom

        -- Cari hit test pada handle atau body effect
        local hitInfo = nil
        if Logic.selectedEffectIndex and Logic.chartEffects[Logic.selectedEffectIndex] then
            hitInfo = Logic.getEffectHitInfo(Logic.chartEffects[Logic.selectedEffectIndex], Logic.selectedEffectIndex, hitLineX, spacing, laneYStart, laneH, x, y)
        end
        if not hitInfo then
            for i, eff in ipairs(Logic.chartEffects) do
                local h = Logic.getEffectHitInfo(eff, i, hitLineX, spacing, laneYStart, laneH, x, y)
                if h then
                    hitInfo = h
                    break
                end
            end
        end

        if button == 1 then -- Left Click: Drag, Select, or Add
            if hitInfo then
                Logic.selectedEffectIndex = hitInfo.effectIndex
                Logic.showEffectInspector = true
                local eff = Logic.chartEffects[hitInfo.effectIndex]
                local p = eff.params or {}

                Logic.pushUndo()

                local dragType = "move"
                if hitInfo.hitType == "handle_duration" then
                    dragType = "resize_duration"
                elseif hitInfo.hitType == "handle_repeat" then
                    dragType = "resize_repeat"
                elseif hitInfo.hitType == "handle_step" then
                    dragType = "resize_step"
                else
                    dragType = "move"
                end

                Logic.effectDrag = {
                    active = true,
                    dragType = dragType,
                    effectIndex = hitInfo.effectIndex,
                    startBeat = eff.beat or 0,
                    startMouseX = x,
                    startDuration = p.duration or 0.8,
                    startRepeatUntilBeat = p.repeatUntilBeat or ((eff.beat or 0) + 4.0),
                    startRepeatStep = p.repeatStep or 1.0,
                    initialLane = eff.lane,
                    hasChanged = false
                }

                if dragType == "move" then
                    Logic.statusMessage = string.format("Selected %s effect at Beat %.2f (Drag to move, right handle to extend)", (eff.lane or ""):upper(), eff.beat or 0)
                elseif dragType == "resize_duration" or dragType == "resize_repeat" then
                    Logic.statusMessage = string.format("Resizing length of %s effect (Drag left/right)", (eff.lane or ""):upper())
                elseif dragType == "resize_step" then
                    Logic.statusMessage = string.format("Adjusting step interval of %s effect", (eff.lane or ""):upper())
                end
            else
                if x >= 170 and y >= laneYStart and y <= laneYStart + #lanes * laneH then
                    local snapEff = Logic.calculateEffectsSnap(hitLineX, x, y, laneYStart, laneH, #lanes)
                    Logic.addEffect(snapEff.laneId, snapEff.beat)
                end
            end
        elseif button == 2 then -- Right Click: Hapus effect
            if hitInfo then
                Logic.selectedEffectIndex = hitInfo.effectIndex
                Logic.deleteSelectedEffect()
            else
                if x >= 170 and y >= laneYStart and y <= laneYStart + #lanes * laneH then
                    local snapEff = Logic.calculateEffectsSnap(hitLineX, x, y, laneYStart, laneH, #lanes)
                    for i, e in ipairs(Logic.chartEffects) do
                        if e.lane == snapEff.laneId and math.abs((e.beat or 0) - snapEff.beat) < 0.05 then
                            Logic.selectedEffectIndex = i
                            Logic.deleteSelectedEffect()
                            break
                        end
                    end
                end
            end
        end
        return
    end

    -- ==========================================
    -- PAGE 1: NOTE EDITOR INPUT (CONCENTRIC RINGS)
    -- ==========================================
    local centerX, centerY = Draw.getPlayfieldCenter()
    local spacing = Logic.stepSpacing * Logic.stepZoom
    local minR = Logic.centerRadius

    -- Transform screen mouse coordinates into world coordinates through camera
    local worldX, worldY = x, y
    if Logic.camera and Logic.camera.toWorldCoords then
        worldX, worldY = Logic.camera:toWorldCoords(x, y)
    end

    local clickedNoteIndex = nil
    for i, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local rawRadius = minR + (nBeat - Logic.currentBeat) * spacing

        if rawRadius >= minR - 5 then
            -- 1. Base position (posisi asli sesuai beat grid)
            local baseNoteX = centerX + math.cos(note.angle or 0) * rawRadius
            local baseNoteY = centerY + math.sin(note.angle or 0) * rawRadius
            local distBase = math.sqrt((worldX - baseNoteX)^2 + (worldY - baseNoteY)^2)

            -- 2. Visual Gimmick Trajectory position (posisi visual yang terlihat)
            local visualX, visualY = Logic.getNoteRenderPos(note, centerX, centerY, spacing, minR)
            local distVisual = math.sqrt((worldX - visualX)^2 + (worldY - visualY)^2)

            if distVisual <= 22 or distBase <= 22 then
                clickedNoteIndex = i
                break
            end
        end
    end

    local isShift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local isCtrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    if button == 1 then
        if clickedNoteIndex then
            Logic.selectNote(clickedNoteIndex, isShift or isCtrl, isShift or isCtrl)
            if not (isShift or isCtrl) then
                Logic.showNoteGimmickModal = true
            end
            Logic.playHitsound(Logic.notes[clickedNoteIndex].type)
            Logic.playAudioSnippet(Logic.notes[clickedNoteIndex].time or Logic.beatToTime(Logic.notes[clickedNoteIndex].beat or 0), 0.25)
        else
            if not (isShift or isCtrl) then
                Logic.clearNoteSelection()
            end
            local snap = Logic.calculateSnap(centerX, centerY, worldX, worldY)
            Logic.addNote(snap.angle, snap.beat)
        end
    elseif button == 2 then
        if clickedNoteIndex then
            if Logic.isNoteSelected(clickedNoteIndex) and Logic.getSelectedNotesCount() > 1 then
                Logic.deleteSelectedNotes()
            else
                Logic.selectedNoteIndex = clickedNoteIndex
                Logic.deleteSelectedNote()
            end
        else
            local snap = Logic.calculateSnap(centerX, centerY, worldX, worldY)
            for i, n in ipairs(Logic.notes) do
                if math.abs((n.beat or 0) - snap.beat) < 0.001 
                and math.abs((n.angle or 0) - snap.angle) < 0.05 then
                    Logic.selectedNoteIndex = i
                    Logic.deleteSelectedNote()
                    break
                end
            end
        end
    end
end

function Update.mousemoved(x, y, dx, dy, istouch)
    if Logic.currentPage == "lane_editor" and Logic.laneBoxSelect.active then
        Logic.laneBoxSelect.curX = x
        Logic.laneBoxSelect.curY = y
        if math.abs(x - Logic.laneBoxSelect.startX) > 4 or math.abs(y - Logic.laneBoxSelect.startY) > 4 then
            Logic.laneBoxSelect.isClick = false
        end
    elseif Logic.currentPage == "effects" then
        local Draw = require("node.editor.draw")
        local hitLineX = Draw.effectsHitLineX
        local laneYStart = Draw.effectsLaneYStart
        local laneH = Draw.effectsLaneHeight
        local lanes = Logic.effectLanes
        local spacing = Logic.effectsSpacing * Logic.effectsZoom

        -- Update hovered element jika tidak sedang dragging
        if not Logic.effectDrag.active and not Draw.isPointerOverUI() then
            Logic.hoveredEffectElement = nil
            if Logic.selectedEffectIndex and Logic.chartEffects[Logic.selectedEffectIndex] then
                local selEff = Logic.chartEffects[Logic.selectedEffectIndex]
                Logic.hoveredEffectElement = Logic.getEffectHitInfo(selEff, Logic.selectedEffectIndex, hitLineX, spacing, laneYStart, laneH, x, y)
            end
            if not Logic.hoveredEffectElement then
                for i, eff in ipairs(Logic.chartEffects) do
                    local h = Logic.getEffectHitInfo(eff, i, hitLineX, spacing, laneYStart, laneH, x, y)
                    if h then
                        Logic.hoveredEffectElement = h
                        break
                    end
                end
            end
        end

        -- Handle ongoing drag (Move, Resize Duration, Resize Repeat, Resize Step)
        if Logic.effectDrag.active and Logic.effectDrag.effectIndex then
            local eff = Logic.chartEffects[Logic.effectDrag.effectIndex]
            if eff then
                local isShiftDown = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
                local p = eff.params or {}
                local bpm = math.max(1, tonumber(Logic.bpm) or 120)
                local snapEff = Logic.calculateEffectsSnap(hitLineX, x, y, laneYStart, laneH, #lanes)
                local continuousBeat = Logic.currentBeat + (x - hitLineX) / spacing
                local targetBeat = isShiftDown and continuousBeat or snapEff.beat

                if Logic.effectDrag.dragType == "move" then
                    targetBeat = math.max(Logic.getMinBeat(), targetBeat)
                    local deltaBeat = targetBeat - eff.beat
                    if math.abs(deltaBeat) > 0.0001 or eff.lane ~= snapEff.laneId then
                        eff.beat = targetBeat
                        eff.time = Logic.beatToTime(targetBeat)
                        eff.lane = snapEff.laneId
                        if p.repeatEnabled and p.repeatUntilBeat then
                            p.repeatUntilBeat = p.repeatUntilBeat + deltaBeat
                        end
                        Logic.effectDrag.hasChanged = true
                        Logic.statusMessage = string.format("Moving %s: Beat %.2f (Time: %.3fs)", (eff.lane or ""):upper(), eff.beat, eff.time)
                        Logic.evaluateContinuousFX(0, Logic.isPlaying)
                    end
                elseif Logic.effectDrag.dragType == "resize_repeat" then
                    local newUntilBeat = math.max((eff.beat or 0) + 0.125, targetBeat)
                    p.repeatUntilBeat = newUntilBeat
                    Logic.effectDrag.hasChanged = true
                    local spanBeats = newUntilBeat - (eff.beat or 0)
                    local repCount = math.floor((spanBeats + 0.001) / (p.repeatStep or 1.0)) + 1
                    Logic.statusMessage = string.format("Repeat Until: Beat %.2f (Length: %.2f beats, %d triggers)", newUntilBeat, spanBeats, repCount)
                    Logic.evaluateContinuousFX(0, Logic.isPlaying)
                elseif Logic.effectDrag.dragType == "resize_duration" then
                    local durBeats = math.max(0.0625, targetBeat - (eff.beat or 0))
                    p.duration = durBeats * (60 / bpm)
                    Logic.effectDrag.hasChanged = true
                    Logic.statusMessage = string.format("Duration: %.2f beats (%.2f sec)", durBeats, p.duration)
                    Logic.evaluateContinuousFX(0, Logic.isPlaying)
                elseif Logic.effectDrag.dragType == "resize_step" then
                    local stepBeats = math.max(0.0625, targetBeat - (eff.beat or 0))
                    if not isShiftDown then
                        local stepOptions = { 0.125, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0 }
                        local closestStep = stepOptions[1]
                        local minDiff = 999
                        for _, s in ipairs(stepOptions) do
                            local diff = math.abs(stepBeats - s)
                            if diff < minDiff then
                                minDiff = diff
                                closestStep = s
                            end
                        end
                        if minDiff < 0.2 then stepBeats = closestStep end
                    end
                    p.repeatStep = stepBeats
                    Logic.effectDrag.hasChanged = true
                    Logic.statusMessage = string.format("Repeat Step: %.2f beats", stepBeats)
                    Logic.evaluateContinuousFX(0, Logic.isPlaying)
                end
            end
        end
    end
end

function Update.mousereleased(x, y, button, istouch, presses)
    if Logic.currentPage == "lane_editor" and Logic.laneBoxSelect.active then
        local bs = Logic.laneBoxSelect
        Logic.laneBoxSelect = { active = false }
        local Draw = require("node.editor.draw")
        local totalLanes = Logic.angleSteps or 16
        if totalLanes <= 0 then totalLanes = 16 end
        local laneYStart = 55
        local laneH = math.max(22, math.min(38, math.floor((love.graphics.getHeight() - laneYStart - 55) / totalLanes)))
        local spacing = Logic.laneSpacing * Logic.laneZoom
        local hitLineX = Draw.laneHitLineX or 180

        local startBeat = bs.startBeat or (Logic.currentBeat + (bs.startX - hitLineX) / spacing)
        local curBeat = Logic.currentBeat + (bs.curX - hitLineX) / spacing
        local minB = math.min(startBeat, curBeat)
        local maxB = math.max(startBeat, curBeat)

        local startLane = math.max(1, math.min(totalLanes, math.floor((bs.startY - laneYStart) / laneH) + 1))
        local curLane = math.max(1, math.min(totalLanes, math.floor((bs.curY - laneYStart) / laneH) + 1))
        local minL = math.min(startLane, curLane)
        local maxL = math.max(startLane, curLane)

        if not bs.isClick and (math.abs(maxB - minB) > 0.05 or math.abs(bs.curY - bs.startY) > 6) then
            Logic.selectNotesInBeatLaneRange(minB, maxB, minL, maxL, totalLanes, bs.additive)
        else
            -- Click on empty area: place note if not holding modifier, or clear selection if clicked outside
            if not bs.additive then
                if x >= 170 and y >= laneYStart and y <= laneYStart + totalLanes * laneH then
                    local snap = Logic.calculateLaneSnap(hitLineX, x, y, laneYStart, laneH, totalLanes)
                    Logic.clearNoteSelection()
                    Logic.addNote(snap.angle, snap.beat)
                else
                    Logic.clearNoteSelection()
                end
            end
        end
    elseif Logic.effectDrag and Logic.effectDrag.active then
        if Logic.effectDrag.effectIndex and Logic.chartEffects[Logic.effectDrag.effectIndex] then
            local currentEff = Logic.chartEffects[Logic.effectDrag.effectIndex]
            local currentId = currentEff.id
            table.sort(Logic.chartEffects, function(a, b) return (a.beat or 0) < (b.beat or 0) end)
            for idx, e in ipairs(Logic.chartEffects) do
                if e.id == currentId then
                    Logic.selectedEffectIndex = idx
                    break
                end
            end
            if Logic.effectDrag.hasChanged then
                Logic.playHitsound("basic")
            end
        end
        Logic.effectDrag = { active = false }
    end
end

function Update.wheelmoved(x, y)
    if y ~= 0 then
        local Draw = require("node.editor.draw")
        if Draw.isPointerOverUI() then
            return
        end

        if Logic.currentPage == "effects" then
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                Logic.effectsZoom = math.max(0.4, math.min(2.5, Logic.effectsZoom + y * 0.1))
            else
                Logic.stepBeat(-y)
            end
        elseif Logic.currentPage == "lane_editor" then
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                Logic.laneZoom = math.max(0.4, math.min(2.5, Logic.laneZoom + y * 0.1))
            else
                Logic.stepBeat(-y)
            end
        else
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                Logic.stepZoom = math.max(0.4, math.min(2.5, Logic.stepZoom + y * 0.1))
            else
                Logic.stepBeat(-y)
            end
        end
    end
end

function Update.keypressed(key)
    local isCtrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    if key == "space" then
        Logic.togglePlay()
    elseif key == "tab" then
        -- Cycle between Circle Editor -> Lane Editor -> Effects Timeline
        if Logic.currentPage == "editor" then
            Logic.currentPage = "lane_editor"
        elseif Logic.currentPage == "lane_editor" then
            Logic.currentPage = "effects"
        else
            Logic.currentPage = "editor"
        end
        if Logic.currentPage ~= "effects" then
            Logic.showEffectInspector = false
        end
        Logic.statusMessage = "Switched to " .. ((Logic.currentPage == "effects") and "Effects Timeline" or ((Logic.currentPage == "lane_editor") and "Lane Note Editor" or "Circle Note Editor"))
    elseif key == "l" and not isCtrl then
        Logic.currentPage = "lane_editor"
        Logic.showEffectInspector = false
        Logic.statusMessage = "Switched to Lane Note Editor"
    elseif key == "e" and not isCtrl then
        if Logic.currentPage == "editor" or Logic.currentPage == "lane_editor" then
            Logic.currentPage = "effects"
            Logic.statusMessage = "Switched to Effects Timeline"
        elseif Logic.currentPage == "effects" and Logic.ghostEffectPos and Logic.ghostEffectPos.valid then
            Logic.addEffect(Logic.ghostEffectPos.laneId, Logic.ghostEffectPos.beat)
        end
    elseif key == "a" and isCtrl then
        Logic.selectAllNotes()
    elseif key == "c" and isCtrl then
        Logic.copySelectedNotes()
    elseif key == "v" and isCtrl then
        Logic.pasteNotes(Logic.currentBeat)
    elseif key == "d" and isCtrl then
        Logic.duplicateSelectedNotes(1.0)
    elseif key == "r" and not isCtrl then
        if Logic.getSelectedNotesCount() > 0 then
            Logic.shuffleSelectedNotes()
        end
    elseif key == "left" then
        local delta = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and -4 or -1
        Logic.stepBeat(delta)
    elseif key == "right" then
        local delta = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 4 or 1
        Logic.stepBeat(delta)
    elseif key == "delete" or key == "backspace" then
        if Logic.currentPage == "effects" then
            Logic.deleteSelectedEffect()
        elseif Logic.getSelectedNotesCount() > 0 then
            Logic.deleteSelectedNotes()
        else
            Logic.deleteSelectedNote()
        end
    elseif key == "1" then
        Logic.selectedNoteType = "basic"
        if Logic.getSelectedNotesCount() > 0 then
            Logic.batchSetNoteType("basic")
        end
    elseif key == "2" then
        Logic.selectedNoteType = "slideup"
        if Logic.getSelectedNotesCount() > 0 then
            Logic.batchSetNoteType("slideup")
        end
    elseif key == "3" then
        Logic.selectedNoteType = "slidedown"
        if Logic.getSelectedNotesCount() > 0 then
            Logic.batchSetNoteType("slidedown")
        end
    elseif key == "s" and isCtrl then
        Logic.saveChart()
    elseif key == "z" and isCtrl then
        Logic.undo()
    elseif key == "y" and isCtrl then
        Logic.redo()
    elseif key == "escape" then
        if Logic.getSelectedNotesCount() > 0 then
            Logic.clearNoteSelection()
        elseif Logic.showEffectInspector then
            Logic.showEffectInspector = false
        elseif Logic.showNoteGimmickModal then
            Logic.showNoteGimmickModal = false
        else
            if Logic.audioSource then Logic.audioSource:stop() end
            _G.Gamestate.switch(require("node.menu"))
        end
    end
end

return Update
