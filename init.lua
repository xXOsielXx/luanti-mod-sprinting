-- Sprinting Mod --

-- Configuration constants for sprinting mechanics
local DOUBLE_TAP_TIME = 0.5  -- Max time (seconds) between forward key presses for double-tap sprint
local DEFAULT_FOV = 72       -- Base field of view when not sprinting
local FOV_BOOST = 20         -- FOV increase during sprint
local FOV_TRANSITION_SPEED = 8 -- Smoothness of FOV changes
local PARTICLE_SCALE = 0.5   -- Size multiplier for sprint particles
local PARTICLE_INTERVAL = 0.1 -- Time between particle spawns (seconds)

-- Mod settings with default values
local ENABLE_HUNGER_DRAIN = minetest.settings:get_bool("sprinting_drain_hunger", true)
local STAMINA_DRAIN = tonumber(minetest.settings:get("sprinting_stamina_drain")) or 0.25
local STAMINA_THRESHOLD = tonumber(minetest.settings:get("sprinting_stamina_threshold")) or 5
local HUNGER_NG_DRAIN = tonumber(minetest.settings:get("sprinting_hunger_ng_drain")) or 0.25
local HUNGER_NG_THRESHOLD = tonumber(minetest.settings:get("sprinting_hunger_ng_threshold")) or 4
local HBHUNGER_DRAIN = tonumber(minetest.settings:get("sprinting_hbhunger_drain")) or 0.5
local HBHUNGER_THRESHOLD = tonumber(minetest.settings:get("sprinting_hbhunger_threshold")) or 6
local SPEED_MULTIPLIER = tonumber(minetest.settings:get("sprinting_speed_multiplier")) or 1.5
local JUMP_MULTIPLIER = tonumber(minetest.settings:get("sprinting_jump_multiplier")) or 1.10
local SPAWN_PARTICLES = minetest.settings:get_bool("sprinting_spawn_particles", true)
local REQUIRE_GROUND = minetest.settings:get_bool("sprinting_require_ground", true)

-- Detect compatible mods for stamina/hunger systems
local has_stamina = minetest.get_modpath("stamina") ~= nil
local has_hunger_ng = minetest.get_modpath("hunger_ng") ~= nil
local has_hbhunger = minetest.get_modpath("hbhunger") ~= nil

-- Player-specific sprint data storage
local sprint_players = {}

-- Animation definitions for different movement states
local ANIMATIONS = {
    idle = {x = 0, y = 79},               -- Standing still animation
    walk = {x = 168, y = 187},           -- Regular walking animation
    dig = {x = 189, y = 198},            -- Primary action (e.g., mining)
    walk_while_dig = {x = 200, y = 219}  -- Walking while performing action
}

-- Animation playback speeds
local ANIM_SPEED_IDLE = 30               -- Base animation speed
local ANIM_SPEED_SPRINT = ANIM_SPEED_IDLE * 1.8 -- Faster animations when sprinting

-- Helper function to get ground texture for particles
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

-- Initialize player data on join
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local physics = player:get_physics_override()
    
    sprint_players[name] = {
        sprinting = false,          -- Current sprint state
        last_key_time = 0,          -- Timestamp of last forward key press
        original_fov = minetest.settings:get("fov") or DEFAULT_FOV, -- Save original FOV
        current_fov = DEFAULT_FOV,  -- Tracks transitioning FOV
        original_speed = physics.speed, -- Base movement speed
        original_jump = physics.jump,   -- Base jump height
        was_pressing_forward = false, -- Previous forward key state
        particle_timer = 0,         -- Cooldown for particle effects
        hbhunger_accumulator = 0,   -- For fractional hunger drain
        using_aux = false           -- Whether using aux1 to sprint
    }
    
    -- Set default animations
    player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig, 
        ANIMATIONS.walk_while_dig, ANIM_SPEED_IDLE)
end)

-- Cleanup player data on leave
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local data = sprint_players[name]
    
    if data then
        -- Restore original physics and FOV
        player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
        player:set_fov(data.original_fov, false)
        sprint_players[name] = nil
    end
end)

