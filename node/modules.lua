local Modules = {}

-- 1. GUI & State Management
_G.Slab       = require("lib.slab")
_G.SlabWindow = require("lib.slab.Internal.UI.Window")
_G.Gamestate  = require("lib.gamestate")

-- 2. Utilities & Parsers
_G.json       = require("lib.json")
_G.lume       = require("lib.lume")
_G.lurker     = require("lib.lurker")
_G.Timer      = require("lib.timer")
_G.tchart     = require("lib.tchart")

-- 3. Audio & Visual Effects
_G.wave       = require("lib.wave")
_G.teffect    = require("lib.teffect")

return Modules
