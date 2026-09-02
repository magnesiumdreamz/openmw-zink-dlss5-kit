[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TargetExecutable,
    [string] $SetupPath,
    [switch] $DownloadSetup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$setupUrl = 'https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe'
$setupHash = 'AFE4C8F13048306307983B8B3D41D5BF00A86820440B0E57DEA10950E1176445'
$commonPath = Join-Path $env:ProgramData 'ReShade'
$manifest = Join-Path $commonPath 'ReShade64.json'
$module = Join-Path $commonPath 'ReShade64.dll'
$registryPath = 'HKLM:\SOFTWARE\Khronos\Vulkan\ImplicitLayers'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ReShadeLayer {
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf) -or -not (Test-Path -LiteralPath $module -PathType Leaf)) { return $false }
    try {
        $properties = Get-ItemProperty -LiteralPath $registryPath -Name $manifest -ErrorAction Stop
        $value = $properties.PSObject.Properties[$manifest].Value
        return $value -eq 0
    } catch { return $false }
}

$target = (Resolve-Path -LiteralPath $TargetExecutable -ErrorAction Stop).Path
if (-not $target.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) { throw "ReShade target is not an executable: $target" }

if (Test-ReShadeLayer) {
    Write-Host "ReShade Vulkan layer is already installed and enabled: $manifest"
    return
}
if (-not (Test-Administrator)) { throw 'Installing the ReShade Vulkan layer requires an administrator PowerShell process.' }

if (-not $SetupPath) {
    if (-not $DownloadSetup) { throw 'Supply -SetupPath or use -DownloadSetup.' }
    $downloadDirectory = Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\downloads'
    New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null
    $SetupPath = Join-Path $downloadDirectory 'ReShade_Setup_6.8.0_Addon.exe'
    if (-not (Test-Path -LiteralPath $SetupPath -PathType Leaf) -or (Get-FileHash -LiteralPath $SetupPath -Algorithm SHA256).Hash -ne $setupHash) {
        $partial = "$SetupPath.partial"
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
        Write-Host "Downloading pinned ReShade 6.8.0 full add-on setup from $setupUrl"
        & curl.exe -L --fail --show-error --retry 3 --output $partial $setupUrl
        if ($LASTEXITCODE -ne 0) { throw "ReShade download failed with curl exit code $LASTEXITCODE." }
        Move-Item -LiteralPath $partial -Destination $SetupPath -Force
    }
}

$setup = (Resolve-Path -LiteralPath $SetupPath -ErrorAction Stop).Path
$actualHash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
if ($actualHash -ne $setupHash) {
    throw "ReShade setup SHA256 does not match the pinned full add-on build. Expected $setupHash, found $actualHash."
}

# Headless Vulkan setup treats an existing per-game ReShade.ini as an existing
# installation. Preserve it temporarily and restore it after installing the layer.
$targetDirectory = Split-Path -Parent $target
$targetConfig = Join-Path $targetDirectory 'ReShade.ini'
$savedConfig = $null
if (Test-Path -LiteralPath $targetConfig -PathType Leaf) {
    $savedConfig = Join-Path $targetDirectory ("ReShade.ini.before-layer-install-{0}.bak" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $targetConfig -Destination $savedConfig
}

try {
    Write-Host 'Installing the ReShade Vulkan implicit layer...'
    $quotedTarget = '"' + $target + '"'
    $process = Start-Process -FilePath $setup -ArgumentList @($quotedTarget, '--api', 'vulkan', '--headless') -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "ReShade setup exited with code $($process.ExitCode)." }
} finally {
    if ($savedConfig) {
        if (Test-Path -LiteralPath $targetConfig -PathType Leaf) { Remove-Item -LiteralPath $targetConfig -Force }
        Move-Item -LiteralPath $savedConfig -Destination $targetConfig -Force
    }
}

if (-not (Test-ReShadeLayer)) {
    throw "ReShade setup finished, but the enabled 64-bit Vulkan layer was not found at $manifest or in $registryPath."
}

Write-Host "ReShade Vulkan layer installed and verified: $manifest"
