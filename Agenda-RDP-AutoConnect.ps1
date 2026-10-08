# Spass-Script: startet die Agenda-RDP-Verbindung. Beim allerersten Start
# auf einem Rechner werden Benutzername/Server abgefragt und lokal im
# Benutzerprofil gespeichert (unabhaengig davon, wo die .exe liegt - so
# funktioniert sie auf jedem Rechner nach einmaliger Einrichtung).
# Danach: Monitor-Auswahl -> Sicherheitsdialog per Tastatur durchklicken.

param(
    [double]$WartenAufDialog = 2.5
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ConfigDir = Join-Path $env:APPDATA "AgendaRDP"
$RdpPath = Join-Path $ConfigDir "Bescheid2025.rdp"

# Shift beim Start gedrueckt halten = gespeicherte Zugangsdaten verwerfen
# und Ersteinrichtung erneut durchlaufen (z.B. nach Tippfehler im Passwort).
$forceReset = ([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift) -ne 0
if ($forceReset -and (Test-Path $RdpPath)) {
    $old = Get-Content -Path $RdpPath -Raw -Encoding Unicode
    if ($old -match '(?im)^full address:s:(.+)$') {
        $oldServer = $matches[1].Trim()
        Start-Process "cmdkey.exe" -ArgumentList "/delete:TERMSRV/$oldServer" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    }
    Remove-Item $RdpPath -Force
}

# --- Ersteinrichtung -------------------------------------------------
function Show-Ersteinrichtung {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Agenda RDP - Ersteinrichtung"
    $form.StartPosition = "CenterScreen"
    $form.Width = 420
    $form.Height = 260
    $form.Topmost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Rechtsklick-Menu fuer Ausschneiden/Kopieren/Einfuegen/Alles auswaehlen,
    # damit Copy-Paste in den Feldern zuverlaessig und sichtbar funktioniert.
    function New-EditContextMenu {
        $menu = New-Object System.Windows.Forms.ContextMenuStrip
        [void]$menu.Items.Add("Ausschneiden", $null, { $script:focusedTextBox.Cut() })
        [void]$menu.Items.Add("Kopieren", $null, { $script:focusedTextBox.Copy() })
        [void]$menu.Items.Add("Einfuegen", $null, { $script:focusedTextBox.Paste() })
        [void]$menu.Items.Add("Alles auswaehlen", $null, { $script:focusedTextBox.SelectAll() })
        return $menu
    }

    # Schreibgeschuetztes, randloses Textfeld statt Label - sieht aus wie
    # eine Beschriftung, laesst sich aber markieren und kopieren.
    function New-CopyableLabel([string]$text, [int]$top) {
        $lbl = New-Object System.Windows.Forms.TextBox
        $lbl.Text = $text
        $lbl.Left = 20; $lbl.Top = $top; $lbl.Width = 370
        $lbl.ReadOnly = $true
        $lbl.BorderStyle = [System.Windows.Forms.BorderStyle]::None
        $lbl.BackColor = [System.Drawing.SystemColors]::Control
        $lbl.TabStop = $false
        return $lbl
    }

    $lblServer = New-CopyableLabel "Server-Adresse:" 20
    $form.Controls.Add($lblServer)

    $txtServer = New-Object System.Windows.Forms.TextBox
    $txtServer.Left = 20; $txtServer.Top = 45; $txtServer.Width = 360
    $txtServer.Text = ""
    $txtServer.ShortcutsEnabled = $true
    $txtServer.ContextMenuStrip = New-EditContextMenu
    $txtServer.Add_Enter({ $script:focusedTextBox = $txtServer })
    $form.Controls.Add($txtServer)

    $lblUser = New-CopyableLabel "Benutzername (z.B. k123456-Nachname@domain.example):" 80
    $form.Controls.Add($lblUser)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Left = 20; $txtUser.Top = 105; $txtUser.Width = 360
    $txtUser.ShortcutsEnabled = $true
    $txtUser.ContextMenuStrip = New-EditContextMenu
    $txtUser.Add_Enter({ $script:focusedTextBox = $txtUser })
    $form.Controls.Add($txtUser)

    $lblPass = New-CopyableLabel "Passwort (wird im Windows-Credential-Manager gespeichert):" 140
    $form.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Left = 20; $txtPass.Top = 165; $txtPass.Width = 360
    $txtPass.UseSystemPasswordChar = $true
    $txtPass.ShortcutsEnabled = $true
    $txtPass.ContextMenuStrip = New-EditContextMenu
    $txtPass.Add_Enter({ $script:focusedTextBox = $txtPass })
    $form.Controls.Add($txtPass)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Einrichten"
    $okButton.Left = 20; $okButton.Top = 195
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    if (-not $txtServer.Text -or -not $txtUser.Text) { return $null }

    return @{
        Server   = $txtServer.Text.Trim()
        Username = $txtUser.Text.Trim()
        Password = $txtPass.Text
    }
}

if (-not (Test-Path $RdpPath)) {
    $setup = Show-Ersteinrichtung
    if (-not $setup) { exit 0 }

    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

    $rdpTemplate = @"
screen mode id:i:2
use multimon:i:1
desktopwidth:i:2560
desktopheight:i:1440
session bpp:i:32
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
username:s:$($setup.Username)
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:$($setup.Server)
audiomode:i:0
redirectprinters:i:1
redirectlocation:i:1
redirectcomports:i:1
redirectsmartcards:i:1
redirectwebauthn:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:0
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
enablerdsaadauth:i:0
camerastoredirect:s:*
devicestoredirect:s:*
drivestoredirect:s:*
selectedmonitors:s:
remoteappmousemoveinject:i:1
"@
    Set-Content -Path $RdpPath -Value $rdpTemplate -Encoding Unicode -NoNewline

    if ($setup.Password) {
        $target = "TERMSRV/$($setup.Server)"
        Start-Process "cmdkey.exe" -ArgumentList "/generic:$target", "/user:$($setup.Username)", "/pass:$($setup.Password)" -WindowStyle Hidden -Wait
    }
}

if (-not (Test-Path $RdpPath)) {
    Write-Error "RDP-Datei nicht gefunden: $RdpPath"
    exit 1
}

# --- Monitor-Auswahl ---------------------------------------------------
# Fragt die Monitor-Ids direkt bei mstsc selbst ab ("mstsc /l"), statt sie
# aus dem Windows-Gerätenamen zu erraten. So stimmt die Nummerierung immer
# exakt mit dem ueberein, was mstsc beim Verbinden tatsaechlich erwartet -
# auch wenn sich die interne \\.\DISPLAYn-Zuordnung mal verschiebt (z.B.
# nach Um-/Anstecken von Monitoren, je nach Installation unterschiedlich).
function Get-MstscMonitore {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes

    $monitore = @()
    $proc = $null
    try {
        $proc = Start-Process "mstsc.exe" -ArgumentList "/l" -PassThru
    } catch { return $monitore }

    $deadline = (Get-Date).AddSeconds(8)
    $el = $null
    while ((Get-Date) -lt $deadline -and -not $el) {
        Start-Sleep -Milliseconds 200
        try {
            $proc.Refresh()
            if ($proc.MainWindowHandle -ne 0) {
                $el = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
            }
        } catch {}
    }

    if ($el) {
        try {
            $textCond = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::Text)
            $textEl = $el.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $textCond)
            if ($textEl) {
                foreach ($line in ($textEl.Current.Name -split "`r?`n")) {
                    if ($line -match '^\s*(\d+):\s*(\d+)\s*x\s*(\d+);\s*\((-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\)') {
                        $monitore += [pscustomobject]@{
                            Id     = [int]$Matches[1]
                            Width  = [int]$Matches[2]
                            Height = [int]$Matches[3]
                            Left   = [int]$Matches[4]
                            Top    = [int]$Matches[5]
                        }
                    }
                }
            }
        } catch {}

        try {
            $btnCond = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::Button)
            $btn = $el.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
            if ($btn) { $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke() }
        } catch {}
    }

    if ($proc -and -not $proc.HasExited) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }

    return $monitore
}

