# Script de diagnostic de l'état de l'import MusicBrainz
# Usage: .\scripts\check_import_status.ps1

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`nDiagnostic de l'etat de l'import MusicBrainz" "Cyan"
Write-ColorOutput "=============================================" "Cyan"
Write-ColorOutput ""

# 1. Verifier si Docker est en cours d'execution
Write-ColorOutput "Etape 1/5: Verification Docker..." "Yellow"
$dockerRunning = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "ERREUR: Docker n'est pas en cours d'execution" "Red"
    Write-ColorOutput "Conseil: Demarrez Docker Desktop" "Cyan"
    exit 1
}
Write-ColorOutput "OK: Docker est en cours d'execution" "Green"

# 2. Vérifier si le conteneur existe et son état
Write-ColorOutput "`nEtape 2/5: Etat du conteneur musicbrainz-db..." "Yellow"
$containerInfo = docker ps -a --filter "name=musicbrainz-db" --format "{{.Names}}|{{.Status}}|{{.State}}" 2>&1
$containerStatus = $containerInfo | Out-String
if ([string]::IsNullOrWhiteSpace($containerStatus.Trim()) -or $containerStatus -match "error") {
    Write-ColorOutput "ERREUR: Conteneur musicbrainz-db introuvable" "Red"
    Write-ColorOutput "Conseil: Lancez: docker compose up -d" "Cyan"
    exit 1
}

$parts = $containerStatus.Trim() -split '\|'
if ($parts.Count -ge 3) {
    Write-ColorOutput "   Nom: $($parts[0])" "White"
    Write-ColorOutput "   Etat: $($parts[1])" "White"
    Write-ColorOutput "   Statut: $($parts[2])" "White"
    
    if ($parts[2] -ne "running") {
        Write-ColorOutput "ATTENTION: Le conteneur n'est pas en cours d'execution" "Yellow"
        Write-ColorOutput "Conseil: Lancez: docker compose up -d" "Cyan"
    }
} else {
    Write-ColorOutput "   Info: $containerStatus" "White"
}

# 3. Verifier l'acces PostgreSQL
Write-ColorOutput "`nEtape 3/5: Test de connexion PostgreSQL..." "Yellow"
try {
    $pgTest = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -c "SELECT version();" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $pgVersion = ($pgTest | Select-String -Pattern "PostgreSQL").Line
        Write-ColorOutput "OK: PostgreSQL est accessible" "Green"
        if ($pgVersion) {
            Write-ColorOutput "   $pgVersion" "Gray"
        }
    } else {
        Write-ColorOutput "ERREUR: PostgreSQL n'est pas accessible (base peut etre en cours de creation)" "Red"
        Write-ColorOutput "ATTENTION: Attendez quelques minutes et reessayez" "Yellow"
        exit 1
    }
} catch {
    Write-ColorOutput "ERREUR: Erreur de connexion PostgreSQL: $_" "Red"
    exit 1
}

# 4. Verifier les tables et donnees
Write-ColorOutput "`nEtape 4/5: Verification des donnees importees..." "Yellow"

$query = @'
SELECT 
    'Tables creees' as metric,
    COUNT(*)::text as value
FROM information_schema.tables 
WHERE table_schema = 'musicbrainz'
UNION ALL
SELECT 
    'Enregistrements' as metric,
    COUNT(*)::text as value
FROM musicbrainz.recording
UNION ALL
SELECT 
    'Artistes' as metric,
    COUNT(*)::text as value
FROM musicbrainz.artist
UNION ALL
SELECT 
    'Oeuvres' as metric,
    COUNT(*)::text as value
FROM musicbrainz.work
UNION ALL
SELECT 
    'Releases' as metric,
    COUNT(*)::text as value
FROM musicbrainz.release;
'@

