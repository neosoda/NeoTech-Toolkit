# =============================================================================
# Module      : NTSecurity
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Audit securite (TPM, Secure Boot, BitLocker, Defender, firewall,
#               comptes locaux, UAC, strategie de groupe).
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTSecurityStatus {
    <#
    .SYNOPSIS
        Posture de securite globale : TPM, Secure Boot, BitLocker, Defender, Firewall, UAC.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'POSTURE DE SECURITE GLOBALE'

    # --- TPM
    Write-NTSubHeader 'TPM'
    $tpm = Get-CimInstance -Namespace 'Root\CIMv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if ($tpm) {
        $tpmEnabled = if ($tpm.PSObject.Properties['IsEnabled_InitialValue'])  { $tpm.IsEnabled_InitialValue  } else { 'N/D' }
        $tpmActive  = if ($tpm.PSObject.Properties['IsActivated_InitialValue']) { $tpm.IsActivated_InitialValue } else { 'N/D' }
        $tpmOwner   = if ($tpm.PSObject.Properties['IsOwned_InitialValue'])    { $tpm.IsOwned_InitialValue    } else { 'N/D' }
        $tpmSpec    = if ($tpm.PSObject.Properties['SpecVersion'])          { $tpm.SpecVersion             } else { 'N/D' }
        $tpmManuf   = if ($tpm.PSObject.Properties['ManufacturerVersion'])  { $tpm.ManufacturerVersion     } else { 'N/D' }
        $tpmManTxt  = if ($tpm.PSObject.Properties['ManufacturerIdText'])   { $tpm.ManufacturerIdText      } else { 'N/D' }
        [pscustomobject]@{
            'TPM Present'        = $tpmEnabled
            'TPM Active'         = $tpmActive
            'TPM Owner'          = $tpmOwner
            'Version'            = "$tpmSpec ($tpmManuf)"
            'Fabricant'          = $tpmManTxt
        } | Format-List
    } else { Write-NTStatus -Message 'Module TPM non disponible ou non active.' -Status WARN }

    # --- Secure Boot
    Write-NTSubHeader 'SECURE BOOT'
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        Write-NTStatus -Message "Secure Boot : ACTIVE" -Status OK
    } catch {
        Write-NTStatus -Message 'Secure Boot : inactif (ou mode Legacy/CSM)' -Status WARN
    }

    # --- BitLocker
    Write-NTSubHeader 'BITLOCKER'
    $bl = Get-BitLockerVolume -ErrorAction SilentlyContinue
    if ($bl) {
        $bl | Select-Object MountPoint, VolumeStatus, @{N='% chiffrement';E={
            if ($_.EncryptionPercentage) { $_.EncryptionPercentage } else { 0 }
        }}, ProtectionStatus, KeyProtector | Format-Table -AutoSize -Wrap
    } else { Write-NTStatus -Message 'BitLocker non actif sur cette edition.' -Status INFO }

    # --- Windows Defender
    Write-NTSubHeader 'WINDOWS DEFENDER'
    $defStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defStatus) {
        $defAv   = if ($defStatus.PSObject.Properties['AntivirusEnabled'])        { $defStatus.AntivirusEnabled }        else { 'N/D' }
        $defAs   = if ($defStatus.PSObject.Properties['AntispywareEnabled'])      { $defStatus.AntispywareEnabled }      else { 'N/D' }
        $defRtp  = if ($defStatus.PSObject.Properties['RealTimeProtectionEnabled']) { $defStatus.RealTimeProtectionEnabled } else { 'N/D' }
        $defAms  = if ($defStatus.PSObject.Properties['AMServiceEnabled'])       { $defStatus.AMServiceEnabled }       else { 'N/D' }
        $defTamp = if ($defStatus.PSObject.Properties['TamperProtection'])       { $defStatus.TamperProtection }       else { 'N/D' }
        $defNis  = if ($defStatus.PSObject.Properties['NISEnabled'])              { $defStatus.NISEnabled }              else { 'N/D' }
        $defSig  = if ($defStatus.PSObject.Properties['AntivirusSignatureVersion']) { $defStatus.AntivirusSignatureVersion } else { 'N/D' }
        $defUpd  = if ($defStatus.PSObject.Properties['AntivirusSignatureLastUpdated']) { $defStatus.AntivirusSignatureLastUpdated } else { 'N/D' }
        $defScan = if ($defStatus.PSObject.Properties['FullScanEndTime'])        { $defStatus.FullScanEndTime }        else { 'N/D' }
        [pscustomobject]@{
            'Antivirus active'         = $defAv
            'Antispyware active'       = $defAs
            'Protection temps reel'    = $defRtp
            'Defender actif'           = $defAms
            'Mode tampons'             = $defTamp
            'NIS active'               = $defNis
            'Defender signatures'      = "$defSig  (MAJ: $defUpd)"
            'Derniere analyse'         = $defScan
        } | Format-List
    } else { Write-NTStatus -Message 'Get-MpComputerStatus indisponible (Defender peut etre desactive).' -Status WARN }

    # --- Pare-feu
    Write-NTSubHeader 'PARE-FEU (par profil)'
    Get-NetFirewallProfile -ErrorAction SilentlyContinue |
        Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, LogFileName |
        Format-Table -AutoSize

    # --- UAC
    Write-NTSubHeader 'UAC (CONTRÃ”LE DE COMPTE UTILISATEUR)'
    $uacKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $uac    = Get-ItemProperty -Path $uacKey -ErrorAction SilentlyContinue
    if ($uac) {
        [pscustomobject]@{
            'ConsentPromptBehaviorAdmin'   = $uac.ConsentPromptBehaviorAdmin
            'PromptOnSecureDesktop'        = $uac.PromptOnSecureDesktop
            'EnableLUA'                    = $uac.EnableLUA
            'EnableInstallerDetection'     = $uac.EnableInstallerDetection
        } | Format-List
    }

    Wait-NTKey
}

