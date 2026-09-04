param([switch]$ValidateOnly)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='HBAO + VAIO compatibility setup'
$form.ClientSize=New-Object Drawing.Size(730,440)
$form.StartPosition='CenterScreen'
$form.FormBorderStyle='FixedDialog'; $form.MaximizeBox=$false
$label=New-Object Windows.Forms.Label
$label.Text="Close OpenMW first. Install Rafael's Shader Pack 2.1 separately, then choose the folder containing HBAO.omwfx and VAIO.omwfx (usually OpenMW\resources\vfs\shaders).`r`n`r`nThis optional patch adds zero-division guards, initializes VAIO's skipped light output, and limits volumetric light calculations to 64. Some crowded scenes may lose light glows; normal scene lighting is unchanged.`r`n`r`nBoth effects compiled in our test. This is NOT a confirmed fix for NVIDIA driver hangs. It does not change NR, enable effects, or disable MXAO automatically. Unknown shader versions are refused. Originals are backed up."
$label.Location=New-Object Drawing.Point(20,15); $label.Size=New-Object Drawing.Size(685,180)
$form.Controls.Add($label)
$path=New-Object Windows.Forms.TextBox
$path.Location=New-Object Drawing.Point(20,205); $path.Size=New-Object Drawing.Size(570,25)
$form.Controls.Add($path)
$browse=New-Object Windows.Forms.Button
$browse.Text='Browse...'; $browse.Location=New-Object Drawing.Point(605,202)
$browse.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog; $dialog.Description='Choose the folder containing BOTH shader files'; if($dialog.ShowDialog() -eq 'OK'){$path.Text=$dialog.SelectedPath}; $dialog.Dispose()})
$form.Controls.Add($browse)
$output=New-Object Windows.Forms.TextBox
$output.Multiline=$true; $output.ReadOnly=$true; $output.ScrollBars='Vertical'
$output.Location=New-Object Drawing.Point(20,290); $output.Size=New-Object Drawing.Size(685,130)
$form.Controls.Add($output)
$patcher=Join-Path $PSScriptRoot 'Patch-RafaelPostProcessing.ps1'
$apply=New-Object Windows.Forms.Button
$apply.Text='Apply patch'; $apply.Location=New-Object Drawing.Point(20,245); $apply.Width=120
$apply.Add_Click({try {$output.Text=(& $patcher -ShaderPath $path.Text.Trim() -Confirm:$false | Out-String)} catch {$output.Text=$_.Exception.Message}})
$form.Controls.Add($apply)
$restore=New-Object Windows.Forms.Button
$restore.Text='Restore backup...'; $restore.Location=New-Object Drawing.Point(160,245); $restore.Width=150
$restore.Add_Click({
    $dialog=New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description='Choose a backup folder containing both .omwfx.before files inside .compat-backups'
    if($dialog.ShowDialog() -eq 'OK'){
        if([Windows.Forms.MessageBox]::Show('Restore original shaders to the selected shader folder?','Restore','YesNo','Question') -eq 'Yes'){
            try {$output.Text=(& $patcher -ShaderPath $path.Text.Trim() -RestoreBackup $dialog.SelectedPath -Confirm:$false | Out-String)} catch {$output.Text=$_.Exception.Message}
        }
    }
    $dialog.Dispose()
})
$form.Controls.Add($restore)
if ($ValidateOnly) {
    if ($form.Controls.Count -ne 6) { throw 'Unexpected wizard control count.' }
    Write-Output 'Wizard controls created successfully.'
} else { [void]$form.ShowDialog() }
$form.Dispose()