function Show-MonitorAuswahl {
    $monitore = Get-MstscMonitore

    if ($monitore.Count -eq 0) {
        # Fallback, falls die mstsc /l - Abfrage mal nicht klappt (z.B.
        # andere Windows-Version/Sprache): aus Screen.AllScreens raten.
        $monitore = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
            [pscustomobject]@{
                Id     = [int]([regex]::Match($_.DeviceName, '\d+').Value) - 1
                Width  = $_.Bounds.Width
                Height = $_.Bounds.Height
                Left   = $_.Bounds.X
                Top    = $_.Bounds.Y
            }
        }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Monitore fuer RDP-Sitzung waehlen"
    $form.StartPosition = "CenterScreen"
    $form.Width = 420
    $form.Height = 130 + ($monitore.Count * 30)
    $form.Topmost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $checkboxes = @()
    $y = 20
    foreach ($mon in $monitore) {
        $label = "Monitor $($mon.Id)  [$($mon.Width)x$($mon.Height) bei ($($mon.Left),$($mon.Top))]"
        if ($mon.Left -eq 0 -and $mon.Top -eq 0) { $label += "  (primaer)" }

        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $label
        $cb.Left = 20
        $cb.Top = $y
        $cb.Width = 370
        $cb.Tag = $mon.Id
        $cb.Checked = $true
        $form.Controls.Add($cb)
        $checkboxes += $cb
        $y += 30
    }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Verbinden"
    $okButton.Left = 20
    $okButton.Top = $y + 10
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

    $ausgewaehlt = $checkboxes | Where-Object { $_.Checked } | ForEach-Object { $_.Tag }
    if ($ausgewaehlt.Count -eq 0) { return $null }
    return ($ausgewaehlt -join ",")
}

