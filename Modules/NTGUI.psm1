# =============================================================================
# Module      : NTGUI
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Interface graphique WPF pour NeoTech Toolkit.
#               - Theme sombre moderne (accent cyan #00D4AA)
#               - Sidebar 7 categories
#               - Zone de sortie (RichTextBox) pour output capture
#               - Compatible avec les fonctions metier existantes
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1
# L'hote STA est requis pour WPF - lance par l'entry point avec -STA

Set-StrictMode -Version Latest

# --- XAML --------------------------------------------------------------------

$XamlMain = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NeoTech Toolkit" Height="720" Width="1180"
        WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="13"
        Background="#1E1E1E" Foreground="#E0E0E0"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <SolidColorBrush x:Key="BgDark"      Color="#1E1E1E"/>
        <SolidColorBrush x:Key="BgPanel"     Color="#252525"/>
        <SolidColorBrush x:Key="BgSubPanel"  Color="#2A2A2A"/>
        <SolidColorBrush x:Key="BgOutput"    Color="#0E0E0E"/>
        <SolidColorBrush x:Key="Accent"      Color="#00D4AA"/>
        <SolidColorBrush x:Key="AccentBlue"  Color="#0078D4"/>
        <SolidColorBrush x:Key="AccentDim"   Color="#B0D0FF"/>
        <SolidColorBrush x:Key="TextDim"     Color="#909090"/>
        <SolidColorBrush x:Key="TextWhite"   Color="#E8E8E8"/>
        <SolidColorBrush x:Key="TextMuted"   Color="#666666"/>
        <SolidColorBrush x:Key="HoverBg"     Color="#2E2E2E"/>
        <SolidColorBrush x:Key="SelBg"       Color="#0E3D38"/>
        <SolidColorBrush x:Key="SelAccent"   Color="#00D4AA"/>
        <SolidColorBrush x:Key="Warn"        Color="#FFD700"/>
        <SolidColorBrush x:Key="Err"         Color="#FF6B6B"/>
        <SolidColorBrush x:Key="Ok"          Color="#4ADE80"/>

        <Style TargetType="Button" x:Key="SideButton">
            <Setter Property="Background"  Value="Transparent"/>
            <Setter Property="Foreground"  Value="{StaticResource TextWhite}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"     Value="20,10"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="FontSize"    Value="13"/>
            <Setter Property="Cursor"      Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{StaticResource HoverBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button" x:Key="SubButton">
            <Setter Property="Background"  Value="{StaticResource BgSubPanel}"/>
            <Setter Property="Foreground"  Value="{StaticResource TextWhite}"/>
            <Setter Property="BorderBrush" Value="#3A3A3A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"     Value="14,8"/>
            <Setter Property="Margin"      Value="0,0,8,8"/>
            <Setter Property="FontSize"    Value="12"/>
            <Setter Property="Cursor"      Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#3A3A3A"/>
                                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource Accent}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBlock" x:Key="SectionHeader">
            <Setter Property="Foreground" Value="{StaticResource TextMuted}"/>
            <Setter Property="FontSize"   Value="11"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin"     Value="0,14,0,6"/>
            <Setter Property="Padding"    Value="20,0"/>
        </Style>

        <Style TargetType="TextBlock" x:Key="TitleText">
            <Setter Property="Foreground" Value="{StaticResource Accent}"/>
            <Setter Property="FontSize"   Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin"     Value="0,0,0,8"/>
        </Style>

        <Style TargetType="Border" x:Key="Card">
            <Setter Property="Background" Value="{StaticResource BgOutput}"/>
            <Setter Property="CornerRadius" Value="4"/>
            <Setter Property="Padding"    Value="14"/>
            <Setter Property="Margin"     Value="0,4,0,0"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- En-tete -->
        <Border Grid.Row="0" Background="{StaticResource AccentBlue}" Padding="20,14">
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="NEOTECH TOOLKIT" Foreground="White" FontWeight="Bold" FontSize="20" VerticalAlignment="Center"/>
                <TextBlock x:Name="HeaderVersion" Text="  v1.0.0  -  Administration Windows" Foreground="{StaticResource AccentDim}" FontSize="13" VerticalAlignment="Center" Margin="12,0,0,0"/>
            </StackPanel>
        </Border>

        <!-- Corps principal : sidebar + contenu -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="240"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Sidebar -->
            <Border Grid.Column="0" Background="{StaticResource BgPanel}">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="Sidebar" Margin="0,8,0,0">
                        <TextBlock Text="AUDIT"           Style="{StaticResource SectionHeader}"/>
                        <Button x:Name="BtnAudit"       Content="&#x1F50D;  Audit Materiel"      Style="{StaticResource SideButton}" Tag="Audit"/>
                        <Button x:Name="BtnReseau"      Content="&#x1F310;  Reseau"             Style="{StaticResource SideButton}" Tag="Reseau"/>
                        <Button x:Name="BtnSecurite"    Content="&#x1F512;  Securite"           Style="{StaticResource SideButton}" Tag="Securite"/>

                        <TextBlock Text="MAINTENANCE"    Style="{StaticResource SectionHeader}"/>
                        <Button x:Name="BtnLogiciels"   Content="&#x1F4E6;  Logiciels"          Style="{StaticResource SideButton}" Tag="Logiciels"/>
                        <Button x:Name="BtnReparation"  Content="&#x1F527;  Reparation"         Style="{StaticResource SideButton}" Tag="Reparation"/>

                        <TextBlock Text="OUTILS"         Style="{StaticResource SectionHeader}"/>
                        <Button x:Name="BtnOutilsAdmin" Content="&#x2699;&#xFE0F;  Outils Admin" Style="{StaticResource SideButton}" Tag="OutilsAdmin"/>
                        <Button x:Name="BtnRapport"     Content="&#x1F4C4;  Rapport"           Style="{StaticResource SideButton}" Tag="Rapport"/>

                        <Separator Margin="16,20" Background="#3A3A3A"/>

                        <Button x:Name="BtnInfo"        Content="&#x2139;&#xFE0F;  Informations"  Style="{StaticResource SideButton}" Tag="Info"/>
                        <Button x:Name="BtnQuitter"     Content="&#x23FB;&#xFE0F;  Quitter"      Style="{StaticResource SideButton}" Tag="Quitter"/>
                    </StackPanel>
                </ScrollViewer>
            </Border>

            <!-- Contenu -->
            <Grid Grid.Column="1" Background="{StaticResource BgDark}">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Border Grid.Row="0" Background="{StaticResource BgSubPanel}" Padding="20,12">
                    <StackPanel>
                        <TextBlock x:Name="CategoryTitle"  Text="Bienvenue"  Style="{StaticResource TitleText}"/>
                        <TextBlock x:Name="CategorySubtitle" Text="Selectionnez une categorie dans la sidebar pour voir les actions disponibles." Foreground="{StaticResource TextDim}" FontSize="12"/>
                    </StackPanel>
                </Border>

                <WrapPanel x:Name="SubMenuPanel" Grid.Row="1" Margin="20,16,20,8"/>

                <Border Grid.Row="2" Background="{StaticResource BgOutput}" Margin="20,8,20,16" CornerRadius="4" Padding="0">
                    <RichTextBox x:Name="OutputBox"
                                 Background="Transparent"
                                 Foreground="{StaticResource TextWhite}"
                                 FontFamily="Consolas, Cascadia Mono, Courier New"
                                 FontSize="12"
                                 BorderThickness="0"
                                 IsReadOnly="True"
                                 IsDocumentEnabled="True"
                                 Padding="14,12"
                                 VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto"/>
                </Border>
            </Grid>
        </Grid>

        <!-- Status bar -->
        <Border Grid.Row="2" Background="{StaticResource AccentBlue}" Padding="20,8">
            <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="StatusText" Text="Pret" Foreground="White" FontSize="12"/>
                <TextBlock Text="  &#x2022;  " Foreground="{StaticResource AccentDim}" FontSize="12"/>
                <TextBlock x:Name="StatusMachine" Foreground="White" FontSize="12"/>
                <TextBlock x:Name="StatusAdmin" Text="  &#x2022;  ADMIN" Foreground="{StaticResource Warn}" FontSize="12" FontWeight="Bold" Margin="12,0,0,0"/>
                <TextBlock x:Name="StatusPS"      Foreground="{StaticResource AccentDim}" FontSize="12" Margin="20,0,0,0"/>
                <TextBlock x:Name="StatusTime"    Foreground="White" FontSize="12" Margin="20,0,0,0" HorizontalAlignment="Right"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
