# UIX audit — Ember dashboard

Written 2026-08-18. UIX version 8.0.1 (`custom_components/uix/manifest.json`).

This file records which UIX features replace which existing hacks in this
repository. Each finding names the file and line. Verdicts are **Do**,
**Consider**, or **Skip**.

## 1. Where the setup stands

UIX runs as an integration. It registers its own frontend resource
`/uix/uix.js?v=8.0.1` in `.storage/lovelace_resources`. You do not manage that
URL.

Three loose ends remain from the card-mod removal:

| Item | State | Action |
|---|---|---|
| card-mod resource | Commented out at `configuration.yaml:35` | Done |
| card-mod files | Still on disk at `www/community/lovelace-card-mod/` | Uninstall through HACS |
| Theme keys | `themes/ember/dark.yaml:3` sets `card-mod-theme:`; `themes/ember/cardmod.yaml` uses `card-mod-*-yaml` keys | See finding 1 |
| Dashboard styles | 106 `card_mod:` keys across `dashboards/` | Leave. UIX reads them |

UIX is a drop-in replacement for card-mod up to version 4.2.1. Every existing
`card_mod:` block keeps working. Rename to `uix:` only when you edit a card for
another reason.

## 2. The 14 sparks, scored against this repository

A spark is a behaviour you attach to a forged element through `forge.sparks`.
Every spark takes a `for` key. `for` is a selector path. `$` crosses one
shadow-root boundary. `$$` crosses any number of boundaries.

| Spark | What it does | Verdict here |
|---|---|---|
| `grid` | Applies CSS Grid to a container. Supports `areas`, `elements`, `media_queries` | **Do** — finding 3 |
| `overlay-icon` | Draws an icon over any element | **Do** — finding 4 |
| `search` | Finds elements by CSS selector, then adds classes, attributes, or text | **Do** — finding 5 |
| `background` | Puts a colour, image, video, or live camera behind an element | **Consider** — finding 6 |
| `lock` | Blocks interaction until the user passes a PIN, passphrase, or confirmation | **Consider** — finding 7 |
| `more-info` | Embeds Home Assistant more-info controls inside a card | **Consider** — finding 8 |
| `event` | Receives `fire-dom-event` data as template variables | **Consider** — finding 9 |
| `attribute` | Sets or removes an HTML attribute | Skip. No current need |
| `tooltip` | Attaches a Home Assistant `wa-tooltip` | Skip. This is a touch dashboard |
| `button` | Inserts an `ha-button` next to an element | Skip. button-card already covers this |
| `tile-icon` | Inserts an `ha-tile-icon` next to an element | Skip. The design uses no tile cards |
| `state-badge` | Inserts a `state-badge` next to an element | Skip. The design uses no entity rows |
| `theme` | Applies a named theme to one element | Skip. Finding 1 is the better route |
| `map` | Keeps map zoom and centre across updates | Not applicable. Ember has no map card |

## 3. Findings

### Finding 1 — Six style blocks are copied across eleven view files

**Do this first. It is the largest duplication in the repository.**

Each Ember view file redefines the same card_mod anchors, because YAML anchors
do not cross an `!include` boundary. Counted definitions:

| Anchor | Times defined | Extra `*` references | Distinct variants |
|---|---|---|---|
| `row_group` | 10 | 4 | 1 |
| `section_head` | 9 | 18 | 1 |
| `screen_title` | 6 | 0 | 1 |
| `rail` | 6 | 7 | **2** |
| `back_chip` | 6 | 0 | 1 |
| `media_mod` | 2 | 15 | 1 |

Each definition is also a use, so `row_group` is applied 14 times from 10
separate copies of the same text.