$selectedMonitors = Show-MonitorAuswahl
if (-not $selectedMonitors) {
    exit 0
}

# Zertifikatswarnung + Passwortabfrage unterdruecken (Passwort liegt im
# Windows-Credential-Manager - das Passwortfeld selbst laeuft auf dem
# sicheren Desktop und ist per SendKeys nicht erreichbar).
$content = Get-Content -Path $RdpPath -Raw -Encoding Unicode
$patched = $content -replace '(?im)^authentication level:i:\d+', 'authentication level:i:0'
$patched = $patched -replace '(?im)^prompt for credentials:i:\d+', 'prompt for credentials:i:0'
$patched = $patched -replace '(?im)^use multimon:i:\d+', 'use multimon:i:1'
$patched = $patched -replace '(?im)^selectedmonitors:s:.*', "selectedmonitors:s:$selectedMonitors"
if ($patched -ne $content) {
    Set-Content -Path $RdpPath -Value $patched -Encoding Unicode -NoNewline
}

# mstsc zeigt als Fenstertitel den Dateinamen der .rdp-Datei an. Damit
# dort der Name der Person statt "Bescheid2025" steht, wird beim Start
# eine Kopie unter einem aus dem Benutzernamen abgeleiteten Dateinamen
# angelegt (z.B. "k123456-Nachname@domain.example" -> "Nachname")
# und diese an mstsc uebergeben. Die eigentliche Konfigurationsdatei
# bleibt unveraendert unter ihrem urspruenglichen Namen gespeichert.
$anzeigename = 'Verbindung'
if ($patched -match '(?im)^username:s:(.+)$') {
    $u = $matches[1].Trim()
    if ($u -match '-([^@]+)@') { $anzeigename = $matches[1] }
    elseif ($u -match '^([^@]+)@') { $anzeigename = $matches[1] }
}
$startPath = Join-Path $ConfigDir "$anzeigename.rdp"
Copy-Item -Path $RdpPath -Destination $startPath -Force

