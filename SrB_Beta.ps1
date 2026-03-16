# --- MEJORA DE NITIDEZ (EVITA LETRAS BORROSAS) ---
$sig = '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
try { Add-Type -MemberDefinition $sig -Name DPI -Namespace WinAPI -ErrorAction SilentlyContinue } catch {}
[WinAPI.DPI]::SetProcessDPIAware()

# --- CONFIGURACIÓN E INICIALIZACIÓN ---
try {
    $showWindowAsync = Add-Type -Name Window -Namespace Console -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -PassThru -ErrorAction SilentlyContinue
    $null = $showWindowAsync::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
} catch {}

$ftpOnline = "ftp.infasemachines.com"
$ftpLocal = "192.168.0.32:31228"
$user = "adminsoprem@infasemachines.com"
$pass = "Imachines2024"
$remotePath = "private/instalaciones"
$localTemp = "C:\InstTemp"

if (!(Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp | Out-Null }

# --- DICCIONARIO DE PROGRAMAS ---
$programas = [ordered]@{
    "Iperius Remote"      = @("iperius.exe", "/verysilent", $false)
    "OnlyOffice"          = @("onlyoffice.exe", "/S /VERYSILENT /SUPPRESSMSGBOXES /NORESTART", $false)
    "Office 365 (32 bits)" = @("office32.exe", $true)
    "Office 365 (64 bits)" = @("office64.exe", $true)
    "Autofirma"           = @("autofirma.exe", "/S", $false)
    "Google Chrome"       = @("chrome.exe", "/silent /install", $false)
    "Firefox"             = @("firefox.exe", "-ms", $false)
    "Java"                = @("java.exe", "/s", $false)
    "Adobe Reader"        = @("Reader_es_install.exe", "/sAll /rs /qn /norestart", $true) 
    "Winrar"              = @("winrar.exe", "/S", $false)
    "VLC Media Player"    = @("vlc.msi", "/qn /norestart", $false)
    "Pdfgear"             = @("pdfgear.exe", "/VERYSILENT /SUPPRESSMSGBOXES", $false)
    "Kaspersky Antivirus" = @("kav.exe", $true)
    "Panda Antivirus"     = @("panda.exe", "/S /silent /sp- /no_opera /norestart", $true)
}

$predeterminados = @("VLC Media Player", "Autofirma", "Java", "Iperius Remote", "Google Chrome", "Firefox", "OnlyOffice", "Winrar", "Panda Antivirus", "Pdfgear")

# --- INTERFAZ (Definiciones Globales) ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Drawing;
    using System.Drawing.Drawing2D;
    using System.Windows.Forms;
    public class RoundedButton : Button {
        public int BorderRadius = 12;
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            GraphicsPath path = new GraphicsPath();
            path.AddArc(0, 0, BorderRadius, BorderRadius, 180, 90);
            path.AddArc(Width - BorderRadius, 0, BorderRadius, BorderRadius, 270, 90);
            path.AddArc(Width - BorderRadius, Height - BorderRadius, BorderRadius, BorderRadius, 0, 90);
            path.AddArc(0, Height - BorderRadius, BorderRadius, BorderRadius, 90, 90);
            path.CloseFigure();
            this.Region = new Region(path);
            using (SolidBrush brush = new SolidBrush(this.BackColor)) { e.Graphics.FillPath(brush, path); }
            TextRenderer.DrawText(e.Graphics, this.Text, this.Font, new Rectangle(0, 0, Width, Height), this.ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
} catch {}

$fontNegrita11 = New-Object Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontStatusNegrita = New-Object Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$fontBotones = New-Object Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$fontTitulosTools = New-Object Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$script:continuarEnMenu = $true

while ($script:continuarEnMenu) {
    $estadoInstalacion = @{}
    
    $form = New-Object Windows.Forms.Form
    $form.Text = "Instalador Sr.B" 
    $form.Size = "650, 560"
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 250)

    # --- SELECTOR DE MODO (ESTILO IGUAL A LOS DETECTORES) ---
    $radioPanel = New-Object Windows.Forms.Panel
    $radioPanel.Location = "25, 20"; $radioPanel.Size = "350, 30"
    
    $rbLocal = New-Object Windows.Forms.RadioButton
    $rbLocal.Text = "Local / FTP"; $rbLocal.Location = "0, 0"; $rbLocal.Size = "110, 25"
    $rbLocal.Font = $fontStatusNegrita; $rbLocal.ForeColor = "DimGray"; $rbLocal.Checked = $true
    
    $rbOnline = New-Object Windows.Forms.RadioButton
    $rbOnline.Text = "Online"; $rbOnline.Location = "120, 0"; $rbOnline.Size = "100, 25"
    $rbOnline.Font = $fontStatusNegrita; $rbOnline.ForeColor = "DimGray"
    
    $radioPanel.Controls.AddRange(@($rbLocal, $rbOnline))
    $form.Controls.Add($radioPanel)

    # --- INDICADORES (LADO DERECHO) ---
    $panelNet = New-Object Windows.Forms.Panel; $panelNet.Location = "440, 5"; $panelNet.Size = "180, 25"
    $dotNet = New-Object Windows.Forms.Label; $dotNet.Text = "●"; $dotNet.ForeColor = "Gray"; $dotNet.Font = New-Object Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold); $dotNet.Location = "0, -3"; $dotNet.AutoSize = $true
    $lblNet = New-Object Windows.Forms.Label; $lblNet.Text = "Internet: ..."; $lblNet.Font = $fontStatusNegrita; $lblNet.ForeColor = "DimGray"; $lblNet.Location = "22, 4"; $lblNet.AutoSize = $true
    $panelNet.Controls.AddRange(@($dotNet, $lblNet)); $form.Controls.Add($panelNet)

    $panelFtp = New-Object Windows.Forms.Panel; $panelFtp.Location = "440, 28"; $panelFtp.Size = "180, 25"
    $dotFtp = New-Object Windows.Forms.Label; $dotFtp.Text = "●"; $dotFtp.ForeColor = "Gray"; $dotFtp.Font = New-Object Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold); $dotFtp.Location = "0, -3"; $dotFtp.AutoSize = $true
    $lblFtp = New-Object Windows.Forms.Label; $lblFtp.Text = "Servidor FTP: ..."; $lblFtp.Font = $fontStatusNegrita; $lblFtp.ForeColor = "DimGray"; $lblFtp.Location = "22, 4"; $lblFtp.AutoSize = $true
    $panelFtp.Controls.AddRange(@($dotFtp, $lblFtp)); $form.Controls.Add($panelFtp)

    $timerStatus = New-Object Windows.Forms.Timer; $timerStatus.Interval = 3000
    $timerStatus.Add_Tick({
        # Check Internet
        if (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue) { $dotNet.ForeColor = "LimeGreen"; $lblNet.Text = "Internet: OK" } else { $dotNet.ForeColor = "Red"; $lblNet.Text = "Internet: Offline" }
        
        # Check FTP Dinámico según el RadioButton seleccionado
        try {
            if ($rbLocal.Checked) {
                $hostActual = ($ftpLocal -split ":")[0]
                $puertoActual = [int]($ftpLocal -split ":")[1]
            } else {
                $hostActual = $ftpOnline
                $puertoActual = 21
            }
            $socket = New-Object System.Net.Sockets.TcpClient
            $connect = $socket.BeginConnect($hostActual, $puertoActual, $null, $null)
            if ($connect.AsyncWaitHandle.WaitOne(800, $false) -and $socket.Connected) { $dotFtp.ForeColor = "LimeGreen"; $lblFtp.Text = "Servidor FTP: OK" } else { $dotFtp.ForeColor = "Red"; $lblFtp.Text = "Servidor FTP: Error" }
            $socket.Close()
        } catch { $dotFtp.ForeColor = "Red"; $lblFtp.Text = "Servidor FTP: Error" }
    })
    $timerStatus.Start()

    # --- LISTA DE APLICACIONES ---
    $checkedListBox = New-Object Windows.Forms.CheckedListBox
    $checkedListBox.Location = "25, 65"; $checkedListBox.Size = "585, 260"; $checkedListBox.CheckOnClick = $true; $checkedListBox.MultiColumn = $true; $checkedListBox.ColumnWidth = 280; 
    $checkedListBox.Font = $fontNegrita11 
    $checkedListBox.BorderStyle = "None"
    foreach ($p in $programas.Keys) { [void]$checkedListBox.Items.Add($p) }
    $form.Controls.Add($checkedListBox)

    # --- BOTONES PRINCIPALES ---
    $btnPre = New-Object RoundedButton; $btnPre.Text = "⚡ Predeterminado"; $btnPre.Location = "25, 345"; $btnPre.Size = "285, 50"; $btnPre.BackColor = "46, 204, 113"; $btnPre.ForeColor = "White"; $btnPre.Font = $fontBotones
    $btnPre.Add_Click({ for ($i=0;$i -lt $checkedListBox.Items.Count;$i++) { $checkedListBox.SetItemChecked($i, ($predeterminados -contains $checkedListBox.Items[$i])) } })
    $form.Controls.Add($btnPre)

    $btnOk = New-Object RoundedButton; $btnOk.Text = "▶ Instalar Seleccionados"; $btnOk.Location = "325, 345"; $btnOk.Size = "285, 50"; $btnOk.BackColor = "52, 152, 219"; $btnOk.ForeColor = "White"; $btnOk.Font = $fontBotones
    $btnOk.Add_Click({ $form.DialogResult = "OK"; $form.Close() })
    $form.Controls.Add($btnOk)

    $btnBorrar = New-Object RoundedButton; $btnBorrar.Text = "✖ Desmarcar Todo"; $btnBorrar.Location = "25, 405"; $btnBorrar.Size = "285, 50"; $btnBorrar.BackColor = "231, 76, 60"; $btnBorrar.ForeColor = "White"; $btnBorrar.Font = $fontBotones
    $btnBorrar.Add_Click({ for ($i=0;$i -lt $checkedListBox.Items.Count;$i++) { $checkedListBox.SetItemChecked($i, $false) } })
    $form.Controls.Add($btnBorrar)

    $btnTools = New-Object RoundedButton; $btnTools.Text = "🛠 Herramientas Avanzadas"; $btnTools.Location = "325, 405"; $btnTools.Size = "285, 50"; $btnTools.BackColor = "156, 39, 176"; $btnTools.ForeColor = "White"; $btnTools.Font = $fontBotones
    $btnTools.Add_Click({
        $toolsForm = New-Object Windows.Forms.Form
        $toolsForm.Text = "Herramientas de Sistema"; $toolsForm.Size = "350, 520"; $toolsForm.StartPosition = "CenterParent"; $toolsForm.FormBorderStyle = "FixedToolWindow"; $toolsForm.BackColor = "230, 230, 235"
        
        $lblMaint = New-Object Windows.Forms.Label; $lblMaint.Text = "Mantenimiento y Reparación"; $lblMaint.Location = "20, 10"; $lblMaint.AutoSize = $true; $lblMaint.Font = $fontTitulosTools; $lblMaint.ForeColor = "DimGray"
        $btnSFC = New-Object RoundedButton; $btnSFC.Text = "Reparar Archivos (SFC)"; $btnSFC.Location = "20, 40"; $btnSFC.Size = "290, 40"; $btnSFC.BackColor = "SteelBlue"; $btnSFC.ForeColor = "White"; $btnSFC.Font = $fontBotones
        $btnSFC.Add_Click({ Start-Process powershell -ArgumentList "-NoProfile -Command `"sfc /scannow; pause`"" -Verb RunAs })
        $btnDISM = New-Object RoundedButton; $btnDISM.Text = "Reparar Imagen (DISM)"; $btnDISM.Location = "20, 90"; $btnDISM.Size = "290, 40"; $btnDISM.BackColor = "SteelBlue"; $btnDISM.ForeColor = "White"; $btnDISM.Font = $fontBotones
        $btnDISM.Add_Click({ Start-Process powershell -ArgumentList "-NoProfile -Command `"DISM /Online /Cleanup-Image /RestoreHealth; pause`"" -Verb RunAs })
        $btnCHK = New-Object RoundedButton; $btnCHK.Text = "Comprobar Disco (CHKDSK)"; $btnCHK.Location = "20, 140"; $btnCHK.Size = "290, 40"; $btnCHK.BackColor = "SteelBlue"; $btnCHK.ForeColor = "White"; $btnCHK.Font = $fontBotones
        $btnCHK.Add_Click({ 
            $dForm = New-Object Windows.Forms.Form; $dForm.Text = "Sel. Unidad"; $dForm.Size = "350, 150"; $dForm.StartPosition = "CenterParent"; $dForm.FormBorderStyle = "FixedToolWindow"; $dForm.BackColor = "White"
            $lblD = New-Object Windows.Forms.Label; $lblD.Text = "Partición:"; $lblD.Location = "20, 25"; $lblD.AutoSize = $true; $lblD.Font = $fontBotones
            $cbD = New-Object Windows.Forms.ComboBox; $cbD.Location = "115, 22"; $cbD.Size = "200, 25"; $cbD.DropDownStyle = "DropDownList"; $cbD.Font = $fontNegrita11
            [System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed'} | ForEach-Object { [void]$cbD.Items.Add($_.Name.Substring(0, 2)) }
            if ($cbD.Items.Count -gt 0) { $cbD.SelectedIndex = 0 }
            $btnRunChk = New-Object RoundedButton; $btnRunChk.Text = "Analizar"; $btnRunChk.Location = "125, 70"; $btnRunChk.Size = "100, 30"; $btnRunChk.BackColor = "SteelBlue"; $btnRunChk.ForeColor = "White"
            $btnRunChk.Add_Click({ $dForm.DialogResult = "OK"; $dForm.Close() })
            $dForm.Controls.AddRange(@($lblD, $cbD, $btnRunChk))
            if ($dForm.ShowDialog() -eq "OK") { $drive = $cbD.SelectedItem; Start-Process powershell -ArgumentList "-NoProfile -Command `"chkdsk $drive /f; pause`"" -Verb RunAs }
        })
        
        $lblAct = New-Object Windows.Forms.Label; $lblAct.Text = "Activación"; $lblAct.Location = "20, 200"; $lblAct.AutoSize = $true; $lblAct.Font = $fontTitulosTools; $lblAct.ForeColor = "DimGray"
        $btnLic = New-Object RoundedButton; $btnLic.Text = "🔑 Activador Windows/Office"; $btnLic.Location = "20, 230"; $btnLic.Size = "290, 45"; $btnLic.BackColor = "DarkOrange"; $btnLic.ForeColor = "White"; $btnLic.Font = $fontBotones
        $btnLic.Add_Click({ Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://get.activated.win | iex`"" -Verb RunAs })

        $lblGest = New-Object Windows.Forms.Label; $lblGest.Text = "Gestión de Software"; $lblGest.Location = "20, 295"; $lblGest.AutoSize = $true; $lblGest.Font = $fontTitulosTools; $lblGest.ForeColor = "DimGray"
        $btnLaunchDes = New-Object RoundedButton; $btnLaunchDes.Text = "🗑 Desinstalar Programas"; $btnLaunchDes.Location = "20, 325"; $btnLaunchDes.Size = "290, 55"; $btnLaunchDes.BackColor = "DarkRed"; $btnLaunchDes.ForeColor = "White"; $btnLaunchDes.Font = $fontBotones
        $btnLaunchDes.Add_Click({
            $unForm = New-Object Windows.Forms.Form; $unForm.Text = "Gestor de Desinstalación"; $unForm.Size = "450, 550"; $unForm.StartPosition = "CenterScreen"
            $unList = New-Object Windows.Forms.CheckedListBox; $unList.Dock = "Fill"; $unList.CheckOnClick = $true; $unList.Font = $fontNegrita11
            $paths = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
            $installed = Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -ne $null } | Select-Object DisplayName, UninstallString, QuietUninstallString | Sort-Object DisplayName
            foreach ($item in $installed) { [void]$unList.Items.Add($item.DisplayName) }
            $unBtn = New-Object RoundedButton; $unBtn.Text = "Eliminar Seleccionados"; $unBtn.Height = 60; $unBtn.Dock = "Bottom"; $unBtn.BackColor = "Black"; $unBtn.ForeColor = "White"; $unBtn.Font = $fontBotones
            $unBtn.Add_Click({
                $seleccionadosDes = $unList.CheckedItems | ForEach-Object { $_.ToString() }
                if ($seleccionadosDes.Count -eq 0) { $unForm.Close(); return }
                foreach ($itemText in $seleccionadosDes) {
                    $pInfo = $installed | Where-Object { $_.DisplayName -eq $itemText } | Select-Object -First 1
                    $uCmd = if ($pInfo.QuietUninstallString) { $pInfo.QuietUninstallString } else { $pInfo.UninstallString }
                    if ($uCmd) {
                        $uCmd = $uCmd.Trim()
                        try {
                            if ($uCmd -match "msiexec") {
                                $guid = if ($uCmd -match "{[A-Z0-9-]+}") { $Matches[0] } else { $uCmd -replace '(?i)msiexec(\.exe)?\s+/(i|x)\s+', '' }
                                Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Verb RunAs -Wait
                            } else {
                                if ($uCmd.StartsWith('"')) { if ($uCmd -match '^"([^"]+)"\s*(.*)$') { $exe = $Matches[1]; $args = ($Matches[2] + " /S /silent /verysilent /qn /norestart").Trim(); Start-Process $exe -ArgumentList $args -Verb RunAs -Wait } }
                                else { $split = $uCmd -split " ", 2; $exe = $split[0]; $args = if ($split.Count -gt 1) { ($split[1] + " /S /silent /verysilent /qn /norestart").Trim() } else { "/S /silent /verysilent /qn /norestart" }; Start-Process $exe -ArgumentList $args -Verb RunAs -Wait }
                            }
                        } catch { Start-Process cmd.exe -ArgumentList "/c $uCmd" -WindowStyle Hidden -Verb RunAs -Wait }
                    }
                }
                [Windows.Forms.MessageBox]::Show("Proceso finalizado.", "Info"); $unForm.Close()
            })
            $unForm.Controls.AddRange(@($unList, $unBtn)); $unForm.ShowDialog()
        })
        $toolsForm.Controls.AddRange(@($lblMaint, $btnSFC, $btnDISM, $btnCHK, $lblAct, $btnLic, $lblGest, $btnLaunchDes)); $toolsForm.ShowDialog()
    })
    $form.Controls.Add($btnTools)

    if ($form.ShowDialog() -ne "OK") { $script:continuarEnMenu = $false; break }

    # --- LÓGICA DE INSTALACIÓN ---
    $timerStatus.Stop()
    $ftpFinal = if ($rbLocal.Checked) { $ftpLocal } else { $ftpOnline }
    $seleccionados = $checkedListBox.CheckedItems | ForEach-Object { $_.ToString() }
    
    if ($seleccionados.Count -gt 0) {
        $progForm = New-Object Windows.Forms.Form; $progForm.Text = "Instalando Software..."; $progForm.Size = "450, 160"; $progForm.StartPosition = "CenterScreen"; $progForm.FormBorderStyle = "FixedToolWindow"
        $progLabel = New-Object Windows.Forms.Label; $progLabel.Location = "20, 20"; $progLabel.Size = "400, 25"; $progLabel.Font = New-Object Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $pBar = New-Object Windows.Forms.ProgressBar; $pBar.Location = "20, 75"; $pBar.Size = "390, 25"; $pBar.Maximum = 100
        $progForm.Controls.AddRange(@($progLabel, $pBar)); $progForm.Show()

        $wc = New-Object System.Net.WebClient; $wc.Credentials = New-Object System.Net.NetworkCredential($user, $pass)
        $actual = 0; $total = $seleccionados.Count

        foreach ($nombre in $seleccionados) {
            $actual++; $progLabel.Text = "Procesando: $nombre ($actual/$total)"; $pBar.Value = [int](($actual / $total) * 100); $progForm.Refresh()
            $config = $programas[$nombre]; $archivo = $config[0]
            $params = if ($config.Count -eq 3) { $config[1] } else { "" }
            $esVisible = if ($config.Count -eq 3) { $config[2] } else { $config[1] }
            $localPath = Join-Path $localTemp $archivo

            try {
                $wc.DownloadFile("ftp://$ftpFinal/$remotePath/$archivo", $localPath)
                if (Test-Path $localPath) {
                    if ($localPath.EndsWith(".msi")) {
                        $proc = Start-Process "msiexec.exe" -ArgumentList "/i `"$localPath`" $params" -Wait -PassThru
                        $estadoInstalacion[$nombre] = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)
                    } else {
                        $style = if ($esVisible) { "Normal" } else { "Hidden" }
                        if ($nombre -eq "Adobe Reader") { Start-Process $localPath -ArgumentList $params -WindowStyle $style; Start-Sleep -Seconds 300; $estadoInstalacion[$nombre] = $true }
                        else { $proc = Start-Process $localPath -ArgumentList $params -Wait -WindowStyle $style -PassThru; $estadoInstalacion[$nombre] = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) }
                    }
                }
            } catch { $estadoInstalacion[$nombre] = $false }
            if (Test-Path $localPath) { Remove-Item $localPath -Force -ErrorAction SilentlyContinue }
        }
        $progForm.Close()

        # Resumen Final
        $resForm = New-Object Windows.Forms.Form; $resForm.Text = "Resumen"; $resForm.Size = "500, 520"; $resForm.StartPosition = "CenterScreen"; $resForm.BackColor = "White"; $resForm.ControlBox = $false
        $resList = New-Object Windows.Forms.ListBox; $resList.Location = "20, 20"; $resList.Size = "445, 280"; $resList.Font = New-Object Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold); $resList.ItemHeight = 25; $resList.DrawMode = "OwnerDrawFixed"
        $resList.Add_DrawItem({ param($s, $e) if ($e.Index -lt 0) { return }; $texto = $s.Items[$e.Index].ToString(); $brushC = if ($texto.Contains(" [ OK ] ")) { [System.Drawing.Color]::DarkGreen } else { [System.Drawing.Color]::DarkRed }; $e.DrawBackground(); $brush = New-Object System.Drawing.SolidBrush($brushC); $e.Graphics.DrawString($texto, $e.Font, $brush, $e.Bounds.X, $e.Bounds.Y); $brush.Dispose() })
        foreach ($n in $seleccionados) { $status = if($estadoInstalacion[$n]){" [ OK ] "}else{" [FALLO] "}; [void]$resList.Items.Add($status + $n) }
        $msgL = New-Object Windows.Forms.Label; $msgL.Text = "¿Qué deseas hacer?"; $msgL.Location = "20, 315"; $msgL.Size = "445, 40"; $msgL.TextAlign = "MiddleCenter"; $msgL.Font = $fontNegrita11
        $btnRe = New-Object RoundedButton; $btnRe.Text = "🔄 Reiniciar"; $btnRe.Location = "20, 370"; $btnRe.Size = "140, 65"; $btnRe.BackColor = "DarkOrange"; $btnRe.ForeColor = "White"; $btnRe.Font = $fontBotones
        $btnRe.Add_Click({ Restart-Computer -Force })
        $btnVol = New-Object RoundedButton; $btnVol.Text = "↩ Inicio"; $btnVol.Location = "172, 370"; $btnVol.Size = "140, 65"; $btnVol.BackColor = "SteelBlue"; $btnVol.ForeColor = "White"; $btnVol.Font = $fontBotones
        $btnVol.Add_Click({ $resForm.Close() })
        $btnFi = New-Object RoundedButton; $btnFi.Text = "✅ Finalizar"; $btnFi.Location = "325, 370"; $btnFi.Size = "140, 65"; $btnFi.BackColor = "DarkGreen"; $btnFi.ForeColor = "White"; $btnFi.Font = $fontBotones
        $btnFi.Add_Click({ $script:continuarEnMenu = $false; $resForm.Close() })
        $resForm.Controls.AddRange(@($resList, $msgL, $btnRe, $btnVol, $btnFi)); $resForm.ShowDialog() | Out-Null
    }
}
if (Test-Path $localTemp) { Remove-Item $localTemp -Recurse -Force -ErrorAction SilentlyContinue }