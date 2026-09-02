[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $UserConfigPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\OpenMW'),
    [switch] $ApplyStableSettings,
    [string] $ImportProfilePath,
    [string] $ModRoot,
    [string] $BaseDataPath,
    [string] $OverwritePath,
    [string[]] $AdditionalDataPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$defaultUserConfigPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\OpenMW'
$targetsLiveProfile = [StringComparer]::OrdinalIgnoreCase.Equals(
    [IO.Path]::GetFullPath($UserConfigPath).TrimEnd('\'),
    [IO.Path]::GetFullPath($defaultUserConfigPath).TrimEnd('\')
)
if ($targetsLiveProfile -and (Get-Process openmw, openmw-launcher -ErrorAction SilentlyContinue)) {
    throw 'Close OpenMW and the OpenMW Launcher before changing the profile.'
}

$activeCfg = Join-Path $UserConfigPath 'openmw.cfg'
$activeSettings = Join-Path $UserConfigPath 'settings.cfg'
foreach ($path in @($activeCfg, $activeSettings)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing active configuration: $path" }
}

function Read-TextFile([string] $Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $encoding = [Text.UTF8Encoding]::new($bom)
    [pscustomobject]@{
        Lines = [Collections.Generic.List[string]]::new([string[]][IO.File]::ReadAllLines($Path, $encoding))
        Encoding = $encoding
        NewLine = if ([Text.Encoding]::UTF8.GetString($bytes).Contains("`r`n")) { "`r`n" } else { "`n" }
    }
}

function Write-TextFile($Info, [string] $Path) {
    [IO.File]::WriteAllText($Path, (($Info.Lines -join $Info.NewLine) + $Info.NewLine), $Info.Encoding)
}

function Set-IniValue($Info, [string] $Section, [string] $Key, [string] $Value) {
    $lines = $Info.Lines
    $start = $lines.FindIndex([Predicate[string]] { param($line) $line -eq "[$Section]" })
    if ($start -lt 0) {
        if ($lines.Count -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
        $lines.Add("[$Section]"); $lines.Add("$Key = $Value"); return
    }
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\[') { $end = $i; break } }
    for ($i = $start + 1; $i -lt $end; $i++) {
        if ($lines[$i] -match ('^' + [regex]::Escape($Key) + '\s*=')) { $lines[$i] = "$Key = $Value"; return }
    }
    $lines.Insert($end, "$Key = $Value")
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$settingsInfo = Read-TextFile $activeSettings
if ($ApplyStableSettings) {
    Set-IniValue $settingsInfo 'Video' 'antialiasing' '0'
    Set-IniValue $settingsInfo 'Video' 'vsync mode' '0'
    Set-IniValue $settingsInfo 'Video' 'framerate limit' '0.0'
    Set-IniValue $settingsInfo 'Camera' 'viewing distance' '16310'
    Set-IniValue $settingsInfo 'Terrain' 'distant terrain' 'true'
    Set-IniValue $settingsInfo 'Terrain' 'object paging' 'true'
    Set-IniValue $settingsInfo 'Terrain' 'object paging active grid' 'true'
}

if ($ImportProfilePath) {
    if (-not $ModRoot) { throw '-ModRoot is required with -ImportProfilePath.' }
    $sourceCfg = Join-Path $ImportProfilePath 'openmw.cfg'
    $sourceSettings = Join-Path $ImportProfilePath 'settings.cfg'
    foreach ($path in @($sourceCfg, $sourceSettings, $ModRoot)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing profile input: $path" }
    }
    $sourceLines = [IO.File]::ReadAllLines($sourceCfg)
    $modNames = @($sourceLines | Where-Object { $_ -match '^data=".*[/\\]mods[/\\](.+)"$' } | ForEach-Object { $Matches[1] })
    $dataPaths = @()
    if ($BaseDataPath) {
        $dataPaths += $BaseDataPath
    } else {
        $dataPaths += @($sourceLines | Where-Object { $_ -match '^data="(.+Morrowind[/\\]Data Files)"$' } | ForEach-Object { $Matches[1] })
    }
    $dataPaths += @($modNames | ForEach-Object { Join-Path $ModRoot $_ })
    if ($OverwritePath) { $dataPaths += $OverwritePath }
    if ($AdditionalDataPath) { $dataPaths += $AdditionalDataPath }
    $content = @($sourceLines | Where-Object { $_ -match '^content=' })
    $groundcover = @($sourceLines | Where-Object { $_ -match '^groundcover=' })
    foreach ($path in $dataPaths) { if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Missing data directory: $path" } }
    foreach ($line in @($content + $groundcover)) {
        $name = $line.Substring($line.IndexOf('=') + 1)
        if (-not ($dataPaths | Where-Object { Test-Path -LiteralPath (Join-Path $_ $name) -PathType Leaf })) { throw "Missing referenced plugin: $name" }
    }
    $cfgInfo = Read-TextFile $activeCfg
    $clean = [Collections.Generic.List[string]]::new()
    foreach ($line in $cfgInfo.Lines) { if ($line -notmatch '^(data|content|groundcover)=') { $clean.Add($line) } }
    $fallback = $clean.FindIndex([Predicate[string]] { param($line) $line -match '^fallback-archive=' })
    if ($fallback -lt 0) { $fallback = 0 }
    $clean.InsertRange($fallback, [string[]]$groundcover)
    foreach ($path in $dataPaths) { $clean.Add("data=`"$path`"") }
    $clean.AddRange([string[]]$content)
    $cfgInfo.Lines = $clean
    if ($PSCmdlet.ShouldProcess($activeCfg, 'Import validated OpenMW profile')) {
        Copy-Item $activeCfg "$activeCfg.before-profile-$stamp.bak"
        Write-TextFile $cfgInfo $activeCfg
    }

    $sourceSettingsLines = [IO.File]::ReadAllLines($sourceSettings)
    $gcStart = [Array]::IndexOf($sourceSettingsLines, '[Groundcover]')
    if ($gcStart -ge 0) {
        $gcEnd = $sourceSettingsLines.Length
        for ($i = $gcStart + 1; $i -lt $sourceSettingsLines.Length; $i++) { if ($sourceSettingsLines[$i] -match '^\[') { $gcEnd = $i; break } }
        $existingStart = $settingsInfo.Lines.FindIndex([Predicate[string]] { param($line) $line -eq '[Groundcover]' })
        if ($existingStart -ge 0) {
            $existingEnd = $settingsInfo.Lines.Count
            for ($i = $existingStart + 1; $i -lt $settingsInfo.Lines.Count; $i++) { if ($settingsInfo.Lines[$i] -match '^\[') { $existingEnd = $i; break } }
            $settingsInfo.Lines.RemoveRange($existingStart, $existingEnd - $existingStart)
        }
        $settingsInfo.Lines.AddRange([string[]]$sourceSettingsLines[$gcStart..($gcEnd - 1)])
    }
}

if ($ApplyStableSettings -or $ImportProfilePath) {
    if ($PSCmdlet.ShouldProcess($activeSettings, 'Apply stable OpenMW settings')) {
        Copy-Item $activeSettings "$activeSettings.before-stable-$stamp.bak"
        Write-TextFile $settingsInfo $activeSettings
    }
}
