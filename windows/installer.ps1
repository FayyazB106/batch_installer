#Requires -Version 5.0

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

# Install types:
#   exe - run directly with Args
#   msi - run via msiexec with Args

$Apps = @(
    [PSCustomObject]@{
        Name     = "Google Chrome"
        Category = "Browser"
        URL      = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        Args     = "/quiet /norestart REBOOT=ReallySuppress"
        File     = "chrome_setup.msi"
        Type     = "msi"
        Selected = $false
    },
    [PSCustomObject]@{
        Name     = "Microsoft Teams"
        Category = "Communication"
        URL      = "https://go.microsoft.com/fwlink/?linkid=2243204"
        Args     = "-p"
        File     = "teamsbootstrapper.exe"
        Type     = "exe"
        WingetId = ""
        Selected = $false
    },
    [PSCustomObject]@{
        Name     = "Adobe Creative Cloud"
        Category = "Creative Suite"
        URL      = "https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v1/wam/download?sapCode=KCCC&startPoint=mam&platform=win"
        Args     = ""
        File     = "adobe_cc_setup.exe"
        Type     = "exe"
        Selected = $false
    },
    [PSCustomObject]@{
        Name     = "TeamViewer"
        Category = "Remote Access"
        URL      = "https://download.teamviewer.com/download/TeamViewer_Setup.exe"
        Args     = "--silentinstall"
        File     = "teamviewer_setup.exe"
        Type     = "exe"
        Selected = $false
    },
    [PSCustomObject]@{
        Name     = "Dropbox"
        Category = "Cloud Storage"
        URL      = "https://www.dropbox.com/download?plat=win&full=1"
        Args     = "/S"
        File     = "dropbox_setup.exe"
        Type     = "exe"
        Selected = $false
    },
    [PSCustomObject]@{
        Name     = "Microsoft Office 365"
        Category = "Productivity"
        URL      = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?productReleaseID=O365BusinessRetail&platform=Def&language=en-us"
        Args     = ""
        File     = "office365_setup.exe"
        Type     = "exe"
        Selected = $false
    }
)

function Write-Line {
    param([string]$Text = "", [string]$Color = "Gray")
    $padded = $Text.PadRight($Host.UI.RawUI.WindowSize.Width)
    Write-Host $padded -ForegroundColor $Color
}

function Write-LineParts {
    param([array]$Parts)
    $width = $Host.UI.RawUI.WindowSize.Width
    $total = 0
    foreach ($p in $Parts) {
        Write-Host -NoNewline $p.Text -ForegroundColor $p.Color
        $total += $p.Text.Length
    }
    $remaining = $width - $total
    if ($remaining -gt 0) { Write-Host (" " * $remaining) -NoNewline }
    Write-Host ""
}

$script:MenuStartRow = 0

function Draw-Menu {
    param([int]$Cursor)
    [Console]::SetCursorPosition(0, $script:MenuStartRow)

    $width = $Host.UI.RawUI.WindowSize.Width
    $title = " BATCH INSTALLER "
    $pad   = [math]::Max(0, [math]::Floor(($width - $title.Length) / 2))
    $line  = "=" * $width

    Write-Line $line                       "DarkCyan"
    Write-Line (" " * $pad + $title)      "White"
    Write-Line $line                       "DarkCyan"
    Write-Line ""
    Write-Line "  Select apps to install:" "Gray"
    Write-Line ""

    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $app   = $Apps[$i]
        $check = if ($app.Selected) { "[X]" } else { "[ ]" }

        if ($i -eq $Cursor) {
            Write-LineParts @(
                @{ Text = "  > ";                 Color = "Cyan" },
                @{ Text = "$check ";              Color = if ($app.Selected) { "Green" } else { "DarkGray" } },
                @{ Text = $app.Name.PadRight(25); Color = "White" },
                @{ Text = "  $($app.Category)";   Color = "DarkCyan" }
            )
        } else {
            Write-LineParts @(
                @{ Text = "    ";                 Color = "Gray" },
                @{ Text = "$check ";              Color = if ($app.Selected) { "Green" } else { "DarkGray" } },
                @{ Text = $app.Name.PadRight(25); Color = if ($app.Selected) { "Gray" } else { "DarkGray" } },
                @{ Text = "  $($app.Category)";   Color = "DarkGray" }
            )
        }
    }

    $selectedCount = @($Apps | Where-Object { $_.Selected }).Count
    Write-Line ""
    Write-Line "  $selectedCount of $($Apps.Count) selected" $(if ($selectedCount -gt 0) { "Cyan" } else { "DarkGray" })
    Write-Line ""
    Write-Line "  [Up/Down] Navigate    [Space] Toggle    [A] All/None    [Enter] Install    [Q] Quit" "DarkGray"
    Write-Line ""
}

