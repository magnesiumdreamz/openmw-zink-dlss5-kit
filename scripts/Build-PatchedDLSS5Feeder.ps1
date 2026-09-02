[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $OutputPath,
    [string] $WorkPath = (Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\feeder-build')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceCommit = '7c58e39e55e03f971da7d0002c837eed7d21a243'
$ngxCommit = 'a291cc7d2cc642a51566f3dfd5376f635cd1b284'
$vulkanCommit = '31386378257ac8653ce5b32c93baec385259ebbe'
$shaderHash = '2233D2F04220E4B71832ED6A0A980F0646AC79966F064B10A0566B209FC44B72'
$projectRoot = Split-Path -Parent $PSScriptRoot
$patchPath = Join-Path $projectRoot 'patches\dlss5-feeder-vulkan-resize-idle.patch'

function Assert-SafeBuildDirectory([string] $Path, [string] $Label) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [IO.Path]::GetPathRoot($full).TrimEnd('\')
    $profile = [Environment]::GetFolderPath('UserProfile').TrimEnd('\')
    if ($full -eq $root -or $full -eq $profile -or $full -eq $projectRoot.TrimEnd('\')) {
        throw "$Label must be a dedicated subdirectory, not a drive, user profile, or repository root: $full"
    }
}

function Test-ZipFile([string] $Path) {
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        $archive.Dispose()
        return $true
    } catch { return $false }
}

function Download-File([string] $Uri, [string] $Path, [switch] $Zip) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if (-not $Zip -or (Test-ZipFile $Path)) { return }
        Remove-Item -LiteralPath $Path -Force
    }
    Write-Host "Downloading $Uri"
    $partial = "$Path.partial"
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
    & curl.exe -L --fail --show-error --retry 3 --output $partial $Uri
    if ($LASTEXITCODE -ne 0) { throw "Download failed with curl exit code $LASTEXITCODE`: $Uri" }
    if ($Zip -and -not (Test-ZipFile $partial)) {
        Remove-Item -LiteralPath $partial -Force
        throw "The downloaded file is not a valid ZIP archive: $Uri"
    }
    Move-Item -LiteralPath $partial -Destination $Path -Force
}

if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required to apply the feeder patch. See docs/downloads.md.'
}

$work = [IO.Path]::GetFullPath($WorkPath)
$output = [IO.Path]::GetFullPath($OutputPath)
Assert-SafeBuildDirectory $work 'WorkPath'
Assert-SafeBuildDirectory $output 'OutputPath'
$downloads = Join-Path $work 'downloads'
$sourceRoot = Join-Path $work "DLSS5-Feeder-$sourceCommit"
New-Item -ItemType Directory -Force -Path $downloads, $output | Out-Null

$feederZip = Join-Path $downloads "DLSS5-Feeder-$sourceCommit.zip"
$ngxZip = Join-Path $downloads "NVIDIA-DLSS-$ngxCommit.zip"
$vulkanZip = Join-Path $downloads "Vulkan-Headers-$vulkanCommit.zip"
$shaderPath = Join-Path $output 'DLSS5_Feed.fx'

Download-File "https://github.com/jlrouzies-fr/DLSS5-Feeder/archive/$sourceCommit.zip" $feederZip -Zip
Download-File "https://github.com/NVIDIA/DLSS/archive/$ngxCommit.zip" $ngxZip -Zip
Download-File "https://github.com/KhronosGroup/Vulkan-Headers/archive/$vulkanCommit.zip" $vulkanZip -Zip
Download-File 'https://github.com/jlrouzies-fr/DLSS5-Feeder/releases/download/v0.6.0-beta.1/DLSS5_Feed.fx' $shaderPath

if ((Get-FileHash -LiteralPath $shaderPath -Algorithm SHA256).Hash -ne $shaderHash) {
    throw 'The downloaded DLSS5_Feed.fx does not match the validated SHA256. Delete it and retry.'
}

