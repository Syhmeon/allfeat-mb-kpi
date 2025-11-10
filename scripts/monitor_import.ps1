# Monitor MusicBrainz Import Progress
# Version: 1.0
# Date: 2025-10-15
# Usage: .\scripts\monitor_import.ps1 [-Interval 30]

param(
    [int]$Interval = 30  # Check every 30 seconds by default
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-ContainerStatus {
    $status = docker inspect musicbrainz-db --format='{{.State.Status}}' 2>$null
    $health = docker inspect musicbrainz-db --format='{{.State.Health.Status}}' 2>$null
    return @{
        Status = $status
        Health = $health
    }
}

function Get-PostgreSQLStatus {
    $result = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -c "SELECT 1;" 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-SchemaTableCount {
    if (-not (Get-PostgreSQLStatus)) {
        return 0
    }
    
    try {
        $query = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'musicbrainz';"
        $result = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -c $query 2>$null
        
        if (-not $result) {
            return 0
        }
        
        # Gérer les tableaux et les chaînes
        $value = if ($result -is [array]) { 
            ($result | Where-Object { $_ -ne $null } | Select-Object -First 1)
        } else { 
            $result 
        }
        
        if (-not $value) {
            return 0
        }
        
        $trimmed = $value.ToString().Trim()
        if ($trimmed -match '^\d+$') {
            return [int]$trimmed
        }
    } catch {
        # En cas d'erreur, retourner 0
        return 0
    }
    
    return 0
}

function Get-DatabaseSize {
    if (-not (Get-PostgreSQLStatus)) {
        return "N/A"
    }
    
    $query = "SELECT pg_size_pretty(pg_database_size('musicbrainz_db'));"
    $result = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -c $query 2>$null
    if ($result) {
        $value = if ($result -is [array]) { $result[0] } else { $result }
        return $value.ToString().Trim()
    }
    return "N/A"
}

function Get-TableCounts {
    if (-not (Get-PostgreSQLStatus)) {
        return $null
    }
    
    # Vérifier d'abord si les tables existent
    $checkQuery = @"
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'musicbrainz' 
    AND table_name IN ('recording', 'artist', 'work', 'release')
);
"@
    
    $tablesExist = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -c $checkQuery 2>$null
    if ($tablesExist) {
        $value = if ($tablesExist -is [array]) { $tablesExist[0] } else { $tablesExist }
        $trimmed = $value.ToString().Trim()
        if ($trimmed -ne "t") {
            return $null
        }
    } else {
        return $null
    }
    
    $query = @"
SELECT 
    'recording' as table_name,
    COUNT(*) as count
FROM musicbrainz.recording
UNION ALL
SELECT 
    'artist' as table_name,
    COUNT(*) as count
FROM musicbrainz.artist
UNION ALL
SELECT 
    'work' as table_name,
    COUNT(*) as count
FROM musicbrainz.work
UNION ALL
SELECT 
    'release' as table_name,
    COUNT(*) as count
FROM musicbrainz.release;
"@
    
    $result = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -c $query 2>$null
    return $result
}

function Get-ImportLogs {
    # Récupérer les dernières lignes des logs du conteneur d'import
    $importContainers = docker ps -a --filter "ancestor=metabrainz/musicbrainz-docker-musicbrainz" --format "{{.ID}}" 2>$null
    if ($importContainers) {
        $latestContainer = ($importContainers -split "`n" | Select-Object -First 1).Trim()
        if ($latestContainer) {
            $logs = docker logs $latestContainer --tail 5 2>&1
            return $logs
        }
    }
    return $null
}

function Format-Number {
    param([long]$Number)
    if ($Number -ge 1000000) {
        return "{0:N1}M" -f ($Number / 1000000)
    } elseif ($Number -ge 1000) {
        return "{0:N0}K" -f ($Number / 1000)
    } else {
        return "{0:N0}" -f $Number
    }
}

# Display header
Clear-Host
Write-ColorOutput "`n🎯 MusicBrainz Import Monitor" "Cyan"
Write-ColorOutput "=============================" "Cyan"
Write-ColorOutput "Checking every $Interval seconds. Press Ctrl+C to exit.`n" "Yellow"

$iteration = 0
$importComplete = $false

while (-not $importComplete) {
    $iteration++
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    # Get container status
    $containerStatus = Get-ContainerStatus
    
    Write-ColorOutput "`n[$timestamp] Check #$iteration" "Cyan"
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Gray"
    
    # Container status
    Write-Host "Container: " -NoNewline
    if ($containerStatus.Status -eq "running") {
        Write-ColorOutput "✅ Running" "Green"
    } else {
        Write-ColorOutput "❌ $($containerStatus.Status)" "Red"
    }
    
    Write-Host "Health:    " -NoNewline
    switch ($containerStatus.Health) {
        "healthy" { Write-ColorOutput "✅ Healthy" "Green" }
        "starting" { Write-ColorOutput "⏳ Starting..." "Yellow" }
        "unhealthy" { Write-ColorOutput "⚠️  Unhealthy (normal during import)" "Yellow" }
        default { Write-ColorOutput "❓ Unknown" "Gray" }
    }
    
    # PostgreSQL status
    Write-Host "PostgreSQL: " -NoNewline
    $pgReady = Get-PostgreSQLStatus
    if ($pgReady) {
        Write-ColorOutput "✅ Accessible" "Green"
        
        # Schema progress
        $schemaTableCount = Get-SchemaTableCount
        $dbSize = Get-DatabaseSize
        Write-Host "Tables créées: " -NoNewline
        if ($schemaTableCount -gt 0) {
            Write-ColorOutput "$schemaTableCount / ~375" "Yellow"
        } else {
            Write-ColorOutput "0 / ~375 (⏳ En attente...)" "Gray"
        }
        Write-Host "Taille DB:      " -NoNewline
        Write-ColorOutput $dbSize "Cyan"
        
        # Get table counts
        Write-ColorOutput "`nDonnées importées:" "Yellow"
        $tableCounts = Get-TableCounts
        
        if ($tableCounts) {
            $lines = $tableCounts -split "`n" | Where-Object { $_.Trim() -ne "" }
            
            $recordingCount = 0
            $artistCount = 0
            $workCount = 0
            $releaseCount = 0
            
            foreach ($line in $lines) {
                $parts = $line.Trim() -split '\|'
                if ($parts.Count -ge 2) {
                    $tableName = $parts[0].Trim()
                    $count = [long]($parts[1].Trim())
                    
                    switch ($tableName) {
                        "recording" { $recordingCount = $count }
                        "artist" { $artistCount = $count }
                        "work" { $workCount = $count }
                        "release" { $releaseCount = $count }
                    }
                }
            }
            
            # Display counts with progress indicators
            Write-Host "  Recording: " -NoNewline
            $recFormatted = Format-Number $recordingCount
            if ($recordingCount -gt 50000000) {
                Write-ColorOutput "$recFormatted (✅ Target reached: >50M)" "Green"
            } elseif ($recordingCount -gt 1000000) {
                Write-ColorOutput "$recFormatted (⏳ In progress...)" "Yellow"
            } else {
                Write-ColorOutput "$recFormatted (⏳ Starting...)" "Gray"
            }
            
            Write-Host "  Artist:    " -NoNewline
            $artFormatted = Format-Number $artistCount
            if ($artistCount -gt 2000000) {
                Write-ColorOutput "$artFormatted (✅ Target reached: >2M)" "Green"
            } else {
                Write-ColorOutput "$artFormatted" "Gray"
            }
            
            Write-Host "  Work:      " -NoNewline
            $workFormatted = Format-Number $workCount
            if ($workCount -gt 30000000) {
                Write-ColorOutput "$workFormatted (✅ Target reached: >30M)" "Green"
            } else {
                Write-ColorOutput "$workFormatted" "Gray"
            }
            
            Write-Host "  Release:   " -NoNewline
            $relFormatted = Format-Number $releaseCount
            if ($releaseCount -gt 5000000) {
                Write-ColorOutput "$relFormatted (✅ Target reached: >5M)" "Green"
            } else {
                Write-ColorOutput "$relFormatted" "Gray"
            }
            
            # Check if import is complete
            if ($recordingCount -gt 50000000 -and 
                $artistCount -gt 2000000 -and 
                $workCount -gt 30000000 -and 
                $containerStatus.Health -eq "healthy") {
                
                Write-ColorOutput "`n🎉 IMPORT TERMINÉ !" "Green"
                Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
                Write-ColorOutput "`nProchaines étapes:" "Cyan"
                Write-ColorOutput "  1. Créer le schéma KPI: . .\scripts\docker_helpers.ps1; Initialize-AllfeatKPI" "White"
                Write-ColorOutput "  2. Appliquer les vues:  . .\scripts\docker_helpers.ps1; Apply-KPIViews" "White"
                Write-ColorOutput "  3. Tester les vues:     . .\scripts\docker_helpers.ps1; Test-KPIViews" "White"
                Write-ColorOutput "`nOu utiliser le quick start:" "Cyan"
                Write-ColorOutput "  .\quick_start_docker.ps1 -SkipImport" "White"
                
                $importComplete = $true
            }
        } else {
            Write-ColorOutput "  ⏳ Tables principales pas encore créées..." "Gray"
            Write-ColorOutput "  (L'import est en cours de création des schémas/tables)" "Gray"
        }
        
        # Afficher les derniers logs d'import
        $importLogs = Get-ImportLogs
        if ($importLogs) {
            Write-ColorOutput "`nDerniers logs d'import:" "Gray"
            $importLogs | ForEach-Object {
                if ($_ -match "skipping|COPY|ERROR|FATAL") {
                    if ($_ -match "ERROR|FATAL") {
                        Write-ColorOutput "  $_" "Red"
                    } elseif ($_ -match "COPY") {
                        Write-ColorOutput "  $_" "Green"
                    } else {
                        Write-ColorOutput "  $_" "Gray"
                    }
                }
            }
        }
    } else {
        Write-ColorOutput "⏳ Not ready (téléchargement/import en cours)" "Yellow"
        Write-ColorOutput "`nTéléchargement en cours..." "Gray"
        Write-ColorOutput "Pour voir les logs détaillés: docker compose logs -f musicbrainz" "Gray"
    }
    
    if (-not $importComplete) {
        Write-Host "`nProchain check dans $Interval secondes..." -ForegroundColor Gray
        Start-Sleep -Seconds $Interval
    }
}

Write-ColorOutput "`n✅ Monitoring terminé." "Green"