function Get-NTLocalUsers {
    <#
    .SYNOPSIS
        Liste des comptes locaux et membres des groupes sensibles.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'COMPTES LOCAUX ET GROUPES'

    Write-NTSubHeader 'COMPTES LOCAUX'
    Get-LocalUser -ErrorAction SilentlyContinue |
        Select-Object Name, Enabled, PasswordRequired, PasswordLastSet, LastLogon, Description |
        Format-Table -AutoSize -Wrap

    Write-NTSubHeader 'MEMBRES DU GROUPE ADMINISTRATEURS'
    try {
        Get-LocalGroupMember -Group 'Administrateurs' -ErrorAction Stop |
            Select-Object Name, ObjectClass, PrincipalSource |
            Format-Table -AutoSize -Wrap
    } catch {
        Write-NTStatus -Message "Impossible de lire le groupe : $($_.Exception.Message)" -Status FAIL
    }

    Wait-NTKey
}

function Get-NTGroupPolicy {
    <#
    .SYNOPSIS
        Resultat de strategie de groupe (gpresult).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'STRATEGIE DE GROUPE (GPRESULT)'

    if (-not (Test-NTAdmin)) {
        Write-NTStatus -Message 'gpresult etendu necessite les droits administrateur (resultat partiel ci-dessous).' -Status WARN
    }

    $runGpresult = {
        param($scope)
        & gpresult.exe "/scope" $scope "/v" 2>&1 | Out-String -Width ([int]::MaxValue)
    }

    Write-NTSubHeader 'ORDINATEUR'
    $r = Invoke-NTSafe -Component 'Security' -Title 'gpresult /scope computer' -ScriptBlock {
        $out = & gpresult.exe /scope computer /v 2>&1 | Out-String -Width ([int]::MaxValue)
        if ($LASTEXITCODE -ne 0) { throw "gpresult a echoue (code $LASTEXITCODE)" }
        $out
    }
    if ($r.Success) {
        ($r.Data -split "`n" | Select-String -Pattern 'GPO|Group Policy|Strat' | Select-Object -First 20) |
            ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-NTStatus -Message $r.Error -Status WARN
    }

    Write-NTSubHeader 'UTILISATEUR'
    $r = Invoke-NTSafe -Component 'Security' -Title 'gpresult /scope user' -ScriptBlock {
        $out = & gpresult.exe /scope user /v 2>&1 | Out-String -Width ([int]::MaxValue)
        if ($LASTEXITCODE -ne 0) { throw "gpresult a echoue (code $LASTEXITCODE)" }
        $out
    }
    if ($r.Success) {
        ($r.Data -split "`n" | Select-String -Pattern 'GPO|Group Policy|Strat' | Select-Object -First 20) |
            ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-NTStatus -Message $r.Error -Status WARN
        Write-Host '  Astuce : lancer en invite de commandes admin (gpresult /USER $env:USERNAME /V)' -ForegroundColor DarkGray
    }

    Wait-NTKey
}
# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0sjKgBhbNR64pP1sLsILg4sd
# wl2gggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUKb1cn3bw38QS5S0utIqVoOjsj7swDQYJKoZIhvcNAQEBBQAE
# ggEAVSTzRY2h6Cb7ukBHuxwzpUOyuiTT260iQZc5OoyIbidwpWof5n5cFXmKH0Go
# 7ypltFfed77hZG8BUbtTPoLoOPa7ZQ2o2x8HVM/3R+bSi2VajWU56nSTaIAta4m/
# sAbQnCViWGUCGFpo4rGDHiwSHt3clq9JZquwhS2KBN/aW2ZQI7YQaFPKWyIlNBzc
# bHt81FWCXzIN67DUyx9DGrD4vjFgVCdhfst/VqoujDSY05W0L34FToqKQ3g0cgeE
# l32GIUDbKNgILLLRxSpBBKp+FKRuXp5GTwTexQ/VSAORBhNi+JdjYim24D49tAXZ
# 15X8PT+jLzHyRp43QSW6gVd0kg==
# SIG # End signature block
