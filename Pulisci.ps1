<#
.SYNOPSIS
  Pulisce ricorsivamente cartelle bin, obj e .vs a partire dalla cartella indicata.

.DESCRIPTION
  - Se non passi nessun parametro, parte dalla cartella corrente.
  - Cerca in tutte le sottocartelle per nomi esatti: bin, obj, .vs
  - Mostra un riepilogo, chiede conferma e poi cancella.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RootPath = (Get-Location).Path
)

# -----------------------------
# 1. Validazione percorso radice
# -----------------------------
if (-not (Test-Path -LiteralPath $RootPath)) {
    Write-Host "Percorso non valido: $RootPath" -ForegroundColor Red
    exit 1
}

$RootPath = (Resolve-Path -LiteralPath $RootPath).Path
Write-Host "Cartella radice: $RootPath" -ForegroundColor Cyan

# -----------------------------
# 2. Definizione nomi cartelle da eliminare
# -----------------------------
$targetNames = @('bin', 'obj', '.vs')   # Se vuoi aggiungerne altre, mettile qui.

# -----------------------------
# 3. Ricerca cartelle corrispondenti
# -----------------------------
Write-Host "Ricerca di cartelle: $($targetNames -join ', ') ..." -ForegroundColor Yellow

# IMPORTANTE: -ErrorAction SilentlyContinue evita di bloccare lo script
# su cartelle con accesso negato (es. $RECYCLE.BIN, System Volume Information, ecc.)
$folders = Get-ChildItem -Path $RootPath -Directory -Recurse -Force -ErrorAction SilentlyContinue |
           Where-Object { $targetNames -contains $_.Name }

# Considera anche la cartella radice stessa se si chiama bin/obj/.vs
$rootName = Split-Path -Leaf $RootPath
if ($targetNames -contains $rootName) {
    $rootAsItem = Get-Item -LiteralPath $RootPath -ErrorAction SilentlyContinue
    if ($rootAsItem) {
        $folders = @($rootAsItem) + $folders
    }
}

if (-not $folders -or $folders.Count -eq 0) {
    Write-Host "Nessuna cartella bin/obj/.vs trovata sotto: $RootPath" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Trovate $($folders.Count) cartelle da eliminare:" -ForegroundColor Yellow
$folders | ForEach-Object {
    Write-Host " - $($_.FullName)"
}

Write-Host ""
$answer = Read-Host "ATTENZIONE: verranno CANCELLATE TUTTE queste cartelle. Vuoi continuare? (s/N)"

if ($answer -notin @('s', 'S', 'y', 'Y')) {
    Write-Host "Operazione annullata." -ForegroundColor DarkYellow
    exit 0
}

# -----------------------------
# 4. Cancellazione cartelle
# -----------------------------
Write-Host ""
Write-Host "Avvio eliminazione cartelle..." -ForegroundColor Yellow

$index = 0
foreach ($folder in $folders) {
    $index++
    Write-Host "[$index/$($folders.Count)] Rimozione: $($folder.FullName)"

    try {
        if ($PSCmdlet.ShouldProcess($folder.FullName, "Remove-Item -Recurse -Force")) {
            Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction Stop
        }

        Write-Host "   -> OK" -ForegroundColor Green
    }
    catch {
        Write-Host "   -> ERRORE: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Pulizia completata." -ForegroundColor Green
