# Third-party components

This repository contains integration files only. Download and accept each project's
license separately.

| Component | Official source | Included here? |
|---|---|---|
| OpenMW | [Pinned 0.51.0 installer](https://github.com/OpenMW/openmw/releases/download/openmw-0.51.0/OpenMW-0.51.0-Windows-x64.exe) | No |
| Mesa for Windows | [Pinned 26.2.0 MSVC archive](https://github.com/pal1000/mesa-dist-win/releases/download/26.2.0/mesa3d-26.2.0-release-msvc.7z) | No |
| ReShade | [Pinned 6.8.0 full add-on installer](https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe) | No |
| DLSS5-Feeder | [Pinned tested source](https://github.com/jlrouzies-fr/DLSS5-Feeder/archive/7c58e39e55e03f971da7d0002c837eed7d21a243.zip) | Source patch only |
| VORT shaders | [Pinned commit archive](https://github.com/Vortigern11/vort_Shaders/archive/b410b9f0c0fbb83c8cb42164aaf1655fab386f4a.zip) | No |
| qUINT/MXAO | [Pinned commit archive](https://github.com/martymcmodding/qUINT/archive/98fed77b26669202027f575a6d8f590426c21ebd.zip) | No |
| RHI | [Pinned 2.4.9 installer](https://github.com/RankFTW/RHI/releases/download/RHI-2.4.9/RHI-Setup.exe) | No |
| NVIDIA DLSS build SDK | [Pinned NVIDIA/DLSS source](https://github.com/NVIDIA/DLSS/archive/a291cc7d2cc642a51566f3dfd5376f635cd1b284.zip) and authorized RHI workflow | No |
| Vulkan-Headers | [Pinned Khronos source](https://github.com/KhronosGroup/Vulkan-Headers/archive/31386378257ac8653ce5b32c93baec385259ebbe.zip) | No |
| Lossless Scaling (optional) | [Official site](https://losslessscaling.com/) | No |

Morrowind game data and saves are not part of the kit. With `-BuildPatchedFeeder`, the
installer downloads pinned feeder, NVIDIA SDK, and Vulkan header sources directly
from their official repositories and compiles them locally. All other third-party
files are supplied by the user; the kit does not redistribute them.

See [docs/downloads.md](docs/downloads.md) for the complete pinned list, checksums,
and the proprietary-DLL provenance boundary.
