# Building the patched DLSS5-Feeder

The live-resize fix is now carried forward to DLSS5-Feeder v0.12.1-beta.2,
commit `b4e92bb6c8bfa73c3bfa63decfb083863f48a192`.
The helper uses the shader from that source, normalizes its line endings to match
the release package, and verifies both source and packaged shader hashes.

The normal installation path is automatic. Install Git for Windows and Visual Studio
2022 Build Tools with **Desktop development with C++**, then pass this switch to the
main installer:

```powershell
-BuildPatchedFeeder
```

The installer calls `scripts\Build-PatchedDLSS5Feeder.ps1`. That helper downloads the
commit-pinned feeder source, NVIDIA NGX SDK, Vulkan headers, and matching feeder shader;
applies the repository patch; builds the x64 add-on; and writes a provenance manifest.
The generated files are stored under
`%LOCALAPPDATA%\OpenMW-DLSS5-Kit\validated-feeder`.
The corresponding source/download workspace is under
`%LOCALAPPDATA%\OpenMW-DLSS5-Kit\feeder-build`; both locations can be overridden with
`-FeederBuildOutputPath` and `-FeederBuildWorkPath` when needed.

To build it separately for inspection:

```powershell
.\scripts\Build-PatchedDLSS5Feeder.ps1 `
  -OutputPath "$env:LOCALAPPDATA\OpenMW-DLSS5-Kit\validated-feeder"
```

The build still requires an installed MSVC C++ toolchain and Windows SDK. Source and
header dependencies are downloaded from the exact links in `downloads.md`; proprietary
NVIDIA runtime DLLs are not part of this compilation and remain separate authorized
inputs to the main installer. Its separate RenoDX helper obtains the tested 4.70 add-on.

Before building, check whether a newer upstream release has incorporated an equivalent
Vulkan idle wait. Do not apply the patch twice. A clean build should contain only the
resize-safety change needed by this kit; the removed 33% working-resolution and native-
ratio experiments are not part of the public configuration.

The patch calls `vkDeviceWaitIdle` before imported Vulkan images are destroyed. This
is deliberately conservative and occurs during teardown/resize, not every frame.
