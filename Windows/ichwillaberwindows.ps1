# ============================================================
# VKS-Kiosk - Windows/WSL2 Vorbereitungsskript
# Erstellt den Build-Kontext unter Windows und reicht den
# USB-Stick via usbipd an WSL2 durch.
# ============================================================

# --- 1. Voraussetzungen installieren (idempotent) -----------
Write-Host "`n=== [1/5] Voraussetzungen pruefen ===" -ForegroundColor Cyan
winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements 2>$null
wsl.exe --install --no-launch 2>$null
winget install --exact dorssel.usbipd-win --accept-source-agreements --accept-package-agreements 2>$null
wsl --install -d Debian --no-launch 2>$null
wsl --set-default Debian

# --- 2. USB/IP Tools in WSL installieren --------------------
Write-Host "`n=== [2/5] USB/IP Tools in WSL installieren ===" -ForegroundColor Cyan
wsl -d Debian -u root -- bash -c "apt-get update -qq && apt-get install -y -qq linux-tools-generic hwdata usbutils 2>/dev/null; true"

# --- 3. USB-Stick erkennen und an WSL durchreichen ----------
Write-Host "`n=== [3/5] USB-Stick suchen und durchreichen ===" -ForegroundColor Cyan
$usbList = usbipd list
$storageLine = $usbList | Select-String -Pattern "(Massenspeicher|Mass Storage)" | Select-Object -Last 1

if ($storageLine) {
    $add = ($storageLine.Line.Trim() -split '\s+')[0]
    Write-Host "USB-Massenspeicher gefunden an BUSID: $add" -ForegroundColor Green

    # --force: Windows gibt den Stick komplett frei
    usbipd bind --force --busid $add 2>$null
    Start-Sleep -Seconds 2

    # Attach mit Replug-Erkennung
    $attached = $false
    $maxReplugCycles = 5

    for ($cycle = 1; $cycle -le $maxReplugCycles; $cycle++) {
        # 3 schnelle Versuche pro Zyklus
        for ($i = 1; $i -le 3; $i++) {
            Write-Host "  Attach-Versuch $i/3 (Zyklus $cycle) ..." -ForegroundColor Yellow
            $result = usbipd attach --wsl --busid $add 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  USB-Stick erfolgreich an WSL durchgereicht!" -ForegroundColor Green
                $attached = $true
                break
            }
            Start-Sleep -Seconds 2
        }
        if ($attached) { break }

        # Attach fehlgeschlagen - auf Replug warten
        Write-Host ""
        Write-Host "  Attach fehlgeschlagen. Bitte USB-Stick jetzt ABZIEHEN ..." -ForegroundColor Red -NoNewline

        # Warten bis der Stick verschwindet
        $timeout = 60
        $waited = 0
        while ($waited -lt $timeout) {
            $check = usbipd list 2>$null | Select-String -Pattern "(Massenspeicher|Mass Storage)"
            if (-not $check) { break }
            Start-Sleep -Seconds 1
            $waited++
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        if ($waited -ge $timeout) {
            Write-Host "`n  Timeout: Stick wurde nicht abgezogen. Ueberspringe." -ForegroundColor Red
            break
        }
        Write-Host " erkannt!" -ForegroundColor Green

        Write-Host "  Jetzt USB-Stick wieder EINSTECKEN ..." -ForegroundColor Cyan -NoNewline

        # Warten bis der Stick wieder auftaucht
        $waited = 0
        $add = $null
        while ($waited -lt $timeout) {
            $newLine = usbipd list 2>$null | Select-String -Pattern "(Massenspeicher|Mass Storage)" | Select-Object -Last 1
            if ($newLine) {
                $add = ($newLine.Line.Trim() -split '\s+')[0]
                break
            }
            Start-Sleep -Seconds 1
            $waited++
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        if (-not $add) {
            Write-Host "`n  Timeout: Stick wurde nicht wieder eingesteckt. Ueberspringe." -ForegroundColor Red
            break
        }
        Write-Host " erkannt! Neue BUSID: $add" -ForegroundColor Green

        # Neu binden nach Replug
        Start-Sleep -Seconds 3
        usbipd bind --force --busid $add 2>$null
        Start-Sleep -Seconds 2
    }

    if (-not $attached) {
        Write-Host "`nUSB-Attach nach $maxReplugCycles Zyklen fehlgeschlagen." -ForegroundColor Red
        Write-Host "Stelle sicher, dass PowerShell als Administrator laeuft!" -ForegroundColor Yellow
        Write-Host "Du kannst trotzdem in WSL weiterarbeiten, aber ohne USB-Zugriff.`n" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "WARNUNG: Kein USB-Massenspeicher gefunden! Bitte Stick einstecken und Skript erneut starten." -ForegroundColor Red
}

# --- 4. Junction Link erstellen ----------------------------
Write-Host "`n=== [4/5] Junction Link pruefen ===" -ForegroundColor Cyan
$JunctionPath = Join-Path -Path $env:USERPROFILE -ChildPath "VKS-Kiosk-Windows"
if (-not (Test-Path -Path $JunctionPath)) {
    New-Item -ItemType Junction -Path $JunctionPath -Target $PSScriptRoot | Out-Null
    Write-Host "Junction Link erstellt: $JunctionPath -> $PSScriptRoot" -ForegroundColor Green
} else {
    Write-Host "Junction Link existiert bereits: $JunctionPath" -ForegroundColor DarkGray
}

# --- 5. WSL starten ----------------------------------------
Write-Host "`n=== [5/5] WSL oeffnen ===" -ForegroundColor Cyan
Write-Host "Du bist jetzt in der Linux-Konsole. Fuehre aus:" -ForegroundColor White
Write-Host "  sudo ./make_install_wsl.sh" -ForegroundColor Green
Write-Host ""
Set-Location -Path $JunctionPath
wsl -d Debian

