# HANDOFF — Ember dashboard polish pass

Terse handoff for a new agent. Read `CLAUDE.md` and the auto-memory `ember-dashboard-build.md` first; this doc covers the current *polish-to-match-design* pass on top of the already-complete build.

## What this is

Redesigning the HA dashboard around **Ember** (warm monochrome dark + amber `#e08f5a`). The full build is DONE and lives in the YAML-mode sandbox dashboard **`refactor-dash`** (`dashboards/lovelace-refactor.yaml` → `!include ember/*.yaml`). Storage `Overview` is the untouched fallback. This pass = closing the gap between the built dashboard and the reference design.

## Reference material (already gathered — reuse, don't re-fetch)

- **Design source**: claude.ai design project `bd161cad-f1a7-4621-b579-920be6288d65`, file `Dashboard Directions.dc.html` (read via `mcp__claude-design__read_file`; too big for one read — dumped to a tool-results txt this session).
- **Design screenshots** (target visuals): `https://www.samrenfrew.co.uk/ha/new/design1.png`..`design5.png`.
  - design1 = 5a Home / 5b Lounge / 5e Kitchen; design2 = 5f Office / 5c Lights / 5d Network; design3 = media states 5g/5h/5i; design4 = 5j climate / 5k light tile / 5l toggle row; design5 = 5m alarm / 5n TV remote / 5o nav.
- **Current-state screenshots** (before this pass): `https://www.samrenfrew.co.uk/ha/home.png` (+ kitchen/lights/lounge/network).
- A full **verbatim CSS/geometry extraction** of every Round-5 screen/component was produced this session (tokens, px, radii, layouts). If lost, re-extract from the design HTML.

## Decisions locked in (asked & answered by owner)

1. **Media "Playing" card** → use `custom:mediocre-massive-media-player-card` (from installed `mediocre-hass-media-player-cards`), card-modded to Ember tokens. NOT mini-media-player, NOT hand-built.
2. **Section headings** → convert the uppercase Space-Mono kickers to the design's **mixed-case 15px** section headers, with right-aligned meta where design shows it (e.g. "1 on", "74% used · 40°"). Space Mono stays only for tiny tags (nav "ROOMS" label, climate "TARGET").
3. **Nav** → 5 tabs + text labels (Home / Rooms / Lights / Media / Systems), restyled active state, **and build a new Media view** for the Media tab.

## Done this session

