<#
.SYNOPSIS
  Baut das Auslieferungspaket der Godot-Fassung in godot/build/.

.DESCRIPTION
  Windows 11 mit eingeschalteter "Smart App Control" (SAC) blockiert jede EXE,
  die nicht von einer vertrauenswürdigen Zertifizierungsstelle signiert ist.
  Der Godot-Export-Template ist unsigniert - ein selbstsigniertes Zertifikat
  reicht für SAC NICHT. Deshalb liefert dieses Skript zwei Wege:

    1. SAC-tauglich: die offiziell signierte Godot-Laufzeit (Certum-Zertifikat,
       Prehensile Tales B.V.) + das Spiel als PaulUndRezi.pck + Verknüpfung
       "Paul und REZI.lnk". Läuft überall.
    2. Klassisch: PaulUndRezi.exe (Template mit eingebettetem Spiel), zusätzlich
       mit einem selbstsignierten Zertifikat signiert. Läuft auf Rechnern ohne
       SAC (SmartScreen: "Weitere Informationen → Trotzdem ausführen").

  Mit -Thumbprint <SHA1> wird stattdessen ein gekauftes Code-Signing-Zertifikat
  aus dem Zertifikatspeicher des Benutzers verwendet (dann akzeptiert auch SAC).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1
  powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1 -Thumbprint ABCDEF...
#>
param(
    [string]$Thumbprint = "",
    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Godot = Join-Path $Root ".tools\Godot_v4.7.2-stable_win64_console.exe"
$Runtime = Join-Path $Root ".tools\Godot_v4.7.2-stable_win64.exe"
$Project = Join-Path $Root "godot"
$Build = Join-Path $Project "build"
New-Item -ItemType Directory -Force $Build | Out-Null

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }

if (-not $SkipExport) {
    Step "Spiel als PCK exportieren"
    & $Godot --path $Project --headless --export-pack "Windows" "build/PaulUndRezi.pck" | Out-Null
    Step "Spiel als EXE exportieren (für Rechner ohne Smart App Control)"
    & $Godot --path $Project --headless --export-release "Windows" "build/PaulUndRezi.exe" | Out-Null
}

Step "Signierte Godot-Laufzeit beilegen"
Copy-Item $Runtime (Join-Path $Build "Godot_v4.7.2-stable_win64.exe") -Force
$sig = Get-AuthenticodeSignature (Join-Path $Build "Godot_v4.7.2-stable_win64.exe")
Write-Host ("   Laufzeit-Signatur: {0} ({1})" -f $sig.Status, $sig.SignerCertificate.Subject)

Step "Verknüpfung und Startdatei anlegen"
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut((Join-Path $Build "Paul und REZI.lnk"))
$lnk.TargetPath = Join-Path $Build "Godot_v4.7.2-stable_win64.exe"
$lnk.Arguments = '--main-pack "PaulUndRezi.pck" -- --fullscreen'
$lnk.WorkingDirectory = $Build
$lnk.Description = "Paul & REZI - Das e-Rezept Jump 'n' Run"
$lnk.Save()
$lnkKiosk = $shell.CreateShortcut((Join-Path $Build "Paul und REZI (Messe-Kiosk).lnk"))
$lnkKiosk.TargetPath = $lnk.TargetPath
$lnkKiosk.Arguments = '--main-pack "PaulUndRezi.pck" -- --kiosk'
$lnkKiosk.WorkingDirectory = $Build
$lnkKiosk.Save()
@'
@echo off
cd /d "%~dp0"
start "" "Godot_v4.7.2-stable_win64.exe" --main-pack "PaulUndRezi.pck" -- --fullscreen
'@ | Set-Content -Path (Join-Path $Build "Paul und REZI.bat") -Encoding ASCII

