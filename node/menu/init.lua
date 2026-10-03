local Logic = require("node.menu.logic")
local Update = require("node.menu.update")
local Draw = require("node.menu.draw")

local MenuNode = {
    logic = Logic,
    update = Update,
    draw = Draw
}

function MenuNode:init()
    Logic.loadRecentCharts()
end

function MenuNode:enter(prev, ...)
    Logic.loadRecentCharts()
end

function MenuNode:update(dt)
    Update.update(dt)
    -- Render Slab UI untuk scene Menu
    Draw.all()
end

function MenuNode:draw()
    -- Penggambaran grafis khusus jika ada (Slab.Draw dipanggil di love.draw)
end

function MenuNode:leave()
end

return MenuNode
