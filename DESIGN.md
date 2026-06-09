# TotemBuddy — Design & Architecture

This document explains how TotemBuddy is built, the Blizzard policy rules that
constrain it, and how each feature stays within them. It's aimed at anyone
hacking on the addon.

TotemBuddy is a fork of [TotemDeck](https://github.com/iltGames/TotemDeck)
(MIT). The totem bar, popups, timers, weapon-buff and Reincarnation systems are
inherited; TotemBuddy adds **named sets**, **per-set keybindings**, and the
**quick-react bar**.

---

## 1. The rules that shape everything

### One hardware event = one cast
Since WoW Patch 2.0 (the start of the original TBC), an addon **cannot cast a
spell without a hardware event** (a real keypress or click), and a single
hardware event triggers **one** protected action. The old "drop my whole 4-totem
set with one button" addons were killed by this and are still non-compliant.

**What is legal:** `/castsequence`. One macro that advances one cast per press —
press it four times to drop a four-totem set. Each cast is tied to your
keypress. This is the backbone of TotemBuddy's set casting.

### Combat lockdown (taint)
While you are in combat (`InCombatLockdown()` is true) you may not:
- change a secure frame's attributes (e.g. a `SecureActionButton`'s `macrotext`),
- create/edit/delete macros,
- add or remove key bindings (`SetOverrideBindingClick`, `ClearOverrideBindings`),
- show/hide or reparent secure frames.

**TotemBuddy's rule:** never attempt secure work in combat. Detect it, set a
`pending*` flag, and replay the work on `PLAYER_REGEN_ENABLED` (leaving combat).
This mirrors the inherited `addon.state.pendingActiveUpdates` pattern.

---

## 2. Module map

Load order is defined in `TotemBuddy.toc`.

| File | Responsibility |
|------|----------------|
| `Core.lua` | Addon namespace, saved-variable **defaults**, the `TOTEMS` table (spell IDs + durations), element colours/order, utility lookups (`GetTotemName`, `GetTotemIcon`). |
| `Macros.lua` | Generates the `TB*` cast macros from the active totems. `SetActiveTotem(element, spellID)` is the single choke point for changing an active totem; it queues secure updates when in combat. |
| `Sets.lua` | **Named sets logic** (no UI): save/find/apply/delete/rename/reorder. A set is `{ name, Earth, Fire, Water, Air, keybind }`. |
| `Bindings.lua` | **Per-set secure cast buttons + override keybindings.** Builds each set's `/castsequence`, owns the deferred-in-combat machinery, and the shared `CaptureKeybind` helper. |
| `UI/ActionBar.lua`, `UI/Popup.lua`, `UI/Timers.lua`, `UI/Reincarnation.lua`, `UI/WeaponBuff.lua` | Inherited bar/popup/timer/utility UI. |
| `UI/Config.lua` | The tabbed config window. The **Sets** tab is one `CreateTab` + a content frame that delegates to `addon.BuildSetsTab`. |
| `UI/SetsTab.lua` | The **Sets** tab UI: save box + per-set rows (Apply/Rename/Del/reorder/Bind). |
| `UI/QuickBar.lua` | The **quick-react bar** runtime *and* its standalone config window. |
| `Events.lua` | Event handling, saved-variable migration/init, login setup, and the `PLAYER_REGEN_ENABLED` flush of all deferred work. |
| `Commands.lua` | `/tb` slash-command parsing and dispatch. |

---

## 3. Data model (`TotemBuddyDB`)

Defaults live in `Core.lua`; `Events.lua` backfills missing keys on login.

```lua
activeEarth / activeFire / activeWater / activeAir = <spellID>  -- current active totems

sets = {                                   -- named sets
  { name = "Healing", Earth = 8075, Fire = 3599, Water = 5675, Air = 8512, keybind = "SHIFT-1" },
  ...
}
activeSet = <index|nil>                     -- last applied set (display only)

quickReactEnabled = <bool>                  -- quick bar shown?
quickReact = { <spellID>, ... }             -- totems on the quick bar
quickReactKeybinds = { [spellID] = "ALT-G" } -- per-totem keybinds
quickReactPos = { point, x, y }
```

**Table-default footgun:** the generic "copy missing defaults" loop assigns the
*same table reference* from `defaults` into the DB. For mutable tables
(`quickReact`, …) that would bleed across characters in one session, so
`Events.lua` explicitly replaces them with fresh per-DB copies when it detects
the shared reference (`TotemBuddyDB.x == defaults.x`).

---

## 4. How each feature stays legal

### Sets — applying (out of combat)
`addon.ApplySetByIndex` writes the set's four spell IDs into the
`active<Element>` slots via the inherited `addon.SetActiveTotem`, then the normal
machinery rebuilds the `TBAll` macro and bar buttons. In combat, `SetActiveTotem`
queues per-element updates (`pendingActiveUpdates`) and they replay on combat end.
**No new secure code** — sets are just presets over the existing engine.

### Sets — switching (in combat)
Each set gets a hidden `SecureActionButton` (`TotemBuddySetButtonN`) whose
`macrotext` is the set's `/castsequence` (`Bindings.lua`). The chosen key is
mapped to that button with `SetOverrideBindingClick`. Pressing the key fires one
totem per press; switching sets mid-fight is pressing a *different* already-bound
key. Building buttons and (re)binding keys happen **only out of combat**; if a
change is requested in combat, `pendingBindings` is set and flushed on
`PLAYER_REGEN_ENABLED`.

`addon.NotifySetsChanged()` is the single hook every set mutator calls — it
rebuilds the secure bindings and refreshes the Sets tab.

### Quick-react bar
Each entry is a `SecureActionButton` with a `/cast <totem>` `macrotext` — one
totem per click or per bound key. Same deferred-out-of-combat discipline
(`pendingQuick`, flushed on combat end). The bar is created on login *after a 2s
delay* so `GetSpellInfo` has cached the localized totem names used in macrotext.

### Keybinding capture
`addon.CaptureKeybind(frame, onCaptured)` enables keyboard on a frame, grabs the
next non-modifier key (`OnKeyDown`), builds an `ALT-CTRL-SHIFT-KEY` chord, and
restores input propagation. Escape clears the binding. Shared by sets and the
quick bar.

---

## 5. Known limitations / future work

- **Duplicate keybind across two sets:** last one wins (the later
  `SetOverrideBindingClick` overrides). Could warn on conflict.
- **Sets/quick lists have no scrollbar:** rows stack; fine for ~10 sets and a
  handful of quick totems. Add a `ScrollFrame` if needed.
- **Keybinds are override bindings**, not entries in Blizzard's Key Bindings UI.
  They persist via saved variables and are re-applied on login.
- **Set keybinds beyond 16 sets** are ignored (`MAX_SET_BUTTONS`).
- Not yet localized beyond what the inherited code provides; UI strings are English.

---

## 6. Testing

There is no WoW client in the dev environment, so changes are validated with
`luac -p` (syntax) and by reasoning about the secure/combat rules above. In-game
testing is manual: clone/pull into `Interface/AddOns/`, `/reload`, and exercise
the flows. When adding secure behaviour, always ask: *"does this touch a secure
attribute, macro, or binding — and could it run in combat?"* If yes, it must be
guarded and deferred.
