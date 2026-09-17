# PLAN — Ember dashboard: finish, polish, migrate

Successor to `HANDOFF-EMBER.md` (read it first — its Gotchas section still applies verbatim).
Scope: close the gap between the built `refactor-dash` (YAML mode, `dashboards/ember/`) and the
Round-5 design (`design1.png`–`design5.png` at `samrenfrew.co.uk/ha/new/`), then migrate to
storage (UI) mode as the final phase.

## Honest capability assessment — design vs Home Assistant

Verdict: **every Round-5 element is buildable with cards already installed. No custom
component development is needed, and no new HACS installs.** The design was clearly drawn
with HA card primitives in mind. Per component:

| Design element | Verdict | How |
|---|---|---|
| 5a Home (greeting, pills, rooms list) | ✅ Built, needs polish | button-card templates (`ember_pill`, `ember_room_row`) |
| 5h Playing / 5g idle / 5i mini strip | ✅ Fully coverable | `mediocre-massive-media-player-card` (playing) + `-media-player-card` (idle row) + card-mod to Ember tokens. Group picker is native to it |
| 5j Climate card (drag track, −/+, Boost) | ✅ With one caveat | `vertical-stack-in-card`: button-card header + **my-slider-v2** (installed) as the draggable track + −/+ buttons. Caveat: exact rounded-fill look needs card-mod on my-slider internals — budget iteration time |
| 5k Light tile long-press sheet (brightness + warmth) | ✅ | bubble-card popup per light, templated via **streamline-card** so the popup YAML is written once. my-slider-v2 for both sliders |
| 5l Toggle row | ✅ Built (`ember_toggle_row`) | restyle only |
| 5m Alarm arm/disarm sheet + red armed state | ✅ | bubble popup behind the alarm pill; `alarm_control_panel.alarm` is real. Red armed variant = state-driven card-mod |
| 5n TV remote (number pad, D-pad, VOL/CH) | ✅ | button-card grids + `webostv.button` / `media_player` services on `media_player.lg_webos_tv` (per HANDOFF-EMBER spec) |
| 5o Nav (5 tabs, labels, Rooms popup) | ✅ | navbar-card already does popups + labels; add Media route |
| 5d Network (2-stat internet, chips, usage bars) | ✅ | button-card stats + bar-card (fix value colour) or pure button-card fills |
| Washer/dryer appliance tiles w/ status dot | ✅ Built (`ember_appliance`) | restyle to 2-up grid |
| Mixed-case 15px section headers w/ right meta | ✅ | mushroom-title + card-mod (`!important` on font-size — known gotcha) |

The one *structural* thing HA cannot give us in YAML mode is live editing without
refresh/restart — that is workflow, not capability, and phase 6 addresses it.

## Decisions locked (owner, 2026-07-17 grilling — adds to HANDOFF-EMBER decisions 1–3)

4. **Mode migration**: finish all polish in YAML mode, then migrate to storage mode as the
   **final phase** via raw-config-editor paste. `Overview` stays the untouched fallback.
5. **Climate card**: draggable track (my-slider-v2), not visual-fill-only.
6. **Light tile long-press**: faithful 5k bubble popups, one per light, **templated with
   streamline-card** to avoid per-light YAML duplication. Fidelity > minimalism is the
   owner's standing preference for visuals.
7. **Media view**: all players, state-aware — every player renders as a 5g idle row and
   swaps (conditional card) to the 5h massive card while playing. TV row opens the remote
   popup.

## Phases

Order chosen so each phase is independently shippable and screenshot-checkable by the owner.

### Phase 1 — Fidelity sweep across existing views (no new components)
1. Roll the proven padding + heading fix from `view-home.yaml` to the other 8 views
   (`view-lights`, `view-systems`, `view-room-{lounge,kitchen,bedroom,nursery,ella,office}`).
   Anchors are **per-file** — repeat the edit in each.
2. Same pass: convert uppercase Space-Mono kickers → mixed-case 15px section headers with
   right-aligned meta (HANDOFF decision 2). Space Mono survives only on tiny tags.
3. `ember_mini_media` template: add `margin: 0 24px` (bump `?v=` — template edit).
4. Home status pills (`ember_pill`): slim to 34px, leading mdi icons, persistent alarm pill
   (Disarmed/Armed states, tappable).
5. Scenes → pill-chips on lounge + lights views (Evening/Movie/Relax real scenes + dashed
   "Add preset" chip).