function Show-Menu {
    Clear-Host
    $script:MenuStartRow = [Console]::CursorTop
    [Console]::CursorVisible = $false
    Draw-Menu -Cursor 0
    $cursor = 0

    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { if ($cursor -gt 0) { $cursor-- } }
            40 { if ($cursor -lt ($Apps.Count - 1)) { $cursor++ } }
            32 { $Apps[$cursor].Selected = -not $Apps[$cursor].Selected }
            65 {
                $allSelected = @($Apps | Where-Object { $_.Selected }).Count -eq $Apps.Count
                foreach ($app in $Apps) { $app.Selected = -not $allSelected }
            }
            13 {
                [Console]::CursorVisible = $true
                $chosen = @($Apps | Where-Object { $_.Selected })
                if ($chosen.Count -eq 0) {
                    $statusRow = $script:MenuStartRow + 6 + $Apps.Count + 1
                    [Console]::SetCursorPosition(0, $statusRow)
                    Write-Line "  Please select at least one app." "Yellow"
                    Start-Sleep -Milliseconds 800
                    [Console]::SetCursorPosition(0, $statusRow)
                    Write-Line "  0 of $($Apps.Count) selected" "DarkGray"
                    continue
                } else {
                    return $chosen
                }
            }
            81 {
                [Console]::CursorVisible = $true
                Clear-Host
                Write-Host "  Installer cancelled." -ForegroundColor DarkGray
                exit 0
            }
        }

        Draw-Menu -Cursor $cursor
    }
}

function Get-ContentLength {
    param([string]$Url)
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method    = "HEAD"
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $req.Timeout   = 5000
        $resp = $req.GetResponse()
        $len  = $resp.ContentLength
        $resp.Close()
        return $len
    } catch { return -1 }
}

function Update-DownloadStatus {
    param([string]$Dest, [int]$Row, [System.Diagnostics.Stopwatch]$Timer, [long]$TotalBytes)
    $bytes   = if (Test-Path $Dest) { (Get-Item $Dest).Length } else { 0 }
    $elapsed = [math]::Round($Timer.Elapsed.TotalSeconds, 1)
    $mb      = [math]::Round($bytes / 1MB, 2)
    $dt      = $Timer.Elapsed.TotalSeconds
    $speed   = if ($dt -gt 0) { [math]::Round($bytes / 1MB / $dt, 2) } else { 0 }
    $width   = $Host.UI.RawUI.WindowSize.Width

    if ($TotalBytes -gt 0) {
        $totalMB = [math]::Round($TotalBytes / 1MB, 2)
        $pct     = [math]::Min(100, [math]::Round($bytes / $TotalBytes * 100))
        $bar     = ("#" * [math]::Floor($pct / 5)).PadRight(20, "-")
        $line    = "         [$bar] $($pct.ToString().PadLeft(3))%  $mb / $totalMB MB  $speed MB/s  $($elapsed)s"
    } else {
        $line    = "         $mb MB received  |  $speed MB/s  |  $($elapsed)s"
    }

    [Console]::SetCursorPosition(0, $Row)
    Write-Host $line.PadRight($width) -ForegroundColor DarkGray -NoNewline
    return $bytes
}

