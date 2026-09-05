# =============================================================================
# Module      : NTCommon
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Fonctions partagees par tous les modules NeoTech Toolkit.
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

# --- Constantes globales -----------------------------------------------------

$script:NTVersion      = '1.0.0'
$script:NTCopyright    = '(c) 2026 TechSentinel - Neo Soda'
$script:NTSite         = 'https://techsentinel.fr'
$script:NTLogDir       = Join-Path $PSScriptRoot '..\Logs'
$script:NTLogFile      = $null
$script:NTLogMaxBytes  = 2MB
$script:NTInteractive  = [Environment]::UserInteractive -and -not $Host.Name -eq 'ServerRemoteHost'
$script:NTSupportsAnsi = $Host.UI.SupportsVirtualTerminal -or $PSVersionTable.PSVersion.Major -ge 7

if (-not (Test-Path $script:NTLogDir)) {
    New-Item -ItemType Directory -Path $script:NTLogDir -Force | Out-Null
}

# --- Journalisation ----------------------------------------------------------

function Write-NTLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warning','Error','Debug','Verbose')][string]$Level = 'Info',
        [string]$Component = 'NeoTech'
    )
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line  = "[$stamp] [$Level] [$Component] $Message"
    $script:NTLogFile = Join-Path $script:NTLogDir "NeoTech_$($env:COMPUTERNAME).log"
    if ((Test-Path $script:NTLogFile) -and ((Get-Item $script:NTLogFile).Length -gt $script:NTLogMaxBytes)) {
        $archive = Join-Path $script:NTLogDir "NeoTech_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Move-Item -Path $script:NTLogFile -Destination $archive -Force
    }
    Add-Content -Path $script:NTLogFile -Value $line -Encoding UTF8
    if ($script:NTInteractive -and ($Level -in 'Warning','Error')) {
        $color = if ($Level -eq 'Warning') { 'Yellow' } else { 'Red' }
        Write-Host "  ! $Message" -ForegroundColor $color
    }
}

function Get-NTLogPath {
    if (-not $script:NTLogFile) {
        $script:NTLogFile = Join-Path $script:NTLogDir "NeoTech_$($env:COMPUTERNAME).log"
    }
    return $script:NTLogFile
}

# --- Affichage ---------------------------------------------------------------

function Set-NTWindowSize {
    [CmdletBinding()]
    param([int]$Width = 130, [int]$Height = 42)
    if (-not $script:NTInteractive) { return }
    try {
        if ($Host.UI.RawUI.BufferSize.Width -lt $Width) {
            $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($Width, 9999)
        }
        $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($Width, $Height)
    } catch { }
}

function Set-NTWindowTitle {
    [CmdletBinding()]
    param([string]$Title = "NeoTech Toolkit v$script:NTVersion")
    try { $Host.UI.RawUI.WindowTitle = $Title } catch { }
}

function Write-NTHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Title)
    if ($script:NTInteractive) { Clear-Host }
    $bar = '=' * 76
    Write-Host $bar -ForegroundColor Cyan
    Write-Host "   NEOTECH TOOLKIT v$script:NTVersion  -  $Title" -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor Cyan
    Write-Host ''
}

function Write-NTTitle {
    [CmdletBinding()]
    param()
    if ($script:NTInteractive) { Clear-Host }
    $bar = '=' * 76
    Write-Host $bar -ForegroundColor Cyan
    Write-Host "  NEOTECH TOOLKIT  v$script:NTVersion" -ForegroundColor Cyan
    Write-Host "     Administration et Diagnostic Windows" -ForegroundColor DarkGray
    Write-Host $bar -ForegroundColor Cyan
    Write-Host ''
}

function Write-NTBox {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Title, [int]$Width = 100, [scriptblock]$Content)
    $TL = [char]0x250C; $TR = [char]0x2510; $BL = [char]0x2514; $BR = [char]0x2518; $HZ = [char]0x2500
    $inner = $Width - 2
    $titleUp = $Title.ToUpper()
    $fillerTop = $Width - 7 - $titleUp.Length
    if ($fillerTop -lt 0) { $fillerTop = 0 }
    $topBar    = "$TL$HZ" + '[ ' + $titleUp + ' ]' + ([string]::new($HZ, $fillerTop)) + $TR
    $bottomBar = "$BL" + ([string]::new($HZ, $inner)) + $BR
    Write-Host $topBar -ForegroundColor Cyan
    & $Content
    Write-Host $bottomBar -ForegroundColor Cyan
    Write-Host ''
}

