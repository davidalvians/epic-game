# Persistent zoom investigation — 22 October 2026

## Scope and failure

The earlier October 20 benchmark returned to the original zoom after a short
gesture. It did not validate holding a dense drawing at 4x–20x. The user reported
stuttering at high zoom and strokes flashing during repeated zoom gestures.

The old whole-paper image exceeded its side/byte limits at high zoom and fell
back to replaying the vector history. Zoom invalidation could also replace a
complete preview with an unfinished prefix. Both paths were reproduced and
covered by regression tests.

## Implementation

- Retain complete layer coverage until the entire replacement is ready. Reject
  obsolete asynchronous results after zoom, source edits, clear, or disposal.
- Keep an overview and render the viewport plus overscan at the device density
  multiplied by zoom. Do not allocate a high-density image of invisible paper.
- Prepare large detail images with persistent 384-pixel cores below 5x, where
  wide blur gutters would multiply work across small tiles, and 512-pixel cores
  at higher zoom. Each native job updates a small tile prefix; compose complete
  tiles only at the end. Keep a penultimate full image for immediate undo. This
  avoids repeatedly copying the full viewport after every few strokes.
- Expand native filter input into real tile gutters; copy disjoint cores
  at integer physical coordinates. Frozen-reference pixel tests cover blur,
  transparency, overlapping pressure outlines, erasing, and tile seams.
- Await each native image job, leave three display intervals between background
  jobs, and suspend preparation while transform pointers remain down. A
  one-pixel readback every two jobs bounds submitted GPU work without
  synchronizing every tile. A job contains at most one native blur, 16 other
  draws, or 2 ms of CPU preparation.
  Culled strokes advance the source cursor without creating unchanged textures.
- Clip exact quadratic curves and pressure outlines before rasterization.
  A conservative geometric coverage proof can replace a fully covered brush
  mask with a small fully covered primitive using the original native mask
  operation. Source points are never simplified. Native Impeller composes
  translucent solid masks differently from Skia: an ImageFilter replacement
  passed host tests but failed device pixel comparisons and was removed.
- A conservative nonzero-winding proof can omit raster work preceding a full
  clear/opaque overwrite, including proven unions of clears. This never deletes
  source history; undo and export retain the original editable vectors.
- Combine completed stamp-free layers into one preview texture when possible.
  Live SrcOver strokes on the top visible layer use a separate repaint boundary
  so static pixels are retained while the stroke changes. Multiply and clear
  retain layer isolation. Stamped drawings retain their original widget order.
- Clip smooth paths to the visible raster viewport even when the zoom policy
  has disabled blur. Keep a half-stroke-width margin so visible edges and caps
  remain unchanged; the full vector path remains the source for export.
- Preserve the original brush opacity, blending, pressure algorithm, shapes,
  zoom-dependent blur policy, draft JSON, and 2x full-paper capture. Stamps are
  unchanged. Export waits for a complete full-paper cache independently of zoom.
- Keep the 32 MiB/image, 4096-pixel side and 160 MiB cache allocation bounds.
  Retire temporary and published images after a displayed frame so extended
  offscreen work continues to advance native GPU resource cleanup.

## Verification

`flutter test --no-pub test/drawing_render_cache_test.dart`: **43 tests passed**.
`flutter test --no-pub test/drawing_input_test.dart`: **8 tests passed**. Tests
cover source/zoom cancellation, atomic coverage, new gestures interrupting tile
preparation, undo/redo, clear, layer isolation/deletion, legacy drafts,
pending-stroke capture, high-zoom export, and frozen-reference pixel comparisons
through 20x. Pixel tolerances were not relaxed: mean channel error below 0.5 and
fraction of differences above 8 below 0.005.

`flutter analyze --no-pub`: no errors; 26 existing warnings/information messages
remain in unrelated or previously existing code.

Device performance testing uses an isolated package
`com.epic.epic_app.drawing_benchmark`; it never initializes Firebase or reads,
writes, or removes the user's drafts. Normal builds do not use this package ID.
The harness has multi-layer parity fixtures and a separate dense one-layer
performance fixture. The measured performance fixture contains 1,000 strokes,
512-point long strokes, and 40-unit thick strokes, to isolate live-rendering
cost without making cache setup dominate each interaction sample.

The October 23 device is a Redmi 2201116TG, Android 13, approximately 8 GB RAM,
1080x2400 screen at density 2.75 and reported 120 Hz. The isolated single-layer
profile used 1,000 strokes; results are in `drawing-zoom-results.json`. Animated
measurement phases last two seconds and drain their timing callbacks. Cache
readiness is checked separately. A readback probe rejects empty/off-paper
benchmark fixtures.

Device results are recorded in `drawing-zoom-results.json`. In the latest 4x
profile, thick live watercolor recorded 0/224 raster frames over 16.67 ms
(P95 10.161 ms), down from 54/83 frames (P95 59.738 ms) in the earlier wider
preview. Thick ballpoint recorded 0/201 frames over 16.67 ms (P95 12.848 ms).
The latest pan sample had 8/176 frames above 16.67 ms; a repeated real-pointer
pinch had 8/178. This is a substantial improvement, but does not prove flawless
120 Hz delivery under every interaction. These profile-mode samples were taken
on the 8 GB Redmi, not a 4 GB phone, and can vary with device state.

The isolated device harness first compares original versus cached pixels on the
actual Vulkan/Impeller backend at 1x, 4x, 20x and 0.5x. It separately compares
live strokes of all four brushes at 4x and 20x over three translucent layers.
The same mean/outlier thresholds apply; a failure aborts performance testing.

## Practical limits

These measurements do not establish smoothness in every condition or on a
4 GB phone. The latest thick-watercolor sample had no raster frames over
16.67 ms, but 83/224 exceeded the 8.33 ms budget required to sustain 120 Hz.
Pan and repeated pinch each still had 8 frames above 16.67 ms. The preview is
simplified only while the qualifying thick stroke is actively drawn: ballpoint
uses a smooth centerline at 80% of base thickness; watercolor uses a smooth
centerline at 75% of base thickness, SrcOver, and no blur. Release and export
still use the original full-fidelity vector renderer, blending, and blur. The
live watercolor preview is therefore narrower than the committed stroke. The
latest measurements are promising for roughly 60 Hz, but do not prove the
all-conditions 120 Hz target. Cache detail preparation took about 92.6 seconds
at 4x for the dense fixture. No 4 GB device was available
for measurement.

Initial bulk restores and high-density detail preparation still take time for
this deliberately extreme fixture. A complete preview stays visible during
replacement, and a new gesture pauses further work. Cache allocation accounting
does not bound all Dart/native/GPU memory; sampled RSS is not peak memory.
Two-second timing samples do not cover every background job, touch-to-photon
latency, extended thermal throttling, or the full manual feature checklist.

Do not use an empty/negative-paper fixture, the October 20 lower-zoom benchmark,
or an incomplete cache run as proof that this regression is solved.
