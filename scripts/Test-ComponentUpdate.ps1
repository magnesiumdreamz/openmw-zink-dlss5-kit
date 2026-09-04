# File-level tests only: no game, live profile, registry, or desktop writes.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$FeederPath, [Parameter(Mandatory)][string]$RenoDXPath)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('openmw-kit-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
function Fixture([string]$name) {
    $path = Join-Path $root $name
    New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
    [IO.File]::WriteAllText($path, 'inert installer test fixture')
}
foreach ($name in @('source/openmw.exe','mesa/opengl32.dll','mesa/libgallium_wgl.dll',
    'includes/ReShade.fxh','includes/ReShadeUI.fxh','vort/vort_Motion.fx','vort/vort_common.fxh',
    'quint/qUINT_mxao.fx','quint/qUINT_common.fxh','nr/nvngx_dlss.dll','nr/nvngx_dlssnr.dll')) { Fixture $name }
$addon = & (Join-Path $PSScriptRoot 'Get-TestedRenoDXAddon.ps1') -RenoDXPath $RenoDXPath -CachePath (Join-Path $root 'cache')
Copy-Item -LiteralPath $addon -Destination (Join-Path $root 'nr/renodx-dlss5.addon64')
$installArgs = @{
    OpenMWPath=Join-Path $root 'source'; DestinationPath=Join-Path $root 'destination'
    MesaPath=Join-Path $root 'mesa'; ReShadeShaderPath=Join-Path $root 'includes'
    FeederPath=$FeederPath; VortPath=Join-Path $root 'vort'; QuintPath=Join-Path $root 'quint'
    RenoDXPath=Join-Path $root 'nr'; SkipStableSettings=$true
}
$installer = Join-Path $PSScriptRoot 'Install-OpenMWDLSS5Kit.ps1'
& $installer @installArgs -WhatIf
if (Test-Path $installArgs.DestinationPath) { throw 'WhatIf created a destination.' }
& $installer @installArgs
foreach ($name in @('renodx-dlss5.addon64','dlss5-feed.addon64')) {
    $source = if ($name -like 'renodx*') { $addon } else { Join-Path $FeederPath $name }
    if ((Get-FileHash $source).Hash -ne (Get-FileHash (Join-Path $installArgs.DestinationPath $name)).Hash) { throw "Installed hash mismatch: $name" }
}
& $installer @installArgs -UpdateExisting
if (-not (Get-ChildItem $installArgs.DestinationPath -Directory -Filter 'kit-backup-*')) { throw 'Update backup missing.' }
$bad = Join-Path $root 'bad-feeder'
New-Item -ItemType Directory -Path $bad | Out-Null
Copy-Item (Join-Path $FeederPath 'dlss5-feed.addon64') $bad
Fixture 'bad-feeder/DLSS5_Feed.fx'
$installArgs.FeederPath=$bad
$installArgs.DestinationPath=Join-Path $root 'must-not-exist'
$rejected=$false
try { & $installer @installArgs } catch {
    if ($_.Exception.Message -notlike '*matching v0.12.1-beta.2*') { throw }
    $rejected=$true
}
if (-not $rejected -or (Test-Path $installArgs.DestinationPath)) { throw 'Mismatched shader was not safely rejected.' }
Write-Host "PASS: WhatIf, isolated install, update backup, component hashes, mismatched-shader rejection. Fixtures: $root"
