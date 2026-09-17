# UIX audit — production Overview dashboard

Written 2026-08-18. Findings only. No changes applied.

Target: `.storage/lovelace.lovelace` (Overview, storage mode, 6 views, last
modified 28 July 2026). Read as YAML after conversion. Line references point at
the converted YAML, so they are approximate; the anchor text quoted with each
finding is exact.

Sister document: `UIX-AUDIT.md` covers the WIP Ember dashboard.

Active theme is `themes/oneplus/` — `.storage/frontend_theme` selects `light`
and `dark`, both defined there, and both set `card-mod-theme: cardmod`
(`themes/oneplus/light.yaml:3`, `themes/oneplus/dark.yaml:3`). Ember's theme is
not in play here.

## Part A — Things that are wrong now

These are independent of UIX. They came out of reading the config.

### A1. The tumble dryer chip resets the dishwasher

In the Home view chip strip, the "Tumble Dryer finished" chip has:

```yaml
conditions:
  - entity: input_select.tumble_dryer
    state: Finished
chip:
  entity: input_select.tumble_dryer
  hold_action:
    action: call-service
    service: input_select.select_option
    service_data: {option: 'Off'}
    target:
      entity_id: input_select.dishwasher   # <- wrong entity
```

Holding the tumble-dryer chip clears the dishwasher instead. The washing
machine and dishwasher chips both target their own entity, so this is a
copy-paste slip.

### A2. A Jinja template uses JavaScript optional chaining

The Google Home alarm chip content begins:

```yaml
content: '{% if states[''sensor.gh_next_alarm'']?.state != "unavailable" %}
```

`?.` is JavaScript, not Jinja2. The neighbouring timer chip uses the correct
`states('sensor.gh_next_timer')` form, which confirms this is a mistake rather
than a deliberate idiom. The template cannot render as written.

### A3. Two CSS declarations use `var(--rgb-*)` as a colour

`--rgb-red` and friends hold a comma triple such as `244, 67, 54`, meant for
`rgb(var(--rgb-red))`. Two card_mod blocks use them raw:

```yaml
card_mod:
  style: "ha-card {\n  color: var(--rgb-red)\n}\n"
```

`color: 244, 67, 54` is invalid, so the declaration is dropped.

The 11 `icon_color: var(--rgb-green)` uses are **fine** — checked mushroom's
source, `www/community/lovelace-mushroom/mushroom.js`, where the colour helper
returns an unrecognised value unchanged and the caller wraps it as
`rgb(${...})`. So `rgb(var(--rgb-green))` is what reaches CSS. Only raw CSS
blocks need the fix.

Both offending chips are the green "finished" chips, which also set
`icon_color: var(--rgb-green)`. Red text on a green chip looks like a leftover
in any case. Worth deciding what the intent was.

### A4. A bus condition can never be true

This appears in the Home greeting subtitle and again in the Travel subtitle:

```jinja
{%- elif is_state('input_select.sam_status_select', 'Afternoon')
     and is_state('input_select.sam_status_select', 'Out') %}
```

One entity cannot hold two states at once, so the "next bus home" text never
renders. The first branch tests `input_select.time` for `'Morning'`, so the
second branch probably meant `input_select.time` for `'Afternoon'` and
`input_select.sam_status_select` for `'Out'`.

### A5. Four `#` CSS comments

`#` does not start a comment in CSS. Four places use it that way:

- `# width: calc(100% - 48px);` in the chip-scroll block, 4 copies
- `# display:none;` in the frigate-events block, 2 copies
- `# --mmp-text-color: #fff;` in the mini-media-player block

Browsers skip the malformed declaration, so nothing visibly breaks. It is
misleading to read and one stray brace away from taking the rest of the block
with it. Use `/* */`.

### A6. Two bar-card taps refresh the wrong entity

In the NAS block, `sensor.nas_cpu_utilization_total` has:

```yaml
tap_action:
  service_data: {entity_id: sensor.nas_cpu_load_total}
```

Every other bar in the file refreshes its own entity. Also present: the NAS
disk-usage mini-graph is named `Internet Speed`, copied from the Internet card
above it. `show: {name: false}` hides it, so it is cosmetic.

