# =============================================================================
# Module      : NTAudit
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Audit materiel et systeme (OS, hardware, pilotes, logiciels, Windows Update).
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTOverview {
    <#
    .SYNOPSIS
        Synthese rapide machine et OS.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'SYNTHESE MACHINE ET OS'
    $os    = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs    = Get-CimInstance Win32_ComputerSystem    -ErrorAction SilentlyContinue
    $bios  = Get-CimInstance Win32_BIOS              -ErrorAction SilentlyContinue
    if (-not $os -or -not $cs) {
        Write-NTStatus -Message 'Impossible de lire les informations systeme (CIM indisponible).' -Status FAIL
        Wait-NTKey; return
    }
    $uptime = (Get-Date) - $os.LastBootUpTime

    [pscustomobject]@{
        "Nom de l'hote"      = $cs.Name
        "Constructeur"       = $cs.Manufacturer
        "Modele"             = $cs.Model
        "Domaine/Workgroup"  = $cs.Domain
        "Systeme"            = "$($os.Caption) (Build $($os.BuildNumber))"
        "Architecture"       = $os.OSArchitecture
        "Version .NET"       = [System.Environment]::Version.ToString()
        "BIOS"               = if ($bios) { "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)" } else { 'N/D' }
        "Date BIOS"          = if ($bios -and $bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { 'N/D' }
        "Dernier boot"       = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
        "Temps de marche"    = Format-NTDuration -Span $uptime
        "Utilisateur actif"  = "$env:USERNAME (admin: $(if (Test-NTAdmin) {'OUI'} else {'non'}))"
        "Install date"       = if ($os.InstallDate) { $os.InstallDate.ToString('yyyy-MM-dd') } else { 'N/D' }
    } | Format-List
    Wait-NTKey
}

function Get-NTHardwareSpecs {
    <#
    .SYNOPSIS
        Inventaire detaille CPU, RAM, carte mere, GPU.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'CPU / RAM / CARTE MERE / GPU'

    Write-NTSubHeader 'PROCESSEUR'
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    if ($cpu) {
        foreach ($c in $cpu) {
            $cores = if ($c.PSObject.Properties['NumberOfCores']) { $c.NumberOfCores } else { 'N/D' }
            $threads = if ($c.PSObject.Properties['NumberOfLogicalProcessors']) { $c.NumberOfLogicalProcessors } else { 'N/D' }
            $virt = if ($c.PSObject.Properties['VirtualizationFirmwareEnabled']) { $c.VirtualizationFirmwareEnabled } else { 'N/D' }
            [pscustomobject]@{
                Nom           = $c.Name.Trim()
                Coeurs        = $cores
                Threads       = $threads
                Socket        = $c.SocketDesignation
                FreqMaxMHz     = $c.MaxClockSpeed
                L2CacheKB      = $c.L2CacheSize
                L3CacheKB      = $c.L3CacheSize
                Virtualisation = $virt
            } | Format-List
        }
    } else { Write-NTStatus -Message 'Aucun processeur detecte.' -Status FAIL }

    Write-NTSubHeader 'MEMOIRE VIVE'
    $ram = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    if ($ram) {
        $total = ($ram | Measure-Object -Property Capacity -Sum).Sum
        Write-Host "  Capacite totale : $(Format-NTBytes -Bytes $total) ($([math]::Round($total/1GB,2)) GB)" -ForegroundColor White
        $ram | Select-Object DeviceLocator,
            @{N='Taille';E={Format-NTBytes -Bytes $_.Capacity}},
            @{N='Vitesse (MT/s)';E={$_.Speed}},
            Manufacturer,
            PartNumber,
            @{N='Type';E={
                switch ($_.SMBIOSMemoryType) {
                    20  {'DDR'}
                    21  {'DDR2'}
                    24  {'DDR3'}
                    26  {'DDR4'}
                    30  {'DDR5'}
                    default {"Type $($_.SMBIOSMemoryType)"}
                }
            }} | Format-Table -AutoSize
    } else { Write-NTStatus -Message 'Aucune memoire detectee.' -Status FAIL }

    Write-NTSubHeader 'CARTE MERE'
    $mb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    if ($mb) {
        $mb | Select-Object Manufacturer, Product, Version, SerialNumber, SKU | Format-List
    } else { Write-NTStatus -Message 'Carte mere inconnue.' -Status WARN }

    Write-NTSubHeader 'CARTE(S) GRAPHIQUE(S)'
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    if ($gpu) {
        $gpu | Select-Object Name,
            @{N='VRAM';E={if ($_.AdapterRAM) { Format-NTBytes -Bytes $_.AdapterRAM } else { 'N/D' }}},
            DriverVersion,
            DriverDate,
            VideoModeDescription | Format-Table -AutoSize -Wrap
    } else { Write-NTStatus -Message 'Aucun GPU detecte.' -Status FAIL }

    Wait-NTKey
}

function Get-NTDriverInventory {
    <#
    .SYNOPSIS
        Inventaire des pilotes, classes regroupees, plus anciens.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'INVENTAIRE DES PILOTES'

    Write-NTSubHeader 'RESUME PAR CLASSEMENT'
    $drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceName } |
        Select-Object DeviceName,
            @{N='Classe';E={
                switch ($_.DeviceClass) {
                    'DISPLAY'   {'Affichage'}
                    'NET'       {'Reseau'}
                    'MEDIA'     {'Audio'}
                    'SCSIAdapter' {'Stockage'}
                    'HDC'       {'Controleur disque'}
                    'USB'       {'USB'}
                    'System'    {'Systeme'}
                    'Keyboard'  {'Clavier'}
                    'Mouse'     {'Souris'}
                    'Printer'   {'Imprimante'}
                    'Monitor'   {'Moniteur'}
                    'Bluetooth' {'Bluetooth'}
                    default     { if ($_.DeviceClass) { $_.DeviceClass } else { 'Autre' } }
                }
            }},
            DriverVersion,
            DriverDate,
            Manufacturer |
        Sort-Object Classe, DeviceName

    if ($drivers) {
        $drivers | Format-Table -AutoSize -Wrap
        Write-Host "  Total : $($drivers.Count) pilotes" -ForegroundColor Cyan
    } else {
        Write-NTStatus -Message 'Aucun pilote recuperable.' -Status WARN
    }

    Wait-NTKey
}

