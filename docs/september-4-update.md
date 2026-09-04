# September 4 component update (unreleased)

The repository now reproduces the latest working NR configuration, not a claim
that all underlying driver issues are fixed.

## Installer changes

- Build Feeder v0.12.1-beta.2 at commit `b4e92bb6c8bfa73c3bfa63decfb083863f48a192`.
- Carry forward the Vulkan device-idle wait before destroying imported resources.
  The newer combination still needs a fresh resize/fullscreen regression test.
- Use the matching shader and verify its SHA256; reject older mismatched files.
- Use RenoDX 4.70 (banner v4.7): select the tested hash from the supplied RHI
  directory, otherwise download the pinned RHI archive and verify archive and add-on.
  Failed downloads stop with a manual link, never a silent stale-add-on fallback.
- Preserve update backups. NVIDIA DLLs remain user-supplied, not automatically updated.
  No downloaded binaries are committed. The GUI uses the same backend.

## Observed runtime results

RTX 3090, driver 616.56, OpenMW 0.51.0, Zink, 1920x1080, 30 FPS cap,
OpenMW postprocessing off; modded Seyda Neen. Routes and durations varied.

| Configuration | NVIDIA Event 153 count | Outcome |
| --- | ---: | --- |
| Updated Feeder, older RenoDX, NR off (three short runs) | 0 each | Clean exits |
| Updated Feeder, older RenoDX, NR on, ~104 seconds | 31 | NR evaluated, clean exit |
| Same with synchronous copy-back, ~103 seconds | 71 | NR evaluated, clean exit; slower |
| Updated Feeder, RenoDX 4.70, NR on, ~83 seconds | 8 | NR evaluated, clean exit; no F6 toggles |

The final run reported the fenced NR workset pool and submission tracker active.
Post-startup frame intervals averaged about 36.6–36.8 ms (27 FPS). These are
diagnostic logs, not controlled GPU benchmarks; event counts do not prove an
improvement or identify the exact failing component. No submission failures were logged.

Still present: two missing EvaluateFeature_C hook errors, shutdown depth-resource
and descriptor-heap warnings, custom/untested NR runtime warning, and content-specific
script/mesh warnings. Visible success does not establish long-session stability.
Earlier validation records concern older component combinations.

## Deliberately not included

- `sync_home=1`: did not resolve driver errors and increased waiting.
- `preload cell cache max=15`: warning persisted; no generic fix claimed.
- User-specific mods, saves, postprocessing changes or diagnostic desktop shortcuts.
- The missing data folder was repaired locally; other installs may use custom paths.

Next: NR runtime compatibility, longer matched-route tests, and resolution/window
mode regression tests. Inspect driver events, not just visible playability.

## Repository validation

The full pinned source download/patch/MSVC build passed in a new sandbox. The
release-matching shader hash passed. The automatic RenoDX download verified archive
and binary hashes. File-level installer fixtures passed isolated installation,
update backup, component hash, WhatIf, and mismatched-shader rejection checks.
These fixtures use inert DLL/executable stand-ins and do not claim an in-game test.
Testing also exposed inherited WhatIf propagation into the build helper; the
installer now stops at ShouldProcess before invoking a build during a dry run.
The automatic build was then accepted by the installer's provenance gate in an
isolated fixture install, without the unvalidated-Feeder override.
