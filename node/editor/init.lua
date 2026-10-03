local Logic = require("node.editor.logic")
local Update = require("node.editor.update")
local Draw = require("node.editor.draw")

local EditorNode = {
    logic = Logic,
    update = Update,
    draw = Draw
}

function EditorNode:init()
end

function EditorNode:enter(prev, chartInfo)
    Slab.DisableDocks({ 'Left', 'Right', 'Bottom' })
    if chartInfo then
        Logic.loadChart(chartInfo)
    end
end

function EditorNode:update(dt)
    Update.update(dt)
    Draw.ui()
end

function EditorNode:draw()
    Draw.playfield()
end

function EditorNode:mousepressed(x, y, button, istouch, presses)
    Update.mousepressed(x, y, button, istouch, presses)
end

function EditorNode:mousereleased(x, y, button, istouch, presses)
    Update.mousereleased(x, y, button, istouch, presses)
end

function EditorNode:mousemoved(x, y, dx, dy, istouch)
    Update.mousemoved(x, y, dx, dy, istouch)
end

function EditorNode:wheelmoved(x, y)
    Update.wheelmoved(x, y)
end

function EditorNode:keypressed(key, scancode, isrepeat)
    Update.keypressed(key)
end

function EditorNode:resize(w, h)
    if Logic.camera and Logic.camera.resize then
        Logic.camera:resize(w, h)
    end
end

function EditorNode:leave()
    if Logic.audioSource then
        Logic.audioSource:stop()
    end
end

return EditorNode
