-- Configuration and settings for the Sprinting mod
local config = {}

-- Default constants
config.TIME_IN_AIR_LIMIT = 0.9
config.DOUBLE_TAP_TIME = 0.5
config.DEFAULT_FOV = 72
config.PARTICLE_SCALE = 0.5
config.PARTICLE_INTERVAL = 0.1
config.GRACE_TIME = 0.15 -- seconds to allow initial acceleration
config.FLIGHT_TIME_THRESHOLD = 0.4

-- Read settings (fall back to defaults)
config.DOUBLE_TAP_TIME = math.max(config.DOUBLE_TAP_TIME, tonumber(core.settings:get("dedicated_server_step")) * 2.5)

config.USE_AUX1 = minetest.settings:get_bool("sprinting_use_aux1", true)
config.SPEED_MULTIPLIER = tonumber(minetest.settings:get("sprinting_speed_multiplier")) or 1.5
config.JUMP_MULTIPLIER = tonumber(minetest.settings:get("sprinting_jump_multiplier")) or 1.10

config.ENABLE_STAMINA_DRAIN = minetest.settings:get_bool("sprinting_drain_stamina", true)
config.STAMINA_DRAIN = tonumber(minetest.settings:get("sprinting_stamina_drain")) or 5
config.STAMINA_THRESHOLD = tonumber(minetest.settings:get("sprinting_stamina_threshold")) or 20

config.REQUIRE_GROUND = minetest.settings:get_bool("sprinting_require_ground", true)
config.SPRINT_ON_CLIMBABLE = minetest.settings:get_bool("sprinting_sprint_on_climbable", false)
config.SPRINT_IN_LIQUIDS = minetest.settings:get_bool("sprinting_sprint_in_liquids", true)

config.SPAWN_PARTICLES = minetest.settings:get_bool("sprinting_spawn_particles", true)
config.CHANGE_FOV = minetest.settings:get_bool("sprinting_change_fov", true)
config.FOV_BOOST = minetest.settings:get("sprinting_fov_boost") or 20
config.FOV_TRANSITION_TIME = minetest.settings:get("sprinting_fov_transition_time") or 0.4

-- Conversion factors for compatible mods
config.CONVERSION_FACTOR = {
    STAMINA_DRAIN = {
        stamina = 0.07,
        hunger_ng = 0.07,
        hb_hunger = 0.17
    },
    STAMINA_THRESHOLD = {
        stamina = 0.25,
        hunger_ng = 0.2,
        hb_hunger = 0.3
    }
}

return config
