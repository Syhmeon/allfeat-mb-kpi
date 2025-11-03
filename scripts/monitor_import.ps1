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
    $result = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -t -c "SELECT 1;" 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-TableCounts {
    if (-not (Get-PostgreSQLStatus)) {
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
    
    $result = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -t -c $query 2>$null
    return $result
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
        
        # Get table counts
        Write-ColorOutput "`nTable Counts:" "Yellow"
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
        }
    } else {
        Write-ColorOutput "⏳ Not ready (téléchargement/import en cours)" "Yellow"
        Write-ColorOutput "`nTéléchargement en cours..." "Gray"
        Write-ColorOutput "Pour voir les logs détaillés: docker logs -f musicbrainz-db" "Gray"
    }
    
    if (-not $importComplete) {
        Write-Host "`nProchain check dans $Interval secondes..." -ForegroundColor Gray
        Start-Sleep -Seconds $Interval
    }
}

Write-ColorOutput "`n✅ Monitoring terminé." "Green"


