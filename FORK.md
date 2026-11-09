# Fork notes — 1.4.0

This started as Arjun010011's `omarchy-dynamic-island` (MIT, marketplace
1.0.0). The plugin was rewritten locally for this machine's bar setup and
refreshed through 1.4.0; the fork keeps the original id so installs,
settings and the island IPC (`omarchy-shell dynamic-island …`) keep working.

## What this fork changes (vs upstream 1.0.0)

- **Melted into the bar**: compact pills take the bar's own height
  (`mergeIntoBar`), the strip overlaps the bar (`exclusiveZone -1`), and the
  body paints one flat surface so it reads as the bar's middle tab. `xShift`
  nudges everything sideways.
- **Split resting face** (`idleFace: "split"`): time · weather · battery at
  once instead of a flip cycle; the ticker cycle can still be had with
  `"ticker"`.
- **Weather everywhere**: ticker glances (current + today's range), a wide
  card on the drop-down (temp, condition word, H/L, wind, humidity, next
  rain window / sun times, marker glyph breathing on the card and in the
  pane), a full pane with a Back button, 12-hour rain bars, two-day
  forecast, and its own location file shared with the shell panel.
- **Agent lane**: the `agents/usage/*.json` records (what `opencode-go`'s
  collectors maintain) drive a LEFT-side bubble — a rate-limit ring with the
  bot glyph, accent→orange→red as the meter fills. Tap flashes a card
  (`5h · wk · mo · today`). Never takes over the pill. `opencodeProvider`
  picks the collector id.
- **Quick-settings chips** in the drop-down (replacing timer chips): DND
  (island's own daemon), night light, walk installed themes, lock screen.
- **Media**: the drop-down's now-playing row carries prev/play/next; the
  player pane and weather pane have Back buttons; pill taps with music
  playing open the player directly; the IDLE drop-down stays reachable.
  The pill clock rides inside media views.
- **Stats glance** (ticker): CPU/GPU temps + busiest GPU busy%, sysfs read,
  `stats` toggle.
- **Gestures**: left click expands (opens the player when music plays),
  middle click play/pause, right click dismisses banner/HUD/island,
  scroll volume. Bell bubble (right) counts pending notifications; agent
  bubble (left) walks the provider's limits.
- **Resources**: HUD cards size themselves to their text; BubbleContent got
  a count badge; `state` IPC reports geometry, weather, ticker and the
  agent record, so debugging never needs pixel archaeology.

## Updating

Upstream is dormant (Arjun010011 hasn't touched it since install), so
updates are local: edit files here, two restarts, done. If upstream ever
wakes, the safe path is:

```bash
cd ~/.config/omarchy/plugins/omarchy-dynamic-island
git stash || git checkout -b local-1.4          # your work, kept
git pull                                        # upstream
git rebase upstream/main                        # or merge; conflicts wanted
omarchy restart shell
```

The fork's changes are one commit on top of upstream history, so a rebase
replays them; expect melted-geometry and quickset conflicts.
