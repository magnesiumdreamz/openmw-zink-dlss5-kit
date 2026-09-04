param([Parameter(Mandatory)][string]$OriginalShaderPath)
$ErrorActionPreference='Stop'
$test=Join-Path ([IO.Path]::GetTempPath()) ('rafael-patch-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $test | Out-Null
$names=@('HBAO.omwfx','VAIO.omwfx'); $before=@{}
foreach($name in $names){
    Copy-Item -LiteralPath (Join-Path $OriginalShaderPath $name) -Destination $test
    $before[$name]=(Get-FileHash (Join-Path $test $name)).Hash
}
$patch=Join-Path $PSScriptRoot 'Patch-RafaelPostProcessing.ps1'
& $patch -ShaderPath $test -WhatIf
if(Test-Path (Join-Path $test '.compat-backups')){throw 'WhatIf created backups.'}
& $patch -ShaderPath $test
$after=@{};foreach($name in $names){$after[$name]=(Get-FileHash (Join-Path $test $name)).Hash}
if(-not ([IO.File]::ReadAllText((Join-Path $test 'VAIO.omwfx')).StartsWith('uniform_int'))){throw 'VAIO declaration header regression.'}
$backup=@(Get-ChildItem (Join-Path $test '.compat-backups') -Directory)
& $patch -ShaderPath $test
if(@(Get-ChildItem (Join-Path $test '.compat-backups') -Directory).Count -ne $backup.Count){throw 'Second apply created a backup.'}
foreach($name in $names){if((Get-FileHash (Join-Path $test $name)).Hash -ne $after[$name]){throw 'Second apply changed bytes.'}}
& $patch -ShaderPath $test -RestoreBackup $backup[0].FullName
foreach($name in $names){if((Get-FileHash (Join-Path $test $name)).Hash -ne $before[$name]){throw 'Restore is not byte-exact.'}}
# Corrupt only a disposable fixture; neither target file may change on rejection.
[IO.File]::AppendAllText((Join-Path $test 'VAIO.omwfx'),'unrecognized edit')
$edited=(Get-FileHash (Join-Path $test 'VAIO.omwfx')).Hash
$refused=$false
try {& $patch -ShaderPath $test} catch {if($_.Exception.Message -notlike '*Unsupported or partly modified*'){throw};$refused=$true}
if(-not $refused){throw 'Unknown shader accepted.'}
if((Get-FileHash (Join-Path $test 'HBAO.omwfx')).Hash -ne $before['HBAO.omwfx'] -or (Get-FileHash (Join-Path $test 'VAIO.omwfx')).Hash -ne $edited){throw 'Rejection changed files.'}
Write-Output "PASS: dry run, output hashes, idempotence, byte-exact restore, unknown-version rejection, VAIO header. Fixtures: $test"
