# Building the patched DLSS5-Feeder

The live-resize fix was developed against DLSS5-Feeder commit
`7c58e39e55e03f971da7d0002c837eed7d21a243`.

```powershell
git clone https://github.com/jlrouzies-fr/DLSS5-Feeder.git
Set-Location DLSS5-Feeder
git checkout 7c58e39e55e03f971da7d0002c837eed7d21a243
git apply C:\path\to\OpenMW-Zink-DLSS5-Kit\patches\dlss5-feeder-vulkan-resize-idle.patch
.\build.bat
```

Follow the upstream build documentation to supply the NGX SDK and Vulkan headers.
The expected output is `build\dlss5-feed.addon64`. Copy that file and the matching
`DLSS5_Feed.fx` into a narrow directory passed as `-FeederPath` to the kit installer.

Before building, check whether a newer upstream release has incorporated an equivalent
Vulkan idle wait. Do not apply the patch twice. A clean build should contain only the
resize-safety change needed by this kit; the removed 33% working-resolution and native-
ratio experiments are not part of the public configuration.

The patch calls `vkDeviceWaitIdle` before imported Vulkan images are destroyed. This
is deliberately conservative and occurs during teardown/resize, not every frame.
