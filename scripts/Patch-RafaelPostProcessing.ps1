# SPDX-License-Identifier: GPL-3.0-only
# Shader snippets adapted from Rafael's Shader Pack (Rafael), GPL v3.
# See docs/licenses/Rafael-GPL-3.0.txt and docs/postprocessing-compatibility.md.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ShaderPath,
    [string]$RestoreBackup
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Get-Process openmw,openmw-launcher -ErrorAction SilentlyContinue) { throw 'Close OpenMW and its launcher first.' }
$root = (Resolve-Path -LiteralPath $ShaderPath).Path
$names = @('HBAO.omwfx','VAIO.omwfx')
$original = @('193DEECACABC29B71F793401DBDCC8879719C3C6500B06579CDE7756714F4F4D','44C5FE08468832EBAB9F9A06309C0C9F91BB998C4C066549FD9977553C635779')
$patched = @('1077C667E9538E210AF091973117A1732F9E10AAE9BD3865A91B84AB2C9A5D18','C86C61A909FE01948EF52E2B05D7E6D26EE7CE58CF1662BE263E481D1EC1AC8B')
function Normalize([string]$s) { return $s.Replace("`r`n","`n").TrimEnd() + "`n" }
function Hash([string]$s) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes((Normalize $s)))).Replace('-','') }
    finally { $sha.Dispose() }
}
function Replace-Once([string]$s,[string]$old,[string]$new) {
    if ([regex]::Matches($s,[regex]::Escape($old)).Count -ne 1) { throw "Unexpected shader layout at: $old" }
    return $s.Replace($old,$new)
}
$texts=@(); $hashes=@()
foreach($name in $names) {
    $text=[IO.File]::ReadAllText((Join-Path $root $name))
    $texts+=,(Normalize $text); $hashes+=,(Hash $text)
}
if ($RestoreBackup) {
    $restoreTexts=@()
    for($i=0;$i -lt 2;$i++) {
        $file=Join-Path $RestoreBackup ($names[$i]+'.before')
        $text=[IO.File]::ReadAllText($file)
        if ((Hash $text) -ne $original[$i]) { throw "Backup is not a supported original: $file" }
        if ($hashes[$i] -notin @($original[$i],$patched[$i])) { throw "Refusing to overwrite later edits to $($names[$i])." }
        $restoreTexts+=,$text
    }
    if ($PSCmdlet.ShouldProcess($root,'Restore original HBAO and VAIO shaders')) {
        # Preserve current bytes too, including for recovery from an interrupted restore.
        $safety=Join-Path $root ('.compat-backups\before-restore-'+[guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $safety -Force | Out-Null
        foreach($name in $names){Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $safety ($name+'.before'))}
        try { foreach($name in $names){Copy-Item -LiteralPath (Join-Path $RestoreBackup ($name+'.before')) -Destination (Join-Path $root $name) -Force} }
        catch { foreach($name in $names){Copy-Item -LiteralPath (Join-Path $safety ($name+'.before')) -Destination (Join-Path $root $name) -Force}; throw }
        Write-Output "Original shaders restored. Previous files saved in $safety"
    }
    return
}
if ($hashes[0] -eq $patched[0] -and $hashes[1] -eq $patched[1]) { Write-Output 'Both shaders already have this compatibility patch.'; return }
for($i=0;$i -lt 2;$i++) {
    if ($hashes[$i] -ne $original[$i]) { throw "Unsupported or partly modified $($names[$i]). No files changed. Use the tested Rafael 2.1 pack originals; do not force this patch onto other versions." }
}
$old='            float weight = exp2(-abs(depth - s_depth) / depth / falloff);'
if ([regex]::Matches($texts[0],[regex]::Escape($old)).Count -ne 2) { throw 'Expected two HBAO blur passes.' }
$new='            float weight = exp2(-abs(depth - s_depth) / max(abs(depth), 1e-6) / max(falloff, 1e-6));'
$index=$texts[0].IndexOf($old)
$texts[0]=$texts[0].Remove($index,$old.Length).Insert($index,"            // OpenMW/Zink compatibility: avoid 0/0 for cleared/near-zero depth.`n"+$new)
$texts[0]=Replace-Once $texts[0] $old ("            // Keep the second blur consistent with the guarded first pass.`n"+$new)
$header=@'
uniform_int CompatibilityLightLimit
{
    default = 64;
    min = 8;
    max = 256;
    display_name = "Volumetric light limit (compatibility)";
    description = "Maximum lights evaluated per pixel. Lower values reduce work but may omit some volumetric light glows. Does not limit normal scene lighting.";
}

'@
# OMWFX rejects top-level // comments: the first token must be a declaration.
$texts[1]=(Normalize $header)+"`n"+$texts[1]
$texts[1]=Replace-Once $texts[1] '        direction = direction / worldDistance;' "        if (!(worldDistance > 0.0001f))`n            return sumColor;`n        direction = direction / worldDistance;"
$texts[1]=Replace-Once $texts[1] '        for (int i = 0; i < omw_GetPointLightCount(); i++)' "        int lightCount = min(max(int(omw_GetPointLightCount()), 0), clamp(CompatibilityLightLimit, 8, 256));`n        for (int i = 0; i < lightCount; i++)"
$texts[1]=Replace-Once $texts[1] '        else if (minD / maxD > DepthThresholdPercentage)' '        else if (maxD > 0.0001f && minD / maxD > DepthThresholdPercentage)'
$texts[1]=Replace-Once $texts[1] "        if (!DownscaleEffects || omw.isUnderwater)`n            return;" "        if (!DownscaleEffects || omw.isUnderwater)`n        {`n            // The pass still runs: define its output instead of retaining undefined data.`n            omw_FragColor = float4(0.0f);`n            return;`n        }"
for($i=0;$i -lt 2;$i++) { if ((Hash $texts[$i]) -ne $patched[$i]) { throw "Generated shader differs from tested patch: $($names[$i]). No files changed." } }
if (-not $PSCmdlet.ShouldProcess($root,'Back up and patch HBAO and VAIO')) { return }
$backup=Join-Path $root ('.compat-backups\'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach($name in $names){Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $backup ($name+'.before'))}
try {
    for($i=0;$i -lt 2;$i++) {
        [IO.File]::WriteAllText((Join-Path $root $names[$i]),$texts[$i],[Text.UTF8Encoding]::new($false))
        if ((Hash ([IO.File]::ReadAllText((Join-Path $root $names[$i])))) -ne $patched[$i]) { throw 'Write verification failed.' }
    }
} catch {
    foreach($name in $names){Copy-Item -LiteralPath (Join-Path $backup ($name+'.before')) -Destination (Join-Path $root $name) -Force}
    throw
}
Write-Output "Compatibility patch applied. Backup: $backup"
Write-Output 'Enable HBAO and VAIO in OpenMW yourself. Compilation was tested; eliminating driver hangs is not yet verified.'
