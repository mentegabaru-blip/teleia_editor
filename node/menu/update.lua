local Logic = require("node.menu.logic")

local Update = {}

function Update.update(dt)
    -- Logic update berkala jika diperlukan (misal refresh keyboard shortcuts)
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if love.keyboard.isDown("n") and not Logic.showNewModal then
            Logic.showNewModal = true
        end
    end
end

return Update
