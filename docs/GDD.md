# Triquetra - Game Design Document

**Project Leads:** CJ  
**Genre:** 2D Precision-Brawler  
**Tagline:** *Three forms. One life. Swap wisely or perish.*

---

## 1. Executive Summary

### Philosophy
This document serves as technical communication for peer review. It focuses on design decisions and engineering trade-offs rather than marketing persuasion.

### Core Gameplay Loop
1. **Engage** - Player selects a guardian form and confronts enemies
2. **Defend** - Taking damage locks the active form permanently for the run
3. **Adapt** - Player must cycle between remaining unlocked forms to survive
4. **Reset** - When all three forms are locked, the timeline resets

---

## 2. Mechanics & Systems

### 2.1 The Core Mechanic: Guardian Lock

**Definition:** The player has three guardian forms (Sword, Spear, Bow). When the player takes a hit while in a given form, that form becomes permanently locked for the current run. The player must swap between remaining unlocked forms to survive until all forms are lost, triggering a timeline reset.

**Rationale:** This creates a "triage combat" dynamic where the player must actively manage which form they occupy during each encounter. Rather than a health bar, the resource being depleted is the player's own toolkit. This forces adaptation and creates tension in every swap decision—no form is "safe" if it takes damage.

### 2.2 Tactical Counters (The Trinity)

The combat is built on a strict efficiency model to force player adaptation:

| Agent/Form | Role | Specialty | Affinity |
|------------|------|------------|----------|
| **Sword** | Hard Counter / Defensive | Fast 3-hit melee combo + block parry | Close-range / Single target |
| **Spear** | Soft Counter / Reach | Medium-range poke + lunge | Mid-range / Crowd control |
| **Bow** | Utility / Range | Ranged projectile + arena control | Long-range / Mobile targets |

**Form-Specific Details:**
- **Sword:** Primary attack is a 3-hit combo. Special ability is a block that can parry incoming attacks (immobilizes player during block window).
- **Spear:** Primary attack is a thrust with forward reach. Special ability is a lunge that covers significant distance.
- **Bow:** Primary attack fires an arrow projectile. Special ability is a charged shot with knockback.

### 2.3 The Fail State

**Trigger:** The game ends (timeline resets) when all three guardian forms become locked due to player damage.

**Engineering Trade-off:** Complex enemy AI patterns were deprioritized in favor of static, telegraphed enemy behaviors. This ensures the core loop—form management and precise timing—remains the primary challenge rather than unpredictable AI.

---

## 3. Technical Architecture

### 3.1 Design Patterns

#### Observer Pattern
Used to decouple UI and GameManager from character logic. The `PlayerController` emits signals (`form_changed`, `form_locked`) that `GameManager` listens to, preventing circular dependencies. Similarly, `FormManager` observes guardian state locks and coordinates timeline resets.

#### Finite State Machine (FSM)
Two FSM implementations are utilized:
1. **Guardian FSM** (`BaseGuardianState`) - Manages form lifecycle (Sword/Spear/Bow states) with state-locking on death
2. **Action FSM** (`ActionStateMachine`) - Manages per-form action states (Idle/Run/Attack/Special) with transition guards

#### Priority Queue
Not yet implemented. Reserved for narrative delivery system (Hades-style reactive dialogue) based on persistent flags.

### 3.2 Mitigation of Technical Risks

**Input Latency:** In high-precision games, lag feels unfair.

**Fixes Implemented:**
- **Input Buffering:** `InputManager` queues actions during animations (0.12s window), allowing players to queue attacks slightly before animations complete
- **Coyote Time:** `PlayerController` provides a 0.12s grace period after leaving the ground, allowing late jumps

---

## 4. Narrative Persistence

### Persistent Dictionary
`GameManager` maintains a `persistent_flags` Dictionary that tracks global events and run data:
- `Death_Count` (int) - Total deaths across all runs
- `Boss_Met` (bool) - Whether specific bosses have been encountered
- `Form_Lock_History` (Array) - Track which forms locked in each run

### Reactive Dialogue
Reserved for future implementation. The Priority Queue will select narrative lines based on current Dictionary flags, ensuring narrative progress even upon mechanical failure.

---

## 5. MVP Scope (Week 5 Deliverables)

### Functional Player States
- [x] Sword (3-hit combo attack + block special)
- [x] Spear (thrust attack + lunge special)
- [x] Bow (arrow projectile + charged shot special)
- [x] Form switching with hotkeys (1, 2, 3) and scroll wheel
- [x] Form locking on damage

### One Prototype Boss/Encounter
- [ ] Basic enemy prototype with attack patterns

### The Core Fail-State Trigger
- [x] Timeline reset when all forms locked
- [x] Run state reset in `GameManager`

---

## 6. Visual & Audio Direction

### Visuals
- **Style:** 2D Pixel Art (snapped to pixel grid)
- **Aesthetic:** Gothic scrapbook / mystical artifact theme
- **Rendering:** GL Compatibility mode for broad device support
- **Sprite Resolution:** Low-res sprites scaled to screen with pixel-perfect snapping

### Feedback
- **Hit-stop:** Freeze frame on successful attacks
- **Camera shake:** On damage taken and heavy attacks
- **Hurt/Death animations:** Distinct animations per form with visual color shifts on lock
- **UI:** Minimalist HUD showing active/locked forms

---

## Appendix: Input Map

| Action | Keybind |
|--------|---------|
| Move Left | A / D-pad Left |
| Move Right | D / D-pad Right |
| Jump | Space |
| Attack | Left Mouse |
| Special | Right Mouse |
| Swap Next | Scroll Up |
| Swap Prev | Scroll Down |
| Swap to Form 1 | 1 |
| Swap to Form 2 | 2 |
| Swap to Form 3 | 3 |

---

## Appendix: File Structure

```
res://
├── scripts/
│   ├── autoload/game_manager.gd       # Global run state
│   ├── player/
│   │   ├── player_controller.gd       # Main orchestration
│   │   ├── form_manager.gd            # Form lifecycle
│   │   ├── input_manager.gd           # Input buffering
│   │   ├── visuals_manager.gd         # Animation/sprite
│   │   ├── combat_manager.gd          # Hit detection
│   │   ├── states/
│   │   │   ├── base_guardian_state.gd # State interface
│   │   │   ├── state_sword.gd
│   │   │   ├── state_spear.gd
│   │   │   └── state_bow.gd
│   │   └── states/actions/             # Per-form action FSMs
│   └── enemy/
│       └── enemy.gd
├── scenes/
│   └── main.tscn
└── resources/
```