'@

# --- Catalogue des sous-options (meme structure que la version console) -------

$script:NTGuiActions = @{
    'Audit' = @(
        @{ Key='1'; Label='Synthese machine et OS';       Action={ Get-NTOverview } }
        @{ Key='2'; Label='CPU / RAM / Carte mere / GPU'; Action={ Get-NTHardwareSpecs } }
        @{ Key='3'; Label='Pilotes (inventaire + ages)';  Action={ Get-NTDriverInventory } }
        @{ Key='4'; Label='Stockage (volumes + SMART)';   Action={ Get-NTStorageReport } }
        @{ Key='5'; Label='Espace disque (vue rapide)';   Action={ Get-NTDiskSpace } }
    )
    'Reseau' = @(
        @{ Key='1'; Label='Audit reseau complet';          Action={ Get-NTNetworkSummary } }
        @{ Key='2'; Label='Reparation (DNS/DHCP)';         Action={ Repair-NTNetwork } }
        @{ Key='3'; Label='Reset complet pile reseau';     Action={ Reset-NTNetworkStack } }
        @{ Key='4'; Label='Ports en ecoute';               Action={ Get-NTListeningPorts } }
    )
    'Securite' = @(
        @{ Key='1'; Label='Posture securite globale';      Action={ Get-NTSecurityStatus } }
        @{ Key='2'; Label='Comptes locaux et admins';      Action={ Get-NTLocalUsers } }
        @{ Key='3'; Label='Strategie de groupe';            Action={ Get-NTGroupPolicy } }
    )
    'Logiciels' = @(
        @{ Key='1';  Label='Logiciels installes';          Action={ Get-NTInstalledSoftware } }
        @{ Key='2';  Label='Etat Windows Update';          Action={ Get-NTWindowsUpdateStatus } }
        @{ Key='3';  Label='Batterie (laptop)';            Action={ Get-NTBattery } }
        @{ Key='4';  Label="Plans d'alimentation";         Action={ Get-NTPowerPlan } }
        @{ Key='5';  Label='Demarrage (startup)';          Action={ Get-NTStartupItems } }
        @{ Key='6';  Label='Taches planifiees';            Action={ Get-NTScheduledTasks } }
        @{ Key='7';  Label='Services Windows';             Action={ Get-NTServiceStatus } }
        @{ Key='8';  Label='Processus (top CPU/RAM)';      Action={ Get-NTProcessSnapshot } }
        @{ Key='9';  Label='Evenements (erreurs 24h)';     Action={ Get-NTEventLog } }
        @{ Key='10'; Label='Snapshot performance';         Action={ Get-NTPerformanceSnapshot -DurationSec 5 } }
    )
    'Reparation' = @(
        @{ Key='1'; Label='Health check rapide';           Action={ Get-NTSystemHealth } }
        @{ Key='2'; Label='SFC fichiers systeme';          Action={ Repair-NTSystemFiles } }
        @{ Key='3'; Label='DISM composant image';          Action={ Repair-NTComponentStore } }
        @{ Key='4'; Label='Reset Windows Update';          Action={ Reset-NTWindowsUpdate } }
        @{ Key='5'; Label='Nettoyer fichiers temporaires'; Action={ Clear-NTTempFiles } }
    )
    'OutilsAdmin' = @(
        @{ Key='1'; Label='Gestionnaire de peripheriques';  Action={ Open-NTAdminTool 'devmgmt.msc' } }
        @{ Key='2'; Label='Connexions reseau';              Action={ Open-NTAdminTool 'ncpa.cpl' } }
        @{ Key='3'; Label="Gestion de l'ordinateur";         Action={ Open-NTAdminTool 'compmgmt.msc' } }
        @{ Key='4'; Label="Observateur d'evenements";        Action={ Open-NTAdminTool 'eventvwr.msc' } }
        @{ Key='5'; Label='Editeur du registre';            Action={ Open-NTAdminTool 'regedit.exe' } }
        @{ Key='6'; Label='Services (MMC)';                 Action={ Open-NTAdminTool 'services.msc' } }
        @{ Key='7'; Label='Invite de commandes admin';      Action={ Open-NTAdminTool 'cmd.exe' } }
        @{ Key='8'; Label='Planificateur de taches';        Action={ Open-NTAdminTool 'taskschd.msc' } }
    )
    'Rapport' = @(
        @{ Key='1'; Label='Rapport complet (TXT + HTML)';  Action={ Export-NTReport } }
    )
}