Example: `row_group` is a 12-line block. It appears at
`dashboards/ember/view-home.yaml:205`, `view-lights.yaml:33`,
`view-media.yaml:327`, `view-room-bedroom.yaml:69`, `view-room-ella.yaml:101`,
`view-room-kitchen.yaml:59`, `view-room-lounge.yaml:209`,
`view-room-nursery.yaml:100`, `view-room-office.yaml:114`, and
`view-systems.yaml:101`. All ten copies are byte-identical after whitespace
normalisation. A change to the row group border means ten edits.

The drift has already started. The `rail` block has two variants: the copy at
`dashboards/ember/view-home.yaml:64` uses `gap: 8px`, and the five other copies
use `gap: 10px`. Nothing marks that as deliberate.

UIX fixes this with two features used together:

1. **Theme style variables.** A theme can carry `uix-card`, `uix-card-yaml`,
   `uix-row`, `uix-row-yaml` and so on. The `-yaml` form takes the same
   selector-path map that a card `uix:` block takes.
2. **`uix.class`.** A card can carry `uix: {class: rail}`. The theme then
   selects it with `:host(.rail)`.

So the six blocks move into `themes/ember/` once, and each card carries one
line instead of a twelve-line anchor:

```yaml
# themes/ember/uix.yaml — defined once
ember:
  uix-theme: ember
  uix-card-yaml: |
    .: |
      :host(.row-group) #root {
        background: var(--ember-surface);
        border: 1px solid var(--ember-border);
        border-radius: 22px;
        box-shadow: var(--ember-card-shadow);
        margin: 0 24px;
        padding: 2px 16px;
        gap: 0 !important;
      }
      :host(.row-group) #root > *:not(:last-child) {
        border-bottom: 1px solid var(--ember-divider);
      }
```

```yaml
# any view file — one line replaces the anchor
- type: vertical-stack
  uix:
    class: row-group
  cards: [...]
```

You already use the card-mod version of this idea. `themes/ember/cardmod.yaml:43`
reads `config.card_mod.class` by hand to do class matching. UIX gives the same
behaviour directly through `uix.class` and `:host(.x)`, with no template.

Test the selector form on one card before converting all six. `uix-card-yaml`
injects into the card's shadow root, so `:host` is the card element and `#root`
and `ha-card` are direct children. This should hold, but confirm it once.

Savings: about 46 anchor definitions collapse into 6 theme entries.

### Finding 2 — The live streamline template library is not under version control

`.storage/lovelace.lovelace` and `.storage/lovelace.fire_tablet` instantiate
`custom:streamline-card` 29 times between them. Neither dashboard defines
`streamline_templates`. Reading the card source
(`www/community/streamline-card/streamline-card.js`, function
`loadRemoteTemplates`), the card falls back to fetching
`/hacsfiles/streamline-card/streamline_templates.yaml`.

That file exists. It is 55 KB. It is git-ignored, because `.gitignore:51`
excludes all of `www/community`. It sits in a HACS-managed directory, so a
streamline-card update can remove it. There is no tracked copy.

Foundries fix this. A foundry file lives anywhere in `/config`, so it falls
inside the tracked `*.yaml` allowlist. You register it under **Settings →
Devices & Services → UI eXtension → Configure → Manage foundry files**.

Foundries also resolve on the server, not per dashboard. That removes the
friction in the Phase 6 storage migration: `ember_light_sheet` currently sits
at `dashboards/lovelace-refactor.yaml:32` and only the Refactor dashboard can
see it.

Foundry equivalents for streamline features:

| streamline-card | Foundry |
|---|---|
| `streamline_templates:` in dashboard config | `uix_foundries:` in any registered file |
| `[[variable]]` substitution | `forge.billets`, referenced as `{{ name }}` |
| `variables:` on the instance | `forge.billets:` on the instance |
| No nesting | `foundry:` key gives recursive merge |
| No defaults | Reserved `global` and `global_card` foundries |
| No file directives | `!include` and `!secret` both work |

Billets add string interpolation that streamline has no equivalent for. A
billet value can reference another billet with `{name}`:

