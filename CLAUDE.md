# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`gustavo.notchbar` ("Notch Island") is an Omarchy shell plugin: a Quickshell / Qt Quick (QML) replacement for the stock `omarchy.bar`. This checkout is a personal fork (`origin` = hhrsnm/gustavo.notchbar, `upstream` = GuustTaillieu/gustavo.notchbar) with customizations on top of upstream; merge upstream with `git fetch upstream && git merge upstream/main`, never GitHub's "Sync fork → discard".

There is no build, lint or test suite. QML is loaded live by the single Omarchy shell process (`quickshell -n -p /usr/share/omarchy/shell`).

## Dev loop

```bash
omarchy restart shell        # required after editing Bar.qml / window-level code; plugin hot reload does not rebuild windows
omarchy plugin validate .    # manifest check
journalctl --user --since "-10s" | grep omarchy-shell | grep -i gustavo   # QML errors/warnings
hyprctl layers | grep omarchy-bar   # omarchy-bar (side islands) and omarchy-bar-center (center notch) must both exist
grim -g "560,0 800x60" out.png      # screenshot the bar to verify visuals
```

- If the shell fails to come back after a restart, the environment's `HYPRLAND_INSTANCE_SIGNATURE` is likely stale (Hyprland restarted). Refresh it first:
  `export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr/ | head -1)`.
- Scripted pointer moves: `hyprctl dispatch 'hl.dsp.cursor.move({x=960,y=25})'` (Hyprland uses Lua dispatch syntax). Synthetic moves don't always deliver hover events, so hover behaviour still needs a real-mouse check.
- Open the notch states from the CLI: `omarchy-menu toggle` (menu), `omarchy-menu toggle theme`, `omarchy-menu toggle background`.
- Known harmless warnings on every load: `Bar.qml[...]: Unable to assign [undefined] to QObject*` (4.0.4 sandbox proxy has no `popupModel`) and `CenterIsland.qml[22:3]` (`isFullscreenActive` is not provided; the fullscreen auto-slide from the README is not implemented).

## Architecture

- **`Bar.qml`** — plugin root. Owns bar state (island positions/attach sides, `islandHeight`, `islandGap`, hover/reveal state, active popout), reads the `bar` subtree of `~/.config/omarchy/shell.json` (layout left/center/right, `centerAnchor`), and defines inline components:
  - `BarPanel` — full-width layer window holding the left and right islands (`leftNotch`/`rightNotch`), with an input `mask` limited to the islands. Its `exclusiveZone` reserves space for windows.
  - `CenterPanel` — separate layer window for the center island. Its height is fixed at 100px while idle and only becomes full-screen while expanded (plus a ~590ms hold timer during collapse). **Never bind this window's height to the animating island** — resizing a layer surface every frame causes stutter.
  - `ModuleSlot` / `ModuleList` / `CenterModules` — load widget components from the registry for each layout entry. The center row is split around the anchor widget (`omarchy.clock`): entries before/after it are only shown while `centerSectionRevealHeld` (hover reveal).
- **`CenterIsland.qml`** — the dynamic island. `currentMode` (`clock`, `menu`, `picker`, `history`, OSD modes `volume`/`brightness`/`media-action`, `notification`, `media`, `date-clock`) drives `targetContentWidth/Height`. Width and height animate together through one progress value `sizeT` (`retargetSize()`), so the notch resizes diagonally; open and close are both 200ms. Each mode is a sibling view inside `contentArea` that fades on `currentMode`. The island also contains the menu (driven by `MenuModel.js` over Omarchy's `omarchy-menu.jsonc`), scroll handling (`handleWheel`) and OSD handling.
- **`NotchSurface.qml`** — the island shape, drawn with a QML `Shape` (`CurveRenderer`). It is currently a floating rounded rectangle; the width keeps the old fillet-wing space as transparent padding, so layout code still assumes `contentWidth + radius(*2)`.
- **`NotchPicker.qml`** — the horizontal theme/background picker shown in `picker` mode. `openPickerFor()` in CenterIsland intercepts the `style.theme` / `style.background` menu routes. Moving the selection applies it live (debounced) via `omarchy-theme-set` / `omarchy-theme-bg-set`; closing without confirming reverts.
- **`companion/`** — separate plugins users copy into `~/.config/omarchy/plugins/` and enable. `gustavo.menu` declares `omarchy.clonedFrom: "omarchy.menu"`, so Omarchy's `resolveEnabledId` routes **every** `omarchy.menu` call to it — including the `omarchy.menu` bar widget, which is why it ships its own `BarWidget.qml`. `gustavo.notifications` does the same for notifications.
- **`widgets/`** — notchbar-specific bar widgets, each with a `.manifest.json`. Stock widgets (clock, audio, network…) come from `/usr/share/omarchy/shell/plugins/` and can't be edited; customize them from `ModuleSlot` (see `boldLabels` for the clock).

## Gotchas

- Omarchy 4.0.4 sandboxes third-party plugins: `firstPartyServiceFor` returns a narrow proxy, so not every host API the upstream code expects exists.
- Invisible items report zero `implicitWidth` (a hidden Row ignores its children). That's why `idleModulesWidth` caches the center widgets' width only while `clockView` is visible, and why side islands hide with `opacity` rather than `visible`.
- Hover reveal: `CenterIsland.syncIdleHover()` only counts hover in `clock` mode (and checks the last pointer position against the idle notch), leaves state alone during OSDs, and `Bar.qml`'s `centerSectionRevealTimer` keeps the reveal while a center popout is open.
- `WidgetButton` swallows wheel events; the clock's `wheelMoved` is forwarded to `CenterIsland.handleWheel` so scroll-for-volume works over it.
- Keep the 100px center window large enough: `islandHeight`/`clockContentHeight` + `islandGap` must stay below about 90px.
