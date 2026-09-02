# OpenMW Zink DLSS 5 Kit

Experimental Windows integration for running OpenMW through Mesa Zink and applying
DLSS 5 Neural Rendering through ReShade and DLSS5-Feeder:

```text
OpenMW -> OpenGL -> Mesa Zink -> Vulkan -> ReShade -> DLSS5-Feeder -> DLSS 5 NR
```

> **Working proof of life:** OpenMW 0.51.0 on a GeForce RTX 3090 with NVIDIA
> driver 616.56. The same community path is intended for GeForce RTX 20-, 30-,
> 40-, and 50-series GPUs, but only the RTX 3090 configuration has been validated
> by this project so far.

This is an experimental single-player compatibility kit, not an OpenMW or NVIDIA
release. NVIDIA's official DLSS 5 material targets RTX 50-series hardware; operation
on RTX 20/30/40 cards uses the community feeder/RenoDX path and should be treated as
unsupported experimentation.

See [COMPATIBILITY.md](COMPATIBILITY.md) for the test matrix and reporting checklist.

## Contents

- An installer that builds an isolated runtime from an existing OpenMW installation
  and user-supplied third-party components.
- Portable Zink launchers for the game and OpenMW Launcher.
- The opaque-alpha compatibility shader.
- Stable, MXAO, and depth-diagnostic ReShade presets.
- The DLSS5-Feeder Vulkan resize-safety source patch.
- Documentation of the validated configuration and limitations.

It intentionally does **not** contain Morrowind data, OpenMW binaries, Mesa binaries,
ReShade, MXAO, motion-estimation shaders, RenoDX, DLSS5-Feeder binaries, or NVIDIA
DLSS DLLs.

## Required components

Obtain these from their official projects or authorized distribution channels:

1. OpenMW 0.51.0 and a configured legal Morrowind installation.
2. An x64 MSVC Mesa distribution containing `opengl32.dll` and
   `libgallium_wgl.dll`.
3. ReShade with add-on support installed as a Vulkan layer, plus the official shader
   repository directory containing `ReShade.fxh` and `ReShadeUI.fxh`. The installer
   copies only those two includes.
4. DLSS5-Feeder: `dlss5-feed.addon64` and `DLSS5_Feed.fx`.
5. VORT motion estimation: `vort_Motion.fx`, its includes, and required textures.
6. qUINT MXAO: `qUINT_mxao.fx` and `qUINT_common.fxh`.
7. RHI/RenoDX DLSS 5 components: `renodx-dlss5.addon64`, an authorized
   `nvngx_dlss.dll`, and `nvngx_dlssnr.dll`.

See [THIRD_PARTY.md](THIRD_PARTY.md) for official links and redistribution notes.

## Install

Open PowerShell in this repository and run:

```powershell
.\scripts\Install-OpenMWDLSS5Kit.ps1 `
  -OpenMWPath 'C:\Program Files\OpenMW 0.51.0' `
  -DestinationPath 'C:\Games\OpenMW-Zink-DLSS5' `
  -MesaPath 'C:\Downloads\mesa3d-msvc' `
  -ReShadeShaderPath 'C:\Downloads\reshade-shaders' `
  -FeederPath 'C:\Downloads\DLSS5-Feeder' `
  -VortPath 'C:\Downloads\vort_Shaders' `
  -QuintPath 'C:\Downloads\qUINT' `
  -RenoDXPath 'C:\Downloads\RHI-components'
```

The script validates required files before writing, refuses to overwrite a non-empty
destination unless `-UpdateExisting` is supplied, and creates timestamped backups of
replaced integration files. It never modifies the source OpenMW installation.

Afterward:

1. Enable the ReShade full add-on Vulkan layer for the destination `openmw.exe`.
2. Run `Launch-OpenMW-Launcher-Zink.cmd` to adjust OpenMW settings, or
   `Launch-OpenMW-Zink.cmd` to start directly.
3. Confirm the ReShade preset is `OpenMW-Stable.ini`.
4. Confirm `dlss5-feed.log` reports `feature ready` and delivered frames.
5. Use `OpenMW-Depth-Diagnostic.ini` only after loading into the world.

## Verified defaults

- Full-resolution neural rendering: `work_resolution=100`.
- Reversed Zink depth input and depth copied before clear index 1.
- `vort_MotionEffects`, then `DLSS5_Feed`, then `OpenMW_OpaquePresent`.
- MXAO is optional and disabled in the stable preset.
- MSAA, VSync, and the OpenMW frame limiter should be disabled for measurement.

The optional MXAO preset uses the corrected depth buffer. No other GI/AO packages
are part of this kit.

## Optional 1080p scaling and frame generation

If full-resolution Neural Rendering is too expensive, first try running OpenMW at
`1920x1080` in a bordered or borderless window. [Lossless Scaling](https://losslessscaling.com/)
can then scale that window to the monitor resolution and optionally apply LSFG frame
generation. Its official documentation describes scaling and frame generation as
independent features, so either can be tested alone.

Suggested experiment:

1. Set OpenMW to `1920x1080` windowed/borderless.
2. Establish a stable base frame rate before enabling external processing.
3. In Lossless Scaling, try LS1 or FSR scaling first.
4. Add LSFG only after scaling is stable; start with a 2x fixed multiplier.
5. Compare input latency, UI artifacts, camera-motion artifacts, and generated-frame
   pacing—not only the displayed FPS counter.

Lossless Scaling is commercial third-party software and is not bundled, controlled,
or validated by this repository. It operates after OpenMW presentation; it does not
reduce the measured cost of the in-process DLSS 5 pass unless lowering OpenMW's output
resolution first reduces that workload.

## Important limitations

- Motion vectors are estimated, not native engine vectors.
- UI is processed with the 3D scene and can show temporal artifacts.
- DLSS 5 runs at output resolution; this is not DLSS Super Resolution.
- Do not combine this setup with OptiScaler or NVIDIA Smooth Motion.
- Do not use ReShade full add-on builds in anti-cheat multiplayer games.
- NVIDIA neural runtimes are proprietary and must not be committed or redistributed.

See [docs/installation.md](docs/installation.md) and
[docs/troubleshooting.md](docs/troubleshooting.md).
