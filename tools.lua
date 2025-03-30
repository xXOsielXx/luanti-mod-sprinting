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

return player_is_in_liquid, player_is_on_climbable
