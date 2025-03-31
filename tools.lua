-- Helper functions

local function player_is_in_liquid(pos)
    local feet_pos = { x = pos.x, y = pos.y - 0.5, z = pos.z }
    local head_pos = { x = pos.x, y = pos.y + 0.85, z = pos.z }
    local check_positions = { vector.round(feet_pos), vector.round(head_pos) }
    for _, p in ipairs(check_positions) do
        local node = core.get_node_or_nil(p)
        if node then
            local nodedef = core.registered_nodes[node.name]
            if nodedef and nodedef.liquidtype and nodedef.liquidtype ~= "none" then
                return true
            end
        end
    end
    return false 
end

local function player_is_on_climbable(player)
    local pos = player:get_pos()
    pos.y = pos.y - 0.5 
    local node = minetest.get_node_or_nil(pos)
    if node ~= nil then
        local nodedef = minetest.registered_nodes[node.name]
        return nodedef and nodedef.climbable or false
    else 
        return false
    end
end

local has_beds = minetest.get_modpath("beds") ~= nil
local function player_is_on_bed(player)
    if has_beds then
        if not player or not beds.player then
            return false
        end
        local name = player:get_player_name()
        return beds.player[name] ~= nil
    else
        local pos = player:get_pos()
        local node_below_player = minetest.get_node(vector.new(pos.x, pos.y-0.1, pos.z)).name
        local on_bed = string.match(node_below_player, "bed")
        if on_bed then return true else return false end
    end
end

local function get_particle_texture(pos)
    local ground_pos = vector.new(math.floor(pos.x), math.floor(pos.y - 0.1), math.floor(pos.z))
    local node = minetest.get_node(ground_pos)
    local node_def = minetest.registered_nodes[node.name]
    
    -- Return the node's bottom texture or first texture if unavailable
    if node_def and node_def.tiles then
        local bottom_tile = node_def.tiles[2] or node_def.tiles[1]
        return type(bottom_tile) == "table" and bottom_tile.name or bottom_tile
    end
end

return player_is_in_liquid, player_is_on_climbable, player_is_on_bed, get_particle_texture