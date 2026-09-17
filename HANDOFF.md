# HANDOFF — Overview dashboard: UIX theme repair and performance pass

For the next agent. Read `CLAUDE.md` first, then this. The Ember dashboard has its own
handoff in `HANDOFF-EMBER.md` and `PLAN.md`. It is parked. This document is about the live
storage-mode `Overview` dashboard (`.storage/lovelace.lovelace`) and the active theme
`themes/oneplus/cardmod.yaml`.

## The rule that decides everything

Performance is the first concern for anything UIX or card-mod. Overview has about 294 cards.
UIX injects the theme CSS into every card, and every injected byte can add to the flicker on
first paint. We will not remove the flicker, only limit it. That is why so much of the
dashboard is button-card: its CSS goes inline into the card and nothing is injected.

Apply this to every styling decision:

- Jinja in a theme path costs one server round-trip per card that matches. Never in `.`.
- Static theme CSS in `.` costs nothing on the server, but its bytes reach every card.
- Static inline `card_mod: style:` costs nothing on the server and reaches one card.
- A shared class is only worth it when it saves real edits. Rule of thumb from the owner:
  three or more uses, or use across views. Two side-by-side cards stay inline, even if
  duplicated. `frigate_events`, `state_value` and `dim_icon` are at two uses and should
  move back inline (see tasks).

## Where we are (2 Sep 2026)

Done and confirmed by the owner in the browser:

- Theme classes work again. They were broken since 18 Aug because they were written as paths
  (`.frigate_events$: |`). The fix is class-gated CSS in the `.` root block
  (`ha-card.frigate_events .events`). Details in `CLAUDE.md`, "Sharing CSS between cards".
- `media_card` artwork renders. It uses UIX's host filter as the key: `"&.media_card":`.
- The mobile bottom navbar clears the Android gesture bar. `.header` in
  `card-mod-root-yaml` gets `padding-bottom: max(env(safe-area-inset-bottom, 0px), 24px)`.
  24px is the fallback knob.

Done, not yet confirmed:

- `bar_card` moved from `card-mod-card-yaml` to `card-mod-row-yaml` as `:host(.bar_card)`.
  bar-card with `entity_row: true` is a row, so the card block never reached it. Check the
  NAS and NUC CPU/Memory bars on the Systems view.

Done, not yet applied:

- `overview-b4.yaml` at the repo root is the Overview config with `chip_rail` (4), `scroll`
  (7) and `no_overflow` (5) moved back to inline static styles. Those cards have no
  `ha-card`, so a class cannot reach them. It differs from the live dashboard in those 16
  cards only. Paste it into Overview's raw configuration editor. Until then the chip rails
  and horizontal scroll rails have no styling at all. `overview-b3.yaml` is the older,
  superseded paste and can be deleted after b4 is in.

## Tasks for tomorrow, in order

1. Confirm the bars, then paste `overview-b4.yaml`. Confirm chip rails and scroll rails.
2. Move `frigate_events`, `state_value` and `dim_icon` back inline. Generate the paste the
   same way as b4 (see "How to change Overview"). Remove the three rule groups from the `.`
   block. `bare` (9 uses, 4 views) and `media_card` (Jinja must be scoped) stay as classes.
   `remote_media` and `no_icon` have no users on Overview; check the other dashboards before
   deciding.
3. Decide about B1. On 18 Aug a session built ten static grid classes (`grid3`, `rail_2` to
   `rail_6`) to replace 15 copies of layout-card grid definitions and all `mediaquery`
   blocks. That output was never pasted and is lost. Under the performance rule it is
   doubtful: the classes would add about 3.6KB to the `.` block, paid by every card, to
   remove config bytes that cost nothing at paint. Recommendation: do not rebuild it.
4. The remaining Jinja paths are the real paint win. `card-mod-row-yaml` under
   `hui-generic-entity-row` is templated for battery and travel-time colours, so every entity
   row opens a subscription. Options: template sensors in `configs/template/` that carry the
   colour as an attribute, or icon colour through `state_color` and customize. Count the rows
   first.
5. Commit. Everything since the 18 Aug commit is uncommitted: the theme, the dashboard,
   `configuration.yaml`, `.storage/lovelace_resources`, `CLAUDE.md`, this file. `backup.sh`
   commits with `.HA_VERSION` as the message and pushes to main.

## How to change Overview

Overview is storage mode. Edits to `.storage/lovelace.lovelace` on disk are overwritten by
Home Assistant. Read the live config from that file, transform it in Python, dump YAML, and
the owner pastes it into the raw configuration editor. `overview-b4.yaml` was made this way:
load the JSON, walk the tree, swap `card_mod.class` for `card_mod.style`, dump with
`sort_keys=False` and literal block scalars for multi-line strings. Always diff the result
against a plain dump of the live config to prove only the intended cards changed.

## What we learned about UIX today (all verified in `custom_components/uix/uix.js`)

- Two patches apply card styles. The `hui-card` patch puts the class on the card element and
  the style inside the card's shadow root. The `ha-card` patch puts the class on `ha-card`
  and skips itself when a `hui-card` wrapper exists. layout-card creates children with
  `createCardElement`, which returns raw card elements, so on Overview only the `ha-card`
  patch runs. Result: the class is on `ha-card` and nowhere else. `:host(.x)` never matches.
- Cards with no `ha-card` (layout-card, mushroom-chips-card) get no class at all. Inline only.
- A theme key `.x$` does `querySelector(".x")` inside the card, finds `ha-card.x`, then `$`
  enters ha-card's own shadow root, which holds a slot. Nothing to style there.
- A key starting with `&` is a host filter. `&.x` runs the children only when the style
  root's host carries the class. It worked for `media_card`. Quote it in YAML.
- Entity rows (including custom cards with `entity_row: true`) are patched as rows: class on
  the row element, style prepended into its shadow root. `:host(.x)` works there, and the
  rules belong in `card-mod-row-yaml`.
- `#` is not a CSS comment. A `# foo: bar;` line is an invalid declaration and the parser
  discards it. One ending in `:` instead of `;` swallows everything to the next `}`. Several
  of these were in the theme and were removed today. Search the dashboards for more.
- Theme changes need `frontend.reload_themes` and a hard refresh. Home Assistant was last
  restarted 2 Sep 13:11.

## Environment notes

- Repo is on an SMB mount at `/Volumes/Docker/data/homeassistant`. Docker and the HA CLI are
  not reachable from the Mac. The HA web server at `192.168.0.4:8123` is reachable and serves
  the frontend bundles unauthenticated if you need to read frontend source.
- HA is `2026.8.2` (`.HA_VERSION`). `CLAUDE.md` still says 2026.5.4 in one place.
- The Cursor Source Control panel fights git for `index.lock` on this mount. Auto-refresh is
  off in `.vscode/settings.json`; do not turn it back on.
