--[[
  Sprinting Mod: Optimized and Refactored
  Uses horizontal velocity to detect collisions and cancel sprint
]]

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Load helper functions
local player_is_in_liquid,
      player_is_on_climbable,
      player_is_lying_on_bed,
      get_particle_texture,
      check_for_double_tap =
        dofile(modpath.."/tools.lua")

-- Configuration constants
local DOUBLE_TAP_TIME        = math.max(0.5, tonumber(core.settings:get("dedicated_server_step")) * 2.5)
local DEFAULT_FOV            = 72
local PARTICLE_SCALE         = 0.5
local PARTICLE_INTERVAL      = 0.1
local GRACE_TIME             = 0.15 -- seconds to allow initial acceleration

-- Settings
local USE_AUX1               = minetest.settings:get_bool("sprinting_use_aux1", true)
local SPEED_MULTIPLIER       = tonumber(minetest.settings:get("sprinting_speed_multiplier")) or 1.5
local JUMP_MULTIPLIER        = tonumber(minetest.settings:get("sprinting_jump_multiplier")) or 1.10
local ENABLE_STAMINA_DRAIN   = minetest.settings:get_bool("sprinting_drain_stamina", true)
local STAMINA_DRAIN          = tonumber(minetest.settings:get("sprinting_stamina_drain")) or 0.35
local STAMINA_THRESHOLD      = tonumber(minetest.settings:get("sprinting_stamina_threshold")) or 5
local HUNGER_NG_DRAIN        = tonumber(minetest.settings:get("sprinting_hunger_ng_drain")) or 0.35
local HUNGER_NG_THRESHOLD    = tonumber(minetest.settings:get("sprinting_hunger_ng_threshold")) or 4
local HBHUNGER_DRAIN         = tonumber(minetest.settings:get("sprinting_hbhunger_drain")) or 0.85
local HBHUNGER_THRESHOLD     = tonumber(minetest.settings:get("sprinting_hbhunger_threshold")) or 6
local REQUIRE_GROUND         = minetest.settings:get_bool("sprinting_require_ground", true)
local SPRINT_ON_CLIMBABLE    = minetest.settings:get_bool("sprinting_sprint_on_climbable", true)
local SPRINT_IN_LIQUIDS      = minetest.settings:get_bool("sprinting_sprint_in_liquids", true)
local SPAWN_PARTICLES        = minetest.settings:get_bool("sprinting_spawn_particles", true)
local CHANGE_FOV             = minetest.settings:get_bool("sprinting_change_fov", true)
local FOV_BOOST              = tonumber(minetest.settings:get("sprinting_fov_boost")) or 20
local FOV_TRANSITION_TIME    = tonumber(minetest.settings:get("sprinting_fov_transition_time")) or 0.4

-- Mod detections
local has_stamina            = minetest.get_modpath("stamina") ~= nil
local has_hunger_ng          = minetest.get_modpath("hunger_ng") ~= nil
local has_hbhunger           = minetest.get_modpath("hbhunger") ~= nil
local has_character_anim     = minetest.get_modpath("character_anim") ~= nil

-- Disable default sprint in stamina mod
if has_stamina then
  if stamina.settings then
    stamina.settings.sprint = false
    stamina.settings.sprint_particles = false
  else
    stamina.enable_sprint = false
    stamina.enable_sprint_particles = false
  end
end

-- Animation definitions
local ANIMATIONS = {
  idle = {x=0, y=79},
  walk = {x=168, y=187},
  dig = {x=189, y=198},
  walk_dig = {x=200, y=219}
}

-- Player sprint data
local sprint_players = {}

-- Initialize player data
minetest.register_on_joinplayer(function(player)
  local name = player:get_player_name()
  local phys = player:get_physics_override()
  sprint_players[name] = {
    sprinting            = false,
    last_key_time        = 0,
    original_fov         = tonumber(minetest.settings:get("fov")) or DEFAULT_FOV,
    current_fov          = 0,
    original_speed       = phys.speed,
    original_jump        = phys.jump,
    was_pressing_forward = false,
    particle_timer       = 0,
    hbhunger_accumulator = 0,
    using_aux            = false,
    sprint_start_time    = 0,
    collision            = false,
  }
  player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig, ANIMATIONS.walk_dig, 30)
end)

-- Restore player state on leave
minetest.register_on_leaveplayer(function(player)
  local name = player:get_player_name()
  local data = sprint_players[name]
  if data then
    player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
    player:set_fov(0, false)
    sprint_players[name] = nil
  end
end)