function Write-NTMenuItem {
    [CmdletBinding()]
    param([string]$Key, [Parameter(Mandatory)][string]$Label, [string]$Hint, [switch]$Highlight)
    $keyStr = if ($Key) { "[$Key]" } else { "   " }
    $keyColor = if ($Highlight) { 'Magenta' } else { 'Cyan' }
    Write-Host "   " -NoNewline
    Write-Host $keyStr.PadRight(6) -ForegroundColor $keyColor -NoNewline
    Write-Host $Label -ForegroundColor $(if($Highlight){'White'}else{'Gray'}) -NoNewline
    if ($Hint) { Write-Host "  " -NoNewline; Write-Host $Hint -ForegroundColor DarkGray } else { Write-Host '' }
}

function Write-NTStatusBar {
    [CmdletBinding()]
    param()
    $bar = [string]::new([char]0x2500, 100)
    $admin = if (Test-NTAdmin) { 'ADMIN' } else { 'user' }
    $time  = Get-Date -Format 'dd/MM/yyyy HH:mm'
    Write-Host ''
    Write-Host $bar -ForegroundColor DarkGray
    Write-Host ("  {0,-18}  {1,-15}  {2,-12}  {3,-10}  {4}" -f $env:COMPUTERNAME, $env:USERNAME, "v$script:NTVersion", $admin, $time) -ForegroundColor DarkGray
    Write-Host $bar -ForegroundColor DarkGray
}

function Write-NTSubHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ("  " + [char]0x25B6 + " " + $Title) -ForegroundColor Yellow
    Write-Host ("  " + [string]::new([char]0x2500, 70)) -ForegroundColor DarkGray
}

function Wait-NTKey {
    [CmdletBinding()]
    param([string]$Message = 'Appuyez sur une touche pour continuer...', [switch]$Force)
    $hasConsole = $false
    try { $null = [Console]::KeyAvailable; $hasConsole = $true } catch { }
    if ($hasConsole -or $Force) {
        Write-Host ''
        Write-Host $Message -ForegroundColor DarkGray
        if ($hasConsole) {
            try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') }
            catch { try { Read-Host 'Entree' | Out-Null } catch { Start-Sleep -Seconds 2 } }
        }
    }
}

function Read-NTChoice {
    [CmdletBinding()]
    param([string]$Prompt = 'Selectionner une option')
    return Read-Host $Prompt
}

function Get-NTColor {
    param([ValidateSet('OK','WARN','FAIL','INFO','TITLE')][string]$Kind = 'INFO')
    switch ($Kind) { 'OK' {'Green'} 'WARN' {'Yellow'} 'FAIL' {'Red'} 'INFO' {'White'} 'TITLE' {'Cyan'} }
}

function Write-NTStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message, [ValidateSet('OK','WARN','FAIL','INFO')][string]$Status = 'INFO')
    $tag  = switch ($Status) { 'OK' {'[OK] '} 'WARN' {'[!!] '} 'FAIL' {'[KO] '} default {'[--] '} }
    $col  = switch ($Status) { 'OK' {'Green'} 'WARN' {'Yellow'} 'FAIL' {'Red'} default {'Gray'} }
    Write-Host ("  $tag$Message") -ForegroundColor $col
}

# --- Elevation ---------------------------------------------------------------

