# =============================================================================
# Module      : NTPerformance
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Processus, services, observateur d'evenements, snapshot perf.
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTProcessSnapshot {
    <#
    .SYNOPSIS
        Snapshot instantane des processus (top CPU/RAM).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'PROCESSUS - SNAPSHOT'

    Write-NTSubHeader 'TOP 15 PAR CPU'
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CPU -ne $null } |
        Sort-Object CPU -Descending |
        Select-Object -First 15 |
        Select-Object Name, Id, @{N='CPU (s)';E={[math]::Round($_.CPU,1)}},
            @{N='RAM (MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}},
            @{N='Threads';E={$_.Threads.Count}},
            Path |
        Format-Table -AutoSize -Wrap

    Write-NTSubHeader 'TOP 15 PAR RAM'
    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 15 |
        Select-Object Name, Id, @{N='RAM (MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}},
            @{N='CPU (s)';E={[math]::Round($_.CPU,1)}},
            @{N='Threads';E={$_.Threads.Count}},
            Path |
        Format-Table -AutoSize -Wrap

    Write-NTSubHeader 'COMPTEURS GLOBAUX'
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $cpuLoad = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
            Measure-Object -Property LoadPercentage -Average).Average
        $procs = @(Get-Process -ErrorAction SilentlyContinue)
        $threadCount = ($procs | ForEach-Object {
            if ($_.Threads) { @($_.Threads).Count } else { 0 }
        } | Measure-Object -Sum).Sum
        [pscustomobject]@{
            'CPU Load (%)'        = $cpuLoad
            'RAM totale (MB)'     = [math]::Round($os.TotalVisibleMemorySize/1KB,1)
            'RAM libre (MB)'      = [math]::Round($os.FreePhysicalMemory/1KB,1)
            'RAM utilisee (%)'    = [math]::Round((1 - $os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,1)
            'Commit total (MB)'   = [math]::Round($os.TotalVirtualMemorySize/1KB,1)
            'Commit libre (MB)'   = [math]::Round($os.FreeVirtualMemory/1KB,1)
            'Threads systeme (approx)' = $threadCount
            'Processus actifs'    = $procs.Count
        } | Format-List
    }
    Wait-NTKey
}

function Get-NTEventLog {
    <#
    .SYNOPSIS
        Evenements recents (System, Application) : erreurs et warnings des 24 dernieres heures.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'OBSERVATEUR D EVENEMENTS (24H)'

    $since = (Get-Date).AddHours(-24)

    Write-NTSubHeader 'ERREURS SYSTEME (top 25)'
    try {
        Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$since} -ErrorAction Stop |
            Select-Object -First 25 |
            Select-Object TimeCreated, ProviderName, Id, @{N='Message';E={
                if ($_.Message.Length -gt 200) { $_.Message.Substring(0,200) + '...' } else { $_.Message }
            }} | Format-Table -AutoSize -Wrap
    } catch {
        Write-NTStatus -Message "Aucun evenement Systeme erreur ou journal vide." -Status INFO
    }

    Write-NTSubHeader 'ERREURS APPLICATION (top 25)'
    try {
        Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=$since} -ErrorAction Stop |
            Select-Object -First 25 |
            Select-Object TimeCreated, ProviderName, Id, @{N='Message';E={
                if ($_.Message.Length -gt 200) { $_.Message.Substring(0,200) + '...' } else { $_.Message }
            }} | Format-Table -AutoSize -Wrap
    } catch {
        Write-NTStatus -Message "Aucun evenement Application erreur ou journal vide." -Status INFO
    }

    Wait-NTKey
}

function Get-NTServiceStatus {
    <#
    .SYNOPSIS
        Etat global des services (compte par type).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'SERVICES WINDOWS'

    Write-NTSubHeader 'RESUME'
    $services = Get-Service -ErrorAction SilentlyContinue
    $services | Group-Object Status |
        Select-Object @{N='Etat';E={$_.Name}}, Count |
        Format-Table -AutoSize

    Write-NTSubHeader 'SERVICES ARRETES QUI DEMARRENT EN AUTO (candidats a investiguer)'
    $stoppedAuto = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State='Stopped'" -ErrorAction SilentlyContinue |
        Select-Object Name, DisplayName, StartMode, State, StartName |
        Sort-Object DisplayName
    if ($stoppedAuto) {
        $stoppedAuto | Format-Table -AutoSize -Wrap
        Write-Host "  Total : $($stoppedAuto.Count) services en Auto mais arretes" -ForegroundColor Cyan
    } else {
        Write-NTStatus -Message 'Aucun service Auto arrete. Poste propre.' -Status OK
    }

    Wait-NTKey
}

function Get-NTPerformanceSnapshot {
    <#
    .SYNOPSIS
        Snapshot performance (CPU/RAM/disque) sur une duree parametrable.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet(3,5,10,30)][int]$DurationSec = 5
    )
    Write-NTHeader "SNAPSHOT PERFORMANCE (${DurationSec}s)"

    Write-Host "  Echantillonnage sur $DurationSec secondes..." -ForegroundColor Cyan
    $samples = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $DurationSec; $i++) {
        $cpuSample = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
            Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $ramPct = if ($os) { [math]::Round((1 - $os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,1) } else { 0 }
        $samples.Add([pscustomobject]@{
            Time  = (Get-Date).ToString('HH:mm:ss')
            CPU   = $cpuSample
            RAM   = $ramPct
        })
        Start-Sleep -Seconds 1
    }

    $samples | Format-Table -AutoSize

    [pscustomobject]@{
        'CPU moyen'   = [math]::Round((($samples | Measure-Object -Property CPU -Average).Average), 1)
        'CPU max'     = [math]::Round((($samples | Measure-Object -Property CPU -Maximum).Maximum), 1)
        'RAM moyen'   = [math]::Round((($samples | Measure-Object -Property RAM -Average).Average), 1)
        'RAM max'     = [math]::Round((($samples | Measure-Object -Property RAM -Maximum).Maximum), 1)
    } | Format-List

    Wait-NTKey
}

Export-ModuleMember -Function `
    Get-NTProcessSnapshot, Get-NTEventLog, Get-NTServiceStatus, Get-NTPerformanceSnapshot

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULrg/BXfwyvVkbSnZ7hJ8sawK
# 2FugggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUl86h2dKfwn58Q7hol+K51YlaTc4wDQYJKoZIhvcNAQEBBQAE
# ggEAs3mRTthQXRV9LOjbhS7LZQHH9SC11eX+JSD7UgMH47J9isApOcndEjK4o1JQ
# AIRiG3Xb640iowLdBqlVnH3iNRBOsPU7TP4FQZEELDAiR69spyI5wJBTBQLLoJYu
# aj/dJDXOqb2db+bsCJEABCySne/GcCYy35n+VylxuTS02m6/ltXtfHAE3hfOl7T4
# HqPoHRUb681X5lXYsWPw1Kykn6Wcs+oZ6Fmw9v0BsAulh5NdUQu9F3XO/Dt0mRFQ
# tvgqWJ7vKkTISe5JLjJBNh9AL1A1ifOl34rhDdQB1MlFNdT7VHkvFGuMOggvGoe6
# 5JWQ+S7zIuYUH1cG5eDRjEFr9A==
# SIG # End signature block