function Get-NTInstalledSoftware {
    <#
    .SYNOPSIS
        Inventaire des logiciels installes (32 + 64 bits).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'LOGICIELS INSTALLES'

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = foreach ($p in $paths) {
        try {
            Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | ForEach-Object {
                $name = if ($_.PSObject.Properties['DisplayName']) { $_.DisplayName } else { $null }
                $ver  = if ($_.PSObject.Properties['DisplayVersion']) { $_.DisplayVersion } else { $null }
                $pub  = if ($_.PSObject.Properties['Publisher']) { $_.Publisher } else { '' }
                if ($name -and $ver) {
                    [pscustomobject]@{
                        DisplayName    = $name
                        DisplayVersion = $ver
                        Publisher      = $pub
                    }
                }
            }
        } catch { }
    }

    $apps = @($apps | Sort-Object DisplayName -Unique)

    if ($apps.Count -gt 0) {
        Write-Host "  Total : $($apps.Count) applications" -ForegroundColor Cyan
        $apps | Format-Table -AutoSize -Wrap

        Write-NTSubHeader 'EDITEURS LES PLUS PRESENTS'
        $apps | Group-Object Publisher |
            Where-Object { $_.Name } |
            Sort-Object Count -Descending |
            Select-Object -First 15 |
            ForEach-Object { Write-Host ("  {0,-40}  {1} application(s)" -f $_.Name, $_.Count) }
    } else {
        Write-NTStatus -Message 'Aucun logiciel trouve dans le registre.' -Status WARN
    }

    Wait-NTKey
}

function Get-NTWindowsUpdateStatus {
    <#
    .SYNOPSIS
        Etat de Windows Update (historique + en attente).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'WINDOWS UPDATE'

    $wuSession = New-Object -ComObject Microsoft.Update.Session -ErrorAction SilentlyContinue
    if (-not $wuSession) {
        Write-NTStatus -Message 'COM Microsoft.Update.Session indisponible (service WUA peut etre arrete).' -Status FAIL
        Wait-NTKey; return
    }
    $searcher = $wuSession.CreateUpdateSearcher()
    try {
        Write-NTSubHeader 'HISTORIQUE RECENT (20 derniers)'
        $history = $searcher.QueryHistory(0, 20) | ForEach-Object {
            [pscustomobject]@{
                Date    = $_.Date.ToString('yyyy-MM-dd HH:mm')
                Titre   = $_.Title
                Result  = switch ($_.ResultCode) { 0 {'Non lance'} 1 {'Incomplet'} 2 {'OK'} 3 {'KO'} 4 {'Annule'} default {"Code $($_.ResultCode)"} }
                Categorie = $_.Categories | Select-Object -First 1 -ExpandProperty Name
            }
        }
        $history | Format-Table -AutoSize -Wrap

        Write-NTSubHeader 'MISES A JOUR EN ATTENTE'
        $pendingCount = 0
        try {
            $searchResult = $searcher.Search('IsInstalled=0 and IsHidden=0')
            $pendingCount = $searchResult.Updates.Count
        } catch { }
        if ($pendingCount -gt 0) {
            Write-NTStatus -Message "$pendingCount mise(s) a jour en attente." -Status WARN
        } else {
            Write-NTStatus -Message 'Aucune mise a jour en attente.' -Status OK
        }
    } catch {
        Write-NTStatus -Message "Erreur : $($_.Exception.Message)" -Status FAIL
    } finally {
        try {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($searcher) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wuSession) | Out-Null
        } catch { }
    }

    Wait-NTKey
}

Export-ModuleMember -Function Get-NTOverview, Get-NTHardwareSpecs, Get-NTDriverInventory, Get-NTInstalledSoftware, Get-NTWindowsUpdateStatus
# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOSdCE4umeVjiNqQnrle9AGfG
# 1Y2gggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUTVX1iJScD2d3BJbbahedoCNcXQYwDQYJKoZIhvcNAQEBBQAE
# ggEAYhIZeIQUr1PlgD8tGQdc2NdPrCbtT5Dn2SHYSkGhr9DlDOLdXA6//S3PZ6dz
# Ssq0ADOJ1tL8XK585C4uN8g11GLX04dAIuYIpNgWmjdCTMtVbX43ovRzTa6lPuKE
# S0d6ohJBlIVa0rA4kOxDGj+MB2eku9XXj4w8/b15WGYPx16tIYsINU3FXgSzG5YH
# PUcMjmLVzygH4QI+tR/Ttvy8kMNJrdS/QCusk1rvTJLljB5sQIdDCuIfobT+1fct
# 8M7XeGvNu3Vv1gadyi3hb4aWvVdz9pJ+yqblb7/CNv6I5u0brxAFGyuzNe+OQV0R
# NjOob2apQoxu8w8uU8J2y6ELnQ==
# SIG # End signature block
