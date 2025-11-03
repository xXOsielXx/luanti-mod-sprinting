local modpath = minetest.get_modpath(minetest.get_current_modname())
local helpers = dofile(modpath.."/lib/helpers.lua")
-- Player-related utilities for the Sprinting mod

local has_beds = minetest.get_modpath("beds") ~= nil

local function update_air_time(data, on_ground, dtime, limit)
    if not on_ground then
        data.time_in_air = (data.time_in_air or 0) + dtime
    else
        data.time_in_air = 0
    end
    return data.time_in_air
end

local function player_is_on_ground(pos)
    local x,y,z = helpers.round_node_pos(pos, -0.1)
    local feet_pos = vector.new(x, y, z)
    local n = helpers.node_at(feet_pos)
    return helpers.node_is_solid(n)
end

local function player_is_in_liquid(pos)
    local x = math.floor(pos.x + 0.5)
    local z = math.floor(pos.z + 0.5)
    local feet_y = math.floor(pos.y - 0.1 + 0.5)
    local node_y = math.floor(pos.y + 0.5)
    local mid_y = node_y + 1
    local below_y = math.floor(pos.y - 1.1 + 0.5)

    local positions = {
        vector.new(x, feet_y, z),
        vector.new(x, mid_y, z),
        vector.new(x, below_y, z)
    }
    for _, p in ipairs(positions) do
        local n = helpers.node_at(p)
        if helpers.node_is_liquid(n) then
            return true
        end
    end
    return false
end

local function player_is_on_climbable(player)
    local pos = player:get_pos()
    pos.y = pos.y - 0.5
    local node = helpers.node_at(pos)
    if node then
        local nodedef = minetest.registered_nodes[node.name]
        return nodedef and nodedef.climbable or false
    end
    return false
end

local function player_is_lying_on_bed(player, node)
    if has_beds then
        if not player or not beds.player then
            return false
        end
        local name = player:get_player_name()
        return beds.player[name] ~= nil
    else
        return node.name:match("bed") and true or false
    end
end

local function get_particle_texture(node)
    local node_def = minetest.registered_nodes[node.name]
    if not node_def or not node_def.tiles then
        return nil
    end
    local tiles = node_def.tiles
    local idx = (node.name:match("dirt.*grass") and 2) or 1
    local tile_entry = tiles[idx]
    if type(tile_entry) == "table" then
        tile_entry = tile_entry.name or tile_entry[1]
    end
    if type(tile_entry) ~= "string" then
        return nil
    end
    local colnum = math.random(0, 2)
    local rownum = math.random(0, 2)
    local sheet_modifier = string.format("^[sheet:3x3:%d,%d]", colnum, rownum)
    return tile_entry .. sheet_modifier
end

local function check_for_double_tap(controls, data, DOUBLE_TAP_TIME)
    if controls.up and not data.was_pressing_forward and not controls.down and not controls.sneak then
        local current_time = minetest.get_us_time() / 1e6
        if (current_time - data.last_key_time) < DOUBLE_TAP_TIME then
            return true
        end
        data.last_key_time = current_time
    end
    return false
end

return update_air_time,
    player_is_on_ground,
    player_is_in_liquid,
    player_is_on_climbable,
    player_is_lying_on_bed,
    get_particle_texture,
    check_for_double_tap