if (Test-Path -LiteralPath $sourceRoot) {
    Remove-Item -LiteralPath $sourceRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $sourceRoot | Out-Null

$extractRoot = Join-Path $work 'extract'
if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
New-Item -ItemType Directory -Path $extractRoot | Out-Null

Expand-Archive -LiteralPath $feederZip -DestinationPath (Join-Path $extractRoot 'feeder') -Force
Expand-Archive -LiteralPath $ngxZip -DestinationPath (Join-Path $extractRoot 'ngx') -Force
Expand-Archive -LiteralPath $vulkanZip -DestinationPath (Join-Path $extractRoot 'vulkan') -Force

$feederExtracted = @(Get-ChildItem -LiteralPath (Join-Path $extractRoot 'feeder') -Directory)
$ngxExtracted = @(Get-ChildItem -LiteralPath (Join-Path $extractRoot 'ngx') -Directory)
$vulkanExtracted = @(Get-ChildItem -LiteralPath (Join-Path $extractRoot 'vulkan') -Directory)
if ($feederExtracted.Count -ne 1 -or $ngxExtracted.Count -ne 1 -or $vulkanExtracted.Count -ne 1) {
    throw 'One of the pinned source archives had an unexpected directory layout.'
}
Get-ChildItem -LiteralPath $feederExtracted[0].FullName -Force | Copy-Item -Destination $sourceRoot -Recurse -Force

& git.exe -C $sourceRoot apply --check $patchPath
if ($LASTEXITCODE -ne 0) { throw 'The resize-safety patch does not apply cleanly to the pinned feeder source.' }
& git.exe -C $sourceRoot apply $patchPath
if ($LASTEXITCODE -ne 0) { throw 'Applying the resize-safety patch failed.' }

$ngxDestination = Join-Path $sourceRoot 'external\ngx'
Get-ChildItem -LiteralPath (Join-Path $ngxExtracted[0].FullName 'include') -File |
    Copy-Item -Destination $ngxDestination -Force
New-Item -ItemType Directory -Force -Path (Join-Path $ngxDestination 'libs') | Out-Null
Copy-Item -LiteralPath (Join-Path $ngxExtracted[0].FullName 'lib\Windows_x86_64\x64\nvsdk_ngx_d.lib') `
    -Destination (Join-Path $ngxDestination 'libs\nvsdk_ngx_d.lib') -Force

$vulkanDestination = Join-Path $sourceRoot 'external\vulkan'
Copy-Item -LiteralPath (Join-Path $vulkanExtracted[0].FullName 'include\vulkan') `
    -Destination $vulkanDestination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $vulkanExtracted[0].FullName 'include\vk_video') `
    -Destination $vulkanDestination -Recurse -Force

Write-Host 'Building the patched feeder with the installed Visual C++ toolchain...'
& cmd.exe /d /c "`"$(Join-Path $sourceRoot 'build.bat')`""
if ($LASTEXITCODE -ne 0) { throw "The feeder build failed with exit code $LASTEXITCODE." }

$builtAddon = Join-Path $sourceRoot 'build\dlss5-feed.addon64'
if (-not (Test-Path -LiteralPath $builtAddon -PathType Leaf)) {
    throw 'The build completed without producing build\dlss5-feed.addon64.'
}
Copy-Item -LiteralPath $builtAddon -Destination (Join-Path $output 'dlss5-feed.addon64') -Force

$addonHash = (Get-FileHash -LiteralPath (Join-Path $output 'dlss5-feed.addon64') -Algorithm SHA256).Hash
$provenance = [ordered]@{
    feederSourceCommit = $sourceCommit
    ngxSourceCommit = $ngxCommit
    vulkanHeadersCommit = $vulkanCommit
    patchSha256 = (Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).Hash
    addonSha256 = $addonHash
    shaderSha256 = $shaderHash
    builtAtUtc = [DateTime]::UtcNow.ToString('o')
}
$provenance | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'feeder-build-provenance.json') -Encoding utf8

Write-Host "Patched feeder ready: $output"
Write-Host "SHA256: $addonHash"
