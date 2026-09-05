# =============================================================================
# Module      : NTStartup
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Inventaire demarrage et taches planifiees.
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTStartupItems {
    <#
    .SYNOPSIS
        Inventaire complet des elements de demarrage : registre + dossier Startup + taches planifiees.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'ELEMENTS DE DEMARRAGE'

    $items = New-Object System.Collections.Generic.List[object]

    # Registre HKLM / HKCU Run et RunOnce
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    foreach ($p in $regPaths) {
        if (-not (Test-Path $p)) { continue }
        $reg = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
        if (-not $reg) { continue }
        $reg | Get-Member -Type NoteProperty | Where-Object {
            $_.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider'
        } | ForEach-Object {
            $val = $reg.($_.Name)
            if ($val) {
                $items.Add([pscustomobject]@{
                    Source   = $p
                    Nom      = $_.Name
                    Commande = $val
                    Type     = 'Registre'
                })
            }
        }
    }

    # Dossiers Startup
    $startupDirs = @(
        [Environment]::GetFolderPath('Startup'),
        [Environment]::GetFolderPath('CommonStartup')
    )
    foreach ($d in $startupDirs) {
        if (Test-Path $d) {
            $shortcuts = Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue
            if ($shortcuts) {
                $shortcuts | ForEach-Object {
                    $items.Add([pscustomobject]@{
                        Source   = $d
                        Nom      = $_.Name
                        Commande = $_.FullName
                        Type     = 'Raccourci'
                    })
                }
            }
        }
    }

    # Taches planifiees (Boot / Logon)
    $bootTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.State -ne 'Disabled' -and $_.Triggers
    } | Where-Object {
        $_.Triggers | Where-Object { $_.CimClass -and $_.CimClass.CimClassName -match 'BootTrigger|LogonTrigger' }
    }
    if ($bootTasks) {
        $bootTasks | ForEach-Object {
            $cmdText = ''
            if ($_.Actions) {
                $parts = $_.Actions | ForEach-Object {
                    $exe = if ($_.PSObject.Properties['Execute'])   { $_.Execute }   else { '' }
                    $arg = if ($_.PSObject.Properties['Arguments']) { $_.Arguments } else { '' }
                    "$exe $arg".Trim()
                }
                $cmdText = ($parts -join '; ').Trim()
            }
            $items.Add([pscustomobject]@{
                Source   = 'TaskScheduler'
                Nom      = $_.TaskName
                Commande = $cmdText
                Type     = "Tache ($($_.State))"
            })
        }
    }

    if ($items.Count -gt 0) {
        $items | Format-Table -AutoSize -Wrap
        Write-Host "  Total : $($items.Count) elements de demarrage" -ForegroundColor Cyan
    } else {
        Write-NTStatus -Message 'Aucun element de demarrage detecte.' -Status INFO
    }

    Wait-NTKey
}

function Get-NTScheduledTasks {
    <#
    .SYNOPSIS
        Liste des taches planifiees systeme et utilisateur (avec prochaine exec).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'TACHES PLANIFIEES'

    Write-NTSubHeader 'TACHES ACTIVES (toutes sources)'
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' }
    if ($tasks) {
        $rows = foreach ($t in $tasks) {
            $next = 'N/D'
            $info = $null
            try { $info = Get-ScheduledTaskInfo -InputObject $t -ErrorAction Stop } catch { }
            if ($info) {
                $nextRun = $info.NextRunTime
                if ($nextRun -and $nextRun -ne [DateTime]::MinValue -and $nextRun.Year -gt 1900) {
                    $next = $nextRun.ToString('yyyy-MM-dd HH:mm')
                }
            }
            $trigNames = @()
            if ($t.Triggers) {
                $trigNames = $t.Triggers | ForEach-Object {
                    if ($_.PSObject.Properties['CimClass'] -and $_.CimClass.PSObject.Properties['CimClassName']) {
                        $_.CimClass.CimClassName -replace 'Trigger',''
                    } else { '' }
                }
            }
            [pscustomobject]@{
                TaskPath        = $t.TaskPath
                TaskName        = $t.TaskName
                State           = if ($t.PSObject.Properties['State']) { $t.State.ToString() } else { 'Unknown' }
                Declencheurs    = ($trigNames -join ',')
                'Prochaine exec'= $next
            }
        }
        $rows | Sort-Object TaskPath, TaskName | Format-Table -AutoSize -Wrap
        Write-Host "  Total : $($rows.Count) taches actives" -ForegroundColor Cyan
    } else {
        Write-NTStatus -Message 'Aucune tache active trouvee.' -Status INFO
    }
    Wait-NTKey
}

Export-ModuleMember -Function Get-NTStartupItems, Get-NTScheduledTasks
# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUS6zxh5USfYhvMFxlzL1r599M
# E/igggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUruYJ1rB13watXYOOc2jhK7Ijk4cwDQYJKoZIhvcNAQEBBQAE
# ggEAQdXKzLrcdGL2ATsm9zrSl/S9LGnk7uZtP6CRyW6Z/8PcotQQ7KNEmYBIAb/P
# AiwlrWfJNVGH/cP9GApSwJsBWdBLnlP9vnpirbL3+f6ftHfBpqilpQumS4IkWP+P
# jPFNHjm0GZKh0yK1B2nHi2lDLAq8/X0NlSS+NiHVc2oRxFzybsMujxxvPcQkbe2h
# 6r2JNLtBA5WgCfHb6m48tj7h461ndW1bb41m6cs3RePRUfOzwsbnE1GHfm7lxk69
# ufhQkDKscq+DVigkKg/6Gb0/6vrcSmIj088/ctAxzpWqmN2z405/cMHwDpKtbuB1
# EBPe9vactmkW5prMPJDWoxmqfQ==
# SIG # End signature block