function Download-File {
    param([string]$Url, [string]$Dest)

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Host "         URL: $Url" -ForegroundColor DarkGray

    # HEAD request to get total size for progress display
    $totalBytes = Get-ContentLength -Url $Url
    if ($totalBytes -gt 0) {
        $totalMB = [math]::Round($totalBytes / 1MB, 2)
        Write-Host "         Size: $totalMB MB" -ForegroundColor DarkGray
    } else {
        Write-Host "         Size: unknown" -ForegroundColor DarkGray
    }

    $statusRow = [Console]::CursorTop
    Write-Host ""

    # Run download in a background job - synchronous inside, so job.State reliably signals completion
    # so job.State reliably signals completion (no cross-runspace event issues)
    $job = Start-Job -ScriptBlock {
        param($url, $dest)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($url, $dest)
    } -ArgumentList $Url, $Dest

    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    while ($job.State -eq 'Running') {
        Update-DownloadStatus -Dest $Dest -Row $statusRow -Timer $timer -TotalBytes $totalBytes | Out-Null
        Start-Sleep -Milliseconds 300
    }

    $timer.Stop()
    Update-DownloadStatus -Dest $Dest -Row $statusRow -Timer $timer -TotalBytes $totalBytes | Out-Null
    [Console]::SetCursorPosition(0, $statusRow + 1)
    Write-Host ""

    $jobError = $job | Receive-Job 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
    Remove-Job $job -Force

    if ($jobError) {
        Write-Host "         Error: $jobError" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path $Dest) -or (Get-Item $Dest).Length -lt 1000) {
        Write-Host "         Failed: file empty or missing after download" -ForegroundColor Red
        return $false
    }

    # Validate the file is a real binary, not an HTML error page
    # EXE/DLL = MZ header (4D 5A), MSI = OLE header (D0 CF 11 E0)
    $header = [System.IO.File]::ReadAllBytes($Dest) | Select-Object -First 4
    $isMZ  = ($header[0] -eq 0x4D -and $header[1] -eq 0x5A)
    $isMSI = ($header[0] -eq 0xD0 -and $header[1] -eq 0xCF -and $header[2] -eq 0x11 -and $header[3] -eq 0xE0)
    if (-not $isMZ -and -not $isMSI) {
        $preview = [System.Text.Encoding]::UTF8.GetString(
            [System.IO.File]::ReadAllBytes($Dest), 0, [math]::Min(300, (Get-Item $Dest).Length)
        ).Trim() -replace '\s+', ' '
        Write-Host "         Error: server returned a web page instead of a file." -ForegroundColor Red
        Write-Host "         Preview: $($preview.Substring(0, [math]::Min(200, $preview.Length)))" -ForegroundColor DarkGray
        Remove-Item $Dest -Force -ErrorAction SilentlyContinue
        return $false
    }

    $mb   = [math]::Round((Get-Item $Dest).Length / 1MB, 2)
    $secs = [math]::Round($timer.Elapsed.TotalSeconds, 1)
    Write-Host "         Done: $mb MB in $($secs)s" -ForegroundColor DarkGray
    return $true
}


function Get-WingetPath {
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = "$env:LocalAppData\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $local) { return $local }
    $glob = Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe" `
            -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($glob) { return $glob.FullName }
    return $null
}

