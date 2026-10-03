local Logic = require("node.editor.logic")

local Draw = {
    panelWidth = 320,
    effectsHitLineX = 220,
    laneHitLineX = 220,
    effectsLaneYStart = 90,
    effectsLaneHeight = 85
}

function Draw.getPlayfieldCenter()
    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local centerX = winW / 2
    local centerY = winH / 2
    return centerX, centerY
end

function Draw.getHexagonVertices(cx, cy, r, rot)
    rot = rot or 0
    local vertices = {}
    for i = 0, 5 do
        local angle = rot + i * (math.pi / 3)
        table.insert(vertices, cx + math.cos(angle) * r)
        table.insert(vertices, cy + math.sin(angle) * r)
    end
    return vertices
end

function Draw.isPointerOverUI()
    if not Slab.IsVoidHovered() then
        return true
    end
    local mx, my = love.mouse.getPosition()
    if SlabWindow.IsObstructed(mx, my) then
        return true
    end
    return false
end

-- ==========================================
-- PAGE 1: NOTE EDITOR PLAYFIELD (CONCENTRIC RINGS)
-- ==========================================

function Draw.drawNotePlayfield()
    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local centerX, centerY = Draw.getPlayfieldCenter()

    local spacing = Logic.stepSpacing * Logic.stepZoom
    local minR = Logic.centerRadius
    local maxR = math.max(winW, winH) * 0.75

    -- 1. Deep Matte Black Background & Subtle Center Vignette
    love.graphics.setColor(0.04, 0.04, 0.04, 1.0)
    love.graphics.rectangle("fill", 0, 0, winW, winH)

    -- Subtle center judgment anchor gradient
    love.graphics.setColor(0.12, 0.12, 0.12, 0.35)
    love.graphics.circle("fill", centerX, centerY, minR + 40)

    -- 2. Precision Concentric Beat Rings & Radial Guides
    local minBeat = Logic.getMinBeat()
    local startBeat = math.floor(math.max(minBeat, Logic.currentBeat - 1))
    local endBeat = math.floor(Logic.currentBeat + (maxR / spacing) + 2)

    -- Radial Angle Guides (Clean thin architectural lines)
    if Logic.effects.showAngleGuides and Logic.angleSteps > 0 then
        love.graphics.setColor(0.20, 0.20, 0.20, 0.40)
        love.graphics.setLineWidth(1)
        for i = 0, Logic.angleSteps - 1 do
            local angle = (i / Logic.angleSteps) * math.pi * 2
            local x1 = centerX + math.cos(angle) * minR
            local y1 = centerY + math.sin(angle) * minR
            local x2 = centerX + math.cos(angle) * maxR
            local y2 = centerY + math.sin(angle) * maxR
            love.graphics.line(x1, y1, x2, y2)
        end
    end

    -- Concentric Rings
    local subStep = 1 / math.min(4, Logic.beatSnap)
    for b = startBeat, endBeat, subStep do
        local isMajorBeat = (math.abs(b - math.floor(b + 0.001)) < 0.001)
        local ringR = minR + (b - Logic.currentBeat) * spacing

        if ringR >= minR - 5 and ringR <= maxR then
            local isCurrentHitRing = math.abs(b - Logic.currentBeat) < 0.06

            if isCurrentHitRing then
                -- Playhead ring: Crisp pure white highlight
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.setLineWidth(2.0)
                love.graphics.circle("line", centerX, centerY, ringR)
            elseif isMajorBeat then
                -- Major beat ring: Solid clean gray with beat index
                love.graphics.setColor(0.40, 0.40, 0.40, 0.70)
                love.graphics.setLineWidth(1.2)
                love.graphics.circle("line", centerX, centerY, ringR)

                if Logic.effects.showBeatNumbers and ringR > 42 then
                    love.graphics.setColor(0.65, 0.65, 0.65, 0.85)
                    love.graphics.print(string.format("%d", math.floor(b)), centerX + 4, centerY - ringR + 2)
                end
            else
                -- Minor subdivision ring: Low opacity hairline
                love.graphics.setColor(0.18, 0.18, 0.18, 0.45)
                love.graphics.setLineWidth(1.0)
                love.graphics.circle("line", centerX, centerY, ringR)
            end
        end
    end

    -- 3. Center Target Indicator (Minimal Geometric Hexagon)
    local hexRing = Draw.getHexagonVertices(centerX, centerY, 9)
    local hexSolid = Draw.getHexagonVertices(centerX, centerY, 5)

    love.graphics.setColor(0.3, 0.3, 0.3, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", hexRing)

    love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
    love.graphics.polygon("fill", hexSolid)

    -- 4. Bezier Curves & Notes
    Draw.drawSimultaneousNoteCurves(centerX, centerY, spacing, minR, maxR)
    Draw.drawNotes(centerX, centerY, spacing, minR, maxR)

    -- 5. Ghost Note cursor
    Draw.drawGhostNote(centerX, centerY)
end

function Draw.drawSimultaneousNoteCurves(centerX, centerY, spacing, minR, maxR)
    local screenCenterX = love.graphics.getWidth() / 2

    local beatGroups = {}
    for _, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local roundedKey = string.format("%.4f", nBeat)
        beatGroups[roundedKey] = beatGroups[roundedKey] or { beat = nBeat, notes = {} }
        table.insert(beatGroups[roundedKey].notes, note)
    end

    for _, group in pairs(beatGroups) do
        if #group.notes == 2 then
            local nBeat = group.beat
            local nRadius = minR + (nBeat - Logic.currentBeat) * spacing
            local isPastHit = (Logic.isPlaying or Logic.previewActive) and (nBeat < Logic.currentBeat)

            if nRadius >= minR and nRadius <= maxR + 50 and not isPastHit then
                local noteVisuals = {}
                for _, n in ipairs(group.notes) do
                    local vx, vy, vr, va, valpha, vvisible = Logic.getNoteRenderPos(n, centerX, centerY, spacing, minR)
                    if vvisible and valpha > 0.05 then
                        table.insert(noteVisuals, {
                            note = n,
                            x = vx,
                            y = vy,
                            radius = vr,
                            angle = va,
                            alpha = valpha,
                            side = (vx < screenCenterX) and "left" or "right"
                        })
                    end
                end

                if #noteVisuals == 2 and (noteVisuals[1].side ~= noteVisuals[2].side) then
                    local nv1 = noteVisuals[1]
                    local nv2 = noteVisuals[2]
                    local lineAlpha = 0.3 * math.min(nv1.alpha, nv2.alpha)

                    -- Simple straight line connecting simultaneous notes (0.3 opacity)
                    love.graphics.setLineWidth(1.5)
                    love.graphics.setColor(1.0, 1.0, 1.0, lineAlpha)
                    love.graphics.line(nv1.x, nv1.y, nv2.x, nv2.y)
                end
            end
        end
    end
end

function Draw.drawNotes(centerX, centerY, spacing, minR, maxR)
    for i, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local rawRadius = minR + (nBeat - Logic.currentBeat) * spacing
        local hasGimmick = (note.gimmick ~= nil and note.gimmick.type ~= nil and note.gimmick.type ~= "none")

        local targetX, targetY, nRadius, nAngle, noteAlpha, isVisible = Logic.getNoteRenderPos(note, centerX, centerY,
            spacing, minR)

        local isPastHit = (Logic.isPlaying or Logic.previewActive) and (nBeat < Logic.currentBeat)
        if rawRadius < minR or isPastHit then
            isVisible = false
        end

        -- Ghost / Anchor Marker for Gimmick note on Beat Grid
        if hasGimmick and not Logic.isPlaying and rawRadius >= minR and rawRadius <= maxR + 50 then
            local baseX = centerX + math.cos(note.angle or 0) * rawRadius
            local baseY = centerY + math.sin(note.angle or 0) * rawRadius

            -- Thin dashed connection line
            love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
            love.graphics.setLineWidth(1)
            love.graphics.line(baseX, baseY, targetX, targetY)

            -- Anchor circle
            love.graphics.setColor(0.7, 0.7, 0.7, 0.6)
            love.graphics.circle("line", baseX, baseY, 6)
        end

        if isVisible and nRadius >= minR and nRadius <= maxR + 50 then
            local isSelected = Logic.isNoteSelected(i)

            local w, h = 22, 22
            local halfW, halfH = w / 2, h / 2
            local playbackTime = Logic.currentTime or 0

            love.graphics.push()
            love.graphics.translate(targetX, targetY)

            local baseAngle = nAngle or note.angle or 0
            local outerRot = baseAngle
            if note.type == "slideup" then
                outerRot = baseAngle - playbackTime * 2.0
            elseif note.type == "slidedown" then
                outerRot = baseAngle + playbackTime * 2.0
            else
                outerRot = baseAngle + playbackTime * 1.5
            end
            love.graphics.rotate(outerRot)

            -- Selection highlight (Crisp white/gray double stroke)
            if isSelected then
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95 * noteAlpha)
                love.graphics.setLineWidth(2.0)
                love.graphics.rectangle("line", -halfW - 4, -halfH - 4, w + 8, h + 8)
            end

            -- Gimmick indicator badge
            if hasGimmick then
                love.graphics.setColor(0.65, 0.65, 0.65, 0.8 * noteAlpha)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", -halfW - 2, -halfH - 2, w + 4, h + 4)
            end

            -- Outer box
            love.graphics.setColor(0.92, 0.92, 0.92, 0.95 * noteAlpha)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", -halfW, -halfH, w, h)

            -- Inner glyph distinguishing Note Types cleanly
            love.graphics.push()
            local innerRot = 0
            if note.type == "basic" then
                innerRot = playbackTime * 2.5
            elseif note.type == "slideup" then
                innerRot = -playbackTime * 3.5 - (math.pi / 4)
            elseif note.type == "slidedown" then
                innerRot = playbackTime * 3.5 + (math.pi / 4)
            end
            love.graphics.rotate(innerRot)

            if note.type == "slideup" then
                -- Triangle Up arrow icon
                love.graphics.setColor(1.0, 1.0, 1.0, 1.0 * noteAlpha)
                love.graphics.polygon("fill", -4, 4, 4, 4, 0, -4)
            elseif note.type == "slidedown" then
                -- Triangle Down arrow icon
                love.graphics.setColor(0.85, 0.85, 0.85, 1.0 * noteAlpha)
                love.graphics.polygon("fill", -4, -4, 4, -4, 0, 4)
            else
                -- Basic note solid center square
                local innerW, innerH = w * 0.32, h * 0.32
                love.graphics.setColor(1.0, 1.0, 1.0, 1.0 * noteAlpha)
                love.graphics.rectangle("fill", -innerW / 2, -innerH / 2, innerW, innerH)
            end
            love.graphics.pop()

            love.graphics.pop()
        end
    end