# --- Fonctions d'affichage dans la RichTextBox ------------------------------

function Write-GuiOutput {
    <#
    .SYNOPSIS
        Affiche du texte dans la RichTextBox de la fenetre.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text,
        [ValidateSet('Normal','OK','WARN','FAIL','TITLE','DIM')][string]$Kind = 'Normal'
    )
    $window = $script:NTGuiWindow
    if (-not $window) { return }

    $doc = $window.OutputBox.Document
    $para = if ($doc.Blocks.LastBlock -is [System.Windows.Documents.Paragraph]) {
        $doc.Blocks.LastBlock
    } else {
        $newPara = New-Object System.Windows.Documents.Paragraph
        $newPara.Margin = New-Object System.Windows.Thickness(0)
        $doc.Blocks.Add($newPara)
        $newPara
    }

    $colorKey = switch ($Kind) {
        'OK'    { 'Ok' }
        'WARN'  { 'Warn' }
        'FAIL'  { 'Err' }
        'TITLE' { 'Accent' }
        'DIM'   { 'TextDim' }
        default { 'TextWhite' }
    }
    $brush = $window.Resources[$colorKey]
    if (-not $brush) { $brush = [System.Windows.Media.Brushes]::White }

    $run = New-Object System.Windows.Documents.Run($Text)
    $run.Foreground = $brush
    $para.Inlines.Add($run)
}