```yaml
uix_foundries:
  ember_light_sheet:
    forge:
      mold: card
      billets:
        entity: light.{room}_lamp   # resolves after room
        room: ~
        name: ~
        icon: lightbulb
```

### Finding 3 — The D-pad uses transparent filler cards

`dashboards/ember/view-room-lounge.yaml:300` builds a 3x3 D-pad as a
`type: grid` with `columns: 3`. Four of the nine cells are empty button-cards
with `background: none` and `tap_action: none`, present only to hold position.

The `grid` spark replaces this. `areas` names the regions and `elements`
assigns those names to children in order, so an empty cell needs no card:

```yaml
type: custom:uix-forge
forge:
  mold: card
  sparks:
    - type: grid
      for: "hui-grid-card $ #root"
      columns: 3
      gap: 8
      areas: '". up ." "left ok right" ". down ."'
      elements: [up, left, ok, right, down]
element:
  type: grid
  square: false
  cards: [ ... five real buttons, no fillers ... ]
```

The same spark also replaces flex tuning done through CSS. At
`dashboards/ember/view-systems.yaml:180` a `horizontal-stack` carries
`#root { margin: 0 24px; gap: 10px !important; } #root > * { flex: 1 1 0 !important; }`.
Swap the stack for a `grid` card and that becomes `columns: 2` plus `gap: 10`.
The spark is documented against grid cards and section containers, so keep the
container a grid card rather than pointing it at a stack.

The spark carries `media_queries`, so the desktop rail tuning noted in
`BACKLOG.md` gets a place to live without a second card_mod block.

### Finding 4 — An inline SVG data URI draws the brightness bulb icon

`dashboards/lovelace-refactor.yaml:74` builds the bulb icon on the brightness
slider with `ha-card::before`, a `-webkit-mask`, a `mask`, and the same MDI path
inlined twice as a `data:image/svg+xml` URI. That is 12 lines to draw one icon.

The `overlay-icon` spark does it in five:

```yaml
sparks:
  - type: overlay-icon
    for: ha-card
    icon: mdi:lightbulb
    icon_color: var(--ember-text)
    icon_size: 22
    icon_position: {left: 18px, top: 50%}
```

This also removes the `variables.icon` custom-field workaround added in the
last session for the pill shield, pill bulb, remote chevrons, and the CH plus
and minus buttons. Those exist because `show_icon: false` at template level
suppressed the icon. An overlay icon does not go through button-card's icon
slot at all.

Note the docs record that `right` and `bottom` positioning was fixed in
8.0.0-beta.4. You run 8.0.1, so both work.

### Finding 5 — my-slider-v2 shadow-DOM styling has no stable selector

Memory records my-slider-v2 styling as an iteration risk. The slider styles
are plain maps, not button-card style lists, and its internals sit behind a
shadow root.

Two UIX features address this:

1. **`uix_forge_path()`.** A browser console helper. It returns the exact
   selector path to any element inside a forged element. This removes the
   guesswork that cost time in the previous two sessions.
2. **The `search` spark.** It runs `querySelectorAll` on a container, optionally
   filters matches by a text regex, then adds classes or attributes. It also
   installs a `MutationObserver`, so elements the slider recreates on update
   are handled again without extra config. Tag the element with a class, then
   style that class from the theme (finding 1).

The `$$` express selector helps too. `A $$ B` crosses any number of
shadow-root boundaries, so you no longer write out each hop.

### Finding 6 — Media card artwork could be a real background

Not a hack replacement. A capability the setup does not have.

The `media_mod` style at `dashboards/ember/view-media.yaml:90` and 14 other
places paints a flat surface colour. The `background` spark accepts
`image_entity`, which reads `entity_picture` from any entity and signs the URL
for you. Pointed at a media player, that gives album artwork behind the card
with no template and no manual URL signing.

`opacity` dims it. `dissolve_target` makes the card surface transparent so the
background shows through. When `for` resolves to an `ha-card`, UIX matches the
card's border radius and margin automatically.

