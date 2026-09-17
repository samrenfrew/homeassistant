# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a **Home Assistant configuration directory** (HA `2026.5.4`, see `.HA_VERSION`), version-controlled in git. It is *not* an application codebase — there is no build step, no compiler, and no test suite. "Development" here means editing YAML configuration, custom component Python, and Lovelace dashboard/frontend files, then reloading or restarting Home Assistant.

Inside Home Assistant this directory is mounted as `/config` (paths in YAML like `/config/media` refer to it), while on the host it lives at `/opt/data/homeassistant`.

## Validating and applying changes

There is no lint/test/build. To check a configuration change:

- **Config check**: from the HA host/CLI, `ha core check` (Supervised/OS installs) validates YAML before applying. If unavailable, use the UI: **Developer Tools → YAML → Check Configuration**.
- **Apply changes without a full restart**: most domains support targeted reloads under **Developer Tools → YAML** (Automations, Scripts, Scenes, Template Entities, Input helpers, etc.). Reserve a full **Restart** for changes to `configuration.yaml`, integrations, or custom components.
- **Restart is required** after editing anything loaded only at startup (top-level `configuration.yaml` keys, most `custom_components/`).

`home-assistant.log` (and `.log.1`) in the root are the runtime logs — check them after applying changes to catch config errors and integration failures.

## Configuration architecture

`configuration.yaml` is the single entry point. It keeps itself small by splitting each domain out with `!include` directives into the `configs/` tree and a few root files:

- `!include <file>.yaml` — one file (e.g. `automation: !include automations.yaml`).
- `!include_dir_merge_list configs/<domain>/` — every `.yaml` in the directory is concatenated into one list. Used for `sensor`, `binary_sensor`, `switch`, `light`, `camera`, `media_player`, `template`, `command_line`, `device_tracker`, `alarm_control_panel`.
- `!include_dir_merge_named configs/<domain>/` — merges into a dict. Used for `mqtt` and `themes`.

So to add e.g. a template sensor, edit `configs/template/sensor.yaml`; to add a command-line sensor, add/extend a file under `configs/command_line/`. **Do not** add a second top-level `sensor:` key in `configuration.yaml` — the split-config includes already own those domains.

Key root-level config files: `automations.yaml`, `scripts.yaml`, `scenes.yaml`, `groups.yaml`, `customize.yaml`, `secrets.yaml`. Files ending in `.old` / `.bak` under `configs/` are disabled/archived and are not loaded.

### Secrets

`!secret <name>` in any YAML resolves against `secrets.yaml`. `secrets.yaml`, `ip_bans.yaml`, and `known_devices*.yaml` are **git-ignored** (see below) — never move real secret values into tracked files.

## Custom components

`custom_components/` holds third-party integrations, most installed and updated via **HACS** (`custom_components/hacs`). Treat these as vendored dependencies: prefer updating them through HACS/the UI rather than hand-editing. `custom_components/llmvision` is one that has been edited directly in this repo (see recent git history). Notable others: `adaptive_lighting`, `frigate`, `better_thermostat`, `spook`/`spook_inverse`, `scheduler`, `google_home`.

## Frontend / dashboards

- `www/` is served at `/local/` and via `/hacsfiles/` (card-mod, button-card, bubble-card, layout-card, etc.). `www/community/` is HACS-managed and git-ignored.
- Lovelace dashboards live in `.storage/` (UI-managed). Only specific ones are tracked (`lovelace`, `lovelace_dashboards`, `lovelace_resources`, `lovelace.*`) — see `.gitignore`. The rest of `.storage/` (auth, entity registry, device registry) is intentionally untracked.
- `themes/` contains custom frontend themes, merged in via `frontend.themes`.

## UIX styling (replaces card-mod)

`custom_components/uix` (UI eXtension, v8.0.1) replaces card-mod. It registers its own
`/uix/uix.js` in `.storage/lovelace_resources`. The card-mod `extra_module_url` is commented
out in `configuration.yaml`. The card-mod bundle still sits unloaded in
`www/community/lovelace-card-mod/`; remove it through HACS when convenient.

**Keep using the `card_mod` keys.** UIX reads card-mod's config and theme keys for backwards
compatibility, and this config still uses them everywhere. Do not rename them in bulk. Theme
key precedence is `uix-<type>-yaml` > `card-mod-<type>-yaml` > `uix-<type>` >
`card-mod-<type>`, and **only the first one found is used** — so adding a `uix-card-yaml`
key would silently disable the existing `card-mod-card-yaml` block.

**The active theme is `themes/oneplus/`.** `.storage/frontend_theme` selects `light` and
`dark`, both of which set `card-mod-theme: cardmod`, so `themes/oneplus/cardmod.yaml` holds
all the shared CSS. `themes/ember/` belongs to a work-in-progress dashboard and is not live.

### Performance rule: never put Jinja in a shared theme path

This is the one thing to get right. A theme style block is a map of DOM selector paths to
CSS. UIX tests **each path separately** for Jinja (`{%` or `{{`):

- **No Jinja** — the CSS is applied in the browser. It costs nothing.
- **Any Jinja** — UIX opens a `render_template` websocket subscription so the server renders
  that CSS. The subscription is keyed on the card's whole config, so cards never share one.
  **One card matching that path means one server round-trip.**

The `.` path matches every card. Jinja there is charged to every card on the dashboard, which
is what makes a dashboard feel slow to paint. Keep `.` static. Put anything templated behind a
class path so only the cards that need it pay. `.media_card$` is the worked example: it reads
`entity_picture` for media artwork, so it must stay templated, and scoping it to that class
takes it from ~294 subscriptions down to 4.

