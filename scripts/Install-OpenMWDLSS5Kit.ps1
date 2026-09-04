[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $OpenMWPath,
    [Parameter(Mandatory)] [string] $DestinationPath,
    [Parameter(Mandatory)] [string] $MesaPath,
    [Parameter(Mandatory)] [string] $ReShadeShaderPath,
    [string] $FeederPath,
    [Parameter(Mandatory)] [string] $VortPath,
    [Parameter(Mandatory)] [string] $QuintPath,
    [Parameter(Mandatory)] [string] $RenoDXPath,
    [ValidateSet('ReShade.ini', 'ReShade2.ini', 'ReShade3.ini')]
    [string] $ReShadeConfigName = 'ReShade.ini',
    [switch] $UpdateExisting,
    [switch] $ApplyStableSettings,
    [switch] $SkipStableSettings,
    [switch] $BuildPatchedFeeder,
    [string] $FeederBuildOutputPath = (Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\validated-feeder'),
    [string] $FeederBuildWorkPath = (Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\feeder-build'),
    [switch] $AllowUnvalidatedFeeder,
    [string] $ImportProfilePath,
    [string] $ModRoot,
    [string] $BaseDataPath,
    [string] $OverwritePath,
    [string[]] $AdditionalDataPath,
    [switch] $CreateDesktopShortcuts,
    [switch] $InstallReShadeVulkan,
    [string] $ReShadeSetupPath,
    [switch] $RegisterReShade
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
if ($BuildPatchedFeeder) {
    if ($FeederPath) { throw 'Use either -FeederPath or -BuildPatchedFeeder, not both.' }
    # Do not let WhatIf partially execute the non-ShouldProcess build helper.
    if (-not $PSCmdlet.ShouldProcess($FeederBuildOutputPath, 'Download, patch, and build Feeder before installation')) { return }
    $FeederPath = $FeederBuildOutputPath
    & (Join-Path $PSScriptRoot 'Build-PatchedDLSS5Feeder.ps1') -OutputPath $FeederPath -WorkPath $FeederBuildWorkPath
}
if (-not $FeederPath) {
    throw 'Supply -FeederPath with a validated binary, or use -BuildPatchedFeeder to download, patch, and compile it automatically.'
}
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
    RenoDXAddon = & (Join-Path $PSScriptRoot 'Get-TestedRenoDXAddon.ps1') -RenoDXPath $renodx
    DLSS = Find-OneFile $renodx 'nvngx_dlss.dll' 'RenoDX/RHI'
    DLSSNR = Find-OneFile $renodx 'nvngx_dlssnr.dll' 'RenoDX/RHI'
}

$knownFeederHashes = @(Get-Content (Join-Path $projectRoot 'config\known-good-feeder-sha256.txt') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[A-Fa-f0-9]{64}$' })
$feederHash = (Get-FileHash -LiteralPath $required.FeederAddon -Algorithm SHA256).Hash
$generatedProvenance = Join-Path $feeder 'feeder-build-provenance.json'
$generatedFeederIsValid = $false
if ($BuildPatchedFeeder -and (Test-Path -LiteralPath $generatedProvenance -PathType Leaf)) {
    $provenance = Get-Content -LiteralPath $generatedProvenance -Raw | ConvertFrom-Json
    $patchHash = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'patches\dlss5-feeder-vulkan-resize-idle.patch') -Algorithm SHA256).Hash
    $generatedFeederIsValid = $provenance.feederSourceCommit -eq 'b4e92bb6c8bfa73c3bfa63decfb083863f48a192' -and
        $provenance.patchSha256 -eq $patchHash -and $provenance.addonSha256 -eq $feederHash
}
if ($feederHash -notin $knownFeederHashes -and -not $generatedFeederIsValid -and -not $AllowUnvalidatedFeeder) {
    throw "Unvalidated dlss5-feed.addon64 (SHA256 $feederHash). Use the tested resize-safe build, build the included patch, or explicitly accept resolution-change crash risk with -AllowUnvalidatedFeeder. No files were changed."
}

if ((Get-FileHash -LiteralPath $required.FeederShader).Hash -ne '491815122018D17D460F02ADC0E5F03ABB6E7489E3B8136BA003927EE06858E9') {
    throw 'Supply the matching v0.12.1-beta.2 DLSS5_Feed.fx; older shaders must not be mixed with this feeder.'
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

if ($InstallReShadeVulkan) { $RegisterReShade = $true }
if ($RegisterReShade) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw '-RegisterReShade requires an elevated PowerShell window. No files were changed.'
    }
}