end

function Draw.getCursorDeadzoneAxis(cx, cy, textWidth, textHeight, offset)
    offset = offset or 14
    textWidth = textWidth or 130
    textHeight = textHeight or 18

    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()

    local c_x_ax = 1
    local c_y_ax = 1

    if cx + offset + textWidth > winW - 10 then
        c_x_ax = -1
    end

    if cy + offset + textHeight > winH - 55 then
        c_y_ax = -1
    elseif cy - offset - textHeight < 55 then
        c_y_ax = 1
    end

    local textX = (c_x_ax == 1) and (cx + offset * c_x_ax) or (cx - textWidth + offset * c_x_ax)
    local textY = (c_y_ax == 1) and (cy + offset * c_y_ax) or (cy - textHeight + offset * c_y_ax)

    return textX, textY, c_x_ax, c_y_ax
end

function Draw.drawGhostNote(centerX, centerY)
    if Logic.isPlaying then return end
    if Draw.isPointerOverUI() then
        Logic.ghostPos.valid = false
        return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    if Logic.camera and Logic.camera.toWorldCoords then
        mouseX, mouseY = Logic.camera:toWorldCoords(mouseX, mouseY)
    end
    local snap = Logic.calculateSnap(centerX, centerY, mouseX, mouseY)
    Logic.ghostPos = snap

    local canPlace, reason, side, extra = Logic.canPlaceNote(snap.angle, snap.beat, Logic.selectedNoteType)

    local text = ""
    local textColor = { 0.88, 0.88, 0.88, 1.0 }

    if not canPlace then
        if reason == "blocked_side" then
            text = string.format("Beat %.2f [Blocked: %s Side]", snap.beat, (side or ""):upper())
        elseif reason == "blocked_slide_conflict" then
            text = string.format("Beat %.2f [Blocked: Has %s]", snap.beat, (extra or "Slide"):upper())
        elseif reason == "blocked_max" then
            text = string.format("Beat %.2f [Blocked: Max 2 Notes]", snap.beat)
        else
            text = string.format("Beat %.2f [Blocked]", snap.beat)
        end
        textColor = { 0.60, 0.60, 0.60, 1.0 }
    elseif reason == "update" then
        text = string.format("Beat %.2f (Update)", snap.beat)
        textColor = { 1.0, 1.0, 1.0, 1.0 }
    else
        text = string.format("Beat %.2f (%s - %s)", snap.beat, (side or ""):upper(),
            (Logic.selectedNoteType or "basic"):upper())
    end

    local w, h = 22, 22
    local halfW, halfH = w / 2, h / 2
    local playbackTime = Logic.currentTime or 0

    love.graphics.push()
    love.graphics.translate(snap.x, snap.y)

    local outerRot = snap.angle or 0
    if Logic.selectedNoteType == "slideup" then
        outerRot = outerRot - playbackTime * 2.0
    elseif Logic.selectedNoteType == "slidedown" then
        outerRot = outerRot + playbackTime * 2.0
    else
        outerRot = outerRot + playbackTime * 1.5
    end
    love.graphics.rotate(outerRot)

    -- Ghost outline
    love.graphics.setColor(canPlace and { 0.9, 0.9, 0.9, 0.7 } or { 0.4, 0.4, 0.4, 0.6 })
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", -halfW, -halfH, w, h)

    love.graphics.push()
    local innerRot = 0
    if Logic.selectedNoteType == "basic" then
        innerRot = playbackTime * 2.5
    elseif Logic.selectedNoteType == "slideup" then
        innerRot = -playbackTime * 3.5 - (math.pi / 4)
    elseif Logic.selectedNoteType == "slidedown" then
        innerRot = playbackTime * 3.5 + (math.pi / 4)
    end
    love.graphics.rotate(innerRot)

    if Logic.selectedNoteType == "slideup" then
        love.graphics.setColor(1, 1, 1, canPlace and 0.8 or 0.4)
        love.graphics.polygon("fill", -4, 4, 4, 4, 0, -4)
    elseif Logic.selectedNoteType == "slidedown" then
        love.graphics.setColor(0.85, 0.85, 0.85, canPlace and 0.8 or 0.4)
        love.graphics.polygon("fill", -4, -4, 4, -4, 0, 4)
    else
        local innerW, innerH = w * 0.32, h * 0.32
        love.graphics.setColor(1, 1, 1, canPlace and 0.8 or 0.4)
        love.graphics.rectangle("fill", -innerW / 2, -innerH / 2, innerW, innerH)
    end
    love.graphics.pop()
    love.graphics.pop()

    -- Ghost badge (drawn directly in world space near note or preserved cleanly)
    local screenSnapX, screenSnapY = snap.x, snap.y
    if Logic.camera and Logic.camera.toCameraCoords then
        screenSnapX, screenSnapY = Logic.camera:toCameraCoords(snap.x, snap.y)
    end

    local font = love.graphics.getFont()
    local textW = font and font:getWidth(text) or 120
    local textH = font and font:getHeight() or 16
    local printX, printY = Draw.getCursorDeadzoneAxis(screenSnapX, screenSnapY, textW, textH, 14)

    -- Save current world badge info for Draw.ui() to render on screen space cleanly
    Draw.ghostBadge = {
        text = text,
        textColor = textColor,
        x = printX,
        y = printY,
        w = textW,
        h = textH
    }
end

-- ==========================================
-- PAGE 2: EFFECTS TIMELINE PLAYFIELD (MULTI-LANE RIGHT-TO-LEFT)
-- ==========================================

