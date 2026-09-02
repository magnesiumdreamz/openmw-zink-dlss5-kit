[CmdletBinding()]
param(
    [string] $CachePath = (Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\components'),
    [switch] $IncludeRHIInstaller
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VerifiedFile {
    param([string] $Name, [string] $Url, [string] $Sha256)
    $downloads = Join-Path $CachePath 'downloads'
    New-Item -ItemType Directory -Force -Path $downloads | Out-Null
    $target = Join-Path $downloads $Name
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $Sha256) { return $target }
        Remove-Item -LiteralPath $target -Force
    }
    $partial = "$target.partial"
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    & curl.exe -L --fail --show-error --connect-timeout 20 --retry 2 $Url -o $partial
    if ($LASTEXITCODE -ne 0) { throw "Download failed (curl exit $LASTEXITCODE): $Url" }
    $actual = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
    if ($actual -ne $Sha256) {
        Remove-Item -LiteralPath $partial -Force
        throw "Hash mismatch for $Name. Expected $Sha256; received $actual."
    }
    Move-Item -LiteralPath $partial -Destination $target -Force
    return $target
}

function Expand-ZipComponent {
    param([string] $Archive, [string] $Name)
    $target = Join-Path $CachePath $Name
    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Expand-Archive -LiteralPath $Archive -DestinationPath $target -Force
    }
    return $target
}

function Find-ContainingFolder {
    param([string] $Root, [string[]] $Files)
    foreach ($candidate in @($Root) + @(Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object FullName)) {
        $valid = $true
        foreach ($file in $Files) {
            if (-not (Test-Path -LiteralPath (Join-Path $candidate $file) -PathType Leaf)) { $valid = $false; break }
        }
        if ($valid) { return $candidate }
    }
    throw "Could not find $($Files -join ', ') below $Root."
}

function Invoke-Component {
    param([string] $Name, [scriptblock] $Action)
    try {
        $path = & $Action
        return [ordered]@{ Success = $true; Path = [string]$path; Error = $null }
    } catch {
        return [ordered]@{ Success = $false; Path = $null; Error = $_.Exception.Message }
    }
}

New-Item -ItemType Directory -Force -Path $CachePath | Out-Null
$result = [ordered]@{ CachePath = $CachePath }

$result.OpenMW = Invoke-Component 'OpenMW' {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'OpenMW 0.51.0'),
        (Join-Path $env:ProgramFiles 'OpenMW'),
        (Join-Path ${env:ProgramFiles(x86)} 'OpenMW')
    )
    $command = Get-Command openmw.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates = @((Split-Path -Parent $command.Source)) + $candidates }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'openmw.exe') -PathType Leaf)) { return $candidate }
    }
    throw 'No existing OpenMW folder was found in the standard install locations. Select it with Browse.'
}

$result.ReShadeShaders = Invoke-Component 'ReShadeShaders' {
    $archive = Get-VerifiedFile 'reshade-shaders-6db142b.zip' 'https://github.com/crosire/reshade-shaders/archive/6db142b4b1a05c764222e5b0bd9a644b7ccfe1dc.zip' '12D082C8AB1DBCB5E221E1B6116A0343F3182EE517F09BB966B117ACC7635312'
    $root = Expand-ZipComponent $archive 'reshade-shaders-6db142b'
    Find-ContainingFolder $root @('Shaders\ReShade.fxh', 'Shaders\ReShadeUI.fxh')
}

$result.Vort = Invoke-Component 'Vort' {
    $archive = Get-VerifiedFile 'vort-shaders-b410b9f.zip' 'https://github.com/Vortigern11/vort_Shaders/archive/b410b9f0c0fbb83c8cb42164aaf1655fab386f4a.zip' '231BA34A75556F9943E359559A89B0D0CC2CAA322D9DCDEE5630061BF9FE13B6'
    $root = Expand-ZipComponent $archive 'vort-shaders-b410b9f'
    Find-ContainingFolder $root @('vort_Motion.fx')
}

$result.Quint = Invoke-Component 'Quint' {
    $archive = Get-VerifiedFile 'quint-98fed77.zip' 'https://github.com/martymcmodding/qUINT/archive/98fed77b26669202027f575a6d8f590426c21ebd.zip' '2F6FF2F5DD39FF400C07ECBBFD1156604459F44D9028D07FA6D98B84D4CFBFA9'
    $root = Expand-ZipComponent $archive 'quint-98fed77'
    Find-ContainingFolder $root @('Shaders\qUINT_mxao.fx', 'Shaders\qUINT_common.fxh')
}

$result.Mesa = Invoke-Component 'Mesa' {
    $archive = Get-VerifiedFile 'mesa3d-26.2.0-release-msvc.7z' 'https://github.com/pal1000/mesa-dist-win/releases/download/26.2.0/mesa3d-26.2.0-release-msvc.7z' 'DCB2719EF346DAB5B609FCB193A5F13CFC4B0502E3F4DE1AD43D349477402F47'
    $sevenZip = Get-VerifiedFile '7zr-26.02.exe' 'https://www.7-zip.org/a/7zr.exe' '56B8CC9F4971CEF253644FAFE54063ED7FDCA551D4DEE0F8C6BAA81B855ACD72'
    $root = Join-Path $CachePath 'mesa-26.2.0-msvc'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        & $sevenZip x $archive "-o$root" -y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7-Zip extraction failed with exit code $LASTEXITCODE." }
    }
    Find-ContainingFolder $root @('opengl32.dll', 'libgallium_wgl.dll')
}

if ($IncludeRHIInstaller) {
    $result.RHIInstaller = Invoke-Component 'RHIInstaller' {
        Get-VerifiedFile 'RHI-Setup-2.4.9.exe' 'https://github.com/RankFTW/RHI/releases/download/RHI-2.4.9/RHI-Setup.exe' 'C3E325CABE2C056010C9F0DC6F6A2CEFBE7E85F6EA99935BFAC573162F03E9E2'
    }
}

$manifest = Join-Path $CachePath 'prerequisites.json'
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifest -Encoding UTF8
Write-Output $manifest
