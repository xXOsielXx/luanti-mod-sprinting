-- Helper functions

local function is_player_running_against_wall(player)
    -- Get the player's position and adjust it to eye level  
    local pos = player:get_pos()  
    pos.y = pos.y + player:get_properties().eye_height  

    -- Calculate horizontal direction (ignoring vertical component)  
    local angle = player:get_look_horizontal()  
    local dir = vector.rotate_around_axis({x=0, y=0, z=1}, {x=0, y=1, z=0}, angle)  
    dir = vector.normalize(dir)  

    -- Calculate position in front of the eyes
    local eye_pos = vector.round(vector.add(pos, dir))
    local eye_node = minetest.get_node(eye_pos)
    local eye_walkable = minetest.registered_nodes[eye_node.name].walkable

    -- Calculate position in front of the feet
    local feet_pos = vector.subtract(eye_pos, {x=0, y=1, z=0})
    local feet_node = minetest.get_node(feet_pos)
    local feet_walkable = minetest.registered_nodes[feet_node.name].walkable

    if eye_walkable or feet_walkable then  
        return true  
    else  
        return false  
    end  
end

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
local function player_is_lying_on_bed(player, node)
    if has_beds then
        if not player or not beds.player then
            return false
        end
        local name = player:get_player_name()
        return beds.player[name] ~= nil
    else
        local on_bed = string.match(node.name, "bed")
        if on_bed then return true else return false end
    end
end

local function get_particle_texture(node)
    local node_def = minetest.registered_nodes[node.name]
    if not node_def or not node_def.tiles then
        return nil
    end

    local tiles = node_def.tiles

    -- Return the node's bottom texture if the node is dirt with grass, 
    -- because it's more visually appealing this way.
    local idx = (node.name:match("dirt.*grass") and 2) or 1
    local tile_entry = tiles[idx]

    if type(tile_entry) == "table" then
        tile_entry = tile_entry.name or tile_entry[1]
    end

    if type(tile_entry) ~= "string" then
        return nil
    end

    -- Choose a random subtile from a 3x3 texture sheet
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

return is_player_running_against_wall, player_is_in_liquid, player_is_on_climbable, player_is_lying_on_bed, get_particle_texture, check_for_double_tap