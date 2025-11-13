# Script de vérification légère de l'état de la base MusicBrainz
# Usage: .\scripts\check_import_status.ps1
# 
# Vérifie uniquement les comptages des tables clés (sans boucles ni monitoring)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n🔍 Vérification de l'état de la base MusicBrainz" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput ""

# Vérifier que le container existe et est en cours d'exécution
$containerStatus = docker inspect musicbrainz-db --format='{{.State.Status}}' 2>&1
if ($LASTEXITCODE -ne 0 -or $containerStatus -ne "running") {
    Write-ColorOutput "❌ Container musicbrainz-db n'existe pas ou n'est pas en cours d'exécution." "Red"
    Write-ColorOutput "💡 Démarrez avec: docker compose up -d db" "Cyan"
    exit 1
}
Write-ColorOutput "✅ Container musicbrainz-db est en cours d'exécution" "Green"

# Vérifier l'accès PostgreSQL
Write-ColorOutput "`n🔌 Test de connexion PostgreSQL..." "Yellow"
$pgTest = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ PostgreSQL n'est pas accessible" "Red"
    exit 1
}
Write-ColorOutput "✅ PostgreSQL est accessible" "Green"

# Comptages des tables clés (requêtes légères uniquement)
Write-ColorOutput "`n📊 Comptages des tables clés:" "Yellow"

$query = @"
SELECT 
    'recording' as table_name,
    COUNT(*) as row_count
FROM musicbrainz.recording
UNION ALL
SELECT 
    'work',
    COUNT(*)
FROM musicbrainz.work
UNION ALL
SELECT 
    'artist',
    COUNT(*)
FROM musicbrainz.artist
UNION ALL
SELECT 
    'release',
    COUNT(*)
FROM musicbrainz.release
UNION ALL
SELECT 
    'isrc',
    COUNT(*)
FROM musicbrainz.isrc
UNION ALL
SELECT 
    'iswc',
    COUNT(*)
FROM musicbrainz.iswc;
"@

try {
    $results = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -A -F "|" -c $query 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $results | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
            $parts = $_ -split '\|'
            if ($parts.Count -ge 2) {
                $tableName = $parts[0].Trim()
                $rowCount = [long]($parts[1].Trim())
                $formatted = if ($rowCount -ge 1000000) { 
                    "{0:N1}M" -f ($rowCount / 1000000) 
                } elseif ($rowCount -ge 1000) { 
                    "{0:N0}K" -f ($rowCount / 1000) 
                } else { 
                    $rowCount.ToString() 
                }
                Write-ColorOutput "  $tableName : $formatted ($rowCount)" "White"
            }
        }
    } else {
        Write-ColorOutput "  ⚠️  Erreur lors de la récupération des comptages" "Yellow"
    }
} catch {
    Write-ColorOutput "  ❌ Erreur: $_" "Red"
}

Write-ColorOutput "`n✅ Vérification terminée" "Green"
Write-ColorOutput ""
