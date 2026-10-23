# Drawing performance work

## Status

Implementation in `codex/drawing-performance`. Device performance and visual
equivalence must be measured before treating this as a verified release.

The October 20 results below do not cover the persistent high-zoom regression
reported afterwards. See `drawing-zoom-fix.md` for the October 22 investigation,
viewport cache changes, and new measurements. The October 20 whole-paper cache
policy below is historical; the current renderer retains a complete preview
and prepares a cropped, full-density viewport in bounded native jobs.

The original renderer was exercised on a Samsung SM-A366B, Android 16/API 36,
with about 8 GB physical RAM. Android killed its process with `LOW_MEMORY`
during preparation of the deterministic 1,000-stroke extreme-overlap fixture,
before frame samples could be collected. This is a failure of that particular
stress case, not a claim that every drawing with 1,000 strokes crashes.
Do not interpret source changes or desktop tests as a 60 fps or 4 GB guarantee.

## Changes

| File | Change |
| --- | --- |
| `models/drawing_models.dart` | Move existing enums/models to a shared library; preserve draft keys/defaults; retain incremental smoothing segments. Controller re-exports the models for existing callers. |
| `widgets/stroke_renderer.dart` | Extract the existing brush renderer. Preserve pressure, blending, opacity, shapes, dots, and the high-zoom blur guard. Reuse completed quadratic smoothing segments for pencil/watercolor. |
| `drawing_render_cache.dart` | Flatten at most 16 strokes per native raster job. Keep a bounded live/pending tail and a previous-prefix undo checkpoint; reject stale asynchronous results on clear, resize, deletion and disposal. Bulk restores progressively prepare their images instead of replaying thousands of blur operations in a frame. |
| `widgets/drawing_canvas.dart` | Separate transform rebuilding from paper content. Each layer has a repaint boundary; live pointer updates repaint the active layer rather than rebuilding the paper/stamp tree. |
| `widgets/drawing_painter.dart` | Draw the cache plus uncached tail and live stroke; compare painter state rather than always repainting. Retain layer isolation for clear/multiply and the eraser preview. |
| `widgets/layer_thumbnail.dart` | Cache the original thumbnail renderer, including stamps, at thumbnail pixel density. Keep original coordinates, visibility and vector fallback. |
| `drawing_screen.dart` | Connect the shared renderer and thumbnail widget. |
| `drawing_controller.dart` | Append live points in place; keep distance filtering unchanged; dispose cache workers/images; serialize draft encoding off the UI isolate and keep saves ordered; release temporary capture/pipette images. |
| `debug/drawing_stress_fixture.dart`, `tool/drawing_profile.dart` | Deterministic 1,000/3,000/5,000-stroke scenarios using the actual canvas and layer panel, with no Firebase session or persisted drafts. |
| `android/gradle.properties` | Remove an obsolete machine-specific Java path that prevented builds after the laptop reinstall. No runtime behavior change. |

The stamp widget, stamp painter and stamp model are unchanged. No dependency is
added or updated. JSON keys, legacy decoding and image capture resolution remain
the same. Capture prepares full-resolution caches in bounded batches before
capturing the paper at the existing 2x output density.

## Cache policy and limitations

- Original strokes remain authoritative and are never replaced by bitmap data.
- Allocate at the device pixel density multiplied by zoom (at least 1x zoom).
- Limit an individual image to 4096 pixels per side and 32 MiB of raw RGBA.
- Limit resident/retired cached RGBA images, undo checkpoints and a requested
  new image to 160 MiB. These are upper limits, not eager allocations.
  This is a cache allocation policy, not a limit on total process/GPU memory.
- High zoom prepares the visible region plus overscan at the requested density.
  Completed previews stay visible until the replacement is complete. Large
  detail jobs use spatial tiles with blur gutters, then copy their disjoint
  cores into a committed image. Dense history never falls back to replaying all
  vectors on every displayed frame when an allocation fails.
- During an active pinch, reuse the last image as a transient preview. Rebuild
  at the final density and original zoom-dependent blur after the gesture.
  Panning at a constant scale reuses layer contents.
- Undo reuses the previous baked prefix when available and replays its bounded
  tail immediately. If that checkpoint cannot cover the edit, rebuild in
  batches. Zoom replacements publish atomically; source strokes are retained
  throughout. An initial bulk restore still needs preparation time.
- Pressure-sensitive active strokes still call the original `perfect_freehand`
  algorithm. Its cost for extremely long strokes still needs device measurement.
- Raster/vector equivalence is subject to intermediate alpha rounding and image
  sampling. Pixel tests and manual Android checks are mandatory.
- Completed-stroke JSON snapshots use weak keys; background JSON encoding still
  incurs snapshot/isolate transfer work. First autosave and draft load require
  measurement with long strokes, not just a large stroke count.

## Automated verification

Run from `epic_app`:

```powershell
flutter analyze
flutter test test/drawing_input_test.dart test/drawing_render_cache_test.dart
flutter test
flutter build apk --debug
flutter build apk --release
```

Current validation: all 32 tests pass. Analyzer diagnostics match the original
baseline exactly (26 existing diagnostics, no additions). The dependency
lockfile is unchanged. Both renderer variants build successfully in profile
mode using the same Flutter/native dependencies.

The new tests cover a frozen pre-change brush renderer, incremental smoothing,
cached/pending/live composition, eraser and multiply, multiple layers, undo/redo,
clear/deletion while recording, append during baking, vector capture fallback,
extreme zoom, draft schema/defaults, input thresholds and pause/time-up guards.
Mixed-stroke fixtures include 1,000, 3,000 and 5,000 strokes across three layers.
These tests validate correctness and completeness, not physical-device FPS.

