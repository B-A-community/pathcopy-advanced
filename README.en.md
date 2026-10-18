# PathCopy Advanced — copy along a path for SketchUp 2024 / 2025

[Русский](README.md) · **English**

A SketchUp plugin that copies groups and components along a path and sweeps a
railing profile along the same path. A replacement for Smustard's PathCopy,
untouched since 2014.

Version 1.0 · [Apache 2.0](LICENSE) licence · © 2026 B&A community

Created by [maksarsanjeev](https://github.com/maksarsanjeev) — see [AUTHORS](AUTHORS).

Two packages, Russian and English. The language is baked into the build;
there is nothing to switch at runtime.

## How to use it

1. Click an edge — that is the path. Connected edges are followed
   automatically, no `Weld` needed. Click a face to use its outline;
   `Ctrl`+click (`Option` on macOS) adds another path.
2. Click the group or component to copy. `Ctrl`+click adds more objects and
   the copies alternate between them.
3. Change anything in the settings panel — the copies rebuild in place and
   the whole session stays **a single undo step**.

## What it does

**The path.** A chain of unwelded edges is walked automatically: from the
clicked edge the plugin follows its neighbours while each vertex has exactly
two edges, and stops at a junction instead of guessing. A face outline, an
arc, a circle, a closed loop — all the same. Several paths in one go.

**Distribution.**

| Mode | What it does |
|---|---|
| Spacing | A fixed distance; the leftover is handled by the alignment — start, centre or end |
| Count | Exactly N copies, evenly spread |
| Fit spacing | The nearest spacing to the one you typed that divides the path evenly |
| Fit per segment | A copy on every vertex, spacing fitted inside each segment — the mode for railings |
| Vertices | One copy per vertex |

Plus offsets from the start and the end. On a closed loop the closing copy
does not duplicate the first one.

**Orientation.** By heading; a full 3D tangent that follows the slope; by the
path plane (a loop drawn on a wall carries its copies in the wall); or no
rotation at all. At a vertex a copy takes the direction of the outgoing
segment — a post at a corner stands square to the rail, not on the bisector;
on gentle bends the tangent is averaged. On a closed loop the copies can face
**outward or inward** regardless of which way the loop was drawn. The
**Along** / **Across** buttons set the object along or perpendicular to the
line.

**Railing.** A profile swept along the same path: rectangular or round, its
own width and height, aligned on the centre of the line or wholly outward or
inward, raised above the path (a handrail over the balusters) and extended
past the ends. Corners are mitred, so a turn is a single piece with no gaps.

**Finishing by hand.** Click a placed copy to turn it by the given angle,
`Shift`+click turns it back. The turn survives any rebuild.

**Randomisation.** Random rotation, scale and offset within the given
bounds, reproducible from the seed.

**The result.** Copies inherit the material, tag, name and shadow settings of
the source; a component keeps its own scale and rotation. Optionally
everything is grouped and given a chosen tag.

## Controls

| Input | Action |
|---|---|
| Click an edge or face | The path. `Ctrl`+click (`Option` on Mac) adds another |
| Click a group/component | The object. `Ctrl`+click adds more |
| Click a placed copy | Turn it; `Shift`+click turns it back |
| `48` | Spacing between copies, in model units |
| `20x` | Exactly 20 copies |
| `0` | The "vertices" mode |
| `Tab` | Cycle the distribution mode |
| `↑` `↓` | Cycle the orientation |
| `←` `→` | Cycle where the leftover goes |
| `Esc` | One step back; removes the placed copies first |
| Right-click | The same options as the panel |

The tool deliberately binds no letter keys: in SketchUp a bare letter always
goes to the user's own shortcut (`R` is the Rectangle tool), never to the
tool.

A preview is drawn before the click: the highlighted path, markers at the
placement points, bounding boxes of the copies and the railing wireframe.
Settings are remembered between sessions.

## Installation

Take the package for your language — `pathcopy-advanced-1.0.0-eng.rbz` or
`-rus.rbz` — and install it: SketchUp → **Extensions → Extension Manager →
Install Extension**. The tool and the panel button appear under
**Extensions → PathCopy Advanced**, the toolbar under **View → Toolbars →
PathCopy Advanced**. Restart SketchUp afterwards — Ruby files are cached.

The build is unsigned, so under **Extension Manager → Settings** the loading
policy must be "Unrestricted" or "Approve unidentified extensions".

For development `.\dev_install.ps1` copies `src\` straight into the SketchUp
2024 Plugins folder; for another version use `.\dev_install.ps1 -Version 2025`.

## Layout

```
src/
  pathcopy_advanced.rb             extension registrar
  pathcopy_advanced/
    main.rb                        wiring, menu, toolbar
    lang.rb                        Ruby-side strings: ru + en
    constants.rb                   version, tolerances, limits, mode lists
    path.rb                        polyline with an arc-length parameterisation
    path_builder.rb                entities → ordered chains
    distribution.rb                where the copies go, in length coordinates
    placement.rb                   lengths → world transformations
    railing.rb                     railing: profile, mitre, skin
    copier.rb                      entity creation, undo
    settings.rb                    options and their persistence
    panel.rb                       settings panel (HtmlDialog)
    about.rb                       the About window
    menus.rb                       context menu and dialogs
    tool.rb                        the tool: preview, measurement box, keys
    html/                          panel.html, about.html, i18n.js (ru + en), ba.css, ba.js
    icons/                         *.svg (Windows) + *.png (fallback), cursor
    instructor/ru, instructor/en   the Instructor panel in both languages
tests/                             offline tests and live scenarios
tools/                             package build and icon generation
(packages are built locally into dist/ and are not committed)
```

The namespace is `BACommunity::PathCopyAdvanced`.

## Building

```bash
powershell -ExecutionPolicy Bypass -File "tools\build_rbz.ps1"
```

Builds both packages into `dist/`. For one language use `-Lang ru` or
`-Lang en`. A language package is the same source: in a copy the `LANG` line
is swapped in `lang.rb` (Ruby) and `html/i18n.js` (the windows). The version
is read from `constants.rb`.

Icons are regenerated separately, only when the shapes change:

```bash
powershell -ExecutionPolicy Bypass -File "tools\build_icons.ps1"
```

## Testing

Two levels. The geometry core does not depend on a live model, so it runs
under plain Ruby 3.2 against an API stub:

```bash
ruby tests/run_tests.rb
```

What the stub cannot vouch for — transformation composition order,
`Group#copy`, nested undo operations, picking, menus, the panel — is checked
by the `tests/live_*.rb` scripts inside a running SketchUp. Each writes its
report to `build/*_result.txt`, because `load` through the Ruby console or a
bridge returns `true`, not the script's value.

| Script | What it checks |
|---|---|
| `live_test.rb` | Paths, distribution, orientation, anchor, single undo, tool start-up |
| `live_recheck.rb` | Scale, bounds anchoring, material and tag inheritance, grouping, alternation |
| `live_interact.rb` | Measurement box, `12x`, arrows, `Tab`, `Esc`, undo |
| `live_pick.rb` | Real picking via `view.screen_coords` → `onLButtonDown`, `Ctrl`+click |
| `live_misc.rb` | Context menu, settings persistence, icon resolution |
| `live_facing.rb` | Outward/inward on two circles, a hand-drawn clockwise loop, render |
| `live_fence.rb` | A rectangle with a stray line at a corner: a post on every corner, all square to a rail; a second path by `Ctrl`+click |
| `live_railing.rb` | Railing: solid, mitre at corners, alignment, extension, closed loop; turning a copy by click |
| `live_scene.rb` | Builds a demo scene and renders it into `build/` |

Version 1.0 was run against **both** language packages: 118 offline tests and
157 live checks on each, SketchUp 2024 (24.0.484).

## Where this came from

The original is Rick Wilson's PathCopy 2.200 (Smustard, 2014): a single
461-line class, a path of only one edge or one `Curve`, components losing
their scale, undo through `Sketchup.undo`, and a spacing of 0.001 freezing
SketchUp solid. The point-by-point review is in [AUDIT.md](AUDIT.md) (in
Russian). The original is under the Smustard EULA ("All Rights Reserved"), so
this is written from scratch and the original is not part of the repository.

## Gotchas

- An `.rbz` is a plain ZIP; `pathcopy_advanced.rb` must sit **at the root** of
  the archive and the paths inside must use forward slashes (see the comment
  in `build_rbz.ps1`).
- SVG icons are understood only by the Windows build of SketchUp (2016+);
  macOS needs PDF, so there the code falls back to PNG.
- SketchUp keeps uniform scale in the matrix w term: `xaxis.length` on a
  scaled instance always reads 1 — use `xscale`.
- The measurement box reads the value in model units: `200` in a millimetre
  model is 200 mm, not 200 inches.

## Licence

Apache License 2.0 — see [LICENSE](LICENSE).