-- Main loop for sprinting logic
minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local data = sprint_players[name]
        if not data then return end
        
        local controls = player:get_player_control()
        local pos = player:get_pos()
        local on_ground = minetest.get_node(vector.new(pos.x, pos.y-0.1, pos.z)).name ~= "air"

        -- Get stamina/hunger values (infinite if mod not present)
        local current_stamina = has_stamina and tonumber(player:get_meta():get("stamina:level")) or math.huge
        local current_hunger = math.huge
        
        -- Check hunger levels based on available mods
        if ENABLE_HUNGER_DRAIN then
            if has_hunger_ng then
                local hunger_info = hunger_ng.get_hunger_information(name)
                current_hunger = hunger_info and hunger_info.hunger.exact or current_hunger
            elseif has_hbhunger then
                current_hunger = hbhunger.get_hunger_raw(player) or current_hunger
            end
        end

        -- Handle sprint activation via aux1 (sneak) + forward
        if controls.aux1 and controls.up and not controls.sneak then
            if not data.sprinting then
                local can_sprint = true
                -- Check stamina requirements
                if has_stamina then can_sprint = current_stamina > STAMINA_THRESHOLD end
                -- Check hunger requirements based on mod
                if ENABLE_HUNGER_DRAIN then
                    if has_hunger_ng then can_sprint = can_sprint and current_hunger > HUNGER_NG_THRESHOLD
                    elseif has_hbhunger then can_sprint = can_sprint and current_hunger > HBHUNGER_THRESHOLD end
                end
                -- Check if grounded when required
                if REQUIRE_GROUND then can_sprint = can_sprint and on_ground end
                
                -- Activate sprint if all conditions met
                if can_sprint then
                    data.sprinting = true
                    data.using_aux = true
                    player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig,
                        ANIMATIONS.walk_while_dig, ANIM_SPEED_SPRINT)
                end
            end
        else
            -- Handle double-tap forward to sprint
            if controls.up and not data.was_pressing_forward and not controls.sneak then
                local current_time = minetest.get_us_time() / 1e6
                if (current_time - data.last_key_time) < DOUBLE_TAP_TIME then
                    local can_sprint = true
                    if has_stamina then can_sprint = current_stamina > STAMINA_THRESHOLD end
                    if ENABLE_HUNGER_DRAIN then
                        if has_hunger_ng then can_sprint = can_sprint and current_hunger > HUNGER_NG_THRESHOLD
                        elseif has_hbhunger then can_sprint = can_sprint and current_hunger > HBHUNGER_THRESHOLD end
                    end
                    if REQUIRE_GROUND then can_sprint = can_sprint and on_ground end
                    
                    if can_sprint then
                        data.sprinting = true
                        data.using_aux = false
                        player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig,
                            ANIMATIONS.walk_while_dig, ANIM_SPEED_SPRINT)
                    end
                end
                data.last_key_time = current_time
            end
        end

        -- Apply sprint effects if active
        if data.sprinting then
            -- Drain stamina
            if has_stamina and ENABLE_HUNGER_DRAIN then
                stamina.change(player, -STAMINA_DRAIN * dtime)
            end
            
            -- Drain hunger based on mod
            if ENABLE_HUNGER_DRAIN then
                if has_hunger_ng then
                    hunger_ng.alter_hunger(name, -HUNGER_NG_DRAIN * dtime)
                elseif has_hbhunger then
                    -- Accumulate fractional drain for hbhunger's integer system
                    data.hbhunger_accumulator = data.hbhunger_accumulator + HBHUNGER_DRAIN * dtime
                    if data.hbhunger_accumulator >= 1 then
                        local new_hunger = math.max(0, hbhunger.get_hunger_raw(player) - math.floor(data.hbhunger_accumulator))
                        hbhunger.hunger[name] = new_hunger
                        hbhunger.set_hunger_raw(player)
                        data.hbhunger_accumulator = data.hbhunger_accumulator % 1
                    end
                end
            end

            -- Apply speed and jump boosts
            player:set_physics_override({
                speed = data.original_speed * SPEED_MULTIPLIER,
                jump = data.original_jump * JUMP_MULTIPLIER
            })
        end

        -- Check for sprint termination conditions
        if data.sprinting and (
            (data.using_aux and (not controls.aux1 or not controls.up)) or -- Released controls
            (not data.using_aux and not controls.up) or -- Stopped moving forward
            (has_stamina and current_stamina <= STAMINA_THRESHOLD) or -- Out of stamina
            (ENABLE_HUNGER_DRAIN and ((has_hunger_ng and current_hunger <= HUNGER_NG_THRESHOLD) or
            (has_hbhunger and current_hunger <= HBHUNGER_THRESHOLD))) or -- Hunger too low
            controls.sneak -- Stop sprint when crouching
        ) then
            data.sprinting = false
            data.using_aux = false
            -- Restore original movement settings
            player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
            -- Reset animation speed
            player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig,
                ANIMATIONS.walk_while_dig, ANIM_SPEED_IDLE)
        end

        -- Smooth FOV transition
        local target_fov = data.sprinting and (data.original_fov + FOV_BOOST) or data.original_fov
        data.current_fov = data.current_fov + (target_fov - data.current_fov) * dtime * FOV_TRANSITION_SPEED
        player:set_fov(data.current_fov, false)

        -- Spawn trail particles when sprinting
        if SPAWN_PARTICLES and data.sprinting and on_ground then
            data.particle_timer = data.particle_timer + dtime
            if data.particle_timer >= PARTICLE_INTERVAL then
                data.particle_timer = 0
                local texture = get_particle_texture(pos)
                
                if texture then
                    minetest.add_particlespawner({
                        amount = 4,
                        time = 0.4,
                        minpos = vector.subtract(pos, 0.2),
                        maxpos = vector.add(pos, 0.2),
                        minvel = {x = -0.8, y = 2.0, z = -0.8},
                        maxvel = {x = 0.8, y = 3.0, z = 0.8},
                        minacc = {x = 0, y = -5, z = 0},
                        minexptime = 0.4,
                        maxexptime = 0.6,
                        minsize = PARTICLE_SCALE,
                        maxsize = PARTICLE_SCALE * 1.2,
                        collisiondetection = true,
                        vertical = false,
                        playername = name,
                        glow = 2,
                        texture = texture
                    })
                end
            end
        end

        -- Update previous control state
        data.was_pressing_forward = controls.up
    end
end)