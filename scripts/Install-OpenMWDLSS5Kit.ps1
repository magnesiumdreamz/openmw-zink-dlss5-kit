[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $OpenMWPath,
    [Parameter(Mandatory)] [string] $DestinationPath,
    [Parameter(Mandatory)] [string] $MesaPath,
    [Parameter(Mandatory)] [string] $ReShadeShaderPath,
    [Parameter(Mandatory)] [string] $FeederPath,
    [Parameter(Mandatory)] [string] $VortPath,
    [Parameter(Mandatory)] [string] $QuintPath,
    [Parameter(Mandatory)] [string] $RenoDXPath,
    [ValidateSet('ReShade.ini', 'ReShade2.ini', 'ReShade3.ini')]
    [string] $ReShadeConfigName = 'ReShade.ini',
    [switch] $UpdateExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-Directory([string] $Path, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label directory does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Find-OneFile([string] $Root, [string] $Name, [string] $Label) {
    $matches = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Name)
    if ($matches.Count -eq 0) { throw "$Label is missing '$Name' under: $Root" }
    if ($matches.Count -gt 1) {
        $paths = $matches.FullName -join [Environment]::NewLine
        throw "$Label contains multiple '$Name' files. Supply a narrower directory:`n$paths"
    }
    return $matches[0].FullName
}

function Copy-WithBackup([string] $Source, [string] $Target, [string] $BackupRoot) {
    if (Test-Path -LiteralPath $Target) {
        $relative = [IO.Path]::GetRelativePath($script:destination, $Target)
        $backup = Join-Path $BackupRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
        Copy-Item -LiteralPath $Target -Destination $backup -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Target -Force
}

$openmw = Resolve-Directory $OpenMWPath 'OpenMW'
$mesa = Resolve-Directory $MesaPath 'Mesa'
$reshadeShaders = Resolve-Directory $ReShadeShaderPath 'ReShade shaders'
$feeder = Resolve-Directory $FeederPath 'DLSS5-Feeder'
$vort = Resolve-Directory $VortPath 'VORT'
$quint = Resolve-Directory $QuintPath 'qUINT'
$renodx = Resolve-Directory $RenoDXPath 'RenoDX/RHI'
$destination = [IO.Path]::GetFullPath($DestinationPath)

if (-not (Test-Path -LiteralPath (Join-Path $openmw 'openmw.exe') -PathType Leaf)) {
    throw "OpenMW source does not contain openmw.exe: $openmw"
}
if ([StringComparer]::OrdinalIgnoreCase.Equals($openmw.TrimEnd('\'), $destination.TrimEnd('\'))) {
    throw 'DestinationPath must differ from OpenMWPath; the kit always preserves the source installation.'
}

$required = [ordered]@{
    MesaOpenGL = Find-OneFile $mesa 'opengl32.dll' 'Mesa'
    MesaGallium = Find-OneFile $mesa 'libgallium_wgl.dll' 'Mesa'
    ReShadeInclude = Find-OneFile $reshadeShaders 'ReShade.fxh' 'ReShade shaders'
    ReShadeUIInclude = Find-OneFile $reshadeShaders 'ReShadeUI.fxh' 'ReShade shaders'
    FeederAddon = Find-OneFile $feeder 'dlss5-feed.addon64' 'DLSS5-Feeder'
    FeederShader = Find-OneFile $feeder 'DLSS5_Feed.fx' 'DLSS5-Feeder'
    VortShader = Find-OneFile $vort 'vort_Motion.fx' 'VORT'
    QuintShader = Find-OneFile $quint 'qUINT_mxao.fx' 'qUINT'
    QuintInclude = Find-OneFile $quint 'qUINT_common.fxh' 'qUINT'
    RenoDXAddon = Find-OneFile $renodx 'renodx-dlss5.addon64' 'RenoDX/RHI'
    DLSS = Find-OneFile $renodx 'nvngx_dlss.dll' 'RenoDX/RHI'
    DLSSNR = Find-OneFile $renodx 'nvngx_dlssnr.dll' 'RenoDX/RHI'
}

$vortIncludes = @(Get-ChildItem -LiteralPath $vort -Recurse -File -Filter 'vort_*.fxh')
if ($vortIncludes.Count -eq 0) { throw "VORT include files were not found under: $vort" }
$vortTextures = @(Get-ChildItem -LiteralPath $vort -Recurse -File | Where-Object {
    $_.Name -like 'vort_*' -and $_.Extension -in '.png', '.jpg', '.dds'
})

$destinationExists = Test-Path -LiteralPath $destination
if ($destinationExists) {
    $hasFiles = @(Get-ChildItem -LiteralPath $destination -Force).Count -gt 0
    if ($hasFiles -and -not $UpdateExisting) {
        throw "Destination is not empty. Use -UpdateExisting to update it: $destination"
    }
}

$destinationExe = Join-Path $destination 'openmw.exe'
$runningDestination = @(Get-Process openmw -ErrorAction SilentlyContinue | Where-Object {
    try { [StringComparer]::OrdinalIgnoreCase.Equals($_.Path, $destinationExe) } catch { $false }
})
if ($runningDestination.Count -gt 0) {
    throw "Close the destination OpenMW process before installing or updating: $destinationExe"
}

if (-not $PSCmdlet.ShouldProcess($destination, 'Build isolated OpenMW Zink DLSS5 runtime')) { return }

if (-not $destinationExists) { New-Item -ItemType Directory -Path $destination | Out-Null }
if (-not (Test-Path -LiteralPath (Join-Path $destination 'openmw.exe'))) {
    Get-ChildItem -LiteralPath $openmw -Force | Copy-Item -Destination $destination -Recurse -Force
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $destination "kit-backup-$stamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$shaderRoot = Join-Path $destination 'reshade-shaders\Shaders'
$includeRoot = Join-Path $shaderRoot 'Includes'
$textureRoot = Join-Path $destination 'reshade-shaders\Textures'
$quintRoot = Join-Path $shaderRoot 'qUINT'
New-Item -ItemType Directory -Force -Path $shaderRoot, $includeRoot, $textureRoot, $quintRoot | Out-Null

Copy-WithBackup $required.MesaOpenGL (Join-Path $destination 'opengl32.dll') $backupRoot
Copy-WithBackup $required.MesaGallium (Join-Path $destination 'libgallium_wgl.dll') $backupRoot
Copy-WithBackup $required.ReShadeInclude (Join-Path $shaderRoot 'ReShade.fxh') $backupRoot
Copy-WithBackup $required.ReShadeUIInclude (Join-Path $shaderRoot 'ReShadeUI.fxh') $backupRoot
Copy-WithBackup $required.FeederAddon (Join-Path $destination 'dlss5-feed.addon64') $backupRoot
Copy-WithBackup $required.FeederShader (Join-Path $shaderRoot 'DLSS5_Feed.fx') $backupRoot
Copy-WithBackup $required.VortShader (Join-Path $shaderRoot 'vort_Motion.fx') $backupRoot
Copy-WithBackup $required.QuintShader (Join-Path $quintRoot 'qUINT_mxao.fx') $backupRoot
Copy-WithBackup $required.QuintInclude (Join-Path $quintRoot 'qUINT_common.fxh') $backupRoot
Copy-WithBackup $required.RenoDXAddon (Join-Path $destination 'renodx-dlss5.addon64') $backupRoot
Copy-WithBackup $required.DLSS (Join-Path $destination 'nvngx_dlss.dll') $backupRoot
Copy-WithBackup $required.DLSSNR (Join-Path $destination 'nvngx_dlssnr.dll') $backupRoot

foreach ($file in $vortIncludes) {
    Copy-WithBackup $file.FullName (Join-Path $includeRoot $file.Name) $backupRoot
}
foreach ($file in $vortTextures) {
    Copy-WithBackup $file.FullName (Join-Path $textureRoot $file.Name) $backupRoot
}

Copy-WithBackup (Join-Path $projectRoot 'shaders\OpenMW_OpaquePresent.fx') (Join-Path $shaderRoot 'OpenMW_OpaquePresent.fx') $backupRoot
Copy-WithBackup (Join-Path $projectRoot 'shaders\OpenMW_DepthDiagnostic.fx') (Join-Path $shaderRoot 'OpenMW_DepthDiagnostic.fx') $backupRoot
Copy-WithBackup (Join-Path $projectRoot 'config\dlss5-feed.cfg') (Join-Path $destination 'dlss5-feed.cfg') $backupRoot
Copy-WithBackup (Join-Path $projectRoot 'config\ReShade-kit.ini') (Join-Path $destination $ReShadeConfigName) $backupRoot

foreach ($preset in 'OpenMW-Stable.ini', 'OpenMW-MXAO.ini', 'OpenMW-Depth-Diagnostic.ini') {
    Copy-WithBackup (Join-Path $projectRoot "presets\$preset") (Join-Path $destination $preset) $backupRoot
}
Copy-WithBackup (Join-Path $projectRoot 'scripts\Launch-OpenMW-Zink.cmd') (Join-Path $destination 'Launch-OpenMW-Zink.cmd') $backupRoot
Copy-WithBackup (Join-Path $projectRoot 'scripts\Launch-OpenMW-Launcher-Zink.cmd') (Join-Path $destination 'Launch-OpenMW-Launcher-Zink.cmd') $backupRoot

$installedFiles = @(
    'opengl32.dll', 'libgallium_wgl.dll', 'dlss5-feed.addon64',
    'renodx-dlss5.addon64', 'nvngx_dlss.dll', 'nvngx_dlssnr.dll',
    $ReShadeConfigName, 'dlss5-feed.cfg', 'Launch-OpenMW-Zink.cmd',
    'Launch-OpenMW-Launcher-Zink.cmd'
)
$manifest = foreach ($relative in $installedFiles) {
    $path = Join-Path $destination $relative
    $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
    "{0}  {1}" -f $hash.Hash, $relative
}
$manifestPath = Join-Path $destination 'kit-install-manifest.sha256'
[IO.File]::WriteAllLines($manifestPath, $manifest)

if (@(Get-ChildItem -LiteralPath $backupRoot -Recurse -File).Count -eq 0) {
    Remove-Item -LiteralPath $backupRoot -Force
    $backupRoot = '(none; no integration files were replaced)'
}

Write-Host "OpenMW Zink DLSS5 kit installed to: $destination"
Write-Host "Backup: $backupRoot"
Write-Host "Manifest: $manifestPath"
Write-Host 'Next: install/enable the ReShade Vulkan add-on layer for this openmw.exe, then run Launch-OpenMW-Launcher-Zink.cmd.'