### A7. The first Scenes tile is bound to the wrong entity

On the Lights view, the four scene tiles are Morning, Evening, Bright, Full.
Only the first carries an `entity:`, and it is `scene.evening` under the title
`Morning`. The tap action calls `light.turn_on` directly, so behaviour is
unaffected, but any state-based styling reads the wrong entity.

### A8. Production has no cache-busting on the button-card template library

`/local/button-card.js` is a fork. It adds `_getTemplates`, which reads
`lovelace.config.button_card_templates_url`, defaulting to
`/local/button_card_templates.yaml`. Upstream button-card has no such key —
confirmed by diffing against `www/community/button-card/button-card.js`.

The Ember sandbox sets that key with a `?v=11` cache-buster
(`dashboards/lovelace-refactor.yaml:16`). Overview sets no top-level keys but
`kiosk_mode`, so it fetches the un-versioned default URL. Edits to
`www/button_card_templates.yaml` may not reach a browser until a hard refresh.

Fix without touching anything else: add
`button_card_templates_url: /local/button_card_templates.yaml?v=1` to the
Overview config and bump it on edit.

## Part B — Duplication that UIX removes

### B1. The 3-up responsive card grid is defined 15 times

**The largest single win.**

This block appears verbatim 15 times across the six views:

```yaml
layout:
  grid-template-columns: repeat(3, minmax(calc((100% / 3) - 12px), 1fr))
  grid-column-gap: var(--grid-column-gap, 16px)
  grid-row-gap: var(--grid-row-gap, 13px)
  margin: 0
  card_margin: 0
  reflow: true
  grid-auto-flow: dense
  mediaquery:
    '(max-width: 1199px)':
      grid-template-columns: repeat(2, minmax(calc((100% / 2) - 8px), 1fr))
```

A UIX foundry holds it once. The `grid` spark expresses the same thing, and it
takes `media_queries` natively:

```yaml
# a registered foundry file, e.g. configs/uix/foundries.yaml
uix_foundries:
  card_grid:
    forge:
      mold: card
      grid_options: {columns: full}
      sparks:
        - type: grid
          for: "hui-grid-card $ #root"
          columns: repeat(3, minmax(0, 1fr))
          gap: "13px 16px"
          auto_flow: row dense
          media_queries:
            - query: "(max-width: 1199px)"
              columns: repeat(2, minmax(0, 1fr))
```

Each use then becomes:

```yaml
- type: custom:uix-forge
  foundry: card_grid
  element:
    type: grid
    square: false
    cards: [ ... ]
```

Note the `calc((100% / 3) - 12px)` inside `minmax` is doing what `minmax(0,
1fr)` plus a real `gap` does, so the arithmetic goes away with it.

**One thing this does not carry over.** Several children use
`view_layout: {grid-column: 1 / -1}` or `span 2` to go full width. The grid
spark's equivalent is `areas` plus `elements`, which needs every child named.
For a single full-width card the native grid card's per-card
`grid_options: {columns: full}` is simpler. Plan this per grid rather than
assuming a mechanical swap.

### B2. Seven copies of the icon-plus-text row

```yaml
layout:
  margin: 0
  card_margin: 0
  grid-template-columns: 100px 1fr
  place-items: center start
  padding: 0
```

Four uses are the Lights scene tiles (Morning, Evening, Bright, Full), three
are on the Home Assistant view (Uptime, Dark Mode, Restart System). Each wraps
a `large_button` and a `mushroom-title-card`.

The four scene tiles differ only in icon, `brightness_pct`, title and subtitle,
and all four repeat the raw area UUID `20de8f858167599cc6d5981a1b37bc6c`. This
is the cleanest foundry-with-billets case in the dashboard, and billet
interpolation is built for it:

```yaml
uix_foundries:
  scene_row:
    forge:
      mold: card
      billets:
        area: 20de8f858167599cc6d5981a1b37bc6c
        icon: ~
        pct: ~
        title: ~
      sparks:
        - type: grid
          for: "hui-grid-card $ #root"
          columns: "100px 1fr"
          place_items: center start
    element:
      type: grid
      cards:
        - type: custom:button-card
          template: large_button
          icon: "{{ icon }}"
          tap_action:
            action: perform-action
            perform_action: light.turn_on
            target: {area_id: "{{ area }}"}
            data: {transition: 1, brightness_pct: "{{ pct }}"}
          hold_action: {action: more-info, haptic: heavy}
        - type: custom:mushroom-title-card
          title: "{{ title }}"
          subtitle: "Lounge lights at {{ pct }}%"
```