`card-mod-row-yaml` is still templated for battery and travel-time colours. That cost is per
entity row and has not been addressed.

### Sharing CSS between cards

Use a class, not a copied style block. Set `card_mod: {class: bare}` on the card, then add
class-gated rules to the static `.` block of `card-mod-card-yaml`, written as `ha-card.bare { }`
or `ha-card.frigate_events .events { }`. Plain CSS, so it costs nothing. A card can carry
several classes (`class: media_card fire`). Prefer this over the older
`{% if 'x' in config.card_mod.class %}` guards, which are Jinja and therefore cost a round-trip.
Existing classes: `bare`, `bar_card`, `frigate_events`, `state_value`, `dim_icon`, `media_card`,
`fire`, `remote_media`, `no_icon`, `no-hover`, `drive_time`.

**Where the class lands.** Every card on Overview sits inside a layout-card, which creates raw
card elements rather than `hui-card` wrappers. In that case UIX puts the class on the card's
`ha-card` and nowhere else. `:host(.x)` does not match, and a card with no `ha-card`
(layout-card, mushroom-chips-card) cannot be reached by a class at all. Those cards keep their
style inline: the chip rails, the horizontal scroll rails and `grid-layout {overflow: hidden}`.
Static inline CSS is as free as theme CSS, so this only loses deduplication.

**Do not write a class as a path (`.bare$: |`).** That was tried and silently did nothing:
the path selects `ha-card.bare` inside the card, then `$` steps into ha-card's own shadow
root, which holds only a slot. When a class needs a real path, to keep Jinja scoped, use
UIX's host filter as the key: `"&.media_card": {.: ...}`. Quote it, because `&` starts a
YAML anchor.

A class on an entity row (bar-card with `entity_row: true`) is a row, not a card. Its rules
go in `card-mod-row-yaml` as `:host(.bar_card) ...`, because the row patch puts the class on
the row element and styles its shadow root.

**CSS cannot reach slotted content.** `ha-markdown` inside `hui-markdown-card` is one
example: its `h2` sits two shadow roots deep, in `ha-markdown-element`, and no selector from
the card root can reach it. Check the real DOM before nesting a path, using
`uix_forge_path()` in the browser console to get the exact path.

Theme and card CSS at the same path do **not** conflict. `zr()` in `uix.js` concatenates them,
theme first, so a card can add to a themed path rather than replace it.

The markdown cards keep their styling inline on purpose. Sharing it through the theme was tried
and reverted: only three markdown cards exist across all dashboards, each needs different
padding, and padding cannot be split from the shared typography because both live at the same
`ha-markdown$` path. Not worth a theme entry.

Weigh theme against inline by how many cards use the rule. A theme path is paid for by every
card it matches; an inline style is paid for only by its own card.

### Editing storage-mode dashboards

Every dashboard except `refactor-dash` is storage mode. Home Assistant keeps the Lovelace
config in memory and rewrites `.storage/lovelace*`, so edits made to those files on disk get
overwritten. To change one, produce a complete YAML document and let the owner paste it into
the dashboard's raw configuration editor. Read the current state by converting the JSON:

```bash
python3 -c "import json,yaml;print(yaml.safe_dump(json.load(open('.storage/lovelace.lovelace'))['data']['config'],sort_keys=False,width=200))"
```

### layout-card: do not move its grid definitions into CSS variables

`custom:layout-card` applies its `layout:` block as **inline styles on the `#root` div inside
its own shadow root**, and only passes through keys starting with `grid` plus `place-items` and
`place-content`. Other keys (`margin`, `card_margin`, `padding`, `height`, `reflow`,
`mediaquery`) are handled by its own JavaScript, so arbitrary CSS in `layout:` is ignored.

Replacing the repeated `grid-template-columns` values with a `var(--grid-3up)` fed from the
theme was tried and reverted: the variable did not resolve at `#root` and every grid collapsed
to a single column. The literal values are duplicated across 15 cards on the Overview
dashboard. Leave them duplicated unless you can test a change on one card first.

### Layout that must not be changed

Views use `custom:vertical-layout` with `max_cols: 2` and `custom:layout-break` cards to place
cards in the left or right column on desktop and a single column on mobile. This is deliberate.
UIX has no equivalent, and 28 cards depend on layout-card reading their `view_layout` key.
Card-level grids inside those views are fair game; the view-level layout is not.

### Forge, foundries and sparks

UIX Forge (`custom:uix-forge`) adds templated elements, reusable server-side foundries and
bolt-on behaviours called sparks. None of it is in use yet. Foundry files need a top-level
`uix_foundries` key and must be registered under Settings → Devices & Services → UI eXtension
→ Configure. `UIX-AUDIT.md` and `UIX-AUDIT-PRODUCTION.md` record what is worth adopting.

## Git conventions (important)

`.gitignore` uses an **ignore-everything-then-allowlist** strategy: only specific file extensions (`*.yaml`, `*.yml`, `*.html`, `*.css`, fonts) and a short list of `.storage/lovelace*` files are tracked. This means large runtime artifacts present in the working tree — `home-assistant_v2.db*`, `*.log`, `zigbee.db`, `backups/`, `media/` — are deliberately untracked. Do not `git add -f` them.

`backup.sh` is the commit helper the owner uses: it stages everything, commits with the contents of `.HA_VERSION` as the message, and pushes to `main`.