## Physical-device verification

Use the same physical Android phone with 4 GB RAM and the same profile build
configuration for the old and new renderer. Record device/SoC, Android version,
display refresh rate, canvas size, layer count, tool mix and stroke point count.
Test both many short strokes and long/thick strokes covering the paper, including
overlapping watercolor, erasing, stamps and long sessions.

| Stroke count | Before build/raster p95 | After build/raster p95 | Before/after undo | Before/after peak memory |
| --- | --- | --- | --- | --- |
| 1,000 | LOW_MEMORY before measurement | See final table below | Baseline unavailable / final below | Peak unavailable |
| 3,000 | Not attempted after baseline failure | See final table below | Final below | Peak unavailable |
| 5,000 | Not attempted after baseline failure | See final table below | Final below | Peak unavailable |

Repeat the original prompt's full regression checklist: every tool, stamp hit
testing/transforms/z-order, layer operations, undo/redo/clear, pan/zoom/rotate,
old/new drafts, capture/result, timer/template/symmetry, lifecycle, and transitions
between live, pending and cached strokes. None of these manual checks is marked
passed until tested on a device.

### Preliminary native run

The bounded-raster implementation completed all three extreme fixtures on the
8 GB SM-A366B without a process death. Its report samples process RSS at phase
boundaries, not a peak allocation, and does not include all GPU memory.
Observed RSS during drawing was about 264–312 MiB; the managed main-canvas image
cache was about 32.1 MiB. Opening the layer panel still produced slow frames.

Most preliminary phases reported `rasterDrained: false`: the final animation
frame can have an unchanged scene and therefore produce no raster timing. A
dirty-label raster probe was added for the final run. The preliminary samples
are diagnostic evidence only; do not use them as a complete before/after FPS
comparison. The pre-change run died before producing valid FPS measurements.

## References

- [Flutter SDK archive](https://docs.flutter.dev/install/archive)
- [Flutter manual installation](https://docs.flutter.dev/install/manual)
- [Flutter PictureRecorder API](https://api.flutter.dev/flutter/dart-ui/PictureRecorder-class.html)

## Final native results (2026-10-20)

All measured phases drained their raster timing callbacks and reported complete main-canvas caches. The count is the initial fixture count; drawing adds two strokes before the undo phase. Each animated phase lasts two seconds.

| Initial strokes | Phase | Build p95 ms | Raster p95 ms | Frames over 16.7 ms / sampled | Max raster ms |
| --- | --- | --- | --- | --- | --- |
| 1,000 | draw-ballpoint | 3.363 | 3.565 | 0 / 122 | 6.659 |
| 1,000 | draw-watercolor | 2.317 | 6.331 | 0 / 122 | 8.375 |
| 1,000 | pan-rotate | 2.681 | 2.547 | 0 / 122 | 3.890 |
| 1,000 | zoom | 3.329 | 2.566 | 0 / 122 | 5.654 |
| 1,000 | layer-panel | 1.124 | 8.473 | 1 / 109 | 41.409 |
| 3,000 | draw-ballpoint | 3.266 | 3.307 | 0 / 122 | 4.514 |
| 3,000 | draw-watercolor | 2.241 | 6.582 | 0 / 122 | 9.000 |
| 3,000 | pan-rotate | 2.717 | 2.449 | 0 / 122 | 2.979 |
| 3,000 | zoom | 3.250 | 2.458 | 0 / 122 | 3.239 |
| 3,000 | layer-panel | 0.564 | 6.944 | 2 / 96 | 20.643 |
| 5,000 | draw-ballpoint | 3.061 | 3.241 | 0 / 122 | 4.056 |
| 5,000 | draw-watercolor | 1.916 | 6.567 | 0 / 122 | 8.410 |
| 5,000 | pan-rotate | 3.085 | 2.482 | 0 / 122 | 3.056 |
| 5,000 | zoom | 3.542 | 2.512 | 0 / 122 | 6.671 |
| 5,000 | layer-panel | 0.554 | 3.413 | 0 / 88 | 4.626 |

| Initial strokes | Undo UI-frame wait ms | Cache-ready wait ms |
| --- | --- | --- |
| 1,000 | 9.968 | 9.979 |
| 3,000 | 7.902 | 7.920 |
| 5,000 | 10.920 | 10.932 |

RSS sampled across these phases ranged from 258.9 to 304.5 MiB. Main-canvas cache during drawing was approximately 32.1 MiB. These are not peak or total GPU-memory measurements.

No measured drawing/pan/zoom phase exceeded 16.7 ms in either build or raster work. Layer-panel opening still had isolated slow frames in the 1,000- and 3,000-stroke cases. `totalSpan` can be longer than build/raster time because it includes scheduling/queue delay; do not equate these results with a latency guarantee.

The October 20 harness drove the real controller/canvas with synthetic updates.
It did not measure touch-to-photon latency, persistent high zoom, thermal
throttling, long-session stability, or a 4 GB phone. Its whole-paper cache could
fall back to expensive vector rendering. That policy has since been replaced;
see `drawing-zoom-fix.md` for the October 22 investigation and current limits.

Machine-readable sanitized results: `drawing-benchmark-results.json`. Raw local logs: `D:\development\downloads\drawing-final-profile.log`. Normal release build succeeded (arm64, `lib/main.dart`); no dependency changes were needed.

The normal debug build also succeeded. The release app replaced the temporary
benchmark on the phone and passed the checked startup log (no fatal Android or
Flutter error). This startup check does not replace the full manual checklist.