Each tile becomes four lines. Note the subtitle now derives from `pct`, so the
label cannot drift from the action — today they are two independent strings.

### B3. Nine copies of the transparent-chip style

```yaml
card_mod:
  style: "ha-card {\n  background: none !important;\n  border:1px solid transparent !important\n}\n"
```

Nine uses, on `menu`, `template` and `quickbar` chips across five views. This
is a theme job, not a foundry job. UIX supports `uix.class` plus a `:host(.x)`
rule in the theme, so the nine copies become `uix: {class: bare-chip}` and one
theme entry. See `UIX-AUDIT.md` finding 1 for the mechanism — production is
better placed to use it than Ember is, because
`themes/oneplus/cardmod.yaml` already does hand-rolled class matching at lines
123, 131, 163 and 241 via `config.card_mod.class`. Those five templates collapse
into plain `:host(.x)` selectors with no Jinja.

### B4. Five copies of the chip-scroll rail, five of the 48px header grid

Every view except TV opens with the same header: a 48px gutter grid holding a
back arrow or menu chip, a scrolling chip strip, and a quickbar.

- `grid-template-columns: 48px minmax(calc(100% - (48px*2)), auto) 48px` — 5 copies
- The chip-scroll block that hides scrollbars — 5 copies (4 identical, the Home
  one adds `scroll-snap-type`)
- `grid-layout { overflow: hidden }` — 5 copies

One `view_header` foundry covers all three. The Home view's grid uses
`(48px*1)` rather than `(48px*2)` because it has no back arrow, so the gutter
count wants to be a billet.

Note `48px*1` multiplies by one. Harmless, but it shows this was cloned and
edited rather than parameterised.

### B5. Repeated card_mod bodies with two or more uses

52 card_mod blocks reduce to 18 distinct style bodies. Beyond B3, the repeats
are:

| Uses | What it styles | Route |
|---|---|---|
| 5 | `grid-layout { overflow: hidden }` on layout-cards | Theme class, or drops out with B1 |
| 4 | chip-scroll rail on mushroom-chips-card | Foundry (B4) |
| 3 | bar-card internals on NAS, NUC, PC | Theme class |
| 2 | frigate-events grid on front and back door | Theme class |
| 2 | mini-graph state value weight | Theme class |
| 2 | collapsable-cards icon and focus | Theme class |
| 2 | markdown title-card typography | Theme class |
| 2 | `ha-card { color: var(--rgb-red) }` | Delete or fix, see A3 |

The bar-card block also contains an empty `bar-card-name { }` rule.

### B6. The Docker services block is duplicated for NAS and NUC

Two ~35-line `collapsable-cards` blocks differ only by host. Every difference
is a substring of `nas` or `nuc`:

- `sensor.nas_docker*` / `sensor.nuc_docker*`
- `sensor.docker_on_nas_running_containers` / `..._on_nuc_...`
- the same for `stopped_containers` and `unhealthy_containers`

Billet interpolation covers this exactly — a string billet may reference
another with `{name}`:

```yaml
uix_foundries:
  docker_panel:
    forge:
      mold: card
      billets:
        host: ~                                    # 'nas' or 'nuc'
        glob: sensor.{host}_docker*
        running: sensor.docker_on_{host}_running_containers
        stopped: sensor.docker_on_{host}_stopped_containers
        unhealthy: sensor.docker_on_{host}_unhealthy_containers
```

Each use is then `foundry: docker_panel` plus `billets: {host: nas}`.

### B7. The door-activity icon map appears four times

A 9-line JavaScript block mapping `object_type` to an icon (cat, dog, bird,
package, bicycle, car, person) is inlined four times — front and back door, on
both the Home and Home Assistant views. The label JS is duplicated with it.

This one is **not** a UIX job. It is button-card JavaScript, and the right home
is a new entry in `www/button_card_templates.yaml` alongside the 34 already
there. Cheapest possible fix, no new tooling.