- **Root-caused the two big issues:**
  - **Padding (owner's #1):** only title *text* was inset; every surface card + rail sat flush to both edges. `layout.padding` does NOT work — layout-card's `vertical-layout` ignores it (only `grid-layout` reads `layout.padding`; vertical hardcodes `--layout-padding: 4px 0px 4px 0px`). **Fix = per-card card-mod insets** (the method titles already use): surface `#root { margin: 0 24px }`, rails keep 24px left + bleed right, titles keep 24px internal padding.
  - **Heading sizes (owner's #2):** mushroom-title-card sizes its title via `--title-font-size` (default 24px), so card-mod `.title{font-size:…}` (no `!important`) was ignored → all headings collapsed to ~24px. **Fix = add `!important` to font-size** (do NOT switch to ha-markdown — not needed).
- **`dashboards/ember/view-home.yaml` fully patched** with the above (padding per-card + `!important` heading sizes). Awaiting owner screenshot confirmation before rolling the identical pattern to the other 8 views.

## Not done yet (task list order)

Only Home's padding+heading fix is applied. Remaining:

- **Roll padding+heading fix to the other 8 views** (`view-lights`, `view-systems`, `view-room-{lounge,kitchen,bedroom,nursery,ella,office}`). Each view **re-declares the anchors** (`&screen_title`, `&kicker`, `&section_title`, `&rail`, `&row_group`) — so the edit must be repeated per file. Also convert kickers→mixed-case 15px section titles per Decision 2.
- **`ember_mini_media` template** needs `margin: 0 24px` (home now-playing strip) — deferred because touching the template needs a cache-bump (see gotchas).
- **TV remote** (owner #3): replace stock `media-control` in the `#tv-remote` bubble popup (in `view-room-lounge.yaml`) with the full 5n remote (power, 1-9/0 number pad, D-pad+OK, back/home/mute, VOL/CH). Build as button-card grids. Control = `webostv.button` (buttons: UP/DOWN/LEFT/RIGHT/ENTER/BACK/HOME/CHANNELUP/CHANNELDOWN/0-9) + `media_player` volume/power services on `media_player.lg_webos_tv`. Legacy `remote_button` templates exist (dead code) as a reference.
- **Media card** (owner #4): swap mini-media-player → mediocre-massive in the "Playing" conditional sections (lounge/bedroom/kitchen); kitchen idle → 5g compact.
- **Hive climate card** rebuild (`ember_climate` template): currently BROKEN — renders a stray "7° TARGET" disc instead of the horizontal amber slider. Rebuild to 5j (horizontal track + amber fill, − left / + right, correct target).
- **Home status pills** (`ember_pill`): slim to 34px, add leading mdi icons, add a persistent tappable Disarmed/Armed alarm pill (currently only shows when armed).
- **Scenes → pill-chips** (lounge/lights): currently square tiles; design wants pills (Evening/Movie/Relax + dashed "Add preset"). NOTE scenes Movie/Evening/Relax/Reading are all REAL (`scenes.yaml`) — keep them, just restyle.
- **Network view** (`view-systems`): Internet → compact 2-stat (↓/↑) + chips card (not 5 rows); NAS/NUC → move meta into heading + restyle bars (currently unreadable: dark values on amber bar-card); Appliances → 2-up grid.
- **Nav + Media view** per Decision 3 (`_navbar.yaml` + new `view-media.yaml` + register in `lovelace-refactor.yaml`).
- **Validate + cache-bust** at the end.

## Known issues / blockers

- `ember_climate` Hive card is visually broken (see above).
- bar-card CPU/RAM/Disk values render as dark text on the amber fill → invisible (Network view).
- Owner viewing on mobile; kiosk hides the HA header → each view re-adds a menu/back chip.

## Gotchas (would-have-been-useful-to-know)

- **`vertical-layout` ≠ padding-configurable.** Use per-card card-mod insets, not `layout.padding`.
- **mushroom-title-card font-size needs `!important`** (variable-driven default wins otherwise).
- **Cache-busters — bump on every edit:**
  - Editing `www/button_card_templates.yaml` → bump `button_card_templates_url: /local/button_card_templates.yaml?v=N` in `dashboards/lovelace-refactor.yaml` (currently `?v=6`), else cards show "template 'ember_*' is missing".
  - Editing `www/stylesheet.css` or fonts → bump `?v=N` on the `type:css` resource in `.storage/lovelace_resources` **and full HA restart** (resources read only at startup; no reload service).
- **Anchors are per-file**, not shared — repeat anchor edits in every view file.
- **Validation:** `docker exec homeassistant python -m homeassistant --script check_config -c /config` (no `ha`/`hass` CLI; HA is container `homeassistant`). check_config does NOT validate Lovelace dashboards — they re-read on browser refresh only. For dashboard YAML syntax, run a python `yaml.load` with a permissive `!`-multi-constructor (native check chokes on `!include`).
- **No local browser** to render the design HTML (no chromium/playwright). Rely on the design screenshots + extracted CSS.
- Paths: repo = `/opt/data/homeassistant` (host) = `/config` (inside HA). Ember views: `dashboards/ember/`. Templates: `www/button_card_templates.yaml` (ember_* family starts ~line 1072). Theme tokens: `themes/2025/dark.yaml` (`--ember-*`). Derived sensors: `configs/template/ember.yaml`.
- Installed-but-unused-here cards worth knowing: `streamline-card`, `mediocre-hass-media-player-cards` (3 variants: `-media-player-card`, `-massive-media-player-card`, `-multi-media-player-card`), `bar-card`, `bubble-card`, `navbar-card`.
