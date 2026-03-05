# Player Controller Setup (Single Node + 3 Guardian States)

This project now uses one player node with form states (`Sword`, `Spear`, `Bow`) instead of three separate player characters.

## Added Files

- `scripts/autoload/game_manager.gd`
- `scripts/player/player_controller.gd`
- `scripts/player/states/base_guardian_state.gd`
- `scripts/player/states/state_sword.gd`
- `scripts/player/states/state_spear.gd`
- `scripts/player/states/state_bow.gd`
- `scenes/player/player.tscn`

`GameManager` is already registered as an Autoload in `project.godot`.

## Input Actions to Create in Project Settings

In **Project > Project Settings > Input Map**, add:

- `attack`
- `special`
- `swap_next`
- `swap_prev`

Movement defaults to built-in UI actions:

- `ui_left`
- `ui_right`
- `ui_up`
- `ui_down`

## How to Use

1. Instance `scenes/player/player.tscn` into your main level scene.
2. Select `Player/GuardianSprite` and create a `SpriteFrames` resource.
3. Add animations using the exact names below.
4. Add frames from your assets for each animation.
5. Implement form-specific attack/special internals in:
   - `state_sword.gd`
   - `state_spear.gd`
   - `state_bow.gd`
6. Route enemy lethal damage to the current state via `receive_lethal_damage()`.

## Naming Rule (Important)

- Do not give a script `class_name` that matches an Autoload singleton name.
- Current singleton name is `GameManager` (configured in `project.godot`).
- Keep `scripts/autoload/game_manager.gd` without `class_name GameManager` to avoid parser conflicts.

## Required Animation Names

- Sword: `sword_idle`, `sword_attack`, `sword_parry`
- Spear: `spear_idle`, `spear_attack`, `spear_impale`
- Bow: `bow_idle`, `bow_shot`, `bow_disengage`

Suggested source folders:

- Sword -> `assets/skeleton_sprites/Skeleton_Warrior`
- Spear -> `assets/skeleton_sprites/Skeleton_Spearman`
- Bow -> `assets/skeleton_sprites/Skeleton_Archer`

## Current Behavior

- Form swap cycles Sword -> Spear -> Bow, skipping locked forms.
- Lethal damage locks a form for the current run.
- Lock events update `GameManager` guardian pool.
- If all forms are locked, `GameManager` emits timeline reset (`no_guardians_remaining`).
- Basic input buffering and swap coyote window are present in `PlayerController`.

## Next Integration Points

- Add Pandora trigger script to call `GameManager.request_timeline_reset("pandora_breached")`.
- Add `CombatResolver` for deterministic rock-paper-scissors outcomes.
- Connect HUD to `GameManager.guardian_pool_changed` and `GameManager.guardian_locked`.