function Draw.drawEffectsPlayfield()
    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local hitLineX = Draw.effectsHitLineX
    local laneYStart = Draw.effectsLaneYStart
    local laneH = Draw.effectsLaneHeight
    local lanes = Logic.effectLanes
    local spacing = Logic.effectsSpacing * Logic.effectsZoom
    local headerW = 140

    -- 1. Dark Solid Background
    love.graphics.setColor(0.04, 0.04, 0.04, 1.0)
    love.graphics.rectangle("fill", 0, 0, winW, winH)

    -- 2. Render Lanes
    for idx, lane in ipairs(lanes) do
        local ly = laneYStart + (idx - 1) * laneH
        local isEven = (idx % 2 == 0)

        -- Lane track background (Subtle alternating shades)
        love.graphics.setColor(isEven and { 0.07, 0.07, 0.07, 0.95 } or { 0.05, 0.05, 0.05, 0.95 })
        love.graphics.rectangle("fill", 0, ly, winW, laneH)

        -- Lane border lines
        love.graphics.setColor(0.14, 0.14, 0.14, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, ly, winW, ly)
        love.graphics.line(0, ly + laneH, winW, ly + laneH)

        -- Lane Left Header Card (Clean dark minimal card)
        love.graphics.setColor(0.10, 0.10, 0.10, 0.98)
        love.graphics.rectangle("fill", 8, ly + 6, headerW, laneH - 12, 1, 1)

        love.graphics.setColor(0.22, 0.22, 0.22, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 8, ly + 6, headerW, laneH - 12, 1, 1)

        -- Lane Title & Number
        love.graphics.setColor(0.92, 0.92, 0.92, 1.0)
        love.graphics.print(string.format("%s %s", lane.icon or "-", lane.name), 16, ly + 14)

        love.graphics.setColor(0.48, 0.48, 0.48, 0.9)
        love.graphics.print(string.format("TRACK #%d", idx), 16, ly + 34)
    end

    -- 3. Beat Timeline Grid Lines
    local minBeat = Logic.getMinBeat()
    local visibleStartBeat = math.floor(math.max(minBeat, Logic.currentBeat - (hitLineX / spacing)))
    local visibleEndBeat = math.floor(Logic.currentBeat + ((winW - hitLineX) / spacing) + 3)
    local subStep = 1 / math.min(8, Logic.beatSnap)
    local totalLanesH = #lanes * laneH

    for b = visibleStartBeat, visibleEndBeat, subStep do
        local bx = hitLineX + (b - Logic.currentBeat) * spacing
        if bx >= headerW + 15 and bx <= winW + 20 then
            local isMajorBeat = (math.abs(b - math.floor(b + 0.001)) < 0.001)

            if isMajorBeat then
                love.graphics.setColor(0.28, 0.28, 0.28, 0.70)
                love.graphics.setLineWidth(1.2)
                love.graphics.line(bx, laneYStart - 18, bx, laneYStart + totalLanesH)

                love.graphics.setColor(0.65, 0.65, 0.65, 0.85)
                love.graphics.print(string.format("%d", math.floor(b)), bx + 3, laneYStart - 16)
            else
                love.graphics.setColor(0.12, 0.12, 0.12, 0.50)
                love.graphics.setLineWidth(1.0)
                love.graphics.line(bx, laneYStart, bx, laneYStart + totalLanesH)
            end
        end
    end

    -- 4. Effect Events
    local hovered = Logic.hoveredEffectElement
    local isDragging = (Logic.effectDrag and Logic.effectDrag.active)
    local bpm = math.max(1, tonumber(Logic.bpm) or 120)

    for i, eff in ipairs(Logic.chartEffects) do
        local effBeat = eff.beat or Logic.timeToBeat(eff.time or 0)
        local effX = hitLineX + (effBeat - Logic.currentBeat) * spacing
        local laneIndex = 1
        for lIdx, l in ipairs(lanes) do
            if l.id == eff.lane then
                laneIndex = lIdx
                break
            end
        end

        local effY = laneYStart + (laneIndex - 1) * laneH + (laneH / 2)
        local isSelected = (Logic.selectedEffectIndex == i)
        local p = eff.params or {}

        local durSec = p.duration or ((eff.lane == "zoom") and 0.25 or 0.8)
        local durBeats = durSec * (bpm / 60)
        local isRepeat = (p.repeatEnabled and p.repeatUntilBeat and p.repeatUntilBeat > effBeat)
        local spanEndBeat = isRepeat and p.repeatUntilBeat or (effBeat + durBeats)
        local endX = hitLineX + (spanEndBeat - Logic.currentBeat) * spacing

        -- Duration / Span Bar
        if isRepeat then
            if endX >= headerW + 15 and effX <= winW + 50 then
                local barStartX = math.max(headerW + 15, effX)
                local barEndX = math.min(winW + 20, endX)
                local barW = math.max(4, barEndX - barStartX)

                love.graphics.setColor(0.20, 0.20, 0.20, isSelected and 0.40 or 0.25)
                love.graphics.rectangle("fill", barStartX, effY - 9, barW, 18, 1, 1)

                love.graphics.setColor(isSelected and { 0.8, 0.8, 0.8, 0.8 } or { 0.45, 0.45, 0.45, 0.6 })
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", barStartX, effY - 9, barW, 18, 1, 1)

                -- Step ticks
                if p.repeatStep and p.repeatStep > 0 then
                    local numSteps = math.floor(((p.repeatUntilBeat - effBeat) + 0.001) / p.repeatStep)
                    for sIdx = 1, numSteps do
                        local stepBeat = effBeat + sIdx * p.repeatStep
                        local stepX = hitLineX + (stepBeat - Logic.currentBeat) * spacing
                        if stepX >= headerW + 15 and stepX <= winW + 50 then
                            local isStepHovered = (hovered and hovered.effectIndex == i and hovered.hitType == "handle_step" and sIdx == 1)
                            if sIdx == 1 then
                                love.graphics.setColor(isStepHovered and { 1, 1, 1, 1 } or { 0.7, 0.7, 0.7, 0.9 })
                                love.graphics.rectangle("fill", stepX - 3, effY - 10, 6, 20, 1, 1)
                            else
                                love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                                love.graphics.circle("fill", stepX, effY, 2)
                            end
                        end
                    end
                end

                -- Resize Handle Bar
                if endX >= headerW + 15 and endX <= winW + 50 then
                    local isEndHovered = (hovered and hovered.effectIndex == i and hovered.hitType == "handle_repeat")
                    local isEndDragged = (isDragging and Logic.effectDrag.effectIndex == i and Logic.effectDrag.dragType == "resize_repeat")

                    love.graphics.setColor((isEndHovered or isEndDragged) and { 1, 1, 1, 1 } or { 0.7, 0.7, 0.7, 0.9 })
                    love.graphics.rectangle("fill", endX - 4, effY - 12, 8, 24, 1, 1)
                    love.graphics.setColor(0, 0, 0, 0.8)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", endX - 4, effY - 12, 8, 24, 1, 1)
                end
            end
        else
            if durBeats > 0 and endX >= headerW + 15 and effX <= winW + 50 then
                local barStartX = math.max(headerW + 15, effX)
                local barEndX = math.min(winW + 20, endX)
                local barW = math.max(2, barEndX - barStartX)

                love.graphics.setColor(0.18, 0.18, 0.18, isSelected and 0.35 or 0.20)
                love.graphics.rectangle("fill", barStartX, effY - 7, barW, 14, 1, 1)

                love.graphics.setColor(isSelected and { 0.75, 0.75, 0.75, 0.7 } or { 0.40, 0.40, 0.40, 0.5 })
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", barStartX, effY - 7, barW, 14, 1, 1)

                local isDurHovered = (hovered and hovered.effectIndex == i and hovered.hitType == "handle_duration")
                local isDurDragged = (isDragging and Logic.effectDrag.effectIndex == i and Logic.effectDrag.dragType == "resize_duration")

                love.graphics.setColor((isDurHovered or isDurDragged) and { 1, 1, 1, 1 } or { 0.65, 0.65, 0.65, 0.85 })
                love.graphics.rectangle("fill", endX - 3, effY - 10, 6, 20, 1, 1)
            end
        end

        -- Effect Block Body
        if effX >= headerW + 15 and effX <= winW + 50 then
            local blockW = 32
            local blockH = 26
            local bx = effX - blockW / 2
            local by = effY - blockH / 2
            local isBodyHovered = (hovered and hovered.effectIndex == i and hovered.hitType == "body")
            local isBodyDragged = (isDragging and Logic.effectDrag.effectIndex == i and Logic.effectDrag.dragType == "move")

            if isSelected or isBodyDragged then
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", bx - 2, by - 2, blockW + 4, blockH + 4, 1, 1)
            elseif isBodyHovered then
                love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", bx - 2, by - 2, blockW + 4, blockH + 4, 1, 1)
            end

            love.graphics.setColor(0.12, 0.12, 0.12, 0.98)
            love.graphics.rectangle("fill", bx, by, blockW, blockH, 1, 1)

            love.graphics.setColor(0.45, 0.45, 0.45, 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", bx, by, blockW, blockH, 1, 1)

            -- Centered minimal label
            love.graphics.setColor(0.95, 0.95, 0.95, 0.95)
            local iconStr = eff.lane:sub(1, 2):upper()
            love.graphics.print(iconStr, bx + 7, by + 5)
        end
    end

    -- 5. Drag Tooltip Overlay
    if isDragging and Logic.effectDrag.effectIndex and Logic.chartEffects[Logic.effectDrag.effectIndex] then
        local eff = Logic.chartEffects[Logic.effectDrag.effectIndex]
        local mx, my = love.mouse.getPosition()
        local tipText = ""
        if Logic.effectDrag.dragType == "move" then
            tipText = string.format("Move: Beat %.2f (%.3fs)", eff.beat or 0, eff.time or 0)
        elseif Logic.effectDrag.dragType == "resize_repeat" then
            local p = eff.params or {}
            tipText = string.format("Repeat Until: Beat %.2f (%.2fb)", p.repeatUntilBeat or 0, (p.repeatUntilBeat or 0) - (eff.beat or 0))
        elseif Logic.effectDrag.dragType == "resize_duration" then
            local p = eff.params or {}
            local durSec = p.duration or 0.8
            local durBeats = durSec * (bpm / 60)
            tipText = string.format("Duration: %.2f beats (%.2fs)", durBeats, durSec)
        end

        love.graphics.setColor(0.08, 0.08, 0.08, 0.95)
        love.graphics.rectangle("fill", mx + 12, my - 24, 200, 20, 1, 1)
        love.graphics.setColor(0.35, 0.35, 0.35, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", mx + 12, my - 24, 200, 20, 1, 1)
        love.graphics.setColor(0.92, 0.92, 0.92, 1)
        love.graphics.print(tipText, mx + 18, my - 21)
    end

    -- 6. Playhead Cursor (Clean vertical needle)
    love.graphics.setColor(0.95, 0.95, 0.95, 1.0)
    love.graphics.setLineWidth(2.0)
    love.graphics.line(hitLineX, laneYStart - 24, hitLineX, laneYStart + totalLanesH + 12)

    love.graphics.setColor(0.20, 0.20, 0.20, 0.95)
    love.graphics.rectangle("fill", hitLineX - 40, laneYStart - 32, 80, 16, 1, 1)
    love.graphics.setColor(0.50, 0.50, 0.50, 0.9)
    love.graphics.rectangle("line", hitLineX - 40, laneYStart - 32, 80, 16, 1, 1)

    love.graphics.setColor(0.95, 0.95, 0.95, 1.0)
    love.graphics.print(string.format("B %.2f", Logic.currentBeat), hitLineX - 24, laneYStart - 31)

    -- 7. Ghost Effect Cursor
    if not Logic.isPlaying and not isDragging and not Draw.isPointerOverUI() then
        local mx, my = love.mouse.getPosition()
        if mx >= headerW + 15 and my >= laneYStart and my <= laneYStart + totalLanesH then
            local snapEff = Logic.calculateEffectsSnap(hitLineX, mx, my, laneYStart, laneH, #lanes)
            Logic.ghostEffectPos = snapEff

            local gW = 30
            local gH = 24
            local gx = snapEff.x - gW / 2
            local gy = snapEff.y - gH / 2

            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
            love.graphics.rectangle("fill", gx, gy, gW, gH, 1, 1)

            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", gx, gy, gW, gH, 1, 1)

            love.graphics.setColor(0.85, 0.85, 0.85, 0.9)
            love.graphics.print(string.format("B %.2f", snapEff.beat), snapEff.x + 18, snapEff.y - 7)
        else
            Logic.ghostEffectPos.valid = false
        end
    end
end

-- ==========================================
-- PAGE 3: LANE NOTE EDITOR PLAYFIELD (HORIZONTAL MULTI-LANE)
-- ==========================================

function Draw.drawLanePlayfield()
    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local hitLineX = Draw.laneHitLineX or 220
    local totalLanes = Logic.angleSteps or 16
    if totalLanes <= 0 then totalLanes = 16 end
    local laneYStart = 50
    local availH = winH - laneYStart - 52
    local laneH = math.max(20, math.min(36, math.floor(availH / totalLanes)))
    local spacing = Logic.laneSpacing * Logic.laneZoom
    local headerW = 140

    -- 1. Dark Clean Solid Background
    love.graphics.setColor(0.04, 0.04, 0.04, 1.0)
    love.graphics.rectangle("fill", 0, 0, winW, winH)

    -- 2. Render Lanes
    local totalHeight = totalLanes * laneH
    for idx = 1, totalLanes do
        local ly = laneYStart + (idx - 1) * laneH
        local isEven = (idx % 2 == 0)

        love.graphics.setColor(isEven and { 0.06, 0.06, 0.06, 0.95 } or { 0.045, 0.045, 0.045, 0.95 })
        love.graphics.rectangle("fill", 0, ly, winW, laneH)

        love.graphics.setColor(0.12, 0.12, 0.12, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, ly, winW, ly)
        love.graphics.line(0, ly + laneH, winW, ly + laneH)

        -- Lane Left Header Card
        local laneAngle = Logic.laneToAngle(idx, totalLanes)
        local deg = math.deg(laneAngle)
        local isLeft = (math.cos(laneAngle) < 0)

        love.graphics.setColor(0.09, 0.09, 0.09, 0.98)
        love.graphics.rectangle("fill", 6, ly + 2, headerW, laneH - 4, 1, 1)

        love.graphics.setColor(0.20, 0.20, 0.20, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 6, ly + 2, headerW, laneH - 4, 1, 1)

        love.graphics.setColor(0.85, 0.85, 0.85, 0.95)
        love.graphics.print(string.format("L%02d  %.0f deg [%s]", idx, deg, isLeft and "L" or "R"), 14, ly + (laneH * 0.5) - 6)
    end

    -- 3. Beat Grid Lines
    local minBeat = Logic.getMinBeat()
    local visibleStartBeat = math.floor(math.max(minBeat, Logic.currentBeat - (hitLineX / spacing)))
    local visibleEndBeat = math.floor(Logic.currentBeat + ((winW - hitLineX) / spacing) + 3)
    local subStep = 1 / math.min(8, Logic.beatSnap)

    for b = visibleStartBeat, visibleEndBeat, subStep do
        local bx = hitLineX + (b - Logic.currentBeat) * spacing
        if bx >= headerW + 15 and bx <= winW + 20 then
            local isMajorBeat = (math.abs(b - math.floor(b + 0.001)) < 0.001)
            if isMajorBeat then
                love.graphics.setColor(0.28, 0.28, 0.28, 0.70)
                love.graphics.setLineWidth(1.2)
                love.graphics.line(bx, laneYStart - 14, bx, laneYStart + totalHeight)

                love.graphics.setColor(0.65, 0.65, 0.65, 0.85)
                love.graphics.print(string.format("%d", math.floor(b)), bx + 3, laneYStart - 15)
            else
                love.graphics.setColor(0.12, 0.12, 0.12, 0.45)
                love.graphics.setLineWidth(1.0)
                love.graphics.line(bx, laneYStart, bx, laneYStart + totalHeight)
            end
        end
    end

    -- 4. Playhead Line
    love.graphics.setColor(0.95, 0.95, 0.95, 1.0)
    love.graphics.setLineWidth(2.0)
    love.graphics.line(hitLineX, laneYStart - 18, hitLineX, laneYStart + totalHeight + 8)

    love.graphics.setColor(0.20, 0.20, 0.20, 0.95)
    love.graphics.rectangle("fill", hitLineX - 35, laneYStart - 28, 70, 16, 1, 1)
    love.graphics.setColor(0.50, 0.50, 0.50, 0.9)
    love.graphics.rectangle("line", hitLineX - 35, laneYStart - 28, 70, 16, 1, 1)

    love.graphics.setColor(0.95, 0.95, 0.95, 1.0)
    love.graphics.print(string.format("B %.2f", Logic.currentBeat), hitLineX - 22, laneYStart - 27)

    -- 5. Render Notes in Lanes
    local hovered = nil
    if not Draw.isPointerOverUI() and not Logic.laneBoxSelect.active then
        local mx, my = love.mouse.getPosition()
        hovered = Logic.getLaneNoteHitInfo(hitLineX, spacing, laneYStart, laneH, totalLanes, mx, my)
    end

    for i, note in ipairs(Logic.notes) do
        local nBeat = note.beat or Logic.timeToBeat(note.time or 0)
        local nx = hitLineX + (nBeat - Logic.currentBeat) * spacing
        local laneIdx = Logic.angleToLane(note.angle or 0, totalLanes)
        local ny = laneYStart + (laneIdx - 1) * laneH + laneH * 0.5

        local isPast = (Logic.isPlaying or Logic.previewActive) and (nBeat < Logic.currentBeat)
        if not isPast and nx >= headerW + 16 and nx <= winW + 40 then
            local isSelected = Logic.isNoteSelected(i)
            local isHoveredNote = (hovered and hovered.noteIndex == i)
            local noteW = 24
            local noteH = math.min(20, laneH - 4)

            -- Selection highlight
            if isSelected then
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.setLineWidth(2.0)
                love.graphics.rectangle("line", nx - (noteW * 0.5) - 3, ny - (noteH * 0.5) - 2, noteW + 6, noteH + 4, 1, 1)
            elseif isHoveredNote then
                love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", nx - (noteW * 0.5) - 2, ny - (noteH * 0.5) - 1, noteW + 4, noteH + 2, 1, 1)
            end

            -- Note Body
            local nType = note.type or "basic"
            love.graphics.setColor(0.90, 0.90, 0.90, 0.95)
            love.graphics.rectangle("fill", nx - noteW * 0.5, ny - noteH * 0.5, noteW, noteH, 1, 1)

            love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
            if nType == "slideup" then
                love.graphics.polygon("fill", nx - 4, ny + 3, nx + 4, ny + 3, nx, ny - 3)
            elseif nType == "slidedown" then
                love.graphics.polygon("fill", nx - 4, ny - 3, nx + 4, ny - 3, nx, ny + 3)
            else
                love.graphics.rectangle("fill", nx - 3, ny - 3, 6, 6, 1, 1)
            end

            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", nx - noteW * 0.5, ny - noteH * 0.5, noteW, noteH, 1, 1)

            -- Gimmick indicator marker
            local hasGimmick = (note.gimmick ~= nil and note.gimmick.type ~= nil and note.gimmick.type ~= "none" and note.gimmick.type ~= "")
            if hasGimmick then
                love.graphics.setColor(0.3, 0.3, 0.3, 0.9)
                love.graphics.rectangle("fill", nx + (noteW * 0.5) - 6, ny - (noteH * 0.5), 6, 6)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("line", nx + (noteW * 0.5) - 6, ny - (noteH * 0.5), 6, 6)
            end
        end
    end

    -- 6. Ghost Note Cursor Preview
    if not Logic.isPlaying and not Logic.laneBoxSelect.active and not Draw.isPointerOverUI() then
        local mx, my = love.mouse.getPosition()
        if mx >= headerW + 15 and my >= laneYStart and my <= laneYStart + totalHeight then
            local snap = Logic.calculateLaneSnap(hitLineX, mx, my, laneYStart, laneH, totalLanes)
            Logic.ghostLaneNotePos = snap

            local gw = 24
            local gh = math.min(20, laneH - 4)
            local gx = snap.x
            local gy = snap.y

            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
            love.graphics.rectangle("fill", gx - gw * 0.5, gy - gh * 0.5, gw, gh, 1, 1)
            love.graphics.setColor(0.8, 0.8, 0.8, 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", gx - gw * 0.5, gy - gh * 0.5, gw, gh, 1, 1)

            local deg = math.deg(snap.angle)
            local tipText = string.format("B %.2f | L%d (%.0f deg)", snap.beat, snap.laneIndex, deg)
            love.graphics.setColor(0.08, 0.08, 0.08, 0.92)
            love.graphics.rectangle("fill", gx + 14, gy - 10, 120, 18, 1, 1)
            love.graphics.setColor(0.25, 0.25, 0.25, 0.9)
            love.graphics.rectangle("line", gx + 14, gy - 10, 120, 18, 1, 1)
            love.graphics.setColor(0.9, 0.9, 0.9, 0.95)
            love.graphics.print(tipText, gx + 18, gy - 8)
        else
            Logic.ghostLaneNotePos.valid = false
        end
    end

    -- 7. Box-Selection (Marquee Drag) Overlay
    if Logic.laneBoxSelect.active then
        local bs = Logic.laneBoxSelect
        local startBeat = bs.startBeat or (Logic.currentBeat + (bs.startX - hitLineX) / spacing)
        local curBeat = Logic.currentBeat + (bs.curX - hitLineX) / spacing
        local minB = math.min(startBeat, curBeat)
        local maxB = math.max(startBeat, curBeat)

        local bx1 = hitLineX + (minB - Logic.currentBeat) * spacing
        local bx2 = hitLineX + (maxB - Logic.currentBeat) * spacing
        local by1 = math.min(bs.startY, bs.curY)
        local by2 = math.max(bs.startY, bs.curY)

        local bx = bx1
        local by = by1
        local bw = math.max(2, bx2 - bx1)
        local bh = math.max(2, by2 - by1)

        love.graphics.setColor(0.25, 0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", bx, by, bw, bh, 1, 1)

        love.graphics.setColor(0.85, 0.85, 0.85, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx, by, bw, bh, 1, 1)
    end
end

-- ==========================================
-- UI TOP BAR & PAGE NAVIGATION
-- ==========================================

function Draw.drawTopBar()
    local winW = love.graphics.getWidth()

    if Slab.BeginWindow('TeleiaTopBarNav', {
            X = 0, Y = 0, W = winW, H = 42,
            NoSavedSettings = true, AllowResize = false, AllowMove = false,
            Border = 1, BgColor = { 0.07, 0.07, 0.07, 1.0 },
            AutoScrollX = false
        }) then
        -- Return to Menu
        if Slab.Button("< Lib", { W = 55, H = 26 }) then
            if Logic.audioSource then Logic.audioSource:stop() end
            _G.Gamestate.switch(require("node.menu"))
        end

        Slab.SameLine({ Pad = 10 })
        Slab.Text("VIEW:", { Color = { 0.50, 0.50, 0.50, 1.0 } })

        Slab.SameLine({ Pad = 5 })
        local isEditor = (Logic.currentPage == "editor")
        if Slab.Button("Radial [Tab]", { W = 85, H = 26, Active = isEditor }) then
            Logic.currentPage = "editor"
            Logic.showEffectInspector = false
        end

        Slab.SameLine({ Pad = 3 })
        local isLane = (Logic.currentPage == "lane_editor")
        if Slab.Button("Lanes [L]", { W = 75, H = 26, Active = isLane }) then
            Logic.currentPage = "lane_editor"
            Logic.showEffectInspector = false
        end

        Slab.SameLine({ Pad = 3 })
        local isEffects = (Logic.currentPage == "effects")
        if Slab.Button("FX [E]", { W = 60, H = 26, Active = isEffects }) then
            Logic.currentPage = "effects"
        end

        -- Center Song Title & Time Readout with Difficulty Badge
        Slab.SameLine({ Pad = 10 })
        local mins = math.floor(Logic.currentTime / 60)
        local secs = Logic.currentTime % 60
        local songTitle = (Logic.metadata and Logic.metadata.name and Logic.metadata.name.text) or "Untitled"
        if #songTitle > 18 then
            songTitle = songTitle:sub(1, 15) .. "..."
        end
        local diffName = (Logic.currentDifficulty or "NORMAL"):upper()
        Slab.Text(string.format("%s [%s] | %02d:%05.2f | B %.2f | %0.0f BPM", songTitle, diffName, mins, secs, Logic.currentBeat, Logic.bpm),
            { Color = { 0.80, 0.80, 0.80, 1.0 } })

        -- Right playback controls
        local leftElementsW = 600
        local rightControlsW = 150
        local rightPad = math.max(6, winW - leftElementsW - rightControlsW - 30)
        Slab.SameLine({ Pad = rightPad })

        if Slab.Button(Logic.isPlaying and "Pause" or "Play [Spc]", { W = 75, H = 26, Active = Logic.isPlaying }) then
            Logic.togglePlay()
        end

        Slab.SameLine({ Pad = 4 })
        if Slab.Button("Save [S]", { W = 65, H = 26 }) then
            Logic.saveChart()
        end

        Slab.EndWindow()
    end
end

-- ==========================================
-- EFFECT SETTINGS INSPECTOR MODAL
-- ==========================================

function Draw.drawEffectInspector()
    if Logic.currentPage ~= "effects" or not Logic.showEffectInspector or not Logic.selectedEffectIndex then return end
    local eff = Logic.chartEffects[Logic.selectedEffectIndex]
    if not eff then
        Logic.showEffectInspector = false
        return
    end

    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local inspW = 320
    local inspH = math.min(560, winH - 60)

    if Slab.BeginWindow('EffectInspectorWindow', {
            Title = string.format("Effect Settings - %s", string.upper(eff.lane or "FX")),
            X = winW - inspW - 12, Y = 50, W = inspW, H = inspH,
            AllowResize = true, AllowMove = true, ShowMinimize = true, NoSavedSettings = true,
            Border = 1, BgColor = { 0.08, 0.08, 0.08, 0.98 }
        }) then
        eff.params = eff.params or {}
        local p = eff.params

        Slab.Text(string.format("Timing: Beat %.2f (%.3fs)", eff.beat or 0, eff.time or 0), { Color = { 0.65, 0.65, 0.65, 1 } })
        Slab.Separator()

        -- 1. FLASH SETTINGS
        if eff.lane == "flash" then
            Slab.Text("Flash Mode:", { Color = { 0.75, 0.75, 0.75, 1 } })
            local types = {
                { id = "flash_in_out", label = "In / Out (Smooth)", idx = 1 },
                { id = "flash",        label = "Instant Pulse",     idx = 2 }
            }
            local curIdx = (eff.type == "flash") and 2 or 1
            for _, t in ipairs(types) do
                if Slab.RadioButton(t.label, { Index = t.idx, Selected = curIdx }) then
                    eff.type = t.id
                end
                Slab.SameLine({ Pad = 8 })
            end
            Slab.NewLine()
            Slab.Separator()

            Slab.Text("Flash Tone:")
            p.color = p.color or { 1, 1, 1 }
            local colPresets = {
                { label = "White", col = { 1, 1, 1 } },
                { label = "Muted", col = { 0.7, 0.7, 0.7 } },
                { label = "Dim",   col = { 0.4, 0.4, 0.4 } }
            }
            for _, cp in ipairs(colPresets) do
                if Slab.Button(cp.label, { W = 60, H = 22 }) then
                    p.color = { cp.col[1], cp.col[2], cp.col[3] }
                end
                Slab.SameLine({ Pad = 4 })
            end
            Slab.NewLine()

            if Slab.InputNumberSlider('FlashBrightness', math.floor((p.color[1] or 1) * 255), 0, 255) then
                local val = Slab.GetInputNumber() / 255
                p.color = { val, val, val }
            end
            Slab.Separator()

            if eff.type == "flash_in_out" then
                Slab.Text("Fade In (sec):")
                if Slab.InputNumberSlider('FlashFadeIn', p.fadeIn or 0.05, 0.01, 1.0) then
                    p.fadeIn = Slab.GetInputNumber()
                end

                Slab.Text("Fade Out (sec):")
                if Slab.InputNumberSlider('FlashFadeOut', p.fadeOut or 0.25, 0.05, 2.0) then
                    p.fadeOut = Slab.GetInputNumber()
                end
            else
                Slab.Text("Duration (sec):")
                if Slab.InputNumberSlider('FlashDuration', p.duration or 0.3, 0.05, 2.0) then
                    p.duration = Slab.GetInputNumber()
                end
            end

            Slab.Text("Peak Opacity (%):")
            if Slab.InputNumberSlider('FlashPeakAlpha', math.floor((p.peakAlpha or 0.85) * 100), 10, 100) then
                p.peakAlpha = Slab.GetInputNumber() / 100
            end

        -- 2. SHAKE SETTINGS
        elseif eff.lane == "shake" then
            Slab.Text("Shake Mode:", { Color = { 0.75, 0.75, 0.75, 1 } })
            local types = {
                { id = "shake",     label = "Directional", idx = 1 },
                { id = "shake_rot", label = "Rotational",  idx = 2 },
                { id = "trauma",    label = "Trauma",      idx = 3 }
            }
            local curIdx = (eff.type == "shake_rot") and 2 or ((eff.type == "trauma") and 3 or 1)
            for _, t in ipairs(types) do
                if Slab.RadioButton(t.label, { Index = t.idx, Selected = curIdx }) then
                    eff.type = t.id
                end
                Slab.SameLine({ Pad = 6 })
            end
            Slab.NewLine()
            Slab.Separator()

            if eff.type == "shake" then
                Slab.Text("Intensity (px):")
                if Slab.InputNumberSlider('ShakeIntensity', p.intensity or 10, 1, 40) then
                    p.intensity = Slab.GetInputNumber()
                end
                Slab.Text("Axes: " .. (p.axes or "XY"))
                if Slab.Button("XY", { W = 40, H = 22 }) then p.axes = "XY" end
                Slab.SameLine({ Pad = 4 })
                if Slab.Button("X", { W = 40, H = 22 }) then p.axes = "X" end
                Slab.SameLine({ Pad = 4 })
                if Slab.Button("Y", { W = 40, H = 22 }) then p.axes = "Y" end
                Slab.NewLine()
            elseif eff.type == "shake_rot" then
                Slab.Text("Rotation Angle:")
                if Slab.InputNumberSlider('ShakeRotIntensity', (p.rotIntensity or 0.05) * 100, 1, 30) then
                    p.rotIntensity = Slab.GetInputNumber() / 100
                end
            elseif eff.type == "trauma" then
                Slab.Text("Trauma Amount (%):")
                if Slab.InputNumberSlider('TraumaPower', math.floor((p.traumaAmount or 0.6) * 100), 10, 100) then
                    p.traumaAmount = Slab.GetInputNumber() / 100
                end
            end

            Slab.Text("Duration (sec):")
            if Slab.InputNumberSlider('ShakeDur', p.duration or 0.25, 0.05, 2.0) then
                p.duration = Slab.GetInputNumber()
            end

        -- 3. ZOOM SETTINGS
        elseif eff.lane == "zoom" then
            Slab.Text("Zoom Mode:", { Color = { 0.75, 0.75, 0.75, 1 } })
            local types = {
                { id = "pulse",   label = "Pulse",  idx = 1 },
                { id = "bounce",  label = "Bounce", idx = 2 },
                { id = "zoom_to", label = "Target", idx = 3 }
            }
            local curIdx = (eff.type == "bounce") and 2 or ((eff.type == "zoom_to") and 3 or 1)
            for _, t in ipairs(types) do
                if Slab.RadioButton(t.label, { Index = t.idx, Selected = curIdx }) then
                    eff.type = t.id
                end
                Slab.SameLine({ Pad = 8 })
            end
            Slab.NewLine()
            Slab.Separator()

            if eff.type == "zoom_to" then
                Slab.Text("Target Scale (1.0 = Normal):")
                if Slab.InputNumberSlider('TargetScale', p.targetScale or 1.25, 0.5, 2.5) then
                    p.targetScale = Slab.GetInputNumber()
                end
            else
                Slab.Text("Zoom Amount:")
                if Slab.InputNumberSlider('ZoomAmount', math.floor((p.amount or 0.15) * 100), 2, 80) then
                    p.amount = Slab.GetInputNumber() / 100
                end
                Slab.Text("Duration (sec):")
                if Slab.InputNumberSlider('ZoomDuration', p.duration or 0.25, 0.05, 1.5) then
                    p.duration = Slab.GetInputNumber()
                end
            end

        -- 4. PENDULUM / WAVE SETTINGS
        elseif eff.lane == "pendulum" then
            Slab.Text("Oscillation Type:", { Color = { 0.75, 0.75, 0.75, 1 } })
            local types = {
                { id = "pendulum", label = "Pendulum", idx = 1 },
                { id = "wave",     label = "Sine Wave", idx = 2 },
                { id = "wobble",   label = "Wobble",   idx = 3 }
            }
            local curIdx = (eff.type == "wave") and 2 or ((eff.type == "wobble") and 3 or 1)
            for _, t in ipairs(types) do
                if Slab.RadioButton(t.label, { Index = t.idx, Selected = curIdx }) then
                    eff.type = t.id
                end
                Slab.SameLine({ Pad = 6 })
            end
            Slab.NewLine()
            Slab.Separator()

            Slab.Text("Duration (sec):")
            local maxDur = math.max(120.0, (Logic.duration or 300))
            if Slab.InputNumberSlider('PendulumDuration', p.duration or 0.8, 0.05, maxDur, { Precision = 2 }) then
                p.duration = math.max(0.05, Slab.GetInputNumber())
            end

        -- 5. TARGET / ABSOLUTE ROTATE SETTINGS
        elseif eff.lane == "rotate" then
            eff.type = "rotate_to"
            p.targetAngle = p.targetAngle or 90
            p.easing = p.easing or "linear"

            Slab.Text("Target Rotation (deg):", { Color = { 0.75, 0.75, 0.75, 1 } })
            if Slab.InputNumberSlider('RotateTargetAngle', p.targetAngle, -360, 360, { Precision = 0 }) then
                p.targetAngle = math.floor(Slab.GetInputNumber())
            end

            Slab.Text("Duration (sec):")
            local maxDur = math.max(120.0, (Logic.duration or 300))
            if Slab.InputNumberSlider('RotateDuration', p.duration or 0.8, 0.05, maxDur, { Precision = 2 }) then
                p.duration = math.max(0.05, Slab.GetInputNumber())
            end

            Slab.Text("Easing Curve (Flux Template):", { Color = { 0.75, 0.75, 0.75, 1 } })
            local currentEasingName = "Linear (Uniform)"
            if Logic.easingList then
                for _, easeItem in ipairs(Logic.easingList) do
                    if easeItem.id == p.easing then
                        currentEasingName = easeItem.name
                        break
                    end
                end
            end

            if Slab.BeginComboBox('RotateEasingDropdown', { Selected = currentEasingName, W = 280 }) then
                if Logic.easingList then
                    for _, easeItem in ipairs(Logic.easingList) do
                        if Slab.TextSelectable(easeItem.name) then
                            Logic.pushUndo()
                            p.easing = easeItem.id
                        end
                    end
                end
                Slab.EndComboBox()
            end
        end

        Slab.NewLine()
        Slab.Separator()

        -- REPEAT SETTINGS
        Slab.Text("Repeat Cycle:", { Color = { 0.75, 0.75, 0.75, 1 } })
        p.repeatEnabled = p.repeatEnabled or false
        if Slab.CheckBox(p.repeatEnabled, "Enable Continuous Repeat") then
            p.repeatEnabled = not p.repeatEnabled
            if p.repeatEnabled then
                p.repeatUntilBeat = p.repeatUntilBeat or ((eff.beat or 0) + 4.0)
                p.repeatStep = p.repeatStep or 1.0
            end
        end

        if p.repeatEnabled then
            Slab.Text("Repeat Step (Beats):")
            if Slab.InputNumberSlider('RepeatCustomStep', p.repeatStep or 1.0, 0.125, 8.0, { Precision = 2 }) then
                p.repeatStep = math.max(0.0625, Slab.GetInputNumber())
            end

            Slab.Text(string.format("Until Beat (Start: %.2f):", eff.beat or 0))
            local maxBeatVal = math.max((eff.beat or 0) + 32, Logic.timeToBeat(Logic.duration or 300))
            if Slab.InputNumberSlider('RepeatUntilBeat', p.repeatUntilBeat or ((eff.beat or 0) + 4.0), eff.beat or 0, maxBeatVal, { Precision = 2 }) then
                p.repeatUntilBeat = math.max(eff.beat or 0, Slab.GetInputNumber())
            end
        end

        Slab.NewLine()
        Slab.Separator()

        -- Action Buttons
        if Slab.Button("Test Trigger", { W = 85, H = 24 }) then
            Logic.triggerEffect(eff)
        end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Duplicate", { W = 75, H = 24 }) then
            Logic.addEffect(eff.lane, (eff.beat or 0) + 1.0)
        end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Delete", { W = 60, H = 24 }) then
            Logic.deleteSelectedEffect()
        end

        Slab.EndWindow()
    end
end

-- ==========================================
-- NOTE GIMMICK SETTINGS MODAL
-- ==========================================

function Draw.drawNoteGimmickModal()
    if not Logic.showNoteGimmickModal or not Logic.selectedNoteIndex then return end
    local note = Logic.notes[Logic.selectedNoteIndex]
    if not note then
        Logic.showNoteGimmickModal = false
        return
    end

    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local modalW = 340
    local modalH = math.min(580, winH - 60)

    if Slab.BeginWindow('NoteGimmickModalWindow', {
            Title = string.format("Note #%d - Gimmick Settings", Logic.selectedNoteIndex),
            X = winW - modalW - 12, Y = 50, W = modalW, H = modalH,
            AllowResize = true, AllowMove = true, ShowMinimize = true, NoSavedSettings = true,
            Border = 1, BgColor = { 0.08, 0.08, 0.08, 0.98 }
        }) then
        note.gimmick = note.gimmick or {}
        local g = note.gimmick

        Slab.Text(string.format("Type: %s  |  Beat: %.2f  |  Angle: %.1f deg",
            (note.type or "basic"):upper(), note.beat or 0, math.deg(note.angle or 0)),
            { Color = { 0.65, 0.65, 0.65, 1 } })
        Slab.Separator()

        -- Mode Selection Tabs
        local tabW = 145
        local isBuiltin = (Logic.selectedNoteGimmickTab ~= "manual")
        if Slab.Button("Standard Presets", { W = tabW, H = 26, Active = isBuiltin }) then
            Logic.selectedNoteGimmickTab = "builtin"
        end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Custom Trajectory", { W = tabW, H = 26, Active = not isBuiltin }) then
            Logic.selectedNoteGimmickTab = "manual"
        end

        Slab.NewLine()
        Slab.Separator()

        if Logic.selectedNoteGimmickTab == "builtin" then
            Slab.Text("Select Preset:", { Color = { 0.75, 0.75, 0.75, 1 } })

            local builtinList = {
                { id = "none",         name = "None (Standard)",        desc = "Standard note behavior" },
                { id = "speed",        name = "Speed (Approach Rate)",  desc = "Multiplier for approach scroll velocity" },
                { id = "teleport",     name = "Teleport Spawn",         desc = "Appears suddenly near hit position" },
                { id = "sudden_in",    name = "Sudden In",              desc = "Hidden until close to hit line" },
                { id = "hidden_out",   name = "Hidden Out",             desc = "Fades out before reaching center" },
                { id = "spiral_in",    name = "Spiral Curve",           desc = "Spirals around approach trajectory" },
                { id = "accel_rush",   name = "Accelerando (Rush)",     desc = "Starts slow, accelerates into hit" },
                { id = "decel_brake",  name = "Decelerando (Brake)",    desc = "Rushes fast, then decelerates" },
                { id = "zigzag_wave",  name = "Zigzag Wave",            desc = "Oscillates laterally during approach" },
                { id = "blink_strobe", name = "Blink Strobe",           desc = "Strobes on and off rhythmically" },
                { id = "fake_ghost",   name = "Ghost Note",             desc = "Illusion note" },
            }

            local curGimmickType = g.type or "none"
            local currentPresetName = "None (Standard)"
            local currentPresetDesc = "Standard note behavior"
            for _, item in ipairs(builtinList) do
                if item.id == curGimmickType then
                    currentPresetName = item.name
                    currentPresetDesc = item.desc
                    break
                end
            end

            if Slab.BeginComboBox('PresetGimmickDropdown', { Selected = currentPresetName, W = 295 }) then
                for _, item in ipairs(builtinList) do
                    if Slab.TextSelectable(item.name) then
                        Logic.pushUndo()
                        g.type = item.id
                        g.isManual = false
                        g.params = g.params or {}
                        if item.id == "speed" then g.params.speed = g.params.speed or 1.5
                        elseif item.id == "spiral_in" then g.params.rotations = g.params.rotations or 1.0
                        elseif item.id == "sudden_in" or item.id == "hidden_out" then g.params.fadeDistance = g.params.fadeDistance or 0.5
                        elseif item.id == "accel_rush" or item.id == "decel_brake" then g.params.speedMultiplier = g.params.speedMultiplier or 2.0
                        elseif item.id == "zigzag_wave" then g.params.waveFreq = g.params.waveFreq or 3.0; g.params.waveAmp = g.params.waveAmp or 0.25
                        elseif item.id == "blink_strobe" then g.params.blinkRate = g.params.blinkRate or 4.0
                        end
                    end
                end
                Slab.EndComboBox()
            end

            Slab.Text(currentPresetDesc, { Color = { 0.50, 0.50, 0.50, 1.0 } })
            Slab.NewLine()
            Slab.Separator()

            if g.type and g.type ~= "none" then
                Slab.Text("Parameters:", { Color = { 0.75, 0.75, 0.75, 1 } })
                g.params = g.params or {}

                if g.type == "speed" then
                    Slab.Text("Speed Multiplier:")
                    if Slab.InputNumberSlider('GimmickSpeedMult', g.params.speed or 1.5, 0.1, 5.0, { Precision = 2 }) then
                        g.params.speed = Slab.GetInputNumber()
                    end
                elseif g.type == "spiral_in" then
                    Slab.Text("Spiral Rotations:")
                    if Slab.InputNumberSlider('GimmickSpiralRot', g.params.rotations or 1.0, -4.0, 4.0, { Precision = 2 }) then
                        g.params.rotations = Slab.GetInputNumber()
                    end
                elseif g.type == "sudden_in" or g.type == "hidden_out" then
                    Slab.Text("Fade Distance Ratio:")
                    if Slab.InputNumberSlider('GimmickFadeDist', g.params.fadeDistance or 0.5, 0.1, 0.9, { Precision = 2 }) then
                        g.params.fadeDistance = Slab.GetInputNumber()
                    end
                elseif g.type == "zigzag_wave" then
                    Slab.Text("Wave Frequency:")
                    if Slab.InputNumberSlider('GimmickWaveFreq', g.params.waveFreq or 3.0, 1.0, 10.0, { Precision = 1 }) then
                        g.params.waveFreq = Slab.GetInputNumber()
                    end
                end
            end
        else
            -- Manual Custom
            Slab.Text("Custom Trajectory & Rate:", { Color = { 0.75, 0.75, 0.75, 1 } })
            g.isManual = true
            g.manual = g.manual or {}
            local m = g.manual

            Slab.Text("Approach Velocity Scale:")
            if Slab.InputNumberSlider('ManualSpeed', m.speed or 1.0, 0.1, 5.0, { Precision = 2 }) then
                m.speed = Slab.GetInputNumber()
                g.type = "manual"
            end

            Slab.Text("Spawn Angle Offset (deg):")
            if Slab.InputNumberSlider('ManualAngleOffset', m.angleOffset or 0, -180, 180, { Precision = 1 }) then
                m.angleOffset = Slab.GetInputNumber()
                g.type = "manual"
            end

            Slab.Text("Start Radius Scale (%):")
            if Slab.InputNumberSlider('ManualRadiusScale', math.floor((m.startRadiusScale or 1.0) * 100), 20, 300) then
                m.startRadiusScale = Slab.GetInputNumber() / 100
                g.type = "manual"
            end
        end

        Slab.NewLine()
        Slab.Separator()

        if Slab.Button("Preview", { W = 80, H = 24 }) then
            Logic.previewNoteGimmick()
        end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Clear Gimmick", { W = 100, H = 24 }) then
            Logic.pushUndo()
            note.gimmick = nil
            Logic.statusMessage = "Cleared note gimmick"
        end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Delete Note", { W = 85, H = 24 }) then
            Logic.deleteSelectedNote()
        end

        Slab.EndWindow()
    end
end

-- ==========================================
-- SIDEBAR & PRIMARY EDITING CONTROLS
-- ==========================================

function Draw.drawLeftSidebar()
    if Logic.currentPage ~= "editor" then return end
    local winH = love.graphics.getHeight()

    if Slab.BeginWindow('TeleiaEditorWindow', {
            Title = "INSPECTOR",
            X = 0, Y = 42, W = Draw.panelWidth, H = winH - 42 - 44,
            AllowResize = false, AllowMove = false, ShowMinimize = false, NoSavedSettings = true,
            Border = 1, BgColor = { 0.07, 0.07, 0.07, 0.98 }
        }) then
        local tabW = 68
        if Slab.Button("Editor", { W = tabW, H = 26, Active = (Logic.activeTab == "editor") }) then
            Logic.activeTab = "editor"
        end
        Slab.SameLine({ Pad = 4 })
        if Slab.Button("Audio", { W = tabW, H = 26, Active = (Logic.activeTab == "music") }) then
            Logic.activeTab = "music"
        end
        Slab.SameLine({ Pad = 4 })
        if Slab.Button("Meta", { W = tabW, H = 26, Active = (Logic.activeTab == "metadata") }) then
            Logic.activeTab = "metadata"
        end
        Slab.SameLine({ Pad = 4 })
        if Slab.Button("Settings", { W = tabW, H = 26, Active = (Logic.activeTab == "settings" or Logic.activeTab == "effect") }) then
            Logic.activeTab = "settings"
        end

        Slab.NewLine()
        Slab.Separator()

        if Logic.activeTab == "editor" then
            Slab.Text("NOTE TYPE [1-3]:", { Color = { 0.55, 0.55, 0.55, 1 } })
            local types = {
                { id = "basic",     label = "Basic [1]" },
                { id = "slideup",   label = "Slide Up [2]" },
                { id = "slidedown", label = "Slide Down [3]" }
            }
            for _, t in ipairs(types) do
                local isCur = (Logic.selectedNoteType == t.id)
                if Slab.Button(t.label, { W = 88, H = 24, Active = isCur }) then
                    Logic.selectedNoteType = t.id
                    if Logic.getSelectedNotesCount() > 0 then
                        Logic.batchSetNoteType(t.id)
                    end
                end
                Slab.SameLine({ Pad = 4 })
            end
            Slab.NewLine()
            Slab.Separator()

            Slab.Text("BEAT SNAP GRID:", { Color = { 0.55, 0.55, 0.55, 1 } })
            local snapOptions = { 1, 2, 4, 8, 16, 32 }
            for _, s in ipairs(snapOptions) do
                local isCur = (Logic.beatSnap == s)
                if Slab.Button("1/" .. s, { W = 42, H = 22, Active = isCur }) then
                    Logic.beatSnap = s
                end
                Slab.SameLine({ Pad = 4 })
            end
            Slab.NewLine()
            Slab.Separator()

            Slab.Text("RADIAL SECTOR CLAMP:", { Color = { 0.55, 0.55, 0.55, 1 } })
            local angleOptions = { 4, 8, 12, 16, 24, 32 }
            for _, a in ipairs(angleOptions) do
                local isCur = (Logic.angleSteps == a)
                if Slab.Button(tostring(a), { W = 42, H = 22, Active = isCur }) then
                    Logic.angleSteps = a
                end
                Slab.SameLine({ Pad = 4 })
            end
            Slab.NewLine()
            Slab.Separator()

            Slab.Text("TIMELINE ZOOM / SPACING:")
            if Slab.InputNumberSlider('SidebarZoom', Logic.stepZoom, 0.5, 2.5) then
                Logic.stepZoom = Slab.GetInputNumber()
            end
            Slab.Separator()

            Slab.Text(string.format("CHART NOTES: %d total", #Logic.notes), { Color = { 0.7, 0.7, 0.7, 1 } })
            local selCount = Logic.getSelectedNotesCount()
            if selCount > 1 then
                Slab.Text(string.format("SELECTION: %d notes active", selCount), { Color = { 0.95, 0.95, 0.95, 1.0 } })
                if Slab.Button("Clear Selection", { W = 135, H = 24 }) then
                    Logic.clearNoteSelection()
                end
                Slab.SameLine({ Pad = 6 })
                if Slab.Button("Shuffle Notes", { W = 120, H = 24 }) then
                    Logic.shuffleSelectedNotes()
                end
                Slab.NewLine()
                if Slab.Button("Delete Notes", { W = 261, H = 24 }) then
                    Logic.deleteSelectedNotes()
                end
            elseif Logic.selectedNoteIndex and Logic.notes[Logic.selectedNoteIndex] then
                local sel = Logic.notes[Logic.selectedNoteIndex]
                local gType = (sel.gimmick and sel.gimmick.type and sel.gimmick.type ~= "none") and sel.gimmick.type or "None"
                Slab.Text(string.format("Selected #%d  (Beat %.2f | %s)", Logic.selectedNoteIndex, sel.beat or 0, (sel.type or "basic"):upper()))
                Slab.Text("Gimmick: " .. gType, { Color = (gType ~= "None") and { 0.95, 0.95, 0.95, 1 } or { 0.5, 0.5, 0.5, 1 } })

                if Slab.Button("Edit Gimmick", { W = 130, H = 24 }) then
                    Logic.showNoteGimmickModal = true
                end
                Slab.SameLine({ Pad = 6 })
                if Slab.Button("Shuffle [R]", { W = 110, H = 24 }) then
                    Logic.shuffleSelectedNotes()
                end
                Slab.NewLine()
                if Slab.Button("Delete Note", { W = 246, H = 24 }) then
                    Logic.deleteSelectedNote()
                end
            end

        elseif Logic.activeTab == "music" then
            local titleText = Logic.metadata and Logic.metadata.name and Logic.metadata.name.text or "Untitled"
            Slab.Text("Title: " .. titleText, { Color = { 0.9, 0.9, 0.9, 1 } })

            local charterText = Logic.metadata and Logic.metadata.charter and Logic.metadata.charter.text or "Unknown"
            Slab.Text("Charter: " .. charterText, { Color = { 0.6, 0.6, 0.6, 1 } })
            Slab.Separator()

            Slab.Text("BPM (Tempo):")
            if Slab.InputNumberSlider('SidebarBpm', Logic.bpm, 30, 300) then
                Logic.bpm = Slab.GetInputNumber()
                Logic.recalculateNoteTimes()
                Logic.currentBeat = Logic.timeToBeat(Logic.currentTime)
            end

            Slab.Text("Offset (Seconds):")
            if Slab.InputNumberSlider('SidebarOffset', Logic.offset, -2.0, 5.0) then
                Logic.offset = Slab.GetInputNumber()
                Logic.recalculateNoteTimes()
                Logic.currentBeat = Logic.timeToBeat(Logic.currentTime)
            end
            Slab.Separator()

            Slab.Text("Playback Speed Rate:")
            local speedOptions = { { id = 0.5, label = "0.5x" }, { id = 0.75, label = "0.75x" }, { id = 1.0, label = "1.0x" } }
            for _, s in ipairs(speedOptions) do
                local isCur = (math.abs(Logic.playbackRate - s.id) < 0.05)
                if Slab.Button(s.label, { W = 60, H = 24, Active = isCur }) then
                    Logic.playbackRate = s.id
                    if Logic.audioSource and Logic.isPlaying then Logic.audioSource:setPitch(s.id) end
                end
                Slab.SameLine({ Pad = 6 })
            end
            Slab.NewLine()
            Slab.Separator()

            Slab.Text("Master Volume (%):")
            if Slab.InputNumberSlider('SidebarVolume', math.floor(Logic.volume * 100), 0, 100) then
                Logic.volume = math.max(0, math.min(1.0, Slab.GetInputNumber() / 100))
                love.audio.setVolume(Logic.volume)
                if Logic.audioSource then Logic.audioSource:setVolume(Logic.volume) end
            end

        elseif Logic.activeTab == "metadata" then
            Logic.metadata = Logic.metadata or {}
            Logic.metadata.name = Logic.metadata.name or { text = "New Song" }
            Logic.metadata.charter = Logic.metadata.charter or { text = "Anonymous" }
            Logic.metadata.music = Logic.metadata.music or { title = { text = "New Song" }, by = { text = "Artist" } }
            Logic.metadata.music.title = Logic.metadata.music.title or { text = "New Song" }
            Logic.metadata.music.by = Logic.metadata.music.by or { text = "Artist" }

            Slab.Text("Song Title:")
            if Slab.Input('MetaSongTitle', { Text = Logic.metadata.music.title.text or "", W = 280 }) then
                Logic.metadata.music.title.text = Slab.GetInputText()
            end

            Slab.NewLine()
            Slab.Text("Artist:")
            if Slab.Input('MetaSongArtist', { Text = Logic.metadata.music.by.text or "", W = 280 }) then
                Logic.metadata.music.by.text = Slab.GetInputText()
            end

            Slab.NewLine()
            Slab.Text("Charter:")
            if Slab.Input('MetaCreator', { Text = Logic.metadata.charter.text or "", W = 280 }) then
                Logic.metadata.charter.text = Slab.GetInputText()
            end

            Slab.NewLine()
            Slab.Separator()

            if Slab.Button("Open Folder", { W = 135, H = 26 }) then
                Logic.openChartFolder()
            end
            Slab.SameLine({ Pad = 6 })
            if Slab.Button("Reload Audio", { W = 120, H = 26 }) then
                Logic.reloadAudio()
            end

        elseif Logic.activeTab == "settings" or Logic.activeTab == "effect" then
            Slab.Text("VISUAL GUIDES", { Color = { 0.55, 0.55, 0.55, 1 } })
            Slab.Separator()

            if Slab.CheckBox(Logic.effects.showAngleGuides, "Show Radial Angle Guides") then
                Logic.effects.showAngleGuides = not Logic.effects.showAngleGuides
            end

            if Slab.CheckBox(Logic.effects.showBeatNumbers, "Show Beat Numbers on Rings") then
                Logic.effects.showBeatNumbers = not Logic.effects.showBeatNumbers
            end

            Slab.NewLine()
            Slab.Text("AUDIO FEEDBACK", { Color = { 0.55, 0.55, 0.55, 1 } })
            Slab.Separator()

            if Slab.CheckBox(Logic.effects.hitsound, "Hitsound on Notes") then
                Logic.effects.hitsound = not Logic.effects.hitsound
            end

            if Slab.CheckBox(Logic.effects.metronome, "Metronome Tick") then
                Logic.effects.metronome = not Logic.effects.metronome
            end
        end

        Slab.EndWindow()
    end
end

-- ==========================================
-- LANE NOTE EDITOR: BATCH SETTINGS INSPECTOR MODAL / SIDEBAR
-- ==========================================

function Draw.drawLaneInspector()
    if Logic.currentPage == "effects" or Logic.getSelectedNotesCount() == 0 then return end

    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local inspW = 320
    local inspH = math.min(580, winH - 60)

    local summary = Logic.getSelectedNotesSummary()
    local count = summary.count or 0
    if count == 0 then return end

    if Slab.BeginWindow('LaneNoteInspectorWindow', {
            Title = (count > 1) and string.format("Selection - %d Notes", count) or "Note Settings",
            X = winW - inspW - 12, Y = 50, W = inspW, H = inspH,
            AllowResize = true, AllowMove = true, ShowMinimize = true, NoSavedSettings = true,
            Border = 1, BgColor = { 0.08, 0.08, 0.08, 0.98 }
        }) then
        if count == 1 then
            local n = summary.firstNote or Logic.notes[summary.indices[1]]
            local nBeat = n.beat or Logic.timeToBeat(n.time or 0)
            local nLane = Logic.angleToLane(n.angle or 0, Logic.angleSteps or 16)
            Slab.Text(string.format("Note #%d  |  Beat %.2f  |  Track #%d", summary.indices[1], nBeat, nLane),
                { Color = { 0.75, 0.75, 0.75, 1.0 } })
        else
            Slab.Text(string.format("%d Notes (Beats %.2f -> %.2f)", count, summary.minBeat, summary.maxBeat),
                { Color = { 0.90, 0.90, 0.90, 1.0 } })
        end

        Slab.Separator()

        if Slab.Button("Select All", { W = 135, H = 24 }) then
            Logic.selectAllNotes()
        end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Deselect", { W = 135, H = 24 }) then
            Logic.clearNoteSelection()
        end

        Slab.NewLine()
        Slab.Separator()

        -- Lane Assignment
        local totalLanes = Logic.angleSteps or 16
        Slab.Text(string.format("Assign Track (Total %d):", totalLanes), { Color = { 0.55, 0.55, 0.55, 1 } })

        local currentLaneName = summary.laneMixed and "Mixed" or
            string.format("Track #%d (%.0f deg)", summary.laneIndex or 1,
                math.deg(Logic.laneToAngle(summary.laneIndex or 1, totalLanes)))

        if Slab.BeginComboBox('BatchLaneDropdown', { Selected = currentLaneName, W = 280 }) then
            for l = 1, totalLanes do
                local lAngle = Logic.laneToAngle(l, totalLanes)
                local lLabel = string.format("Track #%d (%.0f deg)", l, math.deg(lAngle))
                if Slab.TextSelectable(lLabel) then
                    Logic.batchSetLane(l)
                end
            end
            Slab.EndComboBox()
        end

        Slab.NewLine()
        Slab.Separator()

        -- Nudge timing
        Slab.Text("Nudge Beat Offset:", { Color = { 0.55, 0.55, 0.55, 1 } })
        if Slab.Button("-1b", { W = 62, H = 24 }) then Logic.batchShiftBeat(-1.0) end
        Slab.SameLine({ Pad = 4 })
        if Slab.Button("-1/4", { W = 62, H = 24 }) then Logic.batchShiftBeat(-0.25) end
        Slab.SameLine({ Pad = 4 })
        if Slab.Button("+1/4", { W = 62, H = 24 }) then Logic.batchShiftBeat(0.25) end
        Slab.SameLine({ Pad = 4 })
        if Slab.Button("+1b", { W = 62, H = 24 }) then Logic.batchShiftBeat(1.0) end

        Slab.NewLine()
        Slab.Separator()

        -- Batch Actions
        if Slab.Button("Copy [Ctrl+C]", { W = 135, H = 24 }) then Logic.copySelectedNotes() end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Paste [Ctrl+V]", { W = 135, H = 24 }) then Logic.pasteNotes(Logic.currentBeat) end

        -- Gimmick Controls embedded directly inside Note Settings (supports both Single & Multi-Selection)
        if count >= 1 then
            local isSingle = (count == 1)
            local n = summary.firstNote or Logic.notes[summary.indices[1]]
            n.gimmick = n.gimmick or {}
            local g = n.gimmick

            Slab.NewLine()
            Slab.Separator()
            Slab.Text(isSingle and "NOTE GIMMICK:" or string.format("BATCH GIMMICK (%d Notes):", count), { Color = { 0.85, 0.85, 0.85, 1 } })

            local builtinList = {
                { id = "none",         name = "None (Standard)",        desc = "Standard note behavior" },
                { id = "speed",        name = "Speed (Approach Rate)",  desc = "Multiplier for approach scroll velocity" },
                { id = "teleport",     name = "Teleport Spawn",         desc = "Appears suddenly near hit position" },
                { id = "sudden_in",    name = "Sudden In",              desc = "Hidden until close to hit line" },
                { id = "hidden_out",   name = "Hidden Out",             desc = "Fades out before reaching center" },
                { id = "spiral_in",    name = "Spiral Curve",           desc = "Spirals around approach trajectory" },
                { id = "accel_rush",   name = "Accelerando (Rush)",     desc = "Starts slow, accelerates into hit" },
                { id = "decel_brake",  name = "Decelerando (Brake)",    desc = "Rushes fast, then decelerates" },
                { id = "zigzag_wave",  name = "Zigzag Wave",            desc = "Oscillates laterally during approach" },
                { id = "blink_strobe", name = "Blink Strobe",           desc = "Strobes on and off rhythmically" },
                { id = "fake_ghost",   name = "Ghost Note",             desc = "Illusion note" },
            }

            local curGimmickType = isSingle and (g.type or "none") or (summary.gimmickMixed and "Mixed" or summary.gimmickType)
            local currentPresetName = (curGimmickType == "Mixed") and "Mixed (Multiple)" or "None (Standard)"
            local currentPresetDesc = (curGimmickType == "Mixed") and "Selected notes have different gimmicks" or "Standard note behavior"
            for _, item in ipairs(builtinList) do
                if item.id == curGimmickType then
                    currentPresetName = item.name
                    currentPresetDesc = item.desc
                    break
                end
            end

            if Slab.BeginComboBox('InspectorGimmickDropdown', { Selected = currentPresetName, W = 280 }) then
                for _, item in ipairs(builtinList) do
                    if Slab.TextSelectable(item.name) then
                        local defParams = {}
                        if item.id == "speed" then defParams.speed = 1.5
                        elseif item.id == "spiral_in" then defParams.rotations = 1.0
                        elseif item.id == "sudden_in" or item.id == "hidden_out" then defParams.fadeDistance = 0.5
                        elseif item.id == "accel_rush" or item.id == "decel_brake" then defParams.speedMultiplier = 2.0
                        elseif item.id == "zigzag_wave" then defParams.waveFreq = 3.0; defParams.waveAmp = 0.25
                        elseif item.id == "blink_strobe" then defParams.blinkRate = 4.0
                        end

                        if isSingle then
                            Logic.pushUndo()
                            g.type = item.id
                            g.isManual = false
                            g.params = defParams
                        else
                            Logic.batchSetGimmick(item.id, defParams)
                        end
                    end
                end
                Slab.EndComboBox()
            end

            Slab.Text(currentPresetDesc, { Color = { 0.50, 0.50, 0.50, 1.0 } })

            local activeGType = isSingle and g.type or summary.gimmickType
            if activeGType and activeGType ~= "none" and activeGType ~= "Mixed" then
                local p = g.params or {}
                if activeGType == "speed" then
                    Slab.Text("Speed Multiplier:")
                    if Slab.InputNumberSlider('LaneGimmickSpeedMult', p.speed or 1.5, 0.1, 5.0, { Precision = 2 }) then
                        local val = Slab.GetInputNumber()
                        p.speed = val
                        if not isSingle then Logic.batchSetGimmickParam("speed", val) end
                    end
                elseif activeGType == "spiral_in" then
                    Slab.Text("Spiral Rotations:")
                    if Slab.InputNumberSlider('LaneGimmickSpiralRot', p.rotations or 1.0, -4.0, 4.0, { Precision = 2 }) then
                        local val = Slab.GetInputNumber()
                        p.rotations = val
                        if not isSingle then Logic.batchSetGimmickParam("rotations", val) end
                    end
                elseif activeGType == "sudden_in" or activeGType == "hidden_out" then
                    Slab.Text("Fade Distance Ratio:")
                    if Slab.InputNumberSlider('LaneGimmickFadeDist', p.fadeDistance or 0.5, 0.1, 0.9, { Precision = 2 }) then
                        local val = Slab.GetInputNumber()
                        p.fadeDistance = val
                        if not isSingle then Logic.batchSetGimmickParam("fadeDistance", val) end
                    end
                elseif activeGType == "zigzag_wave" then
                    Slab.Text("Wave Frequency:")
                    if Slab.InputNumberSlider('LaneGimmickWaveFreq', p.waveFreq or 3.0, 1.0, 10.0, { Precision = 1 }) then
                        local val = Slab.GetInputNumber()
                        p.waveFreq = val
                        if not isSingle then Logic.batchSetGimmickParam("waveFreq", val) end
                    end
                end
            end
        end

        Slab.NewLine()
        Slab.Separator()

        -- Action Buttons
        if Slab.Button("Duplicate [Ctrl+D]", { W = 135, H = 24 }) then Logic.duplicateSelectedNotes(1.0) end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Shuffle Note [R]", { W = 135, H = 24 }) then Logic.shuffleSelectedNotes() end

        Slab.NewLine()
        if Slab.Button("Clear Gimmick", { W = 135, H = 24 }) then Logic.batchClearGimmick() end
        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Delete Selection [Del]", { W = 135, H = 24 }) then Logic.deleteSelectedNotes() end

        Slab.EndWindow()
    end
end

-- ==========================================
-- BOTTOM DOCK TIMELINE SCRUBBER
-- ==========================================

function Draw.drawBottomTimeline()
    local winW = love.graphics.getWidth()
    local winH = love.graphics.getHeight()
    local barH = 44
    local barX = (Logic.currentPage == "editor") and Draw.panelWidth or 0
    local barW = winW - barX

    if Slab.BeginWindow('EditorBottomTimeline', {
            X = barX, Y = winH - barH, W = barW, H = barH,
            NoSavedSettings = true, AllowResize = false, AllowMove = false, Border = 1,
            BgColor = { 0.07, 0.07, 0.07, 1.0 }
        }) then
        if Slab.Button("< Step", { W = 65, H = 26 }) then
            Logic.stepBeat(-1)
        end

        Slab.SameLine({ Pad = 6 })
        if Slab.Button("Step >", { W = 65, H = 26 }) then
            Logic.stepBeat(1)
        end

        Slab.SameLine({ Pad = 16 })
        local seekW = barW - 170
        local minTime = Logic.getMinTime()
        if Slab.InputNumberSlider('TimelineSeek', Logic.currentTime, minTime, Logic.duration, { W = seekW, Precision = 2 }) then
            Logic.seekTime(Slab.GetInputNumber())
        end

        Slab.EndWindow()
    end
end

-- ==========================================
-- MAIN DRAW PIPELINE
-- ==========================================

function Draw.ui()
    Draw.drawTopBar()
    Draw.drawLeftSidebar()
    Draw.drawLaneInspector()
    Draw.drawEffectInspector()
    Draw.drawNoteGimmickModal()
    Draw.drawBottomTimeline()

    -- Render ghost badge overlay in pure screen coordinates
    if Draw.ghostBadge and Logic.currentPage == "editor" and not Logic.isPlaying and not Draw.isPointerOverUI() then
        local b = Draw.ghostBadge
        love.graphics.setColor(0.06, 0.06, 0.06, 0.92)
        love.graphics.rectangle("fill", b.x - 4, b.y - 2, b.w + 8, b.h + 4, 1, 1)

        love.graphics.setColor(0.25, 0.25, 0.25, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", b.x - 4, b.y - 2, b.w + 8, b.h + 4, 1, 1)

        love.graphics.setColor(b.textColor or { 0.88, 0.88, 0.88, 1.0 })
        love.graphics.print(b.text, b.x, b.y)
    end
end

function Draw.playfield()
    if not Logic.camera then
        Logic.initCamera()
    end

    if Logic.currentPage == "effects" then
        Draw.drawEffectsPlayfield()
    elseif Logic.currentPage == "lane_editor" then
        Draw.drawLanePlayfield()
    else
        Logic.camera:attach()
        Draw.drawNotePlayfield()
        Logic.camera:detach()
        Logic.camera:draw()
    end
end

function Draw.all()
    Draw.playfield()
    Draw.ui()
end

return Draw
