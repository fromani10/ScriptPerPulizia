<#
.SYNOPSIS
  Pulisce ricorsivamente cartelle bin, obj e .vs a partire dalla cartella indicata.

.DESCRIPTION
  - Se non passi nessun parametro, parte dalla cartella corrente.
  - Cerca in tutte le sottocartelle per nomi esatti: bin, obj, .vs
  - Mostra un riepilogo, chiede conferma e poi cancella.
  - Prima di tutto, prova a chiudere i processi di sviluppo per evitare file bloccati.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RootPath = (Get-Location).Path
)

# -----------------------------
# 0. Terminazione processi di sviluppo
# -----------------------------
Write-Host "Fase 0: controllo processi aperti (Visual Studio, dotnet, msbuild, node, ecc.)..." -ForegroundColor Yellow

# Elenco dei processi che tipicamente bloccano bin/obj/.vs
$devProcesses = @(
    'devenv',        # Visual Studio
    'devenv64',      # VS 2022 a 64 bit
    'MSBuild',       # msbuild
    'dotnet',        # processi dotnet
    'VBCSCompiler',  # compilatore Roslyn
    'node',          # Node.js
    'npm',           # npm
    'npx',           # npx
    'Code',          # VS Code
    'Rider64'        # JetBrains Rider
)

# Trova i processi effettivamente attivi
$runningDevProcs = foreach ($name in $devProcesses) {
    Get-Process -Name $name -ErrorAction SilentlyContinue
}

if ($runningDevProcs -and $runningDevProcs.Count -gt 0) {
    Write-Host "Sono stati trovati i seguenti processi che potrebbero bloccare i file:" -ForegroundColor Yellow
    $runningDevProcs |
        Select-Object Name, Id, MainWindowTitle |
        Sort-Object Name, Id |
        ForEach-Object {
            Write-Host (" - {0} (Id: {1}) {2}" -f $_.Name, $_.Id, $_.MainWindowTitle)
        }

    $killAnswer = Read-Host "Vuoi CHIUDERE questi processi prima di procedere? (s/N)"

    if ($killAnswer -in @('s','S','y','Y')) {
        foreach ($proc in $runningDevProcs) {
            try {
                Write-Host "Chiudo processo: $($proc.Name) (Id: $($proc.Id))..." -ForegroundColor DarkYellow
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Write-Host "   -> Terminato" -ForegroundColor Green
            }
            catch {
                Write-Host "   -> ERRORE nel terminare $($proc.Name) (Id: $($proc.Id)): $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host "Attendo qualche secondo per il rilascio delle risorse..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    else {
        Write-Host "Processi lasciati aperti su richiesta dell'utente." -ForegroundColor DarkYellow
    }
}
else {
    Write-Host "Nessun processo di sviluppo rilevante trovato in esecuzione." -ForegroundColor Green
}

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

# -ErrorAction SilentlyContinue evita blocchi su cartelle con accesso negato
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


Read-Host "Premi INVIO per chiudere"
