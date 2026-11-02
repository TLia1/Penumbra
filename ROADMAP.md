# Penumbra roadmap

Ideas for what could come next, roughly by value for effort within each group. The features that
REVIEW.md suggested are in; what is here is what they left out, their known limits, and housekeeping.

## Shell

- **Stop the lock screen's scenes while the screens are off.** hypridle turns them off after a
  minute, but dawn and eclipse keep drawing behind them. Hyprland reports DPMS per monitor.
- **Steadier wallpaper motion.** Scenes step on a 33 ms timer, not on the display's frames. A
  `FrameAnimation` would be smoother, but it keeps Qt's render loop running at the display's rate,
  so measure the cost first.
- **Record every screen at once.** wf-recorder records one output, so the screenshot overlay's
  All screens mode is for pictures only. Recording each output and joining them side by side with
  ffmpeg would do it.
- **Pin images** in the clipboard history, not only text.
- **Notification rules by content** (a word in the title or body), beside the per-app ones.
- **Choose the web search engine** for the launcher's `?`, instead of DuckDuckGo.

## Calendar

- **Reminders**: a notification before an event starts.
- **Fuller repeat rules**: BYMONTHDAY, BYSETPOS ("last Friday of the month") and changed single
  occurrences (RECURRENCE-ID) are skipped today.
- **Adding events** from the panel, written back as `.ics` for vdirsyncer to upload.

## Project

- **CONFIGURATION.md** is generated, about 880 KB, and changes with every commit. Generate it for
  releases only, or stop tracking it.
- **validation/** holds logs from the first build (Waybar's among them) that no longer describe
  the project. Regenerate or remove them.
- **previews/** screenshots still show the old name, Nocturne. Take new ones.
- **Test the shell's QML** with `qmltestrunner` (Settings search, notification rules, the launcher's
  result kinds), beside the JavaScript tests under Node.