function Clear-GuiOutput {
    $window = $script:NTGuiWindow
    if ($window) {
        $window.OutputBox.Document.Blocks.Clear()
        $doc = New-Object System.Windows.Documents.FlowDocument
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = New-Object System.Windows.Thickness(0)
        $doc.Blocks.Add($para)
        $window.OutputBox.Document = $doc
    }
}

function Invoke-GuiAction {
    <#
    .SYNOPSIS
        Execute une action et redirige TOUTE sa sortie vers la RichTextBox.
    #>
    [CmdletBinding()]
    param([scriptblock]$ScriptBlock, [string]$Label)

    Clear-GuiOutput
    Write-GuiOutput -Text "[ $Label ]`n" -Kind TITLE
    Write-GuiOutput -Text ('-' * 80) -Kind DIM
    Write-GuiOutput -Text "`n"

    $window = $script:NTGuiWindow
    $window.StatusText.Text = "Execution : $Label..."

    # Force le rendu avant execution longue
    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ }) | Out-Null

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $sw.Reset(); $sw.Start()

    try {
        # Capture TOUS les flux (output, error, warning, verbose, info, debug)
        # On utilise une variable globale pour recuperer le resultat
        $global:NTGuiOutput = $null
        $global:NTGuiError  = $null
        & {
            try {
                $global:NTGuiOutput = & $ScriptBlock *>&1 | Out-String -Width ([int]::MaxValue)
            } catch {
                $global:NTGuiError = $_
            }
        }
        $sw.Stop()

        if ($global:NTGuiOutput) {
            $lines = $global:NTGuiOutput -split "`r?`n"
            foreach ($line in $lines) {
                $kind = 'Normal'
                if     ($line -match '^\s*\[OK\]' )  { $kind = 'OK' }
                elseif ($line -match '^\s*\[!!\]')   { $kind = 'WARN' }
                elseif ($line -match '^\s*\[KO\]')   { $kind = 'FAIL' }
                elseif ($line -match '^\s*=+')       { $kind = 'TITLE' }
                elseif ($line -match '^\s*-+')       { $kind = 'DIM' }
                elseif ($line -match ':\s*ERREUR|Error|Exception|FAILED') { $kind = 'WARN' }
                Write-GuiOutput -Text ($line + "`n") -Kind $kind
            }
        }
        if ($global:NTGuiError) {
            Write-GuiOutput -Text "`nERREUR : $($global:NTGuiError.Exception.Message)`n" -Kind FAIL
        }
        Write-GuiOutput -Text "`n" -Kind DIM
        Write-GuiOutput -Text ("Termine en {0:N1}s" -f $sw.Elapsed.TotalSeconds) -Kind DIM
        $window.StatusText.Text = "OK : $Label ($($sw.Elapsed.TotalSeconds.ToString('0.0'))s)"
    } catch {
        Write-GuiOutput -Text "`nERREUR INATTENDUE : $($_.Exception.Message)`n" -Kind FAIL
        $window.StatusText.Text = "ERREUR : $Label"
    }
}

