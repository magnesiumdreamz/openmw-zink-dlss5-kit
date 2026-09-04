# Validation record

## September 4 component update

See [current test results and remaining errors](september-4-update.md). The records
below are historical; they do not establish error-free operation of the newer stack.

## Fresh isolated repository install — 2026-09-02

The installer was run into the new disposable directory
`runtime/repo-install-functional-test` with `-SkipStableSettings`, no shortcuts,
no profile import, and no permanent ReShade registration. Its local `openmw.cfg`
redirected both `config` and `user-data` to a disposable `test-profile`.

Results:

- all 10 install-manifest hashes passed;
- OpenMW reported `zink Vulkan 1.4 (NVIDIA GeForce RTX 3090)`;
- ReShade compiled `vort_Motion.fx`, `DLSS5_Feed.fx`, and
  `OpenMW_OpaquePresent.fx` from the disposable runtime;
- the feeder opened its D3D12 session over Vulkan transport;
- DLSS became ready at 1280x720 with reversed depth and estimated motion;
- frames 1, 2, and 3 were delivered;
- no sandbox OpenMW process remained afterward;
- the system ReShade registration was restored to the installed stability runtime.

The minimal test profile intentionally excluded the user's mod directories. It logged
missing presentation assets at the menu, but this did not affect the successful
Zink/ReShade/DLSS integration test.

Date: 2026-09-01

## Validated hardware

- GeForce RTX 3090 (24 GiB)
- NVIDIA driver 616.56
- Windows, 1920x1080 windowed OpenMW

The project is intended for community testing on RTX 20-, 30-, 40-, and 50-series
GPUs. Only the RTX 3090 has passed this repository's end-to-end validation. NVIDIA's
official DLSS 5 target is RTX 50 series; older RTX operation is an unsupported
community integration.

## Clean sandbox procedure

The installer was run against the untouched OpenMW 0.51.0 installation in Program
Files, writing to a new disposable destination. Third-party inputs came from the
previously validated local component set. The test used the default `ReShade.ini`
configuration name.

The installer passed these checks:

- source and destination were different;
- only required VORT, qUINT MXAO, ReShade include, feeder, RenoDX, Mesa, and kit files
  were deployed;
- no unused GI/AO shaders were present;
- SHA-256 manifest generation succeeded;
- `-UpdateExisting` created a timestamped backup;
- the saved feeder patch applied cleanly to pinned upstream commit
  `7c58e39e55e03f971da7d0002c837eed7d21a243`.

## Runtime evidence

OpenMW reported:

```text
OpenMW version 0.51.0 (revision f4bec41444)
OpenGL Vendor: Mesa
OpenGL Renderer: zink Vulkan 1.4 (NVIDIA GeForce RTX 3090)
OpenGL Version: 4.6 Compatibility Profile, Mesa 26.2.0
Using reverse-z depth buffer
```

ReShade created a 1920x1080 Vulkan swapchain and compiled only the stable techniques:

```text
OpenMW_OpaquePresent.fx
DLSS5_Feed.fx
vort_Motion.fx
```

The feeder reported:

```text
Vulkan transport session ready
1920x1080 work resolution (100%) -> 1920x1080 backbuffer
depth reversed=1
feature ready: 1920x1080 DLAA
frames 1, 2, and 3 delivered successfully
```

The neural-rendering add-on reported feature 18 creation followed by successful
evaluations at counts 1 and 60. Both OpenMW process entries remained responsive.

The machine-wide ReShade application allowlist was restored to its original value
after validation. The disposable runtime and proprietary components are ignored by
Git and are not part of the publication.

## Known log messages

The feeder may briefly report its technique missing before ReShade finishes compiling;
it subsequently discovers the technique and all required textures. The neural add-on
also logs that one optional `EvaluateFeature_C` symbol was not found, while the normal
evaluate hook and feature 18 continue successfully. Neither message blocked this run.

## Automatic patched-feeder validation

Date: 2026-09-02

The `-BuildPatchedFeeder` path was tested from empty build/output directories. It
downloaded the feeder at commit `7c58e39`, NVIDIA/DLSS at `a291cc7`, and Vulkan-Headers
at `3138637`; validated the downloaded ZIPs; applied the repository resize-safety
patch; compiled `dlss5-feed.addon64`; and emitted `feeder-build-provenance.json`.

The main installer then accepted that generated provenance and installed the feeder
into a second isolated OpenMW destination. A 20-second runtime smoke test reported:

```text
OpenGL Renderer: zink Vulkan 1.4(NVIDIA GeForce RTX 3090 (NVIDIA_PROPRIETARY))
EnableHooks=2
feature ready: 1920x1080 DLAA
frame 1, 2, and 3 delivered
signed DLSSNR 310.8.0 D3D12 runtime initialized
inline feature 18 evaluation succeeded (count=1)
inline feature 18 evaluation succeeded (count=60)
```

The test used a copied sandbox profile. The stable runtime was not modified, and the
system ReShade application registration was restored afterward.