-- Sprint logic
minetest.register_globalstep(function(dtime)
  for _, player in ipairs(minetest.get_connected_players()) do
    minetest.chat_send_all(tostring(player:get_meta():get("stamina:level")))
    local name     = player:get_player_name()
    local data     = sprint_players[name]
    if not data then return end

    local controls = player:get_player_control()
    local pos      = player:get_pos()
    local node_below = minetest.get_node({x=pos.x, y=pos.y - 0.1, z=pos.z})
    local on_ground   = node_below.name ~= "air"
    local in_liquid   = player_is_in_liquid(pos)
    local on_climb    = player_is_on_climbable(player)
    local lying_bed   = player_is_lying_on_bed(player, node_below)
    local double_tap  = check_for_double_tap(controls, data, DOUBLE_TAP_TIME)

    if on_climb and not SPRINT_ON_CLIMBABLE then
      data.sprinting = false
    end

    -- Check horizontal velocity for collision reset
    local vel  = player:get_velocity()
    local hvel = math.sqrt(vel.x * vel.x + vel.z * vel.z)
    local sprint_speed = data.original_speed * SPEED_MULTIPLIER

    if hvel >= data.original_speed * 0.95 or on_climb then
      data.collision = false
    end

    -- Sprint activation
    if ((USE_AUX1 and controls.aux1 and controls.up) or double_tap)
      and not controls.down and not controls.sneak and not data.collision and not data.sprinting then

      local can_sprint = true

      if ENABLE_STAMINA_DRAIN then
        if has_hunger_ng then
          can_sprint = hunger_ng.get_hunger_information(name).hunger.exact > HUNGER_NG_THRESHOLD
        elseif has_hbhunger then
          can_sprint = hbhunger.get_hunger_raw(player) > HBHUNGER_THRESHOLD
        elseif has_stamina then
          can_sprint = tonumber(player:get_meta():get("stamina:level")) > STAMINA_THRESHOLD
        end
      end

      if REQUIRE_GROUND then can_sprint = can_sprint and on_ground end
      if not SPRINT_IN_LIQUIDS then can_sprint = can_sprint and not in_liquid end
      if player:get_attach() or lying_bed then can_sprint = false end

      if can_sprint then
        data.sprinting = true
        data.using_aux = controls.aux1
        data.sprint_start_time = minetest.get_us_time() / 1e6

        local r1, spd, r2, r3 = player:get_animation()
        if has_character_anim then
          player:set_animation(r1, spd * SPEED_MULTIPLIER, r2, r3)
        else
          player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig, ANIMATIONS.walk_dig, 30 * SPEED_MULTIPLIER)
        end
      end
    end

    -- Sprint effects
    if data.sprinting then
      if ENABLE_STAMINA_DRAIN then
        if has_hunger_ng and not data.using_aux then
          hunger_ng.alter_hunger(name, -HUNGER_NG_DRAIN * dtime)
        elseif has_hbhunger and not data.using_aux then
          data.hbhunger_accumulator = data.hbhunger_accumulator + HBHUNGER_DRAIN * dtime
          if data.hbhunger_accumulator >= 1 then
            local raw = hbhunger.get_hunger_raw(player)
            hbhunger.hunger[name] = math.max(0, raw - math.floor(data.hbhunger_accumulator))
            hbhunger.set_hunger_raw(player)
            data.hbhunger_accumulator = data.hbhunger_accumulator % 1
          end
        elseif has_stamina then
          stamina.change(player, -STAMINA_DRAIN * dtime)
        end
      end

      player:set_physics_override({speed = data.original_speed * SPEED_MULTIPLIER, jump = data.original_jump * JUMP_MULTIPLIER})

      if SPAWN_PARTICLES and on_ground and not on_climb then
        data.particle_timer = data.particle_timer + dtime
        if data.particle_timer >= PARTICLE_INTERVAL then
          data.particle_timer = 0
          local tex = get_particle_texture(node_below)
          if tex then
            minetest.add_particlespawner{
              amount = math.random(1, 2), time = 0.1,
              minpos = {x=-0.5, y=0.1, z=-0.5}, maxpos = {x=0.5, y=0.1, z=0.5},
              minvel = {x=0, y=5, z=0}, maxvel = {x=0, y=5, z=0},
              minacc = {x=0, y=-13, z=0}, maxacc = {x=0, y=-13, z=0},
              minexptime = 0.1, maxexptime = 1,
              minsize = PARTICLE_SCALE, maxsize = PARTICLE_SCALE * 2,
              collisiondetection = true, attached = player, vertical = false,
              playername = name, glow = 2, texture = tex
            }
          end
        end
      end
    end

    -- FOV adjustment
    if CHANGE_FOV then
      local target_fov = data.sprinting and (data.original_fov + FOV_BOOST) or 0
      if target_fov ~= data.current_fov then
        player:set_fov(target_fov, false, FOV_TRANSITION_TIME)
        data.current_fov = target_fov
      end
    end

    -- Collision detection by velocity
    if data.sprinting and controls.up and not on_climb then
      local now = minetest.get_us_time() / 1e6
      if now - data.sprint_start_time > GRACE_TIME then
        if hvel < sprint_speed then
          data.sprinting = false
          data.collision = true
          player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
          local r1, spd, r2, r3 = player:get_animation()
          if has_character_anim then
            player:set_animation(r1, spd / SPEED_MULTIPLIER, r2, r3)
          else
            player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig, ANIMATIONS.walk_dig, 30)
          end
        end
      end
    end

    -- Termination conditions
    if data.sprinting and (
      (USE_AUX1 and data.using_aux and (not controls.aux1 or not controls.up)) or
      (not data.using_aux and not controls.up) or
      controls.down or controls.sneak or data.collision
    ) then
      data.sprinting = false
      data.collision = true
      player:set_physics_override({speed = data.original_speed, jump = data.original_jump})
      local r1, spd, r2, r3 = player:get_animation()
      if has_character_anim then
        player:set_animation(r1, spd / SPEED_MULTIPLIER, r2, r3)
      else
        player:set_local_animation(ANIMATIONS.idle, ANIMATIONS.walk, ANIMATIONS.dig, ANIMATIONS.walk_dig, 30)
      end
    end

    data.was_pressing_forward = controls.up
  end
end)