Start-Process "mstsc.exe" -ArgumentList "`"$startPath`""

# Der Sicherheitsdialog ist komplett selbst gezeichnet (alle Elemente
# kommen bei UI Automation als generisches "Pane" raus, keines davon ist
# tastatur-fokussierbar oder unterstuetzt irgendein Automation-Pattern -
# live verifiziert, auch fuer Container und Buttons). Es gibt also keine
# Moeglichkeit, den Tastatur-Fokus von hier aus zu verifizieren. UI
# Automation wird deshalb NUR zum Zaehlen der tatsaechlich vorhandenen
# Checkbox-Zeilen benutzt (das funktioniert zuverlaessig, weil rein
# lesend), die eigentliche Bedienung laeuft komplett per SendKeys - ohne
# Maus, aber ohne Erfolgsgarantie, da nicht verifizierbar.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$dlg = $null
$deadline = (Get-Date).AddSeconds([Math]::Max($WartenAufDialog, 15))
while ((Get-Date) -lt $deadline -and -not $dlg) {
    Start-Sleep -Milliseconds 300
    $wins = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition)
    # NUR den spezifischen Titel, nicht den generischen "Remotedesktop-
    # verbindung" - mstsc erzeugt beim Start zusaetzlich ein leeres
    # Platzhalter-Fenster mit genau diesem generischen Titel (0 Kind-
    # elemente), das sonst manchmal statt des echten Dialogs erfasst und
    # aktiviert wird - dann tippt das Script ins falsche Fenster.
    $dlg = $wins | Where-Object { $_.Current.Name -match 'Sicherheitswarnung' } | Select-Object -First 1
}

if ($dlg) {
    $wshell = New-Object -ComObject WScript.Shell
    $wshell.AppActivate($dlg.Current.Name) | Out-Null
    Start-Sleep -Milliseconds 300

    $anzahlCheckboxen = 9
    try {
        $alle = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $headerY = ($alle | Where-Object { $_.Current.Name -match 'folgende Ressourcen' } | Select-Object -First 1).Current.BoundingRectangle.Y
        $footerY = ($alle | Where-Object { $_.Current.Name -match 'Verbindungsstart' } | Select-Object -First 1).Current.BoundingRectangle.Y
        if ($headerY -and $footerY) {
            $checkboxRows = $alle | Where-Object {
                $_.Current.Name -ne '' -and
                -not $_.Current.IsOffscreen -and
                $_.Current.BoundingRectangle.Y -gt $headerY -and
                $_.Current.BoundingRectangle.Y -le $footerY
            }
            if ($checkboxRows.Count -gt 0) { $anzahlCheckboxen = $checkboxRows.Count }
        }
    } catch {}

    # Direkt vor dem Tippen nochmal aktivieren (das Zaehlen der Checkboxen
    # oben braucht selbst etwas Zeit) und grosszuegig warten, damit der
    # Dialog seinen internen Start-Fokus sicher fertig gesetzt hat, bevor
    # der erste Tab losgeht - das ist der wahrscheinlichste Grund fuer die
    # unregelmaessigen Aussetzer.
    $wshell.AppActivate($dlg.Current.Name) | Out-Null
    Start-Sleep -Milliseconds 700

    # 1 Tab zu Beginn landet direkt auf Checkbox 1 (der "Mehr dazu"-Link
    # ist offenbar kein eigener Tab-Stopp - 2 Tabs haben die erste
    # Checkbox uebersprungen und alles Nachfolgende um eins verschoben,
    # bis hin zu einem ueberzaehligen Leertaste-Druck auf "Abbrechen" im
    # anschliessenden Verbindungsaufbau-Dialog).
    [System.Windows.Forms.SendKeys]::SendWait("{TAB}")

    for ($i = 0; $i -lt $anzahlCheckboxen; $i++) {
        Start-Sleep -Milliseconds 15
        [System.Windows.Forms.SendKeys]::SendWait(" ")
        Start-Sleep -Milliseconds 15
        [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
    }

    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait(" ")
}
