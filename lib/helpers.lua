local M = {}

-- Helper utilities for the Sprinting mod
function M.round_node_pos(pos, y_offset)
    y_offset = y_offset or 0
    return math.floor(pos.x + 0.5), math.floor(pos.y + y_offset + 0.5), math.floor(pos.z + 0.5)
end

function M.node_at(pos)
    return core.get_node_or_nil(pos)
end

function M.node_is_solid(node)
    return node and node.name and node.name ~= "ignore" and node.name ~= "air"
end

function M.node_is_liquid(node)
    if not node or not node.name or node.name == "ignore" then return false end
    local nodedef = core.registered_nodes[node.name]
    return nodedef and nodedef.liquidtype and nodedef.liquidtype ~= "none"
end

return M