# --- Gestion de la fenetre ---------------------------------------------------


function Request-NTGuiConfirm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Confirmation"
    )
    $window = $script:NTGuiWindow
    if (-not $window) { return $false }
    $result = [System.Windows.MessageBox]::Show(
        $window, $Message, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

function Start-NTGui {
    <#
    .SYNOPSIS
        Initialise et affiche la fenetre WPF principale. Bloque jusqu'a fermeture.
    .NOTES
        Necessite que les modules metier soient deja importes.
    #>
    [CmdletBinding()]
    param()

    # Charger les assemblies WPF si pas deja fait
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Verifier qu'on est en STA
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
        Write-Error "NTGUI necessite un thread STA. Lancez avec powershell -STA."
        return
    }

    # Charger le XAML
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XamlMain)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $script:NTGuiWindow = $window

    # --- Expose les x:Name du XAML comme proprietes PowerShell sur $window
    #     (sinon $window.StatusMachine etc. ne fonctionnent pas)
    foreach ($_ntName in @(
        'StatusText','StatusMachine','StatusAdmin','StatusPS','StatusTime',
        'HeaderVersion','Sidebar','SubMenuPanel','OutputBox',
        'CategoryTitle','CategorySubtitle',
        'BtnAudit','BtnReseau','BtnSecurite','BtnLogiciels','BtnReparation',
        'BtnOutilsAdmin','BtnRapport','BtnInfo','BtnQuitter'
    )) {
        $_ntEl = $window.FindName($_ntName)
        if ($_ntEl) {
            Add-Member -InputObject $window -Name $_ntName -Value $_ntEl -MemberType NoteProperty -Force
        }
    }

    # Status bar init
    $window.StatusMachine.Text = $env:COMPUTERNAME
    $window.StatusPS.Text      = "PS $($PSVersionTable.PSVersion)"
    $window.StatusAdmin.Text   = if (Test-NTAdmin) { '  •  ADMIN' } else { '  •  USER' }
    $window.HeaderVersion.Text = "  v$NTVersion  -  Administration Windows"

    # Event handlers
    $window.Add_Loaded({
        # Mettre a jour l'heure toutes les secondes
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            $window.StatusTime.Text = (Get-Date -Format 'HH:mm:ss')
        })
        $timer.Start()
    })

    # Bind sidebar buttons
    $sidebar = $window.Sidebar
    foreach ($child in $sidebar.Children) {
        if ($child -is [System.Windows.Controls.Button]) {
            $tag = $child.Tag
            $child.Add_Click({
                param($sender, $e)
                $key = $sender.Tag
                switch ($key) {
                    'Info'    { Show-NTGuiInfo }
                    'Quitter' { $window.Close() }
                    'Rapport' { Show-NTGuiSubMenu -Category 'Rapport' }
                    Default   { Show-NTGuiSubMenu -Category $key }
                }
            })
        }
    }

    # Afficher et bloquer
    [void]$window.ShowDialog()
    return
}

