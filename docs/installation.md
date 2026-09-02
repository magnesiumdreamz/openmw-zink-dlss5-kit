# Installation guide

## Setup wizard

For a guided installation, double-click
`scripts\Start-OpenMWDLSS5Wizard.cmd`. The wizard explains each input, validates
required folders, provides safe defaults, reviews the chosen configuration, and calls
the same `Install-OpenMWDLSS5Kit.ps1` backend documented below. It requests Windows
administrator permission at startup so the optional ReShade registration can be
completed without discarding entered form data.

On the **Required folders** page, click **Download and fill open-source requirements**.
The wizard detects OpenMW in standard install locations and downloads, verifies, and
extracts the pinned Mesa, ReShade shader, VORT, and qUINT packages into
`%LOCALAPPDATA%\OpenMW-DLSS5-Kit\components`. Successful paths are filled automatically.
If a source is unavailable or verification fails, that field remains empty and the
wizard asks you to use **Browse** instead. Re-running the step reuses verified downloads.

Hash mismatches are never accepted silently. The wizard displays the expected and
received hashes and asks whether to continue. Choosing **No** keeps the affected field
unfilled. Choosing **Yes** enables a one-run override, records the unverified file and
both hashes in the prerequisite manifest, and displays the warning again afterward.

The same step downloads the verified RHI installer, but does not run it silently or
obtain proprietary RenoDX/NVIDIA runtime DLLs. Complete the authorized RHI workflow,
then browse to the folder containing the required runtime files. Morrowind itself is
never downloaded or copied by this kit. The wizard can also compile the open-source
patched feeder and install and verify the pinned ReShade full add-on Vulkan layer.

## Safety model

The base installation changes the isolated destination and backs up/applies the tested
OpenMW stability settings. Use `-SkipStableSettings` to leave user settings unchanged.
Desktop shortcuts, saved mod profiles, and the system ReShade Vulkan registration are
changed only when their corresponding opt-in switches are supplied. Profile imports validate
all referenced data directories and plugins before writing and create timestamped
backups. `-RegisterReShade` requires elevation because its application list is stored
under `C:\ProgramData`.

The kit creates an isolated copy of OpenMW. It refuses to install directly over the
source directory and does not copy Morrowind data. OpenMW's normal user configuration
continues to point at the user's existing legal game data.

Installing ReShade's Vulkan layer changes machine-wide Vulkan configuration and
therefore remains an explicit option. The wizard enables it by default and explains
the change. On the command line, use `-InstallReShadeVulkan`; this downloads the pinned
full add-on setup unless `-ReShadeSetupPath` is supplied, verifies its SHA-256, invokes
ReShade's supported headless Vulkan setup, and verifies the installed manifest, DLL,
and HKLM registration. It also registers only the isolated `openmw.exe`.

## Prepare component directories

Extract each component into its own directory. The installer searches recursively but
requires exactly one copy of each required filename; pass a narrower directory if a
download tree contains multiple versions.

Required filenames:

```text
Mesa:            opengl32.dll, libgallium_wgl.dll
ReShade shaders: ReShade.fxh, ReShadeUI.fxh
DLSS5-Feeder:    generated with -BuildPatchedFeeder, or supply
                 dlss5-feed.addon64 and DLSS5_Feed.fx with -FeederPath
VORT:            vort_Motion.fx, vort_*.fxh, required vort_* texture files
qUINT:           qUINT_mxao.fx, qUINT_common.fxh
RenoDX/RHI:      renodx-dlss5.addon64, nvngx_dlss.dll, nvngx_dlssnr.dll
```

Use authorized NVIDIA binaries. Do not download DLLs from random mirrors.

For the automatic feeder build, first install Git for Windows and Visual Studio 2022
Build Tools with the Desktop development with C++ workload. The installer downloads
only commit-pinned source/header archives and the validated feeder shader. It applies
the resize-safety patch before compiling and records the source commits, patch hash,
and resulting binary hash in `feeder-build-provenance.json`.

## Build the runtime

Run the command shown in the root README. Use `-WhatIf` first to validate paths without
writing anything. To refresh an existing generated runtime, add `-UpdateExisting`.
Changed integration files are saved under `kit-backup-<timestamp>`.

If the active Vulkan ReShade instance uses a numbered configuration filename, pass
`-ReShadeConfigName ReShade3.ini`. A normal clean ReShade installation generally uses
the default `ReShade.ini`.

## ReShade Vulkan setup

Use the wizard's **Download, install, and verify the ReShade Vulkan layer** option, or
pass `-InstallReShadeVulkan` to the backend. If a working 64-bit layer is already
installed, the helper leaves it in place. Otherwise it uses the pinned ReShade 6.8.0
full add-on setup. Application registration restricts loading to the generated OpenMW
executable rather than enabling ReShade for unrelated Vulkan applications.

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