try {
    $results = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -t -A -F "|" -c $query 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $metrics = @{}
        $results | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
            $parts = $_ -split '\|'
            if ($parts.Count -ge 2) {
                $metrics[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
        
        # Afficher les résultats
        $tablesCount = 0
        $recordingsCount = 0
        $artistsCount = 0
        $worksCount = 0
        $releasesCount = 0
        
        if ($metrics.ContainsKey('Tables creees')) { $tablesCount = [long]$metrics['Tables creees'] }
        if ($metrics.ContainsKey('Enregistrements')) { $recordingsCount = [long]$metrics['Enregistrements'] }
        if ($metrics.ContainsKey('Artistes')) { $artistsCount = [long]$metrics['Artistes'] }
        if ($metrics.ContainsKey('Oeuvres')) { $worksCount = [long]$metrics['Oeuvres'] }
        if ($metrics.ContainsKey('Releases')) { $releasesCount = [long]$metrics['Releases'] }
        
        Write-ColorOutput "   Tables creees: $tablesCount" "White"
        if ($tablesCount -eq 0) {
            Write-ColorOutput "   ATTENTION: Aucune table trouvee - Import pas encore demarre" "Yellow"
        } elseif ($tablesCount -lt 100) {
            Write-ColorOutput "   EN COURS: Import en cours - Tables en cours de creation" "Yellow"
        } elseif ($tablesCount -lt 375) {
            Write-ColorOutput "   EN COURS: Import partiel - $tablesCount / ~375 tables" "Yellow"
        } else {
            Write-ColorOutput "   OK: Toutes les tables sont creees (~375 attendues)" "Green"
        }
        
        Write-ColorOutput "`n   Donnees importees:" "White"
        $recM = [math]::Round($recordingsCount / 1000000, 2)
        $artM = [math]::Round($artistsCount / 1000000, 2)
        $workM = [math]::Round($worksCount / 1000000, 2)
        $relM = [math]::Round($releasesCount / 1000000, 2)
        Write-ColorOutput "   - Enregistrements: $recM M" "White"
        Write-ColorOutput "   - Artistes: $artM M" "White"
        Write-ColorOutput "   - Oeuvres: $workM M" "White"
        Write-ColorOutput "   - Releases: $relM M" "White"
        
        # Evaluation de l'etat
        Write-ColorOutput "`nEtape 5/5: Evaluation de l'etat..." "Yellow"
        
        $importStatus = "INCONNU"
        $importProgress = 0
        
        if ($tablesCount -eq 0) {
            $importStatus = "ERREUR: Import pas demarre"
            $importProgress = 0
        } elseif ($recordingsCount -eq 0) {
            $importStatus = "EN COURS: Import en preparation"
            $importProgress = 5
        } elseif ($recordingsCount -lt 1000000) {
            $importStatus = "EN COURS: Import debute (telechargement/creation schemas)"
            $importProgress = 10
        } elseif ($recordingsCount -lt 10000000) {
            $importStatus = "EN COURS: Import en cours (10-20%)"
            $importProgress = 15
        } elseif ($recordingsCount -lt 30000000) {
            $importStatus = "EN COURS: Import en cours (30-50%)"
            $importProgress = 40
        } elseif ($recordingsCount -lt 45000000) {
            $importStatus = "EN COURS: Import en cours (70-90%)"
            $importProgress = 80
        } elseif ($recordingsCount -ge 50000000 -and $artistsCount -ge 2000000 -and $worksCount -ge 30000000) {
            $importStatus = "OK: Import termine"
            $importProgress = 100
        } else {
            $importStatus = "EN COURS: Import presque termine"
            $importProgress = 95
        }
        
        Write-ColorOutput "   Etat: $importStatus" "White"
        Write-ColorOutput "   Progression estimee: $importProgress%" "White"
        
        # Recommandations
        Write-ColorOutput "`nRecommandations:" "Cyan"
        
        if ($importProgress -eq 0) {
            Write-ColorOutput "   -> Lancer l'import: docker compose run --rm musicbrainz createdb.sh" "White"
        } elseif ($importProgress -lt 100) {
            Write-ColorOutput "   -> Surveiller l'import: docker compose logs -f musicbrainz" "White"
            Write-ColorOutput "   -> OU utiliser: .\scripts\monitor_import.ps1" "White"
            $hoursRemaining = [math]::Max(1, (100 - $importProgress) / 10)
            Write-ColorOutput "   -> Temps restant estime: $hoursRemaining heures" "White"
        } else {
            Write-ColorOutput "   -> Import termine! Vous pouvez creer le schema KPI:" "White"
            Write-ColorOutput "      . .\scripts\docker_helpers.ps1; Initialize-AllfeatKPI" "White"
            Write-ColorOutput "   -> Puis appliquer les vues:" "White"
            Write-ColorOutput "      Apply-KPIViews" "White"
        }
        
    } else {
        Write-ColorOutput "ERREUR: Erreur lors de la verification des donnees" "Red"
        Write-ColorOutput "   Les tables peuvent etre en cours de creation" "Yellow"
    }
} catch {
    Write-ColorOutput "ERREUR: $_" "Red"
}

Write-ColorOutput "`nOK: Diagnostic termine" "Green"
Write-ColorOutput ""

