--[[
MIT License

Copyright (c) 2017 SSYGEN (Extended with Enhanced Rhythm Game FX by Teleia Editor)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

local function lerp(a, b, x) return a + (b - a) * x end
local function csnap(v, x) return math.ceil(v / x) * x - x / 2 end
local function clamp(val, minVal, maxVal) return math.max(minVal, math.min(maxVal, val)) end

-- Shake generator using multi-sample noise with decay
local function newShake(amplitude, duration, frequency)
    local self = {
        amplitude = amplitude or 0,
        duration = duration or 0,
        frequency = frequency or 60,
        samples = {},
        start_time = love.timer.getTime() * 1000,
        t = 0,
        shaking = true,
    }

    local sample_count = math.max(2, math.floor((self.duration / 1000) * self.frequency))
    for i = 1, sample_count do self.samples[i] = 2 * love.math.random() - 1 end

    return self
end

local function updateShake(self, dt)
    self.t = love.timer.getTime() * 1000 - self.start_time
    if self.t > self.duration then self.shaking = false end
end

local function shakeNoise(self, s)
    if s >= #self.samples then return 0 end
    return self.samples[s] or 0
end

local function shakeDecay(self, t)
    if t > self.duration then return 0 end
    return (self.duration - t) / self.duration
end

local function getShakeAmplitude(self, t)
    if not t then
        if not self.shaking then return 0 end
        t = self.t
    end

    local s = (t / 1000) * self.frequency
    local s0 = math.floor(s)
    local s1 = s0 + 1
    local k = shakeDecay(self, t)
    return self.amplitude * (shakeNoise(self, s0) + (s - s0) * (shakeNoise(self, s1) - shakeNoise(self, s0))) * k
end

-- Camera & Visual Effects Engine
local Camera = {}
Camera.__index = Camera

local function new(x, y, w, h, scale, rotation)
    local winW = w or love.graphics.getWidth()
    local winH = h or love.graphics.getHeight()
    local cx = x or (winW / 2)
    local cy = y or (winH / 2)

    return setmetatable({
        x = cx, y = cy,
        mx = cx, my = cy,
        screen_x = cx, screen_y = cy,
        w = winW, h = winH,
        
        -- Scale & Zoom FX
        scale = scale or 1,
        base_scale = scale or 1,
        cur_scale = scale or 1,
        target_scale = scale or 1,
        zoom_scale_override = nil,
        scale_lerp_speed = 8,
        zoom_pulse_amount = 0,
        zoom_pulse_duration = 0,
        zoom_pulse_timer = 0,
        zoom_bounces = {},

        -- Rotation & Angles
        rotation = rotation or 0,
        base_rotation = rotation or 0,
        rotation_override = nil,

        -- Shake Collections
        horizontal_shakes = {},
        vertical_shakes = {},
        rotational_shakes = {},
        last_horizontal_shake_amount = 0,
        last_vertical_shake_amount = 0,
        last_rotational_shake_amount = 0,

        -- Trauma-based screen shake
        trauma_value = 0,
        trauma_decay = 1.5,
        trauma_max_offset = 20,
        trauma_max_angle = 0.06,
        trauma_time = 0,

        -- Shaky / Gelombang Pendulum Effect
        pendulum_enabled = false,
        pendulum_max_angle = 0.05,
        pendulum_freq = 2.0,
        pendulum_time = 0,
        pendulum_decay = 0,
        pendulum_duration = 0,
        pendulum_timer = 0,
        pendulum_angle_override = nil,

        -- Sine Wave Floating / Oscillation
        wave_enabled = false,
        wave_amp_x = 0,
        wave_amp_y = 0,
        wave_freq_x = 1,
        wave_freq_y = 1,
        wave_time = 0,
        wave_offset_override = nil,

        -- Camera Follow & Bounds
        target_x = nil, target_y = nil,
        scroll_x = 0, scroll_y = 0,
        last_target_x = nil, last_target_y = nil,
        follow_lerp_x = 1, follow_lerp_y = 1,
        follow_lead_x = 0, follow_lead_y = 0,
        deadzone = nil, bound = nil,
        draw_deadzone = false,

        -- Flash Normal
        flashing = false,
        flash_duration = 1, flash_timer = 0, flash_color = {1, 1, 1, 1},

        -- Flash In / Out (Smooth envelope)
        flash_in_out = false,
        flash_in_duration = 0.08,
        flash_out_duration = 0.25,
        flash_in_out_timer = 0,
        flash_in_out_color = {1, 1, 1},
        flash_peak_alpha = 0.85,
        flash_current_alpha = 0,

        -- Fade Transition
        fading = false,
        fade_duration = 1, fade_timer = 0, fade_color = {0, 0, 0, 0},
    }, Camera)
end

function Camera:resize(w, h)
    local curW = w or love.graphics.getWidth()
    local curH = h or love.graphics.getHeight()
    self.w = curW
    self.h = curH
    if not self.target_x and not self.target_y then
        self.x = curW / 2
        self.y = curH / 2
    end
    self.screen_x = self.x
    self.screen_y = self.y
end

function Camera:attach()
    local curW = love.graphics.getWidth()
    local curH = love.graphics.getHeight()
    if self.w ~= curW or self.h ~= curH then
        self:resize(curW, curH)
    end
    love.graphics.push()
    love.graphics.translate(self.w / 2, self.h / 2)
    love.graphics.scale(self.scale)
    love.graphics.rotate(self.rotation)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:move(dx, dy)
    self.x, self.y = self.x + dx, self.y + dy
end

function Camera:toWorldCoords(x, y)
    local curW = love.graphics.getWidth()
    local curH = love.graphics.getHeight()
    if self.w ~= curW or self.h ~= curH then
        self:resize(curW, curH)
    end
    local c, s = math.cos(self.rotation), math.sin(self.rotation)
    x, y = (x - self.w / 2) / self.scale, (y - self.h / 2) / self.scale
    -- Inverse rotation by self.rotation: R(-theta) = [cos, sin; -sin, cos]
    x, y = c * x + s * y, -s * x + c * y
    return x + self.x, y + self.y
end

function Camera:toCameraCoords(x, y)
    local curW = love.graphics.getWidth()
    local curH = love.graphics.getHeight()
    if self.w ~= curW or self.h ~= curH then
        self:resize(curW, curH)
    end
    local c, s = math.cos(self.rotation), math.sin(self.rotation)
    x, y = x - self.x, y - self.y
    x, y = c * x - s * y, s * x + c * y
    return x * self.scale + self.w / 2, y * self.scale + self.h / 2
end

function Camera:getMousePosition()
    return self:toWorldCoords(love.mouse.getPosition())
end

-- ==========================================
-- 1. SHAKE FX (Directional, Rotational, Trauma)
-- ==========================================

function Camera:shake(intensity, duration, frequency, axes)
    if not axes then axes = 'XY' end
    axes = string.upper(axes)

    if string.find(axes, 'X') then table.insert(self.horizontal_shakes, newShake(intensity, duration * 1000, frequency)) end
    if string.find(axes, 'Y') then table.insert(self.vertical_shakes, newShake(intensity, duration * 1000, frequency)) end
end

function Camera:shakeRot(intensityAngle, duration, frequency)
    table.insert(self.rotational_shakes, newShake(intensityAngle, duration * 1000, frequency or 50))
end

function Camera:addTrauma(amount)
    self.trauma_value = clamp(self.trauma_value + (amount or 0.4), 0, 1)
end

function Camera:setTrauma(amount)
    self.trauma_value = clamp(amount or 0, 0, 1)
end

-- ==========================================
-- 2. ZOOM IN / OUT FX (Pulse, Bounce, Lerp)
-- ==========================================

function Camera:zoomTo(targetScale, speed)
    self.target_scale = targetScale
    if speed then self.scale_lerp_speed = speed end
end

function Camera:zoomPulse(amount, duration)
    self.zoom_pulse_amount = amount or 0.15
    self.zoom_pulse_duration = math.max(0.01, duration or 0.25)
    self.zoom_pulse_timer = self.zoom_pulse_duration
end

function Camera:zoomBounce(amount, duration, frequency)
    table.insert(self.zoom_bounces, {
        amount = amount or 0.15,
        duration = duration or 0.35,
        timer = 0,
        freq = frequency or 12
    })
end

-- ==========================================
-- 3. FLASH IN / OUT FX
-- ==========================================

function Camera:flash(duration, color)
    self.flash_duration = duration or 0.5
    self.flash_color = color or {1, 1, 1, 1}
    self.flash_timer = 0
    self.flashing = true
end

function Camera:flashInOut(fadeInDuration, fadeOutDuration, color, peakAlpha)
    self.flash_in_duration = math.max(0.01, fadeInDuration or 0.06)
    self.flash_out_duration = math.max(0.01, fadeOutDuration or 0.22)
    self.flash_in_out_color = color or {1, 1, 1}
    self.flash_peak_alpha = peakAlpha or 0.85
    self.flash_in_out_timer = 0
    self.flash_in_out = true
end

function Camera:fade(duration, color, action)
    self.fade_duration = duration
    self.base_fade_color = self.fade_color
    self.target_fade_color = color
    self.fade_timer = 0
    self.fade_action = action
    self.fading = true
end

-- ==========================================
-- 4. PENDULUM SWAY & SINE WAVE WOBBLE FX
-- ==========================================

function Camera:setPendulum(enabled, maxAngle, frequency, damping)
    self.pendulum_enabled = (enabled ~= false)
    self.pendulum_max_angle = maxAngle or 0.06
    self.pendulum_freq = frequency or 2.5
    self.pendulum_decay = damping or 0
    self.pendulum_timer = 0
    self.pendulum_duration = 0
end

function Camera:pendulumSwing(maxAngle, duration, frequency)
    self.pendulum_enabled = true
    self.pendulum_max_angle = maxAngle or 0.08
    self.pendulum_freq = frequency or 3.0
    self.pendulum_duration = duration or 1.0
    self.pendulum_timer = duration or 1.0
    self.pendulum_decay = 1.0
end

function Camera:setWave(enabled, ampX, ampY, freqX, freqY)
    self.wave_enabled = (enabled ~= false)
    self.wave_amp_x = ampX or 6
    self.wave_amp_y = ampY or 6
    self.wave_freq_x = freqX or 1.5
    self.wave_freq_y = freqY or 2.0
end

function Camera:stopPendulum()
    self.pendulum_enabled = false
    self.pendulum_time = 0
    self.pendulum_timer = 0
    self.pendulum_angle_override = 0
    self.rotation = self.base_rotation
end

function Camera:stopZoom()
    self.zoom_pulse_timer = 0
    self.zoom_bounces = {}
    self.cur_scale = self.base_scale
    self.target_scale = self.base_scale
    self.zoom_scale_override = nil
    self.scale = self.base_scale
end

function Camera:resetVisuals()
    self.pendulum_enabled = false
    self.pendulum_time = 0
    self.pendulum_timer = 0
    self.pendulum_angle_override = 0
    self.rotation = self.base_rotation
    self.scale = self.base_scale
    self.cur_scale = self.base_scale
    self.target_scale = self.base_scale
    self.zoom_scale_override = nil
    self.zoom_pulse_timer = 0
    self.zoom_bounces = {}
    self.flashing = false
    self.flash_in_out = false
    self.horizontal_shakes = {}
    self.vertical_shakes = {}
    self.rotational_shakes = {}
    self.trauma_value = 0
    self.wave_enabled = false
    self.wave_offset_override = nil
    self.x = self.w / 2
    self.y = self.h / 2
    self.last_horizontal_shake_amount = 0
    self.last_vertical_shake_amount = 0
end

function Camera:wobble(amount, duration, frequency)
    self:shake(amount or 8, duration or 0.3, frequency or 35, 'XY')
    self:shakeRot((amount or 8) * 0.003, duration or 0.3, frequency or 35)
    self:zoomPulse(0.08, duration or 0.3)
end

-- ==========================================
-- UPDATE CYCLE
-- ==========================================

function Camera:update(dt)
    self.w = love.graphics.getWidth()
    self.h = love.graphics.getHeight()
    self.mx, self.my = self:toWorldCoords(love.mouse.getPosition())

    -- 1. Flash Normal Update
    if self.flashing then
        self.flash_timer = self.flash_timer + dt
        if self.flash_timer > self.flash_duration then
            self.flash_timer = 0
            self.flashing = false
        end
    end

    -- 2. Flash In / Out Update
    if self.flash_in_out then
        self.flash_in_out_timer = self.flash_in_out_timer + dt
        local totalDuration = self.flash_in_duration + self.flash_out_duration
        if self.flash_in_out_timer < self.flash_in_duration then
            local progress = self.flash_in_out_timer / self.flash_in_duration
            self.flash_current_alpha = progress * self.flash_peak_alpha
        elseif self.flash_in_out_timer < totalDuration then
            local progress = (self.flash_in_out_timer - self.flash_in_duration) / self.flash_out_duration
            self.flash_current_alpha = (1 - progress) * self.flash_peak_alpha
        else
            self.flash_in_out = false
            self.flash_current_alpha = 0
        end
    end

    -- 3. Fade Transition Update
    if self.fading then
        self.fade_timer = self.fade_timer + dt
        local progress = clamp(self.fade_timer / self.fade_duration, 0, 1)
        self.fade_color = {
            lerp(self.base_fade_color[1], self.target_fade_color[1], progress),
            lerp(self.base_fade_color[2], self.target_fade_color[2], progress),
            lerp(self.base_fade_color[3], self.target_fade_color[3], progress),
            lerp(self.base_fade_color[4], self.target_fade_color[4], progress),
        }
        if self.fade_timer > self.fade_duration then
            self.fade_timer = 0
            self.fading = false
            if self.fade_action then self.fade_action() end
        end
    end

    -- 4. Zoom Lerp & Pulses
    if self.zoom_scale_override ~= nil then
        self.scale = self.zoom_scale_override
    else
        local zoomOffset = 0
        if dt > 0 then
            if self.zoom_pulse_timer > 0 then
                self.zoom_pulse_timer = self.zoom_pulse_timer - dt
                local p = clamp(self.zoom_pulse_timer / self.zoom_pulse_duration, 0, 1)
                zoomOffset = zoomOffset + math.sin(p * math.pi) * self.zoom_pulse_amount
            end

            for i = #self.zoom_bounces, 1, -1 do
                local b = self.zoom_bounces[i]
                b.timer = b.timer + dt
                if b.timer >= b.duration then
                    table.remove(self.zoom_bounces, i)
                else
                    local decay = (b.duration - b.timer) / b.duration
                    zoomOffset = zoomOffset + math.sin(b.timer * b.freq * math.pi * 2) * b.amount * decay
                end
            end

            self.cur_scale = lerp(self.cur_scale or self.base_scale, self.target_scale, clamp(dt * self.scale_lerp_speed, 0, 1))
        end

        self.scale = (self.cur_scale or self.base_scale) + zoomOffset
    end

    -- 5. Shake Calculations
    local horizontal_shake_amount, vertical_shake_amount = 0, 0
    for i = #self.horizontal_shakes, 1, -1 do
        updateShake(self.horizontal_shakes[i], dt)
        horizontal_shake_amount = horizontal_shake_amount + getShakeAmplitude(self.horizontal_shakes[i])
        if not self.horizontal_shakes[i].shaking then table.remove(self.horizontal_shakes, i) end
    end
    for i = #self.vertical_shakes, 1, -1 do
        updateShake(self.vertical_shakes[i], dt)
        vertical_shake_amount = vertical_shake_amount + getShakeAmplitude(self.vertical_shakes[i])
        if not self.vertical_shakes[i].shaking then table.remove(self.vertical_shakes, i) end
    end

    local rot_shake_amount = 0
    for i = #self.rotational_shakes, 1, -1 do
        updateShake(self.rotational_shakes[i], dt)
        rot_shake_amount = rot_shake_amount + getShakeAmplitude(self.rotational_shakes[i])
        if not self.rotational_shakes[i].shaking then table.remove(self.rotational_shakes, i) end
    end

    -- 6. Trauma Shake (Perlin-like noise simulation)
    local traumaOffsetX, traumaOffsetY, traumaAngle = 0, 0, 0
    if self.trauma_value > 0 then
        self.trauma_time = self.trauma_time + dt * 25
        local shakePower = self.trauma_value * self.trauma_value
        traumaOffsetX = (love.math.noise(self.trauma_time, 0) * 2 - 1) * self.trauma_max_offset * shakePower
        traumaOffsetY = (love.math.noise(0, self.trauma_time) * 2 - 1) * self.trauma_max_offset * shakePower
        traumaAngle = (love.math.noise(self.trauma_time, self.trauma_time) * 2 - 1) * self.trauma_max_angle * shakePower
        self.trauma_value = math.max(0, self.trauma_value - self.trauma_decay * dt)
    end

    -- 7. Pendulum Swaying Effect
    local pendulumAngle = 0
    if self.pendulum_angle_override ~= nil then
        if self.pendulum_enabled then
            pendulumAngle = self.pendulum_angle_override
        else
            pendulumAngle = 0
        end
    elseif self.pendulum_enabled then
        if dt > 0 then
            self.pendulum_time = self.pendulum_time + dt
        end
        local decayMult = 1.0
        if self.pendulum_duration > 0 then
            if dt > 0 then
                self.pendulum_timer = self.pendulum_timer - dt
            end
            if self.pendulum_timer <= 0 then
                self.pendulum_enabled = false
                decayMult = 0
            else
                decayMult = (self.pendulum_timer / self.pendulum_duration)
            end
        end
        pendulumAngle = math.sin(self.pendulum_time * self.pendulum_freq * math.pi * 2) * self.pendulum_max_angle * decayMult
    end

    -- 8. Sine Wave Floating Motion
    local waveOffsetX, waveOffsetY = 0, 0
    if self.wave_offset_override ~= nil then
        if self.wave_enabled then
            waveOffsetX = self.wave_offset_override[1] or 0
            waveOffsetY = self.wave_offset_override[2] or 0
        end
    elseif self.wave_enabled then
        if dt > 0 then
            self.wave_time = self.wave_time + dt
        end
        waveOffsetX = math.sin(self.wave_time * self.wave_freq_x * math.pi * 2) * self.wave_amp_x
        waveOffsetY = math.cos(self.wave_time * self.wave_freq_y * math.pi * 2) * self.wave_amp_y
    end

    -- Apply Positions & Rotations
    local totalMoveX = horizontal_shake_amount + traumaOffsetX + waveOffsetX
    local totalMoveY = vertical_shake_amount + traumaOffsetY + waveOffsetY
    if not self.target_x and not self.target_y then
        self.x = (self.w / 2) + totalMoveX
        self.y = (self.h / 2) + totalMoveY
    else
        self.x = self.x - self.last_horizontal_shake_amount
        self.y = self.y - self.last_vertical_shake_amount
        self:move(totalMoveX, totalMoveY)
    end
    self.last_horizontal_shake_amount = totalMoveX
    self.last_vertical_shake_amount = totalMoveY

    local rotOverride = self.rotation_override or 0
    self.rotation = self.base_rotation + rotOverride + rot_shake_amount + traumaAngle + pendulumAngle

    -- 9. Follow Target
    if not self.target_x and not self.target_y then return end

    if self.follow_style == 'LOCKON' then
        local w, h = self.w / 16, self.w / 16
        self:setDeadzone((self.w - w) / 2, (self.h - h) / 2, w, h)
    elseif self.follow_style == 'PLATFORMER' then
        local w, h = self.w / 8, self.h / 3
        self:setDeadzone((self.w - w) / 2, (self.h - h) / 2 - h * 0.25, w, h)
    elseif self.follow_style == 'TOPDOWN' then
        local s = math.max(self.w, self.h) / 4
        self:setDeadzone((self.w - s) / 2, (self.h - s) / 2, s, s)
    elseif self.follow_style == 'TOPDOWN_TIGHT' then
        local s = math.max(self.w, self.h) / 8
        self:setDeadzone((self.w - s) / 2, (self.h - s) / 2, s, s)
    elseif self.follow_style == 'SCREEN_BY_SCREEN' then
        self:setDeadzone(0, 0, 0, 0)
    elseif self.follow_style == 'NO_DEADZONE' then
        self.deadzone = nil
    end

    if not self.deadzone then 
        self.x, self.y = self.target_x, self.target_y 
        if self.bound then
            self.x = math.min(math.max(self.x, self.bounds_min_x + self.w / 2), self.bounds_max_x - self.w / 2)
            self.y = math.min(math.max(self.y, self.bounds_min_y + self.h / 2), self.bounds_max_y - self.h / 2)
        end
        return
    end

    local dx1, dy1, dx2, dy2 = self.deadzone_x, self.deadzone_y, self.deadzone_x + self.deadzone_w, self.deadzone_y + self.deadzone_h
    local scroll_x, scroll_y = 0, 0
    local target_x, target_y = self:toCameraCoords(self.target_x, self.target_y)
    local x, y = self:toCameraCoords(self.x, self.y)

    if self.follow_style == 'SCREEN_BY_SCREEN' then
        if self.bound then
            if self.x > self.bounds_min_x + self.w / 2 and target_x < 0 then self.screen_x = csnap(self.screen_x - self.w / self.scale, self.w / self.scale) end
            if self.x < self.bounds_max_x - self.w / 2 and target_x >= self.w then self.screen_x = csnap(self.screen_x + self.w / self.scale, self.w / self.scale) end
            if self.y > self.bounds_min_y + self.h / 2 and target_y < 0 then self.screen_y = csnap(self.screen_y - self.h / self.scale, self.h / self.scale) end
            if self.y < self.bounds_max_y - self.h / 2 and target_y >= self.h then self.screen_y = csnap(self.screen_y + self.h / self.scale, self.h / self.scale) end
        else
            if target_x < 0 then self.screen_x = csnap(self.screen_x - self.w / self.scale, self.w / self.scale) end
            if target_x >= self.w then self.screen_x = csnap(self.screen_x + self.w / self.scale, self.w / self.scale) end
            if target_y < 0 then self.screen_y = csnap(self.screen_y - self.h / self.scale, self.h / self.scale) end
            if target_y >= self.h then self.screen_y = csnap(self.screen_y + self.h / self.scale, self.h / self.scale) end
        end
        self.x = lerp(self.x, self.screen_x, self.follow_lerp_x)
        self.y = lerp(self.y, self.screen_y, self.follow_lerp_y)

        if self.bound then
            self.x = math.min(math.max(self.x, self.bounds_min_x + self.w / 2), self.bounds_max_x - self.w / 2)
            self.y = math.min(math.max(self.y, self.bounds_min_y + self.h / 2), self.bounds_max_y - self.h / 2)
        end
    else
        if target_x < x + (dx1 + dx2 - x) then
            local d = target_x - dx1
            if d < 0 then scroll_x = d end
        end
        if target_x > x - (dx1 + dx2 - x) then
            local d = target_x - dx2
            if d > 0 then scroll_x = d end
        end
        if target_y < y + (dy1 + dy2 - y) then
            local d = target_y - dy1
            if d < 0 then scroll_y = d end
        end
        if target_y > y - (dy1 + dy2 - y) then
            local d = target_y - dy2
            if d > 0 then scroll_y = d end
        end

        if not self.last_target_x and not self.last_target_y then self.last_target_x, self.last_target_y = self.target_x, self.target_y end
        scroll_x = scroll_x + (self.target_x - self.last_target_x) * self.follow_lead_x
        scroll_y = scroll_y + (self.target_y - self.last_target_y) * self.follow_lead_y
        self.last_target_x, self.last_target_y = self.target_x, self.target_y

        self.x = lerp(self.x, self.x + scroll_x, self.follow_lerp_x)
        self.y = lerp(self.y, self.y + scroll_y, self.follow_lerp_y)

        if self.bound then
            self.x = math.min(math.max(self.x, self.bounds_min_x + self.w / 2), self.bounds_max_x - self.w / 2)
            self.y = math.min(math.max(self.y, self.bounds_min_y + self.h / 2), self.bounds_max_y - self.h / 2)
        end
    end
end

function Camera:draw()
    if self.draw_deadzone and self.deadzone then
        local n = love.graphics.getLineWidth()
        love.graphics.setLineWidth(2)
        love.graphics.line(self.deadzone_x - 1, self.deadzone_y, self.deadzone_x + 6, self.deadzone_y)
        love.graphics.line(self.deadzone_x, self.deadzone_y, self.deadzone_x, self.deadzone_y + 6)
        love.graphics.line(self.deadzone_x - 1, self.deadzone_y + self.deadzone_h, self.deadzone_x + 6, self.deadzone_y + self.deadzone_h)
        love.graphics.line(self.deadzone_x, self.deadzone_y + self.deadzone_h, self.deadzone_x, self.deadzone_y + self.deadzone_h - 6)
        love.graphics.line(self.deadzone_x + self.deadzone_w + 1, self.deadzone_y + self.deadzone_h, self.deadzone_x + self.deadzone_w - 6, self.deadzone_y + self.deadzone_h)
        love.graphics.line(self.deadzone_x + self.deadzone_w, self.deadzone_y + self.deadzone_h, self.deadzone_x + self.deadzone_w, self.deadzone_y + self.deadzone_h - 6)
        love.graphics.line(self.deadzone_x + self.deadzone_w + 1, self.deadzone_y, self.deadzone_x + self.deadzone_w - 6, self.deadzone_y)
        love.graphics.line(self.deadzone_x + self.deadzone_w, self.deadzone_y, self.deadzone_x + self.deadzone_w, self.deadzone_y + 6)
        love.graphics.setLineWidth(n)
    end

    -- Flash Normal (Fullscreen)
    local curW = love.graphics.getWidth()
    local curH = love.graphics.getHeight()

    if self.flashing then
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(self.flash_color)
        love.graphics.rectangle('fill', 0, 0, curW, curH)
        love.graphics.setColor(r, g, b, a)
    end

    -- Flash In / Out (Fullscreen)
    if self.flash_in_out and self.flash_current_alpha > 0.001 then
        local r, g, b, a = love.graphics.getColor()
        local col = self.flash_in_out_color
        love.graphics.setColor(col[1] or 1, col[2] or 1, col[3] or 1, self.flash_current_alpha)
        love.graphics.rectangle('fill', 0, 0, curW, curH)
        love.graphics.setColor(r, g, b, a)
    end

    -- Fade (Fullscreen)
    if self.fading or (self.fade_color and self.fade_color[4] and self.fade_color[4] > 0.001) then
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(self.fade_color)
        love.graphics.rectangle('fill', 0, 0, curW, curH)
        love.graphics.setColor(r, g, b, a)
    end
end

function Camera:follow(x, y)
    self.target_x, self.target_y = x, y
end

function Camera:setDeadzone(x, y, w, h)
    self.deadzone = true
    self.deadzone_x = x
    self.deadzone_y = y
    self.deadzone_w = w
    self.deadzone_h = h
end

function Camera:setBounds(x, y, w, h)
    self.bound = true
    self.bounds_min_x = x
    self.bounds_min_y = y
    self.bounds_max_x = x + w
    self.bounds_max_y = y + h
end

function Camera:setFollowStyle(follow_style)
    self.follow_style = follow_style
end

function Camera:setFollowLerp(x, y)
    self.follow_lerp_x = x
    self.follow_lerp_y = y or x
end

function Camera:setFollowLead(x, y)
    self.follow_lead_x = x
    self.follow_lead_y = y or x
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})