# =============================================================================
# Module      : NTReport
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Generation de rapports TXT et HTML.
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTReportPath {
    <#
    .SYNOPSIS
        Construit un chemin de rapport horodate.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('txt','html')][string]$Extension = 'txt',
        [string]$BaseDir = (Join-Path (Get-NTDesktop) ''),
        [string]$Prefix  = 'NeoTech_Rapport'
    )
    $stamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $name  = "${Prefix}_$($env:COMPUTERNAME)_$stamp.$Extension"
    return (Join-Path $BaseDir $name)
}

function Export-NTReport {
    <#
    .SYNOPSIS
        Genere un rapport complet (TXT + HTML) sur le bureau.
    .PARAMETER IncludeSections
        Tableau de sections a inclure. Par defaut : toutes.
    #>
    [CmdletBinding()]
    param(
        [string[]]$IncludeSections = @(
            'Overview','Hardware','Storage','Network','Security',
            'Software','Drivers','Startup','Services','Events'
        )
    )

    $timestamp = Get-Date
    $stampStr  = $timestamp.ToString('yyyy-MM-dd HH:mm:ss')
    $txtPath   = Get-NTReportPath -Extension 'txt'
    $htmlPath  = Get-NTReportPath -Extension 'html'

    Write-NTHeader 'EXPORT RAPPORT'
    Write-Host "  Compilation des sections selectionnees..." -ForegroundColor Cyan

    $report = [ordered]@{}
    if ('Overview'  -in $IncludeSections) { $report['VUE D ENSEMBLE']     = { Get-NTOverviewData } }
    if ('Hardware'  -in $IncludeSections) { $report['MATERIEL (CPU/RAM/MB/GPU)'] = { Get-NTHardwareData } }
    if ('Storage'   -in $IncludeSections) { $report['STOCKAGE']           = { Get-NTStorageData } }
    if ('Network'   -in $IncludeSections) { $report['RESEAU']             = { Get-NTNetworkData } }
    if ('Security'  -in $IncludeSections) { $report['SECURITE']           = { Get-NTSecurityData } }
    if ('Software'  -in $IncludeSections) { $report['LOGICIELS (top 50)'] = { Get-NTSoftwareData } }
    if ('Drivers'   -in $IncludeSections) { $report['PILOTES (top 50)']   = { Get-NTDriverData } }
    if ('Startup'   -in $IncludeSections) { $report['DEMARRAGE']          = { Get-NTStartupData } }
    if ('Services'  -in $IncludeSections) { $report['SERVICES']           = { Get-NTServicesData } }
    if ('Events'    -in $IncludeSections) { $report['EVENEMENTS (24H)']   = { Get-NTEventsData } }

    # --- TXT
    "========================================================================" | Out-File $txtPath -Encoding UTF8
    "                RAPPORT TECHNIQUE - NEOTECH TOOLKIT v$NTVersion"          | Out-File $txtPath -Append -Encoding UTF8
    "========================================================================" | Out-File $txtPath -Append -Encoding UTF8
    "Poste       : $env:COMPUTERNAME"          | Out-File $txtPath -Append -Encoding UTF8
    "Operateur   : $env:USERNAME"              | Out-File $txtPath -Append -Encoding UTF8
    "Date        : $stampStr"                  | Out-File $txtPath -Append -Encoding UTF8
    "PowerShell  : $($PSVersionTable.PSVersion)" | Out-File $txtPath -Append -Encoding UTF8
    "" | Out-File $txtPath -Append -Encoding UTF8

    foreach ($key in $report.Keys) {
        "`n## $key" | Out-File $txtPath -Append -Encoding UTF8
        ('-' * 72) | Out-File $txtPath -Append -Encoding UTF8
        try {
            (& $report[$key]) | Out-File $txtPath -Append -Encoding UTF8
        } catch {
            "ERREUR: $($_.Exception.Message)" | Out-File $txtPath -Append -Encoding UTF8
        }
    }

    # --- HTML
    $html = New-NTHtmlHeader -Title "Rapport NeoTech - $env:COMPUTERNAME"
    $html += "<h1>Rapport technique NeoTech Toolkit</h1>"
    $html += "<p><b>Poste :</b> $env:COMPUTERNAME &middot; <b>Operateur :</b> $env:USERNAME &middot; <b>Date :</b> $stampStr</p>"
    foreach ($key in $report.Keys) {
        $html += "<h2>$([System.Web.HttpUtility]::HtmlEncode($key))</h2>"
        $html += "<pre>"
        try {
            $data = & $report[$key]
            $html += [System.Web.HttpUtility]::HtmlEncode($data)
        } catch {
            $html += "ERREUR: $($_.Exception.Message)"
        }
        $html += "</pre>"
    }
    $html += New-NTHtmlFooter

    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    $html | Out-File $htmlPath -Encoding UTF8

    Write-NTStatus -Message "Rapport TXT :  $txtPath"  -Status OK
    Write-NTStatus -Message "Rapport HTML : $htmlPath" -Status OK
    Wait-NTKey
}

# --- Helpers de collecte (utilises par le rapport) ---------------------------

function Get-NTOverviewData {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if (-not $os) { return "OS indisponible" }
    $up = (Get-Date) - $os.LastBootUpTime
    @"
Nom de l'hote       : $($cs.Name)
Systeme             : $($os.Caption) (Build $($os.BuildNumber))
Architecture        : $($os.OSArchitecture)
Dernier boot        : $($os.LastBootUpTime)
Temps de marche     : $(Format-NTDuration -Span $up)
Utilisateur         : $env:USERNAME (Admin: $(if (Test-NTAdmin) {'OUI'} else {'non'}))
"@
}

function Get-NTHardwareData {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List | Out-String
    $ram = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Format-Table DeviceLocator, Capacity, Speed -AutoSize | Out-String
    $mb  = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Format-List Manufacturer, Product, SerialNumber | Out-String
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Format-Table Name, DriverVersion, AdapterRAM -AutoSize | Out-String
    "## CPU`n$cpu`n## RAM`n$ram`n## Carte mere`n$mb`n## GPU`n$gpu"
}

function Get-NTStorageData {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
        Select-Object DeviceID, VolumeName, FileSystem, Size, FreeSpace |
        Format-Table -AutoSize | Out-String
}

function Get-NTNetworkData {
    $nics = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        $ipv4 = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress -join ', '
        [pscustomobject]@{
            Interface = $_.Name
            MAC       = $_.MacAddress
            IPv4      = $ipv4
            Vitesse   = $_.LinkSpeed
        }
    } | Format-List | Out-String
    "## Interfaces`n$nics"
}

function Get-NTSecurityData {
    $tpm = Get-CimInstance -Namespace 'Root\CIMv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue |
        Select-Object IsEnabled_InitialValue, IsActivated_InitialValue, SpecVersion | Format-List | Out-String
    $bl = Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object MountPoint, VolumeStatus, EncryptionPercentage, ProtectionStatus | Format-Table -AutoSize | Out-String
    "## TPM`n$tpm`n## BitLocker`n$bl"
}

function Get-NTSoftwareData {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayVersion } |
            Select-Object DisplayName, DisplayVersion, Publisher
    }
    ($apps | Sort-Object DisplayName -Unique | Select-Object -First 50 | Format-Table -AutoSize | Out-String) +
    "`n`nTotal : $($apps.Count) applications"
}

function Get-NTDriverData {
    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceName -and $_.DriverVersion } |
        Select-Object -First 50 DeviceName, DeviceClass, DriverVersion, DriverDate |
        Format-Table -AutoSize | Out-String
}

function Get-NTStartupData {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    )
    $items = foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
            Get-Member -Type NoteProperty |
            Where-Object { $_.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider' } |
            ForEach-Object { [pscustomobject]@{ Source = $p; Nom = $_.Name; Valeur = (Get-ItemProperty -Path $p -Name $_.Name -ErrorAction SilentlyContinue).$($_.Name) } }
    }
    $items | Format-Table -AutoSize -Wrap | Out-String
}

function Get-NTServicesData {
    Get-Service -ErrorAction SilentlyContinue |
        Group-Object Status |
        Select-Object @{N='Etat';E={$_.Name}}, Count |
        Format-Table -AutoSize | Out-String
}

function Get-NTEventsData {
    $since = (Get-Date).AddHours(-24)
    $sys = $null
    $app = $null
    try { $sys = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$since} -ErrorAction Stop | Select-Object -First 15 } catch {}
    try { $app = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=$since} -ErrorAction Stop | Select-Object -First 15 } catch {}
    "## System (erreurs 24h)`n$($sys | Select-Object TimeCreated, ProviderName, Id | Format-Table -AutoSize | Out-String)`n## Application (erreurs 24h)`n$($app | Select-Object TimeCreated, ProviderName, Id | Format-Table -AutoSize | Out-String)"
}

# --- HTML helpers -----------------------------------------------------------

function New-NTHtmlHeader {
    param([string]$Title)
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>$([System.Web.HttpUtility]::HtmlEncode($Title))</title>
<style>
body { font-family: 'Segoe UI', Tahoma, sans-serif; margin: 24px; color: #222; }
h1 { color: #0891b2; border-bottom: 3px solid #0891b2; padding-bottom: 8px; }
h2 { color: #0e7490; margin-top: 32px; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
pre { background: #f4f4f4; padding: 12px; border-left: 3px solid #0891b2; overflow-x: auto; font-size: 12px; }
.meta { color: #666; font-size: 13px; }
.footer { margin-top: 48px; color: #999; font-size: 11px; border-top: 1px solid #ddd; padding-top: 12px; }
</style>
</head>
<body>
"@
}

function New-NTHtmlFooter {
    "<div class='footer'>Genere par NeoTech Toolkit v$NTVersion - $NTCopyright - $NTSite</div></body></html>"
}

Export-ModuleMember -Function `
    Export-NTReport, Get-NTReportPath

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUkCGPjnHyxjfQlJtuQ3CWyIII
# 8kWgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUz4VbqwDPX94QxRWViD00D8iu3EYwDQYJKoZIhvcNAQEBBQAE
# ggEAU40pcUrOVVitRpmZ4nXxORcza1OIial3S/FBAom/RfBIbw9DITvjIBfV1wMK
# veVypFSgItmhoI7wH23ooQM5GIHv50KPY1gWruj9HOQCvmMdDhK5c8vIMus6sFdt
# 8gkJCoJsCPUcwXTnTced4KEneFSU8v1mpR8p4xqaggjP3C+FMhyGYRJ7r0e6zChj
# TLIgbURpRyVQHzyyhHBOks+PGKKs0PLcSZHu4f89ks7YabOJlpKnvubplUK3+piq
# s0w02BhPYWo+UCmSjCaQt2Jt5OAK5rEqgaT0zl6L0MaDH7pgMDd+U15b+d4xekKa
# anRiagL8ntF8oFq1jfa6s/RK8Q==
# SIG # End signature block
