# Verification runbook

Use the same saved game, camera position, resolution, and OpenMW settings for every
comparison. Disable MSAA, VSync, and the OpenMW frame limiter while measuring.

## Installation gate

1. Run the installer with `-WhatIf`, then without it.
2. Confirm the source OpenMW directory was not modified.
3. Save `kit-install-manifest.sha256` with the test results.
4. Confirm the ReShade Vulkan layer is scoped to the isolated `openmw.exe`.

## Rendering gate

1. Launch with `Launch-OpenMW-Zink.cmd`.
2. Confirm the OpenGL renderer contains `zink` and the Vulkan GPU is the RTX card.
3. Confirm ReShade reports Vulkan and the expected swapchain resolution.
4. Load a save, select `OpenMW-Depth-Diagnostic.ini`, and confirm near objects are
   dark, distant objects are brighter, and world depth remains stable in motion.
5. Return to `OpenMW-Stable.ini`.
6. Confirm the technique order is VORT, DLSS5 Feed, opaque present.
7. Confirm `dlss5-feed.log` reports feature readiness and delivered frames.
8. Test an exterior, vegetation, an interior with NPCs, water, sky, menus, and UI.
9. Change resolution and window mode in-app, then return to the original settings.

## Regression gate

Reject the build for any of the following:

- desktop transparency or white/grey full-screen flashes;
- incorrect or incomplete depth;
- a frozen 10x10 startup swapchain;
- crash during live resolution changes;
- missing DLSS feature creation or repeated evaluation failures;
- optional MXAO changing alpha or destabilizing the depth selection.

## Benchmark gate

Measure at least three runs of the same scene for:

1. native OpenMW;
2. OpenMW through Zink;
3. Zink plus ReShade with neural rendering disabled;
4. Zink plus ReShade and DLSS 5 Neural Rendering.

Record median FPS, median/p95 frame time, GPU utilization, VRAM, resolution, driver,
OpenMW version, Mesa version, component hashes, and exact preset. Estimate DLSS cost
from paired GPU frame times rather than subtracting FPS.