### Phase 2 — Component rebuilds
1. **Climate 5j** (`ember_climate`, currently broken): rebuild as vertical-stack-in-card =
   button-card header (name, state line, Boost chip) + my-slider-v2 draggable track
   card-modded to the amber rounded fill + − / + circle buttons targeting
   `climate.set_temperature`. Apply to Hive whole-home + TRV variants (`ember_trv`).
2. **Light tile 5k popups**: one streamline-card template holding the bubble-card popup
   (brightness gradient bar + warmth slider + close). Instantiate per light. `hold_action`
   on `ember_light_tile` opens it; tap stays toggle.
3. **Alarm 5m**: bubble popup behind the alarm pill — Home / Away arm buttons, exit-delay
   countdown text, red Disarm state via state-driven card-mod.

### Phase 3 — Media (HANDOFF decisions 1 & 3 + new decision 7)
1. Swap mini-media-player → mediocre-massive in the "Playing" conditional sections
   (lounge / bedroom / kitchen); kitchen idle → 5g compact row. Card-mod to Ember tokens.
2. **TV remote 5n**: replace stock `media-control` in the `#tv-remote` bubble popup
   (`view-room-lounge.yaml`) with button-card grids per the HANDOFF service spec.
3. **New `view-media.yaml`**: all players state-aware (idle row ⇄ massive card via
   conditional). Register in `lovelace-refactor.yaml`.
4. **Navbar**: add Media route → 5 tabs (Home / Rooms / Lights / Media / Systems), enable
   mobile labels, restyle active state to the amber chip.

### Phase 4 — Network & Systems view
1. Internet section → compact 2-stat (↓ / ↑ big numbers) + Ping / AdGuard chips row.
2. NAS / NUC → meta moves into section heading ("74% used · 40°"); fix bar values (dark on
   amber = unreadable) — light text, thin bars per 5d.
3. Appliances → 2-up grid of `ember_appliance` tiles.

### Phase 5 — Validate + owner sign-off
1. `docker exec homeassistant python -m homeassistant --script check_config -c /config`
   (does NOT cover dashboards) + permissive-loader `yaml.load` on every `dashboards/ember/*.yaml`.
2. Bump both cache-busters if templates/CSS changed; full restart if `stylesheet.css` touched.
3. Owner screenshot pass per view against design1–5. Iterate.

### Phase 6 — Migrate YAML → storage (UI) mode
Only after sign-off, so the migrated artefact is final:
1. Create a fresh storage-mode dashboard in the UI (keep `Overview` untouched as fallback).
2. Paste the fully-resolved config via UI raw config editor (three-dots → Raw configuration
   editor). Pre-flatten the `!include`s first (script it: yaml round-trip that inlines
   `ember/*.yaml`) — storage mode has no `!include`.
3. Verify custom root keys survive (`button_card_templates_url`, `kiosk_mode`) — they are
   preserved by the raw editor; if `kiosk_mode` misbehaves in storage mode, its docs cover
   storage dashboards natively.
4. Result: owner can tweak any card in the UI with zero restarts. Agent workflow after
   migration: edit via raw editor paste, or accept `.storage/lovelace.<id>` JSON edits
   (git-track the new storage file by adding it to the `.gitignore` allowlist).
5. Retire `refactor-dash` YAML dashboard from `configuration.yaml` once the storage copy is
   confirmed; keep `dashboards/ember/` in git as the source-of-truth archive.

## Risks / watch-list

- **my-slider-v2 styling depth**: the 5j/5k fills need card-mod into its shadow DOM; if it
  fights back, fallback is visual-fill + −/+ (owner accepted draggable as the goal, not a hill).
- **Conditional card flicker** on media state changes — known Lovelace quirk; acceptable.
- **Cache-busters** remain the #1 footgun until phase 6 removes the YAML-mode workflow
  (`?v=` on templates URL; CSS resource bump needs full restart).
- **check_config blindness** to dashboards — the permissive YAML parse in phase 5 is the only
  syntax net; visual bugs only surface on device.

## Out-of-scope ideas surfaced (→ BACKLOG.md candidates, not written yet)

- Desktop side-rail layout tuning (design 5o right panel) — current pass is mobile-first.
- Git-tracking the migrated storage dashboard file + a small "flatten includes" helper script
  as a reusable tool.
