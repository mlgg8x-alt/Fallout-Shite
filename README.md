# Magic Fallout

A first-person FPS/RPG vertical slice in **Godot 4.6** (GDScript): Fallout-style
gunplay meets Elder Scrolls-style magic and melee.

## Running

1. Install [Godot 4.6](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in the editor and press **F5**.

| Action | Key |
| --- | --- |
| Move | W A S D |
| Sprint (drains stamina) | Shift |
| Jump | Space |
| Crouch (hold) | Ctrl or C |
| Use / interact | E |
| Debug overlay | F3 |
| Pause | Esc |

## Layout

Code is grouped by feature; each scene sits next to its script.

```
game/
  main.tscn / main.gd      Game root: spawns player into level, wires HUD, pause
  player/                  First-person controller (CharacterBody3D)
  components/stat_pool.gd  Regenerating pool used for health, stamina, mana
  interaction/             Interactable component found by the player's use ray
  levels/                  Graybox test level + world-space grid shader
  props/                   Test props (lever that toggles a lamp)
  ui/                      HUD: vitals bars, crosshair, prompt, debug, pause menu
tests/smoke_test.gd        Headless test that drives the player through the level
```

Physics layers: 1 world, 2 player, 3 actors, 4 interactable.

### Extension points

- **Combat:** weapons and spells attach under `Player/Head/Camera3D`; the
  `Mana` and `Health` pools are already on the player.
- **RPG layer:** stats will drive `StatPool.max_value` / `regen_rate` and the
  movement exports on `Player`. Global systems (save/load, quests) go in
  autoloads, not `main.gd`.
- **Content:** anything usable gets an `Interactable` child; the HUD prompt
  and the E key work automatically.

## Testing

```
godot --headless --path . -s tests/smoke_test.gd
```

Checks spawn, walk/sprint speeds, stamina drain, jump height, crouch and
ceiling blocking, stairs and ramp climbing, the lever interaction and pause.
CI runs it on every pull request.