function Install-Apps {
    param($ChosenApps)

    Clear-Host
    $tempDir = $env:TEMP
    $results = @()
    $total   = $ChosenApps.Count

    $width = $Host.UI.RawUI.WindowSize.Width
    $line  = "=" * $width
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host "  BATCH INSTALLER" -ForegroundColor White
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Installing $total app$(if ($total -gt 1) { 's' })..." -ForegroundColor White
    Write-Host ""

    Write-Host "         Session started. Installing: $(($ChosenApps | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor DarkGray

    $i = 1
    foreach ($app in $ChosenApps) {
        $filePath  = Join-Path $tempDir $app.File
        $stepLabel = "[$i/$total]"

        Write-Host "  $stepLabel $($app.Name)" -ForegroundColor Cyan

        if ($app.Type -ne "winget") {
            Write-Host "         Downloading..." -ForegroundColor DarkGray -NoNewline
            Write-Host "         $stepLabel $($app.Name) - downloading from $($app.URL)" -ForegroundColor DarkGray

            $ok = Download-File -Url $app.URL -Dest $filePath
            if (-not $ok) {
                Write-Host "         Download failed." -ForegroundColor Red
                Write-Host "         $stepLabel $($app.Name) - DOWNLOAD FAILED" -ForegroundColor Red
                $results += [PSCustomObject]@{ Name = $app.Name; Status = "FAIL"; Note = "Download failed" }
                Write-Host ""
                $i++
                continue
            }
        }

        Write-Host "         Installing..." -ForegroundColor Yellow
        Write-Host "         $stepLabel $($app.Name) - installer launched" -ForegroundColor DarkGray
        $installTimer = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            if ($app.Type -eq "winget") {
                $winget = Get-WingetPath
                if ($winget) {
                    Write-Host "         Resetting winget sources..." -ForegroundColor DarkGray
                    Start-Process -FilePath $winget -ArgumentList "source reset --force" -Wait -NoNewWindow
                    Write-Host "         Updating winget sources..." -ForegroundColor DarkGray
                    Start-Process -FilePath $winget -ArgumentList "source update" -Wait -NoNewWindow
                    Write-Host "         Installing via winget..." -ForegroundColor DarkGray
                    $proc = Start-Process -FilePath $winget `
                        -ArgumentList "install --id $($app.WingetId) -e --silent --accept-package-agreements --accept-source-agreements --source winget" `
                        -Wait -PassThru -NoNewWindow
                }
                # If winget failed or is unavailable, open browser as fallback
                if (-not $winget -or $proc.ExitCode -ne 0) {
                    Write-Host ""
                    Write-Host "  [!] $($app.Name) could not be installed automatically." -ForegroundColor Yellow
                    Write-Host "      Opening download page in your browser..." -ForegroundColor DarkGray
                    Write-Host "      Sign in with your Microsoft account and click Install." -ForegroundColor DarkGray
                    Write-Host "      Press any key here when done (or to skip)." -ForegroundColor DarkGray
                    Start-Process $app.URL
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    $proc = [PSCustomObject]@{ ExitCode = 0 }
                }
            } elseif ($app.Type -eq "msi") {
                $proc = Start-Process "msiexec.exe" -ArgumentList "/i `"$filePath`" $($app.Args)" -Wait -PassThru
            } elseif ($app.Args -ne "") {
                $proc = Start-Process -FilePath $filePath -ArgumentList $app.Args -Wait -PassThru
            } else {
                $proc = Start-Process -FilePath $filePath -Wait -PassThru
            }

            $installTimer.Stop()
            $installSecs = [math]::Round($installTimer.Elapsed.TotalSeconds, 1)

            if ($proc.ExitCode -eq 0) {
                Write-Host "         Done. ($installSecs`s)" -ForegroundColor Green
                Write-Host "         $stepLabel $($app.Name) - OK (took $installSecs`s)" -ForegroundColor DarkGray
                $results += [PSCustomObject]@{ Name = $app.Name; Status = "OK"; Note = "" }
            } elseif ($proc.ExitCode -eq 3010) {
                Write-Host "         Installed, reboot required to finish. ($installSecs`s)" -ForegroundColor Green
                Write-Host "         $stepLabel $($app.Name) - OK, reboot required (took $installSecs`s)" -ForegroundColor DarkGray
                $results += [PSCustomObject]@{ Name = $app.Name; Status = "OK"; Note = "Reboot required" }
            } elseif ($proc.ExitCode -eq 1603) {
                Write-Host "         Already installed. ($installSecs`s)" -ForegroundColor Yellow
                Write-Host "         $stepLabel $($app.Name) - already installed ($installSecs`s)" -ForegroundColor Yellow
                $results += [PSCustomObject]@{ Name = $app.Name; Status = "WARN"; Note = "Already installed" }
            } else {
                Write-Host "         Installation may have failed (exit code $($proc.ExitCode)). ($installSecs`s)" -ForegroundColor Yellow
                Write-Host "         $stepLabel $($app.Name) - possible failure, exit code $($proc.ExitCode) ($installSecs`s)" -ForegroundColor Yellow
                $results += [PSCustomObject]@{ Name = $app.Name; Status = "WARN"; Note = "Possible failure (exit code $($proc.ExitCode))" }
            }
        } catch {
            Write-Host "         Failed: $_" -ForegroundColor Red
            Write-Host "         $stepLabel $($app.Name) - FAILED: $_" -ForegroundColor Red
            $results += [PSCustomObject]@{ Name = $app.Name; Status = "FAIL"; Note = $_.Exception.Message }
        }

        Write-Host ""
        $i++
    }

    Write-Host $line -ForegroundColor DarkCyan
    Write-Host "  SUMMARY" -ForegroundColor White
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ""

    foreach ($r in $results) {
        switch ($r.Status) {
            "OK"   {
                Write-Host "  [OK]   " -ForegroundColor Green -NoNewline
                if ($r.Note) { Write-Host "$($r.Name)  ($($r.Note))" } else { Write-Host $r.Name }
            }
            "WARN" { Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline; Write-Host "$($r.Name)  ($($r.Note))" }
            "FAIL" { Write-Host "  [FAIL] " -ForegroundColor Red    -NoNewline; Write-Host "$($r.Name)  ($($r.Note))" }
        }
    }

    $okCount   = @($results | Where-Object { $_.Status -eq "OK"   }).Count
    $warnCount = @($results | Where-Object { $_.Status -eq "WARN" }).Count
    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count

    Write-Host ""
    Write-Host "  $okCount succeeded  |  $warnCount warnings  |  $failCount failed" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "         Session complete. OK=$okCount WARN=$warnCount FAIL=$failCount" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press any key to exit." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Clear-Host
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  This installer needs to run as Administrator." -ForegroundColor Yellow
    Write-Host "  Use the Run Me.bat file to launch it correctly." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

$chosen = Show-Menu
Install-Apps -ChosenApps $chosen