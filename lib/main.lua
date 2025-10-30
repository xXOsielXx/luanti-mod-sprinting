-- Main orchestration for the Sprinting mod: registers players and the globalstep
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

local config = dofile(modpath.."/lib/config.lua")
local update_air_time,
    player_is_on_ground,
    player_is_in_liquid,
    player_is_on_climbable,
    player_is_lying_on_bed,
    get_particle_texture,
    check_for_double_tap = dofile(modpath.."/lib/player.lua")

local stamina_mod = dofile(modpath.."/lib/stamina.lua")
local particles_mod = dofile(modpath.."/lib/particles.lua")

local TIME_IN_AIR_LIMIT = config.TIME_IN_AIR_LIMIT
local DOUBLE_TAP_TIME = config.DOUBLE_TAP_TIME
local DEFAULT_FOV = config.DEFAULT_FOV
local PARTICLE_SCALE = config.PARTICLE_SCALE
local PARTICLE_INTERVAL = config.PARTICLE_INTERVAL
local GRACE_TIME = config.GRACE_TIME
local FLIGHT_TIME_THRESHOLD = config.FLIGHT_TIME_THRESHOLD
local FLIGHT_VY_THRESHOLD = config.FLIGHT_VY_THRESHOLD

local USE_AUX1 = config.USE_AUX1
local SPEED_MULTIPLIER = config.SPEED_MULTIPLIER
local JUMP_MULTIPLIER = config.JUMP_MULTIPLIER

local ENABLE_STAMINA_DRAIN = config.ENABLE_STAMINA_DRAIN
local STAMINA_DRAIN = config.STAMINA_DRAIN
local STAMINA_THRESHOLD = config.STAMINA_THRESHOLD

local REQUIRE_GROUND = config.REQUIRE_GROUND
local SPRINT_ON_CLIMBABLE = config.SPRINT_ON_CLIMBABLE
local SPRINT_IN_LIQUIDS = config.SPRINT_IN_LIQUIDS

local SPAWN_PARTICLES = config.SPAWN_PARTICLES
local CHANGE_FOV = config.CHANGE_FOV
local FOV_BOOST = config.FOV_BOOST
local FOV_TRANSITION_TIME = config.FOV_TRANSITION_TIME

local has_stamina = minetest.get_modpath("stamina") and stamina
local has_hunger_ng = minetest.get_modpath("hunger_ng") and hunger_ng
local has_hbhunger = minetest.get_modpath("hbhunger") and hbhunger

local has_character_anim = minetest.get_modpath("character_anim") ~= nil

-- Disable sprint in external stamina mod if present
if has_stamina then
    if stamina.settings then
        stamina.settings.sprint = false
        stamina.settings.sprint_particles = false
    else
        stamina.enable_sprint = false
        stamina.enable_sprint_particles = false
    end
end

local CONVERSION_FACTOR = config.CONVERSION_FACTOR

local sprint_players = {}

local ANIMATIONS = {
    idle = {x = 0, y = 79},
    walk = {x = 168, y = 187},
    dig = {x = 189, y = 198},
    walk_while_dig = {x = 200, y = 219}
}

local ANIM_SPEED_IDLE = 30
local ANIM_SPEED_SPRINT = ANIM_SPEED_IDLE * SPEED_MULTIPLIER

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local physics = player:get_physics_override()
    sprint_players[name] = {
        sprinting = false,
        node_below_player = { name = "air" },
        on_ground = false,
        time_in_air = 0,
        in_liquid = false,
        on_climbable = false,
        lying_on_bed = false,
        double_tap = false,
        last_key_time = 0,
        original_fov = minetest.settings:get("fov") or DEFAULT_FOV,
        current_fov = 0,
        original_speed = physics.speed,
        original_jump = physics.jump,
        was_pressing_forward = false,
        particle_timer = 0,
        current_stamina = math.huge,
        hbhunger_accumulator = 0,
        using_aux = false,
        sprint_start_time = 0,
        collision = false,
        can_sprint = true
    }
    player:set_local_animation(
        ANIMATIONS.idle,
        ANIMATIONS.walk,
        ANIMATIONS.dig,
        ANIMATIONS.walk_while_dig,
        ANIM_SPEED_IDLE
    )
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local data = sprint_players[name]
    if data then
        player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
        player:set_fov(0, false)
        sprint_players[name] = nil
    end
end)

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local data = sprint_players[name]
        if not data then return end
        local controls = player:get_player_control()
        local pos = player:get_pos()
        local dir = player:get_look_dir()

        -- node below sampling aligned with helpers
        local x = math.floor(pos.x + 0.5)
        local z = math.floor(pos.z + 0.5)
        local y = math.floor(pos.y - 0.1 + 0.5)
        data.node_below_player = core.get_node_or_nil(vector.new(x, y, z)) or { name = "ignore" }

        local detected_in_liquid = player_is_in_liquid(pos)
        local now = core.get_us_time() / 1e6
        data._in_liquid_since = data._in_liquid_since or (detected_in_liquid and now or nil)
        if data.in_liquid == nil then data.in_liquid = detected_in_liquid end
        local DEBOUNCE_TIME = 0.12
        if detected_in_liquid ~= data.in_liquid then
            if data._in_liquid_since == nil then
                data._in_liquid_since = now
            else
                if now - data._in_liquid_since >= DEBOUNCE_TIME then
                    data.in_liquid = detected_in_liquid
                end
            end
        else
            data._in_liquid_since = detected_in_liquid and now or nil
        end

    data.on_climbable = player_is_on_climbable(player)
    data.lying_on_bed = player_is_lying_on_bed(player, data.node_below_player)
    data.on_ground = player_is_on_ground(pos)
    data.double_tap = check_for_double_tap(controls, data, DOUBLE_TAP_TIME)

    -- Compute airborne time
    data.time_in_air = update_air_time(data, data.on_ground, dtime, TIME_IN_AIR_LIMIT)

        if ENABLE_STAMINA_DRAIN then
            data.current_stamina = stamina_mod.get_current(player) or data.current_stamina
        end

        -- Apply sprint effects if active
        if data.sprinting then
            if ENABLE_STAMINA_DRAIN then
                stamina_mod.drain(player, data, dtime)
            end
            player:set_physics_override({
                speed = data.original_speed * SPEED_MULTIPLIER,
                jump = data.original_jump * JUMP_MULTIPLIER
            })
            if SPAWN_PARTICLES then
                if data.on_ground and not data.on_climbable and particles_mod.should_spawn(data.node_below_player) then
                    data.particle_timer = data.particle_timer + dtime
                    if data.particle_timer >= PARTICLE_INTERVAL then
                        data.particle_timer = 0
                        particles_mod.spawn_trail(player, data.node_below_player, PARTICLE_SCALE)
                    end
                end
            end
        end

        if CHANGE_FOV then
            local target_fov = data.sprinting and (data.original_fov + FOV_BOOST) or 0
            if target_fov ~= data.current_fov then
                player:set_fov(target_fov, false, FOV_TRANSITION_TIME)
                data.current_fov = target_fov
            end
        end

        -- Collision detection
        local vel = player:get_velocity()
        local hvel = math.sqrt(vel.x * vel.x + vel.z * vel.z)
        local sprint_speed = data.original_speed * SPEED_MULTIPLIER
        if data.sprinting and controls.up and not data.on_climbable then
            local now = minetest.get_us_time() / 1e6
            if now - data.sprint_start_time > GRACE_TIME and hvel < sprint_speed then
                data.collision = true
            end
        end
        if hvel >= data.original_speed * 0.95 then
            data.collision = false
        end

        local function check_if_player_can_sprint()
            data.can_sprint = true
            if ENABLE_STAMINA_DRAIN and data.current_stamina then
                if has_hunger_ng then
                    local threshold_value = STAMINA_THRESHOLD * CONVERSION_FACTOR.STAMINA_THRESHOLD.hunger_ng
                    data.can_sprint = data.current_stamina > threshold_value
                elseif has_hbhunger then
                    local threshold_value = STAMINA_THRESHOLD * CONVERSION_FACTOR.STAMINA_THRESHOLD.hb_hunger
                    data.can_sprint = data.current_stamina > threshold_value
                elseif has_stamina then
                    local threshold_value = STAMINA_THRESHOLD * CONVERSION_FACTOR.STAMINA_THRESHOLD.stamina
                    data.can_sprint = data.current_stamina > threshold_value
                end
            end
            if REQUIRE_GROUND then
                data.can_sprint = data.can_sprint and (data.on_ground or controls.jump or (data.time_in_air < TIME_IN_AIR_LIMIT))
            end
            if not SPRINT_ON_CLIMBABLE then data.can_sprint = data.can_sprint and not data.on_climbable end
            if not SPRINT_IN_LIQUIDS then data.can_sprint = data.can_sprint and not data.in_liquid end
            data.can_sprint = data.can_sprint and not player:get_attach()
            data.can_sprint = data.can_sprint and not data.lying_on_bed
        end

        check_if_player_can_sprint()

    -- Use `data.on_ground` (and `data.time_in_air`) to represent airborne state.
        local can_activate = data.can_sprint and not data.collision and not data.using_aux and not controls.down
            and not (controls.sneak and not data.in_liquid)
        if data.double_tap then
            can_activate = can_activate and data.can_sprint
        end
        if can_activate and ((USE_AUX1 and controls.aux1 and controls.up) or data.double_tap) then
            if REQUIRE_GROUND and not (data.on_ground or controls.jump or (data.time_in_air < TIME_IN_AIR_LIMIT)) and not SPRINT_IN_LIQUIDS then
                can_activate = false
            end
        end
        if can_activate and ((USE_AUX1 and controls.aux1 and controls.up) or data.double_tap) then
            data.sprinting = true
            data.using_aux = controls.aux1
            if has_character_anim then
                local frange, orig_speed, fblend, floop = player:get_animation()
                data.original_anim_speed = orig_speed
                player:set_animation(frange, orig_speed * SPEED_MULTIPLIER, fblend, floop)
            else
                player:set_local_animation(
                    ANIMATIONS.idle,
                    ANIMATIONS.walk, ANIMATIONS.dig,
                    ANIMATIONS.walk_while_dig,
                    ANIM_SPEED_SPRINT
                )
            end
        end

        if data.sprinting and (
            (USE_AUX1 and (data.using_aux and (not controls.aux1 or not controls.up))) or
            (not data.using_aux and not controls.up) or
            data.collision or
            controls.down or
            (controls.sneak and not data.in_liquid and data.on_ground and not controls.jump) or 
            not data.can_sprint
        ) then
            data.sprinting = false
            data.using_aux = false
            player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
            if has_character_anim then
                local frange, _, fblend, floop = player:get_animation()
                player:set_animation(frange, data.original_anim_speed, fblend, floop)
            else
                player:set_local_animation(
                    ANIMATIONS.idle,
                    ANIMATIONS.walk,
                    ANIMATIONS.dig,
                    ANIMATIONS.walk_while_dig,
                    ANIM_SPEED_IDLE
                )
            end
        end

        data.was_pressing_forward = controls.up
    end
end)