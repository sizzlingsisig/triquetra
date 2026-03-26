# Feature Checklist

## Player Controller

- [x] Movement (left/right with normalized diagonals)
- [x] Jump with arc offset
- [x] Coyote time (0.12s grace period)
- [x] Input buffering (0.12s window)
- [x] Form orchestration
- [x] Debug widget
- [x] Camera shake
- [x] Jump offset application to sprite/collision

## Form Manager

- [x] Three guardian forms: Sword, Spear, Bow
- [x] Form switching (next/previous)
- [x] Form locking on damage
- [x] Auto-swap when active form locks
- [x] Form order cycling
- [x] Run state reset coordination
- [x] Signals: form_changed, form_locked

## Guardian States

### Sword
- [x] 3-hit combo attack
- [x] Block special (defensive)
- [x] Action FSM: Idle, Run, Attack, Special
- [x] Attack window timing (0.05-0.18s)
- [x] Particle FX on block
- [x] Death animation trigger

### Spear
- [x] 2-hit combo attack
- [x] Impale special (lunge)
- [x] Action FSM: Idle, Run, Attack, Special
- [x] Attack window timing (0.04-0.16s)
- [x] Particle FX on impale
- [x] Camera shake on special

### Bow
- [x] Arrow projectile attack
- [x] Disengage special (backdash)
- [x] Action FSM: Idle, Run, Attack, Special
- [x] Attack window timing (0.06-0.2s)
- [x] Particle FX on disengage
- [x] Slide trail effect during disengage
- [x] Arrow spawn with delay

## Combat System

- [x] Hit detection (Area2D)
- [x] Attack window timing
- [x] Player damage trigger
- [x] Form lock on lethal damage
- [x] Projectile handling (arrows)
- [x] Jump offset sync for attack area

## Input System

- [x] Action buffering
- [x] Coyote time for jumps
- [x] Command queue consumption
- [x] Multi-action support (move, attack, special, jump, swap)

## Visual Feedback

- [x] Animation playback per form
- [x] Facing direction flip
- [x] Jump arc visualization
- [x] Locomotion states
- [x] Attack window sync
- [x] Particle effects (Sword block, Spear impale, Bow disengage)
- [x] Slide trails (Bow)
- [x] Camera shake API

## Game Manager (Autoload)

- [x] Global run state tracking
- [x] Guardian lock map
- [x] Timeline reset request
- [x] Reset reason tracking
- [x] Persistent flags dictionary
- [x] Active guardian count
- [x] Locked forms retrieval
- [x] Signals: guardian_locked, guardian_pool_changed, timeline_reset_requested

## Input Map

- [x] ui_left / ui_right (A/D, D-pad)
- [x] attack (Left Mouse)
- [x] special (Right Mouse)
- [x] swap1/swap2/swap3 (1/2/3 keys)
- [x] swap_next / swap_prev (Scroll wheel)
- [x] jump (Space)

## Physics

- [x] Jolt Physics (3D) enabled
- [x] Physics layers: player, enemy_body, player_attack, enemy_hurtbox, enemy_attack, projectile

## Debug

- [x] Debug widget display
- [x] Form state display
- [x] Buffered command display
- [x] Locked forms list
- [x] Last reset reason

## Scene Structure

- [x] Main scene (main.tscn)
- [x] Player scene with proper node hierarchy
- [x] GuardianSprite (AnimatedSprite2D)
- [x] AttackArea (Area2D)
- [x] CollisionShape2D
- [x] States container (Node)
- [x] PlayerDebugWidget

## Architecture Patterns

- [x] Observer Pattern (signals for form changes)
- [x] Finite State Machine (Guardian FSM + Action FSM)
- [x] Component-based architecture (managers as children)
- [x] Input buffering for latency mitigation
- [x] Coyote time for jump leniency

## Persistence (MVP)

- [x] Persistent flags dictionary
- [x] Run state reset
- [x] Guardian lock persistence across run

---

## Remaining / Not Implemented

### High Priority
- [ ] Enemy prototypes with attack patterns
- [ ] Boss encounter prototype
- [ ] Health system (current: one-hit lock)
- [ ] Room/level transitions

### Medium Priority
- [ ] Narrative system (Priority Queue for reactive dialogue)
- [ ] World persistence (Death_Count, Boss_Met flags)
- [ ] Save/load system

### Low Priority
- [ ] Additional enemy types
- [ ] Power-ups/items
- [ ] Combo counter UI
- [ ] Leaderboards
- [ ] Sound effects / music
- [ ] Multiple rooms/areas