function Show-NTGuiSubMenu {
    [CmdletBinding()]
    param([string]$Category)
    $window = $script:NTGuiWindow
    if (-not $window) { return }

    $actions = $script:NTGuiActions[$Category]
    if (-not $actions) { return }

    # Mettre a jour le titre
    $titles = @{
        'Audit'      = 'Audit Matériel'
        'Reseau'     = 'Réseau'
        'Securite'   = 'Sécurité'
        'Logiciels'  = 'Logiciels et maintenance'
        'Reparation' = 'Réparation système'
        'OutilsAdmin'= 'Outils administrateur'
        'Rapport'    = 'Rapport'
    }
    $window.CategoryTitle.Text    = $titles[$Category]
    $window.CategorySubtitle.Text = "Choisissez une action ci-dessous. La sortie s'affichera dans le cadre noir."

    # Vider et reconstruire le WrapPanel
    $window.SubMenuPanel.Children.Clear()
    foreach ($a in $actions) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = "[$($a.Key)]  $($a.Label)"
        $btn.Style   = $window.Resources['SubButton']
        $btn.Tag     = $a
        $btn.Add_Click({
            param($s, $e)
            $action = $s.Tag
            Invoke-GuiAction -ScriptBlock $action.Action -Label $action.Label
        })
        $window.SubMenuPanel.Children.Add($btn) | Out-Null
    }
    Clear-GuiOutput
    Write-GuiOutput -Text "Selectionnez une action ci-dessus pour l'executer." -Kind DIM
}

function Show-NTGuiInfo {
    $window = $script:NTGuiWindow
    if (-not $window) { return }
    Clear-GuiOutput
    Write-GuiOutput -Text "NeoTech Toolkit`n" -Kind TITLE
    Write-GuiOutput -Text "Version      : $NTVersion`n" -Kind NORMAL
    Write-GuiOutput -Text "Copyright    : $NTCopyright`n" -Kind NORMAL
    Write-GuiOutput -Text "Site         : $NTSite`n" -Kind NORMAL
    Write-GuiOutput -Text "PowerShell   : $($PSVersionTable.PSVersion)`n" -Kind NORMAL
    Write-GuiOutput -Text "Windows      : $([System.Environment]::OSVersion.VersionString)`n" -Kind NORMAL
    Write-GuiOutput -Text "Admin        : $(if (Test-NTAdmin) {'OUI'} else {'non'})`n" -Kind $(if (Test-NTAdmin) {'OK'} else {'WARN'})
    Write-GuiOutput -Text "Poste        : $env:COMPUTERNAME`n" -Kind NORMAL
    Write-GuiOutput -Text "Utilisateur  : $env:USERNAME`n`n" -Kind NORMAL
    Write-GuiOutput -Text "Ce toolkit est mis a disposition par TechSentinel. Aucune donnee n'est transmise ; tout s'execute en local." -Kind DIM
}

Export-ModuleMember -Function Start-NTGui, Write-GuiOutput, Clear-GuiOutput, Invoke-GuiAction

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUaKVt/LKsjSRtZTXt3SRTUgW6
# vlmgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUgVhdpyfw6MlYiPx1NHeXwcjtqpowDQYJKoZIhvcNAQEBBQAE
# ggEAmtH/YwezM3uTQ5Dx+/GL8yUX2doC6vEQn4ikRh14n9gbwCoymWjtx6pvbxa5
# yQ+MtWv+HbKW9cns58vMn+oSBsRNX5ADZ9dbclU0AczQidvV1rTwrFBUZMFAR4fw
# xK2SwFjmm0bOjVE7wtJggZV3UetNfhtivQSLDDZguHBN83qJzoymJmJ6My/ydZPJ
# P58OqgpxwNDihg/9v369Jm4xIm9rV0cQ4Pr8i78s4HHRV58dYNBxdflKP3pmlZSe
# uF5UVLKBrxy9sbr4zQ3JXb1b8vVo19TRMEqYoT9vfx0R3TD8a11DHoz/UgJcDnn9
# cUMCAi3anz+9QOFZqN1PB7DpzA==
# SIG # End signature block
