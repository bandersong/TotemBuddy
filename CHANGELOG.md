# Changelog

All notable changes to TotemBuddy. TotemBuddy is a fork of
[TotemDeck](https://github.com/iltGames/TotemDeck) (MIT); versions below cover
the fork's additions.

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
