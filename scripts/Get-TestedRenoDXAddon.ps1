[CmdletBinding()]
param(
    [string] $RenoDXPath,
    [string] $CachePath = (Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\renodx-4.70')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$addonHash = 'D5ADF82EB44B065F4C590AC91FE824BAB07AFEA0EB9F994BDE936710C8593952'
$archiveHash = 'D6E356D01B429AF6288F488A4926C44F1D779A7D4586EE8C79D04D3A09A536E6'
$url = 'https://github.com/RankFTW/rhi-repo/releases/download/renodx-dlss5-4.70/renodx-dlss5_4.70.zip'
if ($RenoDXPath) {
    foreach ($file in @(Get-ChildItem -LiteralPath $RenoDXPath -Recurse -File -Filter 'renodx-dlss5.addon64')) {
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -eq $addonHash) { return $file.FullName }
    }
}
New-Item -ItemType Directory -Path $CachePath -Force | Out-Null
$addon = Join-Path $CachePath 'renodx-dlss5.addon64'
if ((Test-Path -LiteralPath $addon) -and (Get-FileHash -LiteralPath $addon).Hash -eq $addonHash) { return $addon }
$archive = Join-Path $CachePath 'renodx-dlss5_4.70.zip'
if (-not (Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive).Hash -ne $archiveHash) {
    Write-Host 'Downloading the tested RenoDX 4.70 add-on (NVIDIA DLLs are not included)...'
    & curl.exe -L --fail --show-error --connect-timeout 20 --retry 2 $url -o $archive
    if ($LASTEXITCODE -ne 0) { throw "RenoDX download failed. Download $url manually and place its extracted add-on in -RenoDXPath, then retry." }
}
if ((Get-FileHash -LiteralPath $archive).Hash -ne $archiveHash) { throw 'RenoDX archive hash mismatch. No add-on was installed.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -ne 'renodx-dlss5.addon64') { throw 'Unexpected RenoDX archive layout.' }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.Entries[0], $addon, $true)
} finally { $zip.Dispose() }
if ((Get-FileHash -LiteralPath $addon).Hash -ne $addonHash) { throw 'RenoDX add-on hash mismatch. No add-on was installed.' }
return $addon
