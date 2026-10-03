require("node.modules")
local MenuNode = require("node.menu")

function love.load(args)
    love.window.setTitle("Rhytmia Editor")
    love.window.setMode(1024, 680, { resizable = true, minwidth = 800, minheight = 500 })
    love.graphics.setBackgroundColor(0.04, 0.04, 0.04)

    -- Inisialisasi Slab GUI & Nonaktifkan Docking Zones (3 kotak biru)
    Slab.Initialize(args)
    Slab.DisableDocks({ 'Left', 'Right', 'Bottom' })

    -- Switch langsung ke Menu Node
    Gamestate.switch(MenuNode)
end

function love.update(dt)
    Slab.Update(dt)
    Gamestate.update(dt)
    lurker.update()
end

function love.draw()
    -- 1. Gambar canvas playfield terlebih dahulu
    Gamestate.draw()
    -- 2. Gambar Slab UI di atas canvas agar tidak tertimpa
    Slab.Draw()
end

function love.mousepressed(x, y, button, istouch, presses)
    if Gamestate.mousepressed then
        Gamestate.mousepressed(x, y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if Gamestate.mousereleased then
        Gamestate.mousereleased(x, y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if Gamestate.mousemoved then
        Gamestate.mousemoved(x, y, dx, dy, istouch)
    end
end

function love.wheelmoved(x, y)
    if Gamestate.wheelmoved then
        Gamestate.wheelmoved(x, y)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if Gamestate.keypressed then
        Gamestate.keypressed(key, scancode, isrepeat)
    end
end

function love.keyreleased(key, scancode)
    if Gamestate.keyreleased then
        Gamestate.keyreleased(key, scancode)
    end
end

function love.textinput(text)
    if Gamestate.textinput then
        Gamestate.textinput(text)
    end
end

function love.resize(w, h)
    if Gamestate.resize then
        Gamestate.resize(w, h)
    end
end

function love.quit()
    if Gamestate.quit then
        Gamestate.quit()
    end
end

