# Optional HBAO + VAIO compatibility patch

Use this only if you have [Rafael's Shader Pack](https://www.nexusmods.com/morrowind/mods/53667)
installed and want to try its HBAO and VAIO effects with this kit. The patcher
supports the exact shader contents tested from pack 2.1 (HBAO's internal version
is 2.0). It tolerates LF/CRLF differences, but refuses other versions or edits.
It does not download or bundle the full shader pack.

## Easy setup

1. Close OpenMW and its launcher.
2. Double-click `scripts/Start-PostProcessingWizard.cmd`.
3. Browse to the folder containing **both** `HBAO.omwfx` and `VAIO.omwfx`.
   In our build this is `OpenMW/resources/vfs/shaders`. If you installed the pack
   as a separate mod, select that mod's Shaders folder instead. Choose the active
   copy; the wizard cannot determine which duplicate mod folder wins your load order.
4. Click **Apply patch**. Keep the displayed backup path.
5. Launch OpenMW, enable postprocessing and select **HBAO, then VAIO**. Disable
   ReShade MXAO if you don't want two AO effects at once. The patcher does not alter
   effect selections, presets, NR, saves, or your settings.

If the folder is protected, run the wizard as administrator only after verifying
the selected folder. Normally no elevation is needed for a user-owned game folder.

## What changes

- Guard both HBAO blur calculations against division by zero.
- Initialize VAIO's light output when that pass exits early.
- Guard VAIO's zero-distance lighting and tile-depth calculations.
- Add **Volumetric light limit (compatibility)**, default 64, adjustable from 8
  to 256 in VAIO's settings. This bounds light calculations per pixel. It may
  omit some glows in busy scenes; normal scene lighting is unaffected. It does
  not sort/select the nearest lights.

The user's game successfully compiled both patched shaders. This is **not yet
a confirmed fix for hangs or NVIDIA Event 153 errors**. Keep resolution fixed,
change one thing at a time, and check logs after testing. A leading top-level
comment caused an earlier VAIO parser error; this patch includes the corrected
declaration-first file.

## Backups and undo

Original bytes are saved beneath the shader folder in `.compat-backups/<unique-id>`.
The backup filenames end in `.before`, so they are not extra active shader files.
To undo, select the same shader folder in the wizard, click **Restore backup**,
and choose the backup folder containing both originals. Later unknown shader edits
are protected: restore refuses to overwrite them. Keep the backup folder.

Already-patched files are left alone. Both inputs and both generated outputs are
checked before writing, with rollback on a write failure. Don't update the shader
pack or launch the game while patching.

Command-line equivalent (Windows PowerShell 5.1 or PowerShell 7):

```powershell
.\scripts\Patch-RafaelPostProcessing.ps1 -ShaderPath 'C:\Games\OpenMW\resources\vfs\shaders' -WhatIf
.\scripts\Patch-RafaelPostProcessing.ps1 -ShaderPath 'C:\Games\OpenMW\resources\vfs\shaders'
.\scripts\Patch-RafaelPostProcessing.ps1 -ShaderPath 'C:\Games\OpenMW\resources\vfs\shaders' -RestoreBackup 'C:\Games\OpenMW\resources\vfs\shaders\.compat-backups\YOUR-BACKUP'
```

The source snippets in the patcher are adapted from Rafael's GPL v3 shader pack.
The patcher is provided under GPL-3.0-only; see [license text](licenses/Rafael-GPL-3.0.txt).
Other kit files retain their existing terms.