Step "EXE signieren"
$exe = Join-Path $Build "PaulUndRezi.exe"
if (Test-Path $exe) {
    $cert = $null
    if ($Thumbprint -ne "") {
        $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $Thumbprint }
        if (-not $cert) { throw "Zertifikat mit Thumbprint $Thumbprint nicht in Cert:\CurrentUser\My" }
    } else {
        $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -eq "CN=Paul & REZI Projekt" } | Select-Object -First 1
        if (-not $cert) {
            Write-Host "   Erzeuge selbstsigniertes Code-Signing-Zertifikat (nur für Rechner ohne Smart App Control)"
            $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Paul & REZI Projekt" `
                -CertStoreLocation Cert:\CurrentUser\My -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(5)
        }
    }
    try {
        $r = Set-AuthenticodeSignature -FilePath $exe -Certificate $cert -HashAlgorithm SHA256 -TimestampServer "http://timestamp.digicert.com"
    } catch {
        $r = Set-AuthenticodeSignature -FilePath $exe -Certificate $cert -HashAlgorithm SHA256
    }
    Write-Host ("   Signatur: {0} - {1}" -f $r.Status, $cert.Subject)
    Export-Certificate -Cert $cert -FilePath (Join-Path $Build "PaulUndRezi-Zertifikat.cer") -Force | Out-Null
    @'
@echo off
echo Dieses Zertifikat ist selbstsigniert. Es wird nur in den Speicher des aktuellen Benutzers
echo eingetragen und macht PaulUndRezi.exe auf Rechnern OHNE Smart App Control zu einem
echo "bekannten Herausgeber". Windows fragt gleich nach Bestaetigung.
pause
certutil -user -addstore Root "%~dp0PaulUndRezi-Zertifikat.cer"
certutil -user -addstore TrustedPublisher "%~dp0PaulUndRezi-Zertifikat.cer"
pause
'@ | Set-Content -Path (Join-Path $Build "Zertifikat-vertrauen (optional).bat") -Encoding ASCII
}

Step "LIESMICH schreiben"
@"
Paul & REZI - Das e-Rezept Jump 'n' Run (Godot-Fassung)
=======================================================

STARTEN
  Doppelklick auf  "Paul und REZI.lnk"   (Vollbild)  oder  "Paul und REZI.bat"
  Messestand:      "Paul und REZI (Messe-Kiosk).lnk"  (Vollbild, Cursor aus, Idle-Reset)

  Beide starten die offiziell signierte Godot-Laufzeit (Godot_v4.7.2-stable_win64.exe,
  Zertifikat: Prehensile Tales B.V. / Certum) mit dem Spiel PaulUndRezi.pck.
  Das funktioniert auch auf Windows 11 mit eingeschalteter Smart App Control.

  Tasten: Pfeile/WASD laufen · LEERTASTE springen (in der Luft nochmal = REZI-Schub)
          E TI-Aktion · SHIFT Huelle · F11 Vollbild · ESC/F12 siehe README

ALTERNATIVE: PaulUndRezi.exe
  Eine einzelne EXE mit eingebettetem Spiel. Sie ist mit einem SELBSTSIGNIERTEN
  Zertifikat signiert. Windows 11 mit Smart App Control blockiert sie trotzdem
  ("Anwendungssteuerungsrichtlinie hat diese Datei blockiert"), weil SAC nur
  Zertifikate von Zertifizierungsstellen akzeptiert. Auf Rechnern ohne SAC zeigt
  SmartScreen einmalig "Weitere Informationen -> Trotzdem ausfuehren".
  Optional: "Zertifikat-vertrauen (optional).bat" traegt das Zertifikat fuer den
  aktuellen Benutzer ein, dann entfaellt die Warnung dort.

EIN "RICHTIGES" ZERTIFIKAT
  Damit auch die EXE unter Smart App Control laeuft, braucht es ein Code-Signing-
  Zertifikat einer Zertifizierungsstelle (z. B. Certum, SSL.com, DigiCert; OV ab
  ca. 100-400 EUR/Jahr, Identitaetspruefung des Unternehmens). Danach:
    powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1 -Thumbprint <SHA1>

Smart App Control ausschalten ist moeglich (Windows-Sicherheit -> App- & Browser-
steuerung -> Smart App Control), aber endgueltig: Es laesst sich ohne Windows-
Neuinstallation nicht wieder einschalten. Nicht empfohlen fuer den Messe-PC.
"@ | Set-Content -Path (Join-Path $Build "LIESMICH.txt") -Encoding UTF8

Step "Fertig"
Get-ChildItem $Build | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}} | Format-Table -AutoSize
