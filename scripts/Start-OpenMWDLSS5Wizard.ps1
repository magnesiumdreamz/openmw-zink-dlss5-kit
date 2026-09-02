[CmdletBinding()]
param([switch] $SelfTest)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$backend = Join-Path $PSScriptRoot 'Install-OpenMWDLSS5Kit.ps1'
$prerequisiteDownloader = Join-Path $PSScriptRoot 'Get-OpenMWDLSS5Prerequisites.ps1'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $backend -PathType Leaf)) {
    throw "Installer backend is missing: $backend"
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# The final page can register ReShade under ProgramData. Elevating once at startup
# avoids losing the user's completed form when Windows displays the UAC prompt.
if (-not $SelfTest -and -not (Test-Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs | Out-Null
    } catch {
        [Windows.Forms.MessageBox]::Show(
            'Setup was cancelled. The wizard needs administrator permission so it can optionally register ReShade for the new OpenMW copy.',
            'OpenMW Zink DLSS 5 Setup', 'OK', 'Information') | Out-Null
    }
    return
}

[Windows.Forms.Application]::EnableVisualStyles()
$font = [Drawing.Font]::new('Segoe UI', 9)
$headingFont = [Drawing.Font]::new('Segoe UI Semibold', 16)
$subheadingFont = [Drawing.Font]::new('Segoe UI Semibold', 10)

$form = [Windows.Forms.Form]::new()
$form.Text = 'OpenMW Zink DLSS 5 Setup'
$form.Size = [Drawing.Size]::new(900, 720)
$form.MinimumSize = [Drawing.Size]::new(820, 650)
$form.StartPosition = 'CenterScreen'
$form.Font = $font

$tabs = [Windows.Forms.TabControl]::new()
$tabs.Location = [Drawing.Point]::new(12, 12)
$tabs.Size = [Drawing.Size]::new(858, 610)
$tabs.Anchor = 'Top,Bottom,Left,Right'
$form.Controls.Add($tabs)

$pages = @()
foreach ($name in @('Welcome', 'Required folders', 'Setup options', 'Review and install')) {
    $page = [Windows.Forms.TabPage]::new($name)
    $page.AutoScroll = $true
    $tabs.TabPages.Add($page) | Out-Null
    $pages += $page
}

function Add-Label($Parent, [string] $Text, [int] $X, [int] $Y, [int] $Width, [int] $Height, $Font = $script:font) {
    $label = [Windows.Forms.Label]::new()
    $label.Text = $Text
    $label.Location = [Drawing.Point]::new($X, $Y)
    $label.Size = [Drawing.Size]::new($Width, $Height)
    $label.Font = $Font
    $Parent.Controls.Add($label)
    return $label
}

function Add-Link($Parent, [string] $Text, [string] $Url, [int] $X, [int] $Y, [int] $Width) {
    $link = [Windows.Forms.LinkLabel]::new()
    $link.Text = $Text
    $link.Location = [Drawing.Point]::new($X, $Y)
    $link.Size = [Drawing.Size]::new($Width, 24)
    $link.Add_LinkClicked({ Start-Process $Url }.GetNewClosure())
    $Parent.Controls.Add($link)
}

$fields = @{}
function Add-FolderField($Parent, [string] $Key, [string] $Title, [string] $Help, [int] $Y) {
    Add-Label $Parent $Title 24 $Y 190 24 $subheadingFont | Out-Null
    $box = [Windows.Forms.TextBox]::new()
    $box.Location = [Drawing.Point]::new(220, $Y)
    $box.Size = [Drawing.Size]::new(500, 24)
    $box.Anchor = 'Top,Left,Right'
    $Parent.Controls.Add($box)
    $fields[$Key] = $box
    $button = [Windows.Forms.Button]::new()
    $button.Text = 'Browse...'
    $button.Location = [Drawing.Point]::new(730, $Y - 1)
    $button.Size = [Drawing.Size]::new(90, 27)
    $button.Anchor = 'Top,Right'
    $button.Add_Click({
        $dialog = [Windows.Forms.FolderBrowserDialog]::new()
        $dialog.Description = $Title
        if ($box.Text -and (Test-Path -LiteralPath $box.Text -PathType Container)) { $dialog.SelectedPath = $box.Text }
        if ($dialog.ShowDialog() -eq 'OK') { $box.Text = $dialog.SelectedPath }
        $dialog.Dispose()
    }.GetNewClosure())
    $Parent.Controls.Add($button)
    Add-Label $Parent $Help 220 ($Y + 27) 600 34 | Out-Null
}

# Welcome page
Add-Label $pages[0] 'OpenMW Zink DLSS 5 Setup' 28 24 760 42 $headingFont | Out-Null
Add-Label $pages[0] 'This wizard creates a separate experimental OpenMW copy. It does not replace your normal OpenMW folder or include Morrowind game files.' 28 78 770 50 | Out-Null
Add-Label $pages[0] 'Before continuing, install or collect:' 28 140 760 28 $subheadingFont | Out-Null
Add-Label $pages[0] "1. A working OpenMW 0.51.0 installation connected to a legal copy of Morrowind.`r`n2. Mesa for Windows, ReShade shader files, VORT shaders, qUINT, and authorized RHI/RenoDX files.`r`n3. Git for Windows and Visual Studio 2022 Build Tools with Desktop development with C++.`r`n4. An NVIDIA RTX GPU and a current driver. This project is verified only on an RTX 3090.`r`n5. ReShade may already be installed, or the wizard can download and install its pinned Vulkan layer." 42 178 760 130 | Out-Null
Add-Label $pages[0] 'The automatic feeder option downloads source code and builds the patched feeder locally. It cannot download proprietary RenoDX/NVIDIA runtime DLLs.' 28 320 770 52 | Out-Null
Add-Link $pages[0] 'Open the pinned downloads page' 'https://github.com/magnesiumdreamz/openmw-zink-dlss5-kit/blob/main/docs/downloads.md' 28 390 330
Add-Link $pages[0] 'Open the full installation guide' 'https://github.com/magnesiumdreamz/openmw-zink-dlss5-kit/blob/main/docs/installation.md' 28 424 330

# Required folders page
Add-Label $pages[1] 'Choose the required folders' 24 18 760 38 $headingFont | Out-Null
Add-Label $pages[1] 'Use extracted component folders, not ZIP files. The wizard checks these paths before installation.' 24 58 760 30 | Out-Null
$downloadPrerequisites = [Windows.Forms.Button]::new()
$downloadPrerequisites.Text = 'Download and fill open-source requirements'
$downloadPrerequisites.Location = [Drawing.Point]::new(24, 92)
$downloadPrerequisites.Size = [Drawing.Size]::new(310, 32)
$pages[1].Controls.Add($downloadPrerequisites)
$prerequisiteStatus = Add-Label $pages[1] 'Downloads are pinned and SHA-256 verified. Failed items remain available through Browse.' 350 95 465 36
Add-FolderField $pages[1] 'OpenMWPath' 'Existing OpenMW' 'The folder containing openmw.exe. It is detected when installed in a standard location; it is never modified.' 140
Add-FolderField $pages[1] 'DestinationPath' 'New DLSS 5 copy' 'A new or empty folder for the separate Zink/DLSS installation. You may type a folder that does not exist yet.' 210
Add-FolderField $pages[1] 'MesaPath' 'Mesa' 'Downloaded and extracted automatically, or select a folder containing opengl32.dll and libgallium_wgl.dll.' 280
Add-FolderField $pages[1] 'ReShadeShaderPath' 'ReShade shaders' 'Downloaded automatically, or select the extracted folder containing the Shaders subfolder.' 350
Add-FolderField $pages[1] 'VortPath' 'VORT motion shaders' 'Downloaded automatically, or select the folder containing vort_Motion.fx.' 420
Add-FolderField $pages[1] 'QuintPath' 'qUINT / MXAO' 'Downloaded automatically, or select the folder containing the Shaders subfolder and qUINT_mxao.fx.' 490
Add-FolderField $pages[1] 'RenoDXPath' 'RHI / RenoDX files' 'Must be selected after authorized RHI setup; it must contain renodx-dlss5.addon64 and NVIDIA DLSS DLLs.' 560

# Options page
Add-Label $pages[2] 'Choose setup options' 24 18 760 38 $headingFont | Out-Null
$autoFeeder = [Windows.Forms.RadioButton]::new()
$autoFeeder.Text = 'Build the patched feeder automatically (recommended)'
$autoFeeder.Location = [Drawing.Point]::new(28, 70)
$autoFeeder.Size = [Drawing.Size]::new(480, 26)
$autoFeeder.Checked = $true
$pages[2].Controls.Add($autoFeeder)
Add-Label $pages[2] 'Downloads pinned source/headers, applies the resize-safety patch, and compiles locally. Requires Git and Visual C++ Build Tools.' 48 98 730 38 | Out-Null
$existingFeeder = [Windows.Forms.RadioButton]::new()
$existingFeeder.Text = 'Use an already-built validated feeder'
$existingFeeder.Location = [Drawing.Point]::new(28, 140)
$existingFeeder.Size = [Drawing.Size]::new(360, 26)
$pages[2].Controls.Add($existingFeeder)
Add-FolderField $pages[2] 'FeederPath' 'Feeder folder' 'Must contain dlss5-feed.addon64 and DLSS5_Feed.fx. Used only when the option above is selected.' 170
$fields.FeederPath.Enabled = $false
$existingFeeder.Add_CheckedChanged({ $fields.FeederPath.Enabled = $existingFeeder.Checked })

$stableSettings = [Windows.Forms.CheckBox]::new()
$stableSettings.Text = 'Apply tested stability settings (recommended)'
$stableSettings.Location = [Drawing.Point]::new(28, 245)
$stableSettings.Size = [Drawing.Size]::new(420, 26)
$stableSettings.Checked = $true
$pages[2].Controls.Add($stableSettings)
Add-Label $pages[2] 'Disables MSAA, VSync, and the frame limiter; enables stable object paging and a moderate view distance. Existing settings are backed up.' 48 274 730 40 | Out-Null

$installLayer = [Windows.Forms.CheckBox]::new()
$installLayer.Text = 'Download, install, and verify the ReShade Vulkan layer (recommended)'
$installLayer.Location = [Drawing.Point]::new(28, 322)
$installLayer.Size = [Drawing.Size]::new(620, 26)
$installLayer.Checked = $true
$pages[2].Controls.Add($installLayer)
Add-Label $pages[2] 'Uses the pinned ReShade 6.8.0 full add-on installer, verifies its SHA-256, installs the system Vulkan layer, and verifies the registry entry.' 48 351 730 40 | Out-Null

$shortcuts = [Windows.Forms.CheckBox]::new()
$shortcuts.Text = 'Create Desktop shortcuts for the game and launcher'
$shortcuts.Location = [Drawing.Point]::new(28, 400)
$shortcuts.Size = [Drawing.Size]::new(470, 26)
$shortcuts.Checked = $true
$pages[2].Controls.Add($shortcuts)
$registerReShade = [Windows.Forms.CheckBox]::new()
$registerReShade.Text = 'Register this copy with the installed ReShade Vulkan layer'
$registerReShade.Location = [Drawing.Point]::new(28, 434)
$registerReShade.Size = [Drawing.Size]::new(520, 26)
$registerReShade.Checked = $true
$registerReShade.Enabled = $false
$pages[2].Controls.Add($registerReShade)
Add-Label $pages[2] 'This limits the installed Vulkan layer to the new openmw.exe and backs up the previous registration. It is required when installing the layer above.' 48 463 730 40 | Out-Null
$installLayer.Add_CheckedChanged({
    if ($installLayer.Checked) { $registerReShade.Checked = $true; $registerReShade.Enabled = $false }
    else { $registerReShade.Enabled = $true }
})

Add-Label $pages[2] 'ReShade settings filename' 28 513 210 24 $subheadingFont | Out-Null
$reshadeConfig = [Windows.Forms.ComboBox]::new()
$reshadeConfig.DropDownStyle = 'DropDownList'
$reshadeConfig.Items.AddRange(@('ReShade.ini', 'ReShade2.ini', 'ReShade3.ini'))
$reshadeConfig.SelectedIndex = 0
$reshadeConfig.Location = [Drawing.Point]::new(245, 510)
$reshadeConfig.Size = [Drawing.Size]::new(180, 26)
$pages[2].Controls.Add($reshadeConfig)
Add-Label $pages[2] 'Leave this at ReShade.ini unless your existing Vulkan setup explicitly uses a numbered file.' 28 543 730 36 | Out-Null

$importProfile = [Windows.Forms.CheckBox]::new()
$importProfile.Text = 'Import an existing OpenMW mod and groundcover profile (advanced)'
$importProfile.Location = [Drawing.Point]::new(28, 593)
$importProfile.Size = [Drawing.Size]::new(590, 26)
$pages[2].Controls.Add($importProfile)
Add-Label $pages[2] 'Enable this only when moving a saved openmw.cfg/settings.cfg profile to known mod folders. Every referenced plugin is validated first.' 48 622 730 42 | Out-Null
Add-FolderField $pages[2] 'ImportProfilePath' 'Saved profile' 'Folder containing the source openmw.cfg and settings.cfg.' 680
Add-FolderField $pages[2] 'ModRoot' 'Mod root' 'Folder whose immediate subfolders correspond to mod entries in the saved profile.' 750
Add-FolderField $pages[2] 'BaseDataPath' 'Morrowind data' 'Your legal Morrowind Data Files folder. Optional when the saved profile already contains a valid path.' 820
Add-FolderField $pages[2] 'OverwritePath' 'Overwrite folder' 'Optional mod-manager overwrite directory.' 890
Add-Label $pages[2] 'Other data folders (one full folder path per line)' 24 965 500 24 $subheadingFont | Out-Null
$additionalPaths = [Windows.Forms.TextBox]::new()
$additionalPaths.Multiline = $true
$additionalPaths.ScrollBars = 'Vertical'
$additionalPaths.Location = [Drawing.Point]::new(24, 995)
$additionalPaths.Size = [Drawing.Size]::new(790, 90)
$pages[2].Controls.Add($additionalPaths)
$profileControls = @($fields.ImportProfilePath, $fields.ModRoot, $fields.BaseDataPath, $fields.OverwritePath, $additionalPaths)
foreach ($control in $profileControls) { $control.Enabled = $false }
$importProfile.Add_CheckedChanged({ foreach ($control in $profileControls) { $control.Enabled = $importProfile.Checked } })

# Review page
Add-Label $pages[3] 'Review and install' 24 18 760 38 $headingFont | Out-Null
Add-Label $pages[3] 'Nothing is installed until you click Install. Close OpenMW and its launcher first.' 24 58 760 28 | Out-Null
$review = [Windows.Forms.RichTextBox]::new()
$review.Location = [Drawing.Point]::new(24, 95)
$review.Size = [Drawing.Size]::new(790, 220)
$review.ReadOnly = $true
$review.Font = [Drawing.Font]::new('Consolas', 9)
$review.Anchor = 'Top,Left,Right'
$pages[3].Controls.Add($review)
$installButton = [Windows.Forms.Button]::new()
$installButton.Text = 'Install'
$installButton.Location = [Drawing.Point]::new(24, 328)
$installButton.Size = [Drawing.Size]::new(130, 34)
$pages[3].Controls.Add($installButton)
$log = [Windows.Forms.RichTextBox]::new()
$log.Location = [Drawing.Point]::new(24, 375)
$log.Size = [Drawing.Size]::new(790, 155)
$log.ReadOnly = $true
$log.Font = [Drawing.Font]::new('Consolas', 8.5)
$log.Anchor = 'Top,Bottom,Left,Right'
$pages[3].Controls.Add($log)

$back = [Windows.Forms.Button]::new()
$back.Text = '< Back'
$back.Location = [Drawing.Point]::new(594, 635)
$back.Size = [Drawing.Size]::new(90, 30)
$back.Anchor = 'Bottom,Right'
$form.Controls.Add($back)
$next = [Windows.Forms.Button]::new()
$next.Text = 'Next >'
$next.Location = [Drawing.Point]::new(690, 635)
$next.Size = [Drawing.Size]::new(90, 30)
$next.Anchor = 'Bottom,Right'
$form.Controls.Add($next)
$close = [Windows.Forms.Button]::new()
$close.Text = 'Close'
$close.Location = [Drawing.Point]::new(786, 635)
$close.Size = [Drawing.Size]::new(84, 30)
$close.Anchor = 'Bottom,Right'
$form.Controls.Add($close)

function Get-InstallerParameters {
    $parameters = @{
        OpenMWPath = $fields.OpenMWPath.Text.Trim()
        DestinationPath = $fields.DestinationPath.Text.Trim()
        MesaPath = $fields.MesaPath.Text.Trim()
        ReShadeShaderPath = $fields.ReShadeShaderPath.Text.Trim()
        VortPath = $fields.VortPath.Text.Trim()
        QuintPath = $fields.QuintPath.Text.Trim()
        RenoDXPath = $fields.RenoDXPath.Text.Trim()
        ReShadeConfigName = [string]$reshadeConfig.SelectedItem
    }
    if ($autoFeeder.Checked) { $parameters.BuildPatchedFeeder = $true }
    else { $parameters.FeederPath = $fields.FeederPath.Text.Trim() }
    if ($stableSettings.Checked) { $parameters.ApplyStableSettings = $true }
    else { $parameters.SkipStableSettings = $true }
    if ($shortcuts.Checked) { $parameters.CreateDesktopShortcuts = $true }
    if ($installLayer.Checked) { $parameters.InstallReShadeVulkan = $true }
    if ($registerReShade.Checked) { $parameters.RegisterReShade = $true }
    if ($importProfile.Checked) {
        $parameters.ImportProfilePath = $fields.ImportProfilePath.Text.Trim()
        $parameters.ModRoot = $fields.ModRoot.Text.Trim()
        if ($fields.BaseDataPath.Text.Trim()) { $parameters.BaseDataPath = $fields.BaseDataPath.Text.Trim() }
        if ($fields.OverwritePath.Text.Trim()) { $parameters.OverwritePath = $fields.OverwritePath.Text.Trim() }
        $extra = @($additionalPaths.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($extra.Count) { $parameters.AdditionalDataPath = $extra }
    }
    return $parameters
}

function Test-PageInputs([int] $PageIndex) {
    $errors = [Collections.Generic.List[string]]::new()
    if ($PageIndex -ge 1) {
        foreach ($key in @('OpenMWPath','MesaPath','ReShadeShaderPath','VortPath','QuintPath','RenoDXPath')) {
            if (-not (Test-Path -LiteralPath $fields[$key].Text.Trim() -PathType Container)) { $errors.Add("Choose a valid $key folder.") }
        }
        if (-not $fields.DestinationPath.Text.Trim()) { $errors.Add('Choose a destination folder for the new copy.') }
        elseif ([StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($fields.OpenMWPath.Text.Trim()).TrimEnd('\'), [IO.Path]::GetFullPath($fields.DestinationPath.Text.Trim()).TrimEnd('\'))) { $errors.Add('The destination must be different from the existing OpenMW folder.') }
    }
    if ($PageIndex -ge 2) {
        if ($existingFeeder.Checked -and -not (Test-Path -LiteralPath $fields.FeederPath.Text.Trim() -PathType Container)) { $errors.Add('Choose the folder containing your validated feeder.') }
        if ($importProfile.Checked) {
            foreach ($key in @('ImportProfilePath','ModRoot')) { if (-not (Test-Path -LiteralPath $fields[$key].Text.Trim() -PathType Container)) { $errors.Add("Choose a valid $key folder.") } }
        }
    }
    if ($errors.Count) {
        [Windows.Forms.MessageBox]::Show(($errors -join "`r`n"), 'Please check these items', 'OK', 'Warning') | Out-Null
        return $false
    }
    return $true
}

function Update-Review {
    $p = Get-InstallerParameters
    $lines = @(
        "Existing OpenMW:  $($p.OpenMWPath)",
        "New DLSS 5 copy:  $($p.DestinationPath)",
        "Feeder:           $(if ($autoFeeder.Checked) {'download, patch, and build automatically'} else {$p.FeederPath})",
        "Stable settings:  $($stableSettings.Checked)",
        "Desktop shortcuts:$($shortcuts.Checked)",
        "Install Vulkan layer:$($installLayer.Checked)",
        "Register ReShade: $($registerReShade.Checked)",
        "Import mod profile:$($importProfile.Checked)"
    )
    $review.Text = $lines -join "`r`n"
}

$tabs.Add_SelectedIndexChanged({
    $back.Enabled = $tabs.SelectedIndex -gt 0
    $next.Enabled = $tabs.SelectedIndex -lt ($tabs.TabCount - 1)
    if ($tabs.SelectedIndex -eq 3) { Update-Review }
})
$back.Add_Click({ if ($tabs.SelectedIndex -gt 0) { $tabs.SelectedIndex-- } })
$next.Add_Click({ if (Test-PageInputs $tabs.SelectedIndex) { if ($tabs.SelectedIndex -lt 3) { $tabs.SelectedIndex++ } } })
$close.Add_Click({ $form.Close() })

$timer = [Windows.Forms.Timer]::new()
$timer.Interval = 300
$script:installJob = $null
$timer.Add_Tick({
    if (-not $script:installJob) { return }
    $output = @(Receive-Job -Job $script:installJob)
    if ($output.Count) { $log.AppendText(($output -join "`r`n") + "`r`n"); $log.ScrollToCaret() }
    if ($script:installJob.State -in @('Completed','Failed','Stopped')) {
        $timer.Stop()
        $state = $script:installJob.State
        $reason = $script:installJob.ChildJobs[0].JobStateInfo.Reason
        Receive-Job -Job $script:installJob -ErrorAction SilentlyContinue | ForEach-Object { $log.AppendText("$_`r`n") }
        Remove-Job -Job $script:installJob -Force
        $script:installJob = $null
        $installButton.Enabled = $true
        $back.Enabled = $true
        if ($state -eq 'Completed') {
            $log.AppendText("`r`nInstallation finished successfully.`r`n")
            [Windows.Forms.MessageBox]::Show('Installation finished. Use the new Desktop shortcut or the launcher in the destination folder.', 'Setup complete', 'OK', 'Information') | Out-Null
        } else {
            $log.AppendText("`r`nInstallation failed: $reason`r`n")
            [Windows.Forms.MessageBox]::Show('Installation did not finish. Read the log on this page; the backend stops on missing or unsafe inputs.', 'Setup did not finish', 'OK', 'Error') | Out-Null
        }
    }
})

$prerequisiteTimer = [Windows.Forms.Timer]::new()
$prerequisiteTimer.Interval = 300
$script:prerequisiteJob = $null
$script:prerequisiteHashOverride = $false

function Start-PrerequisiteDownload([bool] $AllowHashMismatch) {
    $downloadPrerequisites.Enabled = $false
    $script:prerequisiteHashOverride = $AllowHashMismatch
    $prerequisiteStatus.Text = if ($AllowHashMismatch) { 'Downloading unverified replacement after your confirmation...' } else { 'Downloading and verifying requirements. This can take a few minutes...' }
    $script:prerequisiteJob = Start-Job -ScriptBlock {
        param($Downloader, $HashOverride)
        $cache = Join-Path $env:LOCALAPPDATA 'OpenMW-DLSS5-Kit\components'
        if ($HashOverride) { & $Downloader -CachePath $cache -IncludeRHIInstaller -AllowHashMismatch | Out-Null }
        else { & $Downloader -CachePath $cache -IncludeRHIInstaller | Out-Null }
        Join-Path $cache 'prerequisites.json'
    } -ArgumentList $prerequisiteDownloader, $AllowHashMismatch
    $prerequisiteTimer.Start()
}

$prerequisiteTimer.Add_Tick({
    if (-not $script:prerequisiteJob) { return }
    if ($script:prerequisiteJob.State -notin @('Completed','Failed','Stopped')) { return }
    $prerequisiteTimer.Stop()
    $job = $script:prerequisiteJob
    $script:prerequisiteJob = $null
    $manifestPath = @(Receive-Job -Job $job -ErrorAction SilentlyContinue | Select-Object -Last 1)
    $state = $job.State
    $reason = $job.ChildJobs[0].JobStateInfo.Reason
    Remove-Job -Job $job -Force
    $downloadPrerequisites.Enabled = $true
    if ($state -ne 'Completed' -or -not $manifestPath -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $prerequisiteStatus.Text = 'Automatic download did not finish. Use Browse for the required folders.'
        [Windows.Forms.MessageBox]::Show("The automatic prerequisite step failed.`r`n`r`n$reason`r`n`r`nUse the Browse buttons or try again after checking the network connection.", 'Requirements need attention', 'OK', 'Warning') | Out-Null
        return
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $hashFailures = @(@('OpenMW','Mesa','ReShadeShaders','Vort','Quint','RHIInstaller') |
        ForEach-Object { $item = $manifest.$_; if ($item -and $item.Error -like 'Hash mismatch*') { $item } })
    if ($hashFailures.Count -and -not $script:prerequisiteHashOverride) {
        $details = ($hashFailures | ForEach-Object { $_.Error }) -join "`r`n`r`n"
        $choice = [Windows.Forms.MessageBox]::Show(
            "One or more downloads do not match the validated SHA-256 hashes.`r`n`r`n$details`r`n`r`nContinuing could install altered or corrupted code. Download and use these files anyway?",
            'Hash verification failed', 'YesNo', 'Warning', 'Button2')
        if ($choice -eq 'Yes') {
            Start-PrerequisiteDownload $true
            return
        }
    }
    $mapping = [ordered]@{
        OpenMW = 'OpenMWPath'
        Mesa = 'MesaPath'
        ReShadeShaders = 'ReShadeShaderPath'
        Vort = 'VortPath'
        Quint = 'QuintPath'
    }
    $failures = [Collections.Generic.List[string]]::new()
    foreach ($property in $mapping.Keys) {
        $item = $manifest.$property
        if ($item.Success) { $fields[$mapping[$property]].Text = $item.Path }
        else { $failures.Add("$property`: $($item.Error)") }
    }
    if ($manifest.RHIInstaller -and $manifest.RHIInstaller.Success) {
        $failures.Add("RHI/RenoDX: the verified RHI installer was downloaded to $($manifest.RHIInstaller.Path). Run it, obtain the authorized runtime files, then select their folder with Browse.")
    } else {
        $failures.Add('RHI/RenoDX: proprietary runtime files cannot be redistributed. Download RHI from the pinned downloads page, finish its setup, then select the runtime folder with Browse.')
    }
    $hashWarnings = @($manifest.Warnings)
    if ($hashWarnings.Count) {
        $failures.Insert(0, ("WARNING - you approved files with mismatched hashes:`r`n" + ($hashWarnings -join "`r`n")))
    }
    if ($failures.Count) {
        $prerequisiteStatus.Text = 'Available open-source folders were filled. Complete the remaining Browse field(s).'
        [Windows.Forms.MessageBox]::Show(($failures -join "`r`n`r`n"), 'Some requirements still need you', 'OK', 'Information') | Out-Null
    } else {
        $prerequisiteStatus.Text = 'Open-source requirements downloaded, verified, extracted, and filled.'
    }
})

$downloadPrerequisites.Add_Click({
    if (-not (Test-Path -LiteralPath $prerequisiteDownloader -PathType Leaf)) {
        [Windows.Forms.MessageBox]::Show("The downloader script is missing: $prerequisiteDownloader", 'Cannot download requirements', 'OK', 'Error') | Out-Null
        return
    }
    Start-PrerequisiteDownload $false
})

$installButton.Add_Click({
    if (-not (Test-PageInputs 3)) { return }
    $parameters = Get-InstallerParameters
    Update-Review
    $log.Clear()
    $log.AppendText("Starting the tested PowerShell installer...`r`n`r`n")
    $installButton.Enabled = $false
    $back.Enabled = $false
    $script:installJob = Start-Job -ScriptBlock {
        param($Installer, $Parameters)
        $ErrorActionPreference = 'Stop'
        & $Installer @Parameters *>&1 | ForEach-Object { "$_" }
    } -ArgumentList $backend, $parameters
    $timer.Start()
})

$back.Enabled = $false
if ($SelfTest) {
    $requiredFieldNames = @('OpenMWPath','DestinationPath','MesaPath','ReShadeShaderPath','VortPath','QuintPath','RenoDXPath','FeederPath','ImportProfilePath','ModRoot','BaseDataPath','OverwritePath')
    foreach ($name in $requiredFieldNames) {
        if (-not $fields.ContainsKey($name)) { throw "Wizard self-test is missing field: $name" }
    }
    if ($tabs.TabCount -ne 4) { throw "Wizard self-test expected four pages, found $($tabs.TabCount)." }
    $defaultParameters = Get-InstallerParameters
    foreach ($name in @('BuildPatchedFeeder','ApplyStableSettings','CreateDesktopShortcuts','InstallReShadeVulkan','RegisterReShade')) {
        if (-not $defaultParameters.ContainsKey($name)) { throw "Wizard self-test did not wire default option: $name" }
    }
    if (-not (Test-Path -LiteralPath $prerequisiteDownloader -PathType Leaf)) { throw 'Wizard prerequisite downloader is missing.' }
    $backendParameters = (Get-Command -Name $backend).Parameters.Keys
    foreach ($name in $defaultParameters.Keys) {
        if ($name -notin $backendParameters) { throw "Wizard passes an unknown backend parameter: $name" }
    }
    $timer.Dispose()
    $prerequisiteTimer.Dispose()
    $form.Dispose()
    Write-Output 'OpenMW DLSS5 wizard self-test passed: four pages and all installer fields constructed.'
    return
}
[void]$form.ShowDialog()
if ($script:installJob) { Stop-Job $script:installJob -ErrorAction SilentlyContinue; Remove-Job $script:installJob -Force -ErrorAction SilentlyContinue }
if ($script:prerequisiteJob) { Stop-Job $script:prerequisiteJob -ErrorAction SilentlyContinue; Remove-Job $script:prerequisiteJob -Force -ErrorAction SilentlyContinue }
$timer.Dispose()
$prerequisiteTimer.Dispose()
$form.Dispose()