## Part C — What to keep

### C1. The view-level column mechanism stays

Every view is `type: custom:vertical-layout` with `max_cols: 2` (3 on Lights),
and 18 `custom:layout-break` cards assign cards to the left or right column.
That is deliberate and UIX has no equivalent — the `grid` spark styles a
container, it does not distribute cards into balanced columns.

So layout-card keeps earning its place at the **view** level. What B1 and B4
replace is the **card** level: 42 inner `custom:layout-card` instances whose only
job is to hold a repeated grid definition. Those two uses are worth keeping
separate in your head, because the audit only touches the second.

### C2. `view_layout: {show: {mediaquery: ...}}` stays

Five `custom:gap-card` instances appear only above 700px wide. UIX's
`forge.hidden` is templated on entity state, not on viewport width, so there is
no UIX replacement. The `grid` spark's `media_queries` can often remove the need
for a spacer card at all, which is the better fix, but that is a per-case
judgement.

### C3. The button-card fork stays

`/local/button-card.js` is the only button-card loaded — `.storage/lovelace_resources`
lists `/local/button-card.js?test3` and no `/hacsfiles/button-card/` entry. The
fork's `button_card_templates_url` patch is what lets one template library serve
every dashboard. Dropping the fork means finding another way to share 34
templates. Do not remove it as part of this work. See A8 for the cache-buster.

## Part D — Sparks worth adding, not just swapping

| Spark | Where it applies here |
|---|---|
| `map` with `memory: true` | The Home view People map resets zoom and centre on every state update. This is the fix, and Ember has no map so it only applies to production |
| `background` with `image_entity` | The four mushroom media-player cards in the Home speakers swipe stack. Reads `entity_picture` and signs the URL, so album art becomes the card background |
| `lock` | `alarm_control_panel.alarm` appears on Home and on Home Assistant, both with `tap_action: more-info` and no challenge |
| `search` with `append_text` | Replaces the templated `h1::after` version badge on the Home Assistant title card, which currently fakes text through CSS `content:` with an absolute position |
| `more-info` | The many `tap_action: more-info` targets open stock dialogs. Only worth it if you want them styled |

## Part E — Non-UIX wins found on the way

These are cheaper than anything above and do not need UIX at all.

1. **The big subtitle templates belong in `configs/template/`.** The Home
   greeting subtitle is roughly 15 lines of Jinja inline in dashboard config,
   and its bus paragraph is duplicated verbatim in the Travel subtitle,
   including the bug in A4. As template sensors they are reloadable from
   Developer Tools without editing the dashboard, testable in the template
   editor, and defined once. `CLAUDE.md` already documents
   `configs/template/` as the home for these.

2. **Three appliance chips could be one each instead of two.** Washing machine,
   tumble dryer and dishwasher each have two `conditional` chips, one for `On`
   and one for `Finished`, about 25 lines apiece. A single template chip with
   templated `icon_color` and `content` covers both states. Six chips become
   three, and A1 stops being possible.

3. **`severity: [{from: 0, to: 100, color: ...}]`** on every bar-card is a
   constant colour written as a range. Plain `color:` says it directly.

4. **The Batteries subtitle** tests for a low battery with
   `selectattr('state', 'in', ['unavailable','unknown','none'] + (range(0,51) | map('string') | list))`.
   That is string membership, so `'50.0'` does not match. `battery-state-card`
   is already installed and does this natively.

## Part F — Suggested order

Part A first — those are defects, and A1, A2 and A4 change behaviour. A8 is one
line.

Then, in descending value:

1. B1 — the 15 grid copies. Biggest reduction, and it needs the per-card span
   decision made once.
2. B3 plus B5 — move the repeated style bodies into the theme as `uix.class`
   rules, and convert `themes/oneplus/cardmod.yaml`'s four
   `config.card_mod.class` templates to `:host(.x)`.
3. B2 — the scene and action rows. Best demonstration of billets, smallest risk.
4. B4 — the view header.
5. B6 and B7 — the Docker panel and the door-activity template.
6. Part D as you touch each screen.

Part E can happen at any point and is independent of UIX.