function Test-NTAdmin {
    [CmdletBinding()][OutputType([bool])]
    param()
    $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr  = [Security.Principal.WindowsPrincipal]$id
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-NTInteractive {
    [CmdletBinding()][OutputType([bool])]
    param()
    return $script:NTInteractive
}

function Request-NTElevation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [string[]]$ArgumentList = @())
    if (Test-NTAdmin) { return $true }
    $psPath = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
    if (-not $psPath) { $psPath = 'powershell.exe' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psPath
    $psi.Arguments = "-NoProfile -ExecutionPolicy RemoteSigned -File `"$Path`" $($ArgumentList -join ' ')"
    $psi.UseShellExecute = $true
    $psi.Verb = 'runas'
    try { [Diagnostics.Process]::Start($psi) | Out-Null; return $true } catch { return $false }
}

function Request-NTGuiConfirm {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message, [string]$Title = "Confirmation")
    $window = $script:NTGuiWindow
    if (-not $window) { return $false }
    $result = [System.Windows.MessageBox]::Show(
        $window, $Message, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

# --- Gestion d'erreurs -------------------------------------------------------

function Invoke-NTSafe {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Component, [Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-NTLog -Message "Debut : $Title" -Level Debug -Component $Component
        $result = & $ScriptBlock
        $sw.Stop()
        Write-NTLog -Message "OK : $Title ($($sw.Elapsed.TotalSeconds.ToString('0.00'))s)" -Level Info -Component $Component
        return [pscustomobject]@{ Success = $true;  Data = $result; Error = $null; DurationSec = $sw.Elapsed.TotalSeconds }
    } catch {
        $sw.Stop()
        $msg = $_.Exception.Message
        Write-NTLog -Message "ECHEC : $Title - $msg" -Level Error -Component $Component
        return [pscustomobject]@{ Success = $false; Data = $null;    Error = $msg;     DurationSec = $sw.Elapsed.TotalSeconds }
    }
}

# --- Formatage ---------------------------------------------------------------

function Format-NTBytes {
    [CmdletBinding()][OutputType([string])]
    param([Parameter(Mandatory)][double]$Bytes, [int]$Decimals = 2)
    if ($Bytes -le 0) { return '0 B' }
    $units = @('B','KB','MB','GB','TB','PB')
    $pow   = [math]::Floor([math]::Log($Bytes, 1024))
    $pow   = [math]::Min($pow, $units.Count - 1)
    $val   = $Bytes / [math]::Pow(1024, $pow)
    return ('{0} {1}' -f [math]::Round($val, $Decimals), $units[$pow])
}

function Format-NTDuration {
    [CmdletBinding()][OutputType([string])]
    param([Parameter(Mandatory)][TimeSpan]$Span)
    if ($Span.TotalDays -ge 1) { return ('{0}j {1}h {2}m' -f [int]$Span.TotalDays, $Span.Hours, $Span.Minutes) }
    elseif ($Span.TotalHours -ge 1) { return ('{0}h {1}m {2}s' -f [int]$Span.TotalHours, $Span.Minutes, $Span.Seconds) }
    else { return ('{0}m {1}s' -f [int]$Span.TotalMinutes, $Span.Seconds) }
}

function Get-NTScriptInfo {
    [CmdletBinding()][OutputType([pscustomobject])]
    param()
    [pscustomobject]@{
        Version   = $script:NTVersion
        Copyright = $script:NTCopyright
        Site      = $script:NTSite
        LogFile   = Get-NTLogPath
        LogDir    = $script:NTLogDir
        IsAdmin   = Test-NTAdmin
        PowerShell = $PSVersionTable.PSVersion.ToString()
        OS        = [System.Environment]::OSVersion.VersionString
    }
}

# --- Verifications prealables ------------------------------------------------

function Assert-NTWindows {
    [CmdletBinding()]
    param()
    if ($env:OS -ne 'Windows_NT') { Write-Error "NeoTech Toolkit necessite Windows."; exit 1 }
}

function Get-NTDesktop {
    [CmdletBinding()][OutputType([string])]
    param()
    try { return [Environment]::GetFolderPath('Desktop') } catch { return [Environment]::GetFolderPath('UserProfile') }
}


function Invoke-NTWithTimeout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [int]$TimeoutSec = 10,
        [string]$Component = 'NeoTech',
        [string]$Label = 'Operation'
    )
    $job = Start-Job -ScriptBlock $ScriptBlock -ErrorAction Stop
    $completed = Wait-Job $job -Timeout $TimeoutSec
    if (-not $completed) {
        Stop-Job $job
        Remove-Job $job -Force
        Write-NTLog -Message "TIMEOUT (${TimeoutSec}s) : $Label" -Level Warning -Component $Component
        Write-NTStatus -Message "Timeout (${TimeoutSec}s) - $Label" -Status WARN
        return $null
    }
    $result = Receive-Job $job -Keep -ErrorAction SilentlyContinue
    Remove-Job $job -Force
    return $result
}

Export-ModuleMember -Function Write-NTLog, Get-NTLogPath, Set-NTWindowSize, Set-NTWindowTitle, Write-NTHeader, Write-NTTitle, Write-NTBox, Write-NTMenuItem, Write-NTStatusBar, Write-NTSubHeader, Wait-NTKey, Read-NTChoice, Get-NTColor, Write-NTStatus, Test-NTAdmin, Get-NTInteractive, Request-NTElevation, Request-NTGuiConfirm, Invoke-NTSafe, Invoke-NTWithTimeout, Format-NTBytes, Format-NTDuration, Get-NTScriptInfo, Assert-NTWindows, Get-NTDesktop

Export-ModuleMember -Variable NTVersion, NTCopyright, NTSite, NTLogDir, NTLogFile
# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU472p4r1+ZgNOu59p+i4GQCKw
# tYmgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
# AQsFADBgMQswCQYDVQQGEwJGUjERMA8GA1UEBwwIVG91bG91c2UxFTATBgNVBAoM
# DFRlY2hTZW50aW5lbDEnMCUGA1UEAwweTmVvVGVjaCBUb29sa2l0IChUZWNoU2Vu
# dGluZWwpMB4XDTI2MDkwNTA4NTMxMVoXDTMxMDkwNTA5MDMxMVowYDELMAkGA1UE
# BhMCRlIxETAPBgNVBAcMCFRvdWxvdXNlMRUwEwYDVQQKDAxUZWNoU2VudGluZWwx
# JzAlBgNVBAMMHk5lb1RlY2ggVG9vbGtpdCAoVGVjaFNlbnRpbmVsKTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBANmhOxXsQR0O5n0zofF9w368BLZYjxWn
# eJn+nZHgDOZv9xjrvB6d+TPRQshHHFxdAHvYcf7l5a7nDf6UNma27fPYmUut3Lnq
# o9pjsQRHqBOKWGnMEJKV9fZDDxpCuiTfuD6Wf3qOdUvJqTSv8g+a5VFJrY/ZvXl5
# rsRGQIQOMfDKbG3tjAGuKIqVG6zjGi2ZHbJczPmApj2gFtrKKA0cY03xFSZte7dP
# qvAY7YFaNZnms5PociatNhCdcSfHTFGI2WTUlYW69BaX5eUrOGaqAec6eL+avgdg
# CUpEN6cgHLxbTxDID4IOqHVdFdA7oqXw8CN6+zKxYyROxK3BdXdD1HUCAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRCPPTmQoHDrrP/39dmsxIWEoG0MTANBgkqhkiG9w0BAQsFAAOCAQEApk/OCP+k
# PnuPJw1lKwpv8BEWPNqFvKUYy9C697uL5AzyZMiOnZ31H+TYZlBeRjY8LCusKYai
# ZKP+376jMRoDTsTehNbYlBNEbCQHGMwUOUXrNrdARa601DlKNaUyLkpdmHyzKL9A
# eK1Q0gD12fCGd9Nzne3ZLeNDUQB3F+ZeyCy217JapJltBsgY8F7hQH1TnfuKX4pG
# a8iQLW0NXe5UEzytpokllsp9AKmkTIoLTFkLiaFZeQ2w1VlQy9D52w0b1OvNts+f
# 4zhMa11HLrJd0dGluJhXp2SFthz4iKjgK6J0sswy58fxIBHwguwo8rHuKvi3Aqkg
# v3dyED6MOWrTgTGCAhUwggIRAgEBMHQwYDELMAkGA1UEBhMCRlIxETAPBgNVBAcM
# CFRvdWxvdXNlMRUwEwYDVQQKDAxUZWNoU2VudGluZWwxJzAlBgNVBAMMHk5lb1Rl
# Y2ggVG9vbGtpdCAoVGVjaFNlbnRpbmVsKQIQO+7SyralWaVEZNPsB84DmDAJBgUr
# DgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMx
# DAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkq
# hkiG9w0BCQQxFgQURZvnSrWmKORqMTqvn9z4lF9jI3kwDQYJKoZIhvcNAQEBBQAE
# ggEAotZihunsyVsjBbSi+2u9NmYIPuFY1m3hFbSv4kBsuMrd5zPRscXHejTwnNpt
# V5+1gEom4GktWyKLliiZUTb4YqudiAZ8XPKwSbppViWYc2H26x1HNt0tGQfmZGqF
# OsPIxgDD1krJ5wJBowJt+vsZzWDSweZIWYM1usJzJEk7zcPIwSFf74Cf8i7vIDiD
# 79Vk04WlJZiThmq57oQOfqm82jN6HHeilxRf83gJH0pbBLqUOAnDCVvgNtEKNcu2
# Efy6C3+uJNnfDJOG91VB+lMB3ZDZ2nTvX7hVQHS17ppMSHBpFuqr534zITh/n1pD
# Pq5YrlxaXAXhg1YtAHauWk0p4w==
# SIG # End signature block