`camera_entity` does the same with a live camera stream, which is worth noting
for the Frigate views.

### Finding 7 — The alarm popup has no PIN

The alarm popup built in Phase 2 arms and disarms with no challenge. The `lock`
spark adds one:

```yaml
sparks:
  - type: lock
    locks:
      - code: 1234
        admins: true
    unlocked_action:
      action: element_tap
```

A numeric `code` shows the Home Assistant numpad. A text value shows a password
field. `duration` sets how long before it re-locks, default 3000 ms.
`max_retries` and `max_retries_delay` add lockout after repeated failures.

Keep `admins: true`. Without it admins bypass every lock, and on your own
account the lock will look broken.

### Finding 8 — On/off lamps drop out of the popup design

Dimmable lights get the `ember_light_sheet` popup. On/off lamps fall back to
the stock more-info dialog, which does not match the Ember design.

The `more-info` spark embeds `ha-more-info-info` inside a card. That lets an
on/off lamp open an Ember-styled bubble popup that contains the real Home
Assistant controls, instead of leaving the design. `details: true` adds a
collapsible details section.

This fits the standing preference for design fidelity over a minimal build.

### Finding 9 — `fire-dom-event` can carry UI state without helpers

The `event` spark receives `fire-dom-event` payloads and exposes them as
`uixForge.event.<key>` template variables. Any card with a `tap_action` can
fire one:

```yaml
tap_action:
  action: fire-dom-event
  uix_forge:
    - forge_id: my_card
      data: {selected: living_room}
```

This is a way to hold pure display state — a selected tab, a chosen room —
without creating an `input_select` helper.

Do not apply this to the TRV helpers. `input_number.<room>_trv` has Node-RED
sync behind it, and that sync is the point.

## 4. What to leave alone

**The 34 button-card templates in `www/button_card_templates.yaml`.** Keep
them. Foundries hold element configuration; they do not replace button-card.
The file contains 159 `[[[ ]]]` JavaScript blocks and 34 `custom_fields`
entries. Converting those to Jinja is a rewrite, not a migration. Density by
template:

| Template | Lines | JS blocks |
|---|---|---|
| `ember_climate` | 219 | 5 |
| `ember_trv` | 186 | 13 |
| `ember_mini_media` | 89 | 5 |
| `ember_tile` | 89 | 1 |
| `ember_pill` | 63 | 3 |
| `ember_room_row` | 36 | 9 |
| `ember_appliance` | 51 | 7 |
| `ember_appliance_tile` | 46 | 0 |

`ember_appliance_tile` uses no JavaScript. It is the only clean candidate if
you want to try one conversion and judge the result.

**The 106 `card_mod:` keys.** They work. Rename opportunistically.

## 5. Separate problem worth naming

The button-card template library is delivered by a patched build at
`/local/button-card.js?test3`. That build fetches
`/local/button_card_templates.yaml` by URL, and
`dashboards/lovelace-refactor.yaml:16` carries a manual `?v=11` cache-buster
you bump after every edit.

This exists because button-card templates are dashboard-scoped, the same
problem finding 2 describes for streamline. Foundries resolve server-side and
would remove the fetch, the patched build, and the cache-buster.

The catch is that the thing being distributed is button-card JavaScript, which
foundries do not run. So this is only worth doing as part of a decision to move
off button-card, not on its own. Recording it here so the reason is not lost.

## 6. Suggested order

1. Uninstall card-mod through HACS.
2. Finding 1 — move the six style blocks into the theme with `uix.class`. Test
   the selector on one card first.
3. Finding 2 — move the streamline library into a registered foundry file under
   version control.
4. Finding 4 — replace the SVG mask with `overlay-icon`.
5. Finding 3 — rebuild the D-pad with the `grid` spark.
6. Findings 5 to 9 as you touch the relevant screens.
