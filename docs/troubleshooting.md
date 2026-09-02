# Troubleshooting

## Fixes installed by default

The installer adds the opaque final-present pass, reversed-depth configuration, stable
effect order, minimal shader loading, and the tested OpenMW stability settings. It also
checks the feeder binary against the known resize-safe SHA256. Use
`-SkipStableSettings` or `-AllowUnvalidatedFeeder` only when deliberately testing a
different configuration.

## The window freezes during startup

Confirm `SkipLoadingDisabledEffects=1` in the active ReShade configuration and use
`OpenMW-Stable.ini`. The kit includes only MXAO, but loading every discovered shader
can still delay or stall the temporary 10x10 Zink swapchain.

Do not start a second OpenMW instance. The generated launchers exit with code 2 if
`openmw.exe` is already running.

## Desktop or other windows show through the game

Confirm `OpenMW_OpaquePresent` is enabled and is the last technique. The pass forces
the final alpha channel to 1.0 without changing RGB.

## Depth visualization is black

The verified Zink path uses reversed depth:

```text
RESHADE_DEPTH_INPUT_IS_REVERSED=1
```

It also copies depth before clear index 1. Confirm the active configuration filename
contains the `[DEPTH]` section from `config/ReShade-kit.ini`. ReShade may use a
numbered file such as `ReShade3.ini` if multiple Vulkan registrations exist.

## MXAO outlines characters or misses floor contact

First validate depth. Do not compensate for a wrong buffer by increasing AO strength.
The included preset uses a wider radius and lower normal bias to favor floor/wall and
object/floor intersections. MXAO is optional and may still be undesirable in some
scenes.

## DLSS 5 waits for Neural Rendering to start

Check that all three files are beside `openmw.exe`:

```text
renodx-dlss5.addon64
nvngx_dlss.dll
nvngx_dlssnr.dll
```

The feeder log must show its synthetic DLAA feature becoming ready. Update the NVIDIA
driver if feature 18 creation repeatedly fails. Do not combine the feeder with
OptiScaler or NVIDIA Smooth Motion.

## Resolution changes crash

Build DLSS5-Feeder with `patches/dlss5-feeder-vulkan-resize-idle.patch`, or use an
upstream release that incorporates an equivalent Vulkan-device idle wait before
destroying imported images. Preserve the previous working binary before replacing it.

Unknown feeder binaries are rejected by default because the installer cannot repair a
compiled add-on. The override switch acknowledges the risk; it does not fix the binary.

## Settings change but later revert

Exit OpenMW normally after changing settings. Both installed launchers use the normal
OpenMW user profile, but a crash or forced termination may occur before OpenMW writes
`settings.cfg`.

## Balmora is black or objects constantly pop

Use the default stability settings: MSAA and VSync off, a moderate view distance, and
object paging enabled. Dense city overhauls, full groundcover, large shadows, and very
long view distance can create severe paging and GPU-memory pressure.

## The main menu is dark

Do not use the depth-diagnostic preset at startup. Select `OpenMW-Stable.ini`, load a
save, and only then switch to the diagnostic preset.
