# Installation guide

## Safety model

The kit creates an isolated copy of OpenMW. It refuses to install directly over the
source directory and does not copy Morrowind data. OpenMW's normal user configuration
continues to point at the user's existing legal game data.

The installer does not install ReShade's system Vulkan layer because that operation
changes machine-wide Vulkan configuration. Install ReShade with full add-on support
separately and scope it to the isolated `openmw.exe` when the installer permits it.

## Prepare component directories

Extract each component into its own directory. The installer searches recursively but
requires exactly one copy of each required filename; pass a narrower directory if a
download tree contains multiple versions.

Required filenames:

```text
Mesa:            opengl32.dll, libgallium_wgl.dll
ReShade shaders: ReShade.fxh, ReShadeUI.fxh
DLSS5-Feeder:    dlss5-feed.addon64, DLSS5_Feed.fx
VORT:            vort_Motion.fx, vort_*.fxh, required vort_* texture files
qUINT:           qUINT_mxao.fx, qUINT_common.fxh
RenoDX/RHI:      renodx-dlss5.addon64, nvngx_dlss.dll, nvngx_dlssnr.dll
```

Use authorized NVIDIA binaries. Do not download DLLs from random mirrors.

## Build the runtime

Run the command shown in the root README. Use `-WhatIf` first to validate paths without
writing anything. To refresh an existing generated runtime, add `-UpdateExisting`.
Changed integration files are saved under `kit-backup-<timestamp>`.

If the active Vulkan ReShade instance uses a numbered configuration filename, pass
`-ReShadeConfigName ReShade3.ini`. A normal clean ReShade installation generally uses
the default `ReShade.ini`.

## ReShade Vulkan setup

Install the full add-on build of ReShade for Vulkan and allow it to load add-ons.
Avoid enabling the layer globally for unrelated applications where possible. The kit
does not include or install ReShade itself.

At first launch, ReShade should compile only:

```text
vort_Motion.fx
DLSS5_Feed.fx
OpenMW_OpaquePresent.fx
```

`SkipLoadingDisabledEffects=1` is required. Loading all optional effects at startup
previously stalled Zink at its temporary 10x10 bootstrap swapchain.

## Presets

- `OpenMW-Stable.ini`: validated neural-rendering path; default.
- `OpenMW-MXAO.ini`: optional depth-based AO.
- `OpenMW-Depth-Diagnostic.ini`: linear-depth visualization; activate only after a
  save is loaded because menus have no useful world depth.

Keep `OpenMW_OpaquePresent` last. Zink exposes a premultiplied-alpha swapchain in this
configuration, and the final pass prevents framebuffer alpha from becoming Windows
desktop transparency.

## Validation

1. `mesa-zink.log` and OpenMW's renderer string must identify Zink and the NVIDIA GPU.
2. `ReShade.log` must show a Vulkan swapchain at the expected resolution.
3. The depth diagnostic must show near objects darker than distant objects.
4. `dlss5-feed.log` must report feature readiness and continuously delivered frames.
5. Test an exterior, an interior, NPCs, water, vegetation, sky, UI, and live resolution
   changes before treating the installation as stable.
