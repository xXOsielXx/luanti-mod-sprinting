local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
-- Load configuration and player-related helpers from lib/
local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath.."/lib/main.lua")
