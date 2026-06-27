# Changelog

All notable changes to TotemBuddy. TotemBuddy is a fork of
[TotemDeck](https://github.com/iltGames/TotemDeck) (MIT); versions below cover
the fork's additions.

## [2.1.0] — Shields, cooldowns, dispels & the "hard to click" fix

### Added
- **Shield trinity trackers.** Earth Shield, Lightning Shield, and Water Shield,
  each a secure cast button *and* a live tracker showing your shield's charges +
  remaining duration (cooldown swipe + time text), dimmed red when missing.
  Earth Shield uses a smart `@mouseover → @target → @player` cast and scans your
  target/focus/group for *your* shield (aura filter `"PLAYER"`), so it finds the
  one on the tank. Per-shield keybinds; `/tb shields` settings window.
  (`UI/Shields.lua`)
- **Cooldown cluster** (display-only): Nature's Swiftness, Mana Tide Totem, your
  equipped trinkets (slots 13/14), and your **Healing Way** stacks on the tank —
  cooldown swipes + ready glow, plus a gold pulse on Nature's Swiftness while
  it's active. `/tb cooldowns`. (`UI/Cooldowns.lua`)
- **Dispel bar.** Cure Disease + Cure Poison as smart `@mouseover` secure cast
  buttons (cleanse the unit under your cursor without changing target), with
  keybinds. `/tb dispel`. (`UI/Dispel.lua`)
- **Mana Tide Totem** added to the quick-react bar (new installs and, via a
  one-time migration, existing ones).
- **Keybind conflict detection.** Binding a key that another TotemBuddy action
  already uses now prints a warning (override bindings are last-writer-wins, so a
  silent clash would otherwise kill the older button). (`Bindings.lua`)
- Quick-react bar gained a **lock toggle** and a **scale slider** in its config.

### Fixed
- **Buttons were hard to click.** The cooldown swipe frame added over each cast
  button was intercepting the mouse; clicks never reached the button. All
  cooldown frames over clickable buttons now call `EnableMouse(false)`.
- Cast buttons registered both `AnyDown` *and* `AnyUp`, firing the secure cast
  twice per click (and double-running right-click handlers), which felt like
  dropped clicks. Now `AnyDown` only — one responsive cast on press.
- The quick-react bar now moves with a plain drag when unlocked (the old
  Ctrl-only drag was easy to miss and made it feel stuck).

### Changed
- Active totem buttons gained a spell-cooldown swipe (Mana Tide, Fire Nova, the
  Elementals) — GCD-length cooldowns are filtered out so it doesn't flicker.
- All new bars defer their secure work out of combat and flush it on
  `PLAYER_REGEN_ENABLED`, and own their saved-variable tables per character.

### Deliberately deferred (documented, not shipped half-baked)
- **Downrank heal macro auto-swap** and **CC'd-without-Tremor flash alert** were
  scoped (GLM feature pass) but not shipped: the first is really a Healing-Wave
  feature with its own config surface, the second relies on locale-fragile combat
  log parsing. Both need more design before they're trustworthy in a raid.

## [2.0.0] — TotemBuddy fork

### Added
- **Named totem sets.** Save the current four active totems as a named set,
  then list / apply / rename / delete / reorder. UI lives in the new **Sets**
  tab of the config window; also driven from chat
  (`/tb saveset|sets|set|delset`). (`Sets.lua`, `UI/SetsTab.lua`)
- **Per-set keybindings for in-combat switching.** Each set can be bound to a
  key; the key casts the set's `/castsequence` (one totem per press), so you
  switch sets mid-fight by pressing a different bound key — within Blizzard's
  one-hardware-event-per-cast rule. (`Bindings.lua`)
- **Quick-react utility bar.** A movable bar of one-click secure cast buttons
  for reactive totems (Grounding, Tremor, Poison/Disease Cleansing, Earthbind by
  default), with its own config window: show/hide, add by name or spell ID,
  remove, and bind a key per totem. (`UI/QuickBar.lua`, `/tb quick`)
- Documentation: full `README.md`, `DESIGN.md` (architecture + the policy rules
  that shape the addon), and this changelog.

### Changed
- Forked and renamed from TotemDeck: addon identifiers, saved variable
  (`TotemBuddyDB`), slash command (`/tb`), and generated macro prefix (`TB*`,
  e.g. `TBAll`).
- All set/quick secure work (macrotext, override keybindings) is deferred out of
  combat and flushed on `PLAYER_REGEN_ENABLED`, mirroring the existing
  `pendingActiveUpdates` pattern.
- Saved-variable init gives each character its own copies of the quick-react
  tables instead of sharing the defaults reference.

### Removed
- The upstream CurseForge auto-release GitHub Action (would have published the
  fork under the wrong identity).

---

Inherited from TotemDeck: the 4-element totem bar, hover popups, totem timers
(bar/icon styles, expiry sounds), out-of-range dimming, weapon-buff buttons, and
the Reincarnation/Ankh tracker.
