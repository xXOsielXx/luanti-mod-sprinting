local modpath = minetest.get_modpath(minetest.get_current_modname())
local config = dofile(modpath.."/lib/config.lua")

local M = {}

-- Stamina/hunger compatibility helpers for the Sprinting mod
local has_stamina = minetest.get_modpath("stamina") and stamina
local has_hunger_ng = minetest.get_modpath("hunger_ng") and hunger_ng
local has_hbhunger = minetest.get_modpath("hbhunger") and hbhunger

function M.get_current(player)
    local name = player:get_player_name()
    if has_hunger_ng then
        local info = hunger_ng.get_hunger_information(name)
        return info and info.hunger.exact or nil
    end
    if has_hbhunger then
        return hbhunger.get_hunger_raw(player) or nil
    end
    if has_stamina then
        return tonumber(player:get_meta():get("stamina:level")) or nil
    end
    return nil
end

function M.drain(player, data, dtime)
    if not config.ENABLE_STAMINA_DRAIN then return end
    local name = player:get_player_name()
    if has_hunger_ng and (not has_stamina or (has_stamina and not data.using_aux)) then
        hunger_ng.alter_hunger(name, -(config.STAMINA_DRAIN * config.CONVERSION_FACTOR.STAMINA_DRAIN.hunger_ng) * dtime)
    elseif has_hbhunger and (not has_stamina or (has_stamina and not data.using_aux)) then
        local drain_value = (config.STAMINA_DRAIN * config.CONVERSION_FACTOR.STAMINA_DRAIN.hb_hunger)
        data.hbhunger_accumulator = data.hbhunger_accumulator + drain_value * dtime
        if data.hbhunger_accumulator >= 1 then
            local new_hunger = math.max(0, hbhunger.get_hunger_raw(player) - math.floor(data.hbhunger_accumulator))
            hbhunger.hunger[name] = new_hunger
            hbhunger.set_hunger_raw(player)
            data.hbhunger_accumulator = data.hbhunger_accumulator % 1
        end
    elseif has_stamina then
        stamina.change(player, -(config.STAMINA_DRAIN * config.CONVERSION_FACTOR.STAMINA_DRAIN.stamina) * dtime)
    end
end

return M
