# ============================================================
# VKS-Kiosk - Windows/WSL2 Vorbereitungsskript
# Erstellt den Build-Kontext unter Windows und reicht den
# USB-Stick via usbipd an WSL2 durch.
# Als Administrator ausfuehren!
# ============================================================

# Helper: usbipd-Pfad ermitteln (auch nach frischer Installation)
function Get-Usbipd {
    # Zuerst im aktuellen PATH suchen
    $cmd = Get-Command usbipd -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # Dann typische Installationspfade absuchen
    $candidates = @(
        "$env:ProgramFiles\usbipd-win\usbipd.exe",
        "${env:ProgramFiles(x86)}\usbipd-win\usbipd.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

# Helper: USB-Geraet mit gueltiger BUSID (z.B. "1-2") und Massenspeicher finden
function Find-StorageBusid ([string]$usbipdExe) {
    $lines = & $usbipdExe list 2>$null
    foreach ($line in $lines) {
        if ($line -match '^\s*([0-9]+-[0-9]+(?:\.[0-9]+)*)\s+' -and
            $line -match '(Massenspeicher|Mass Storage)') {
            return $Matches[1]
        }
    }
    return $null
}

# ============================================================
# [1/5] Voraussetzungen installieren (idempotent)
# ============================================================
Write-Host "`n=== [1/5] Voraussetzungen pruefen ===" -ForegroundColor Cyan

winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements 2>$null | Out-Null
wsl.exe --install --no-launch 2>$null | Out-Null
wsl --install -d Debian --no-launch 2>$null | Out-Null
wsl --set-default Debian 2>$null | Out-Null

# usbipd installieren falls noetig
$usbipdExe = Get-Usbipd
if (-not $usbipdExe) {
    Write-Host "  Installiere usbipd-win ..." -ForegroundColor Yellow
    winget install --exact dorssel.usbipd-win --accept-source-agreements --accept-package-agreements 2>$null | Out-Null
    # PATH neu laden damit usbipd sofort verfuegbar ist
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $usbipdExe = Get-Usbipd
}

if (-not $usbipdExe) {
    Write-Host "FEHLER: usbipd konnte nicht gefunden werden nach Installation!" -ForegroundColor Red
    Write-Host "Bitte PowerShell neu starten und Skript erneut ausfuehren." -ForegroundColor Yellow
    exit 1
}
Write-Host "  usbipd gefunden: $usbipdExe" -ForegroundColor Green

# ============================================================
# [2/5] USB/IP Tools in WSL installieren
# ============================================================
Write-Host "`n=== [2/5] USB/IP Tools in WSL installieren ===" -ForegroundColor Cyan
# linux-tools-generic existiert nicht in Debian - korrekte Pakete sind usbip und hwdata
wsl -d Debian -u root -- bash -c @"
apt-get update -qq 2>/dev/null
apt-get install -y -qq usbip hwdata usbutils 2>/dev/null
modprobe vhci-hcd 2>/dev/null || true
true
"@
Write-Host "  WSL USB/IP Tools bereit." -ForegroundColor Green

# ============================================================
# [3/5] USB-Stick erkennen und an WSL durchreichen
# ============================================================
Write-Host "`n=== [3/5] USB-Stick suchen und durchreichen ===" -ForegroundColor Cyan

$attached  = $false
$maxCycles = 5

for ($cycle = 1; $cycle -le $maxCycles; $cycle++) {

    # Stick suchen
    $busid = Find-StorageBusid $usbipdExe
    if (-not $busid) {
        Write-Host "  Kein USB-Massenspeicher gefunden." -ForegroundColor Red
        Write-Host "  Bitte USB-Stick einstecken und Enter druecken (oder 'q' zum Ueberspringen): " -ForegroundColor Yellow -NoNewline
        $inp = Read-Host
        if ($inp -eq 'q') { break }
        continue
    }

    Write-Host "  BUSID: $busid - Verbinde ..." -ForegroundColor Green

    # Binden (--force gibt Stick frei, falls Windows ihn haelt)
    & $usbipdExe bind --force --busid $busid 2>$null | Out-Null
    Start-Sleep -Seconds 2

    # 3 Attach-Versuche
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "  Attach-Versuch $i/3 (Zyklus $cycle) ..." -ForegroundColor Yellow
        & $usbipdExe attach --wsl --busid $busid 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  USB-Stick erfolgreich an WSL durchgereicht!" -ForegroundColor Green
            $attached = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if ($attached) { break }

    # Replug anfordern
    if ($cycle -lt $maxCycles) {
        Write-Host ""
        Write-Host "  Attach fehlgeschlagen (Zyklus $cycle/$maxCycles)." -ForegroundColor Red
        Write-Host "  Bitte USB-Stick ABZIEHEN ..." -ForegroundColor Red -NoNewline

        # Warten bis Stick weg ist (max 60s)
        $timeout = 60
        for ($w = 0; $w -lt $timeout; $w++) {
            $check = Find-StorageBusid $usbipdExe
            if (-not $check) { break }
            Start-Sleep -Seconds 1
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        Write-Host " OK" -ForegroundColor Green

        Write-Host "  Jetzt USB-Stick wieder EINSTECKEN ..." -ForegroundColor Cyan -NoNewline
        # Warten bis neuer Stick auftaucht (max 60s)
        for ($w = 0; $w -lt $timeout; $w++) {
            $check = Find-StorageBusid $usbipdExe
            if ($check) { break }
            Start-Sleep -Seconds 1
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        Write-Host " OK" -ForegroundColor Green
        Start-Sleep -Seconds 3  # kurz warten bis Windows den Stick registriert hat
    }
}

if (-not $attached) {
    Write-Host ""
    Write-Host "USB-Attach fehlgeschlagen nach $maxCycles Zyklen." -ForegroundColor Red
    Write-Host "Moegliche Ursachen:" -ForegroundColor Yellow
    Write-Host "  - PowerShell laeuft NICHT als Administrator" -ForegroundColor Yellow
    Write-Host "  - Stick wird von Windows blockiert (Explorer, Antivirus, Laufwerksverschluesselung)" -ForegroundColor Yellow
    Write-Host "Du kannst trotzdem in WSL weiterarbeiten, aber OHNE USB-Zugriff." -ForegroundColor DarkYellow
    Write-Host ""
}

# ============================================================
# [4/5] Junction Link erstellen
# ============================================================
Write-Host "`n=== [4/5] Junction Link pruefen ===" -ForegroundColor Cyan
$JunctionPath = Join-Path -Path $env:USERPROFILE -ChildPath "VKS-Kiosk-Windows"
if (-not (Test-Path -Path $JunctionPath)) {
    New-Item -ItemType Junction -Path $JunctionPath -Target $PSScriptRoot | Out-Null
    Write-Host "  Junction Link erstellt: $JunctionPath -> $PSScriptRoot" -ForegroundColor Green
} else {
    Write-Host "  Junction Link existiert bereits: $JunctionPath" -ForegroundColor DarkGray
}

# ============================================================
# [5/5] WSL starten
# ============================================================
Write-Host "`n=== [5/5] WSL oeffnen ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Naechster Schritt in der Linux-Konsole:" -ForegroundColor White
Write-Host "  sudo ./make_install_wsl.sh" -ForegroundColor Green
Write-Host ""
Set-Location -Path $JunctionPath
wsl -d Debian
