# Pinned downloads for the validated build

These links are versioned or commit-pinned so they do not silently change.

| Required component | Validated download/source |
|---|---|
| OpenMW 0.51.0 | [Windows x64 installer](https://github.com/OpenMW/openmw/releases/download/openmw-0.51.0/OpenMW-0.51.0-Windows-x64.exe) |
| Mesa 26.2.0 MSVC | [Release archive](https://github.com/pal1000/mesa-dist-win/releases/download/26.2.0/mesa3d-26.2.0-release-msvc.7z) |
| ReShade 6.8.0 full add-on build | [Installer](https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe) |
| ReShade shader includes | [Commit 6db142b](https://github.com/crosire/reshade-shaders/archive/6db142b4b1a05c764222e5b0bd9a644b7ccfe1dc.zip) |
| DLSS5-Feeder source | [Tested commit 7c58e39](https://github.com/jlrouzies-fr/DLSS5-Feeder/archive/7c58e39e55e03f971da7d0002c837eed7d21a243.zip) |
| DLSS5 feeder shader | [v0.6.0-beta.1 shader](https://github.com/jlrouzies-fr/DLSS5-Feeder/releases/download/v0.6.0-beta.1/DLSS5_Feed.fx) |
| NVIDIA NGX/DLSS build SDK | [Pinned NVIDIA/DLSS commit a291cc7](https://github.com/NVIDIA/DLSS/archive/a291cc7d2cc642a51566f3dfd5376f635cd1b284.zip) |
| Vulkan build headers | [Pinned Khronos commit 3138637](https://github.com/KhronosGroup/Vulkan-Headers/archive/31386378257ac8653ce5b32c93baec385259ebbe.zip) |
| VORT motion shader | [Commit b410b9f](https://github.com/Vortigern11/vort_Shaders/archive/b410b9f0c0fbb83c8cb42164aaf1655fab386f4a.zip) |
| qUINT MXAO | [Commit 98fed77](https://github.com/martymcmodding/qUINT/archive/98fed77b26669202027f575a6d8f590426c21ebd.zip) |
| RHI 2.4.9 | [RHI-Setup.exe](https://github.com/RankFTW/RHI/releases/download/RHI-2.4.9/RHI-Setup.exe) |
| Git for Windows | [Official Windows download](https://git-scm.com/download/win) |
| Visual Studio 2022 Build Tools | [Official Microsoft download](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) |

Install the Visual Studio **Desktop development with C++** workload, including MSVC
and a Windows SDK. Passing `-BuildPatchedFeeder` to the kit installer automatically
downloads the three pinned source archives above, applies
[`dlss5-feeder-vulkan-resize-idle.patch`](../patches/dlss5-feeder-vulkan-resize-idle.patch),
and builds the feeder. See [`building-feeder.md`](building-feeder.md) for the exact
process. The public v0.7.0 binary does not document this OpenMW resize fix.

Use RHI/RenoDX to obtain `renodx-dlss5.addon64`, `nvngx_dlss.dll`, and
`nvngx_dlssnr.dll` from authorized sources. There is intentionally no unofficial DLL
mirror here. NVIDIA's normal DLSS library is available from the
[official NVIDIA/DLSS repository](https://github.com/NVIDIA/DLSS).

## Recorded SHA256 checksums

```text
56F6CCDA630860A3197FB10C802E047740EA92230474DC442A39674E227F9CE7  OpenMW-0.51.0-Windows-x64.exe
DCB2719EF346DAB5B609FCB193A5F13CFC4B0502E3F4DE1AD43D349477402F47  mesa3d-26.2.0-release-msvc.7z
56B8CC9F4971CEF253644FAFE54063ED7FDCA551D4DEE0F8C6BAA81B855ACD72  7zr.exe 26.02 (used only to extract Mesa)
AFE4C8F13048306307983B8B3D41D5BF00A86820440B0E57DEA10950E1176445  ReShade_Setup_6.8.0_Addon.exe
12D082C8AB1DBCB5E221E1B6116A0343F3182EE517F09BB966B117ACC7635312  reshade-shaders 6db142b archive
C3E325CABE2C056010C9F0DC6F6A2CEFBE7E85F6EA99935BFAC573162F03E9E2  RHI-Setup.exe
231BA34A75556F9943E359559A89B0D0CC2CAA322D9DCDEE5630061BF9FE13B6  vort_Shaders archive
2F6FF2F5DD39FF400C07ECBBFD1156604459F44D9028D07FA6D98B84D4CFBFA9  qUINT archive
74974FA6798D4F09E2A3283D8422FFD7B041A444EFBE40BCB7D1D9D21C7F8234  patched dlss5-feed.addon64
2233D2F04220E4B71832ED6A0A980F0646AC79966F064B10A0566B209FC44B72  DLSS5_Feed.fx
C85F971CE023C9F3492FC7455F0B01A24BA18EA39636407A846902C4360B0B7E  nvngx_dlss.dll 310.8.0
4C5BD1171C7336B4B04FB394DE51DA285AB6EAD6F922D7AFDEC163F71C319D74  nvngx_dlssnr.dll 310.8.SF
9150097CDEE2953CDC9894D2E5606EA5100E6C8F95FC7BB1B407328B4391A07A  renodx-dlss5.addon64
```

Checksums identify exact files; they do not grant redistribution rights.
