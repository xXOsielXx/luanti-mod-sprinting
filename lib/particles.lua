-- Particle utilities for the Sprinting mod
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local config = dofile(modpath.."/lib/config.lua")
local helpers = dofile(modpath.."/lib/helpers.lua")
local _, _, _, _, _, get_particle_texture = dofile(modpath.."/lib/player.lua")

local M = {}

local NO_PARTICLE_GROUPS = {"bed", "door", "rail", "attached_node", "wallmounted", "torch", "sapling", "plant", "grass", "flora", "flower", "seed", "mushroom", "fire"}

function M.should_spawn(node)
    if not node or not node.name then return false end
    for _, group in ipairs(NO_PARTICLE_GROUPS) do
        if minetest.get_item_group(node.name, group) ~= 0 then
            return false
        end
    end
    return true
end

function M.spawn_trail(player, node, scale)
    if not node or not node.name then return end
    local texture = get_particle_texture(node)
    if not texture then return end
    minetest.add_particlespawner({
        amount = math.random(1, 2),
        time = 0.1,
        minpos = {x=-0.5, y=0.1, z=-0.5},
        maxpos = {x=0.5, y=0.1, z=0.5},
        minvel = {x=0, y=5, z=0},
        maxvel = {x=0, y=5, z=0},
        minacc = {x=0, y=-13, z=0},
        maxacc = {x=0, y=-13, z=0},
        minexptime = 0.1,
        maxexptime = 1,
        minsize = scale,
        maxsize = scale * 2,
        collisiondetection = true,
        attached = player,
        vertical = false,
        playername = player:get_player_name(),
        glow = 2,
        texture = texture
    })
end

return M