if (-not $PSCmdlet.ShouldProcess($destination, 'Build isolated OpenMW Zink DLSS5 runtime')) { return }

if (-not $destinationExists) { New-Item -ItemType Directory -Path $destination | Out-Null }
if (-not (Test-Path -LiteralPath (Join-Path $destination 'openmw.exe'))) {
    Get-ChildItem -LiteralPath $openmw -Force | Copy-Item -Destination $destination -Recurse -Force
}

if ($InstallReShadeVulkan) {
    $layerArguments = @{ TargetExecutable = $destinationExe }
    if ($ReShadeSetupPath) { $layerArguments.SetupPath = $ReShadeSetupPath }
    else { $layerArguments.DownloadSetup = $true }
    & (Join-Path $PSScriptRoot 'Install-ReShadeVulkanLayer.ps1') @layerArguments
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

$useStableSettings = $ApplyStableSettings -or -not $SkipStableSettings
if ($useStableSettings -or $ImportProfilePath) {
    $profileArgs = @{
        UserConfigPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\OpenMW'
    }
    if ($useStableSettings) { $profileArgs.ApplyStableSettings = $true }
    if ($ImportProfilePath) { $profileArgs.ImportProfilePath = $ImportProfilePath }
    if ($ModRoot) { $profileArgs.ModRoot = $ModRoot }
    if ($BaseDataPath) { $profileArgs.BaseDataPath = $BaseDataPath }
    if ($OverwritePath) { $profileArgs.OverwritePath = $OverwritePath }
    if ($AdditionalDataPath) { $profileArgs.AdditionalDataPath = $AdditionalDataPath }
    & (Join-Path $projectRoot 'scripts\Configure-OpenMWStableProfile.ps1') @profileArgs
}

if ($CreateDesktopShortcuts) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell
    $shortcutDefinitions = @(
        @{
            Name = 'OpenMW Zink DLSS5.lnk'
            Script = 'Launch-OpenMW-Zink.cmd'
            Icon = 'openmw.exe'
            Description = 'Launch OpenMW through Mesa Zink, Vulkan ReShade, and DLSS 5'
        },
        @{
            Name = 'OpenMW Zink DLSS5 Launcher.lnk'
            Script = 'Launch-OpenMW-Launcher-Zink.cmd'
            Icon = 'openmw-launcher.exe'
            Description = 'Configure the OpenMW Zink DLSS 5 runtime'
        }
    )
    foreach ($definition in $shortcutDefinitions) {
        $shortcutPath = Join-Path $desktop $definition.Name
        if (Test-Path -LiteralPath $shortcutPath) {
            Copy-Item -LiteralPath $shortcutPath -Destination (Join-Path $backupRoot $definition.Name) -Force
        }
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\cmd.exe'
        $launcherPath = Join-Path $destination $definition.Script
        $shortcut.Arguments = "/c `"`"$launcherPath`"`""
        $shortcut.WorkingDirectory = $destination
        $shortcut.IconLocation = "$(Join-Path $destination $definition.Icon),0"
        $shortcut.Description = $definition.Description
        $shortcut.Save()
    }
}

if ($RegisterReShade) {
    $registration = Join-Path $env:ProgramData 'ReShade\ReShadeApps.ini'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $registration) | Out-Null
    if (Test-Path -LiteralPath $registration) {
        Copy-Item -LiteralPath $registration -Destination (Join-Path $backupRoot 'ReShadeApps.ini') -Force
    }
    [IO.File]::WriteAllText($registration, "Apps=$destinationExe`r`n", [Text.UTF8Encoding]::new($false))
}

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
