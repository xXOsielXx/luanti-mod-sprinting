# Sprinting Mod for Minetest

Enhance your Minetest gameplay with a dynamic sprinting mechanic! Activate sprinting with a double-tap of the forward key, and enjoy speed boosts, particle effects, and FOV changes. Compatible with popular hunger and stamina systems.

![Screenshot](screenshot.jpg)
*Example of sprinting particles and FOV effect (HeadAnim mod included).*

---

## Features
- Double-tap **W** (or forward key) to sprint.
- Adjustable speed and jump multipliers.
- Hunger/stamina drain mechanics (supports `stamina`, `hunger_ng`, and `hbhunger`).
- Ground requirement toggle.
- Customizable particle effects and FOV transitions.

---

## Requirements
- **Minetest 5.0+**
- Required Mods:
  - `default`
  - `player_api`

---

## Recommended Mods
If you want to complement the mod with a hunger(stamina) system, consider installing:
- `stamina`
- `hunger_ng`
- `hbhunger`

---

## How to Use
1. **Activation**: Double-tap the **W** key (or your configured forward key) or tap the Aux1 key (default **E**).  
2. **Effects**:
   - Speed and jump boosts while sprinting.
   - FOV increases smoothly for a "fast" feel.
   - Particles spawn underfoot (configurable).  
3. **Conditions**:
   - Requires ground contact (toggleable in settings).
   - The player is not crouching
   - Drains stamina/hunger if enabled and mods are installed.  
4. **Cancellation**: Stops automatically if:
   - You release the forward key.
   - You crouch
   - Stamina/hunger drops below thresholds.

---

## Settings  
Configure in `minetest.conf` or via the in-game "Settings" menu:  

| Setting Name                           | Type  | Default | Description                                  |
|----------------------------------------|-------|---------|----------------------------------------------|
| `sprinting_drain_hunger`               | bool  | `true`  | Enable hunger drain during sprint.           |
| `sprinting_stamina_drain`              | float | `0.25`   | Stamina drained per second.                  |
| `sprinting_stamina_threshold`          | int   | `5`     | Minimum stamina required to sprint.          |
| `sprinting_hunger_ng_drain`            | float | `0.25`   | Hunger NG drained per second.                |
| `sprinting_hunger_ng_threshold`        | int   | `4`     | Minimum Hunger NG required to sprint.        |
| `sprinting_hbhunger_drain`             | float | `0.5`   | HBHunger drained per second.                 |
| `sprinting_hbhunger_threshold`         | int   | `6`     | Minimum HBHunger required to sprint.         |
| `sprinting_speed_multiplier`           | float | `1.5`   | Sprint speed multiplier (e.g., 1.5 = 50% faster). |
| `sprinting_jump_multiplier`            | float | `1.10`  | Sprint jump height multiplier.               |
| `sprinting_require_ground`             | bool  | `true`  | Require standing on ground to start sprint.        |
| `sprinting_spawn_particles`            | bool  | `true`  | Enable sprinting particle effects.           |

---

## License  
MIT License.  
See [LICENSE.txt](LICENSE.txt) for details.  
© 2025 xXOsielXx.  