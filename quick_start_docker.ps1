# Quick Start Script for MusicBrainz Docker + Allfeat KPI
# Version: 1.0
# Date: 2025-10-15
# Purpose: Automated setup of MusicBrainz Docker with KPI views
#
# Usage: .\quick_start_docker.ps1 [-SkipImport] [-SkipTests]

param(
    [switch]$SkipImport,
    [switch]$SkipTests
)

# Import helper functions
. .\scripts\docker_helpers.ps1

Write-ColorOutput "`n🚀 MusicBrainz Docker + Allfeat KPI - Quick Start" "Green"
Write-ColorOutput "==================================================" "Green"

# Step 1: Verify prerequisites
Write-ColorOutput "`n📋 Step 1/6: Verifying prerequisites..." "Cyan"

# Check Docker
Write-ColorOutput "  - Checking Docker Desktop..." "Yellow"
$dockerVersion = docker --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Docker Desktop not found. Please install Docker Desktop for Windows." "Red"
    exit 1
}
Write-ColorOutput "  ✅ Docker Desktop: $dockerVersion" "Green"

# Check Docker Compose
Write-ColorOutput "  - Checking Docker Compose..." "Yellow"
$composeVersion = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Docker Compose not found." "Red"
    exit 1
}
Write-ColorOutput "  ✅ Docker Compose: $composeVersion" "Green"

# Check disk space
Write-ColorOutput "  - Checking disk space on E:..." "Yellow"
$drive = Get-PSDrive E -ErrorAction SilentlyContinue
if ($drive) {
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    Write-ColorOutput "  ✅ Free space: $freeSpaceGB GB" "Green"
    if ($freeSpaceGB -lt 100) {
        Write-ColorOutput "  ⚠️  Warning: Less than 100 GB free. Import may fail." "Yellow"
    }
} else {
    Write-ColorOutput "  ⚠️  Drive E: not found. Using default volume." "Yellow"
}

# Step 2: Start MusicBrainz Docker container
if (-not $SkipImport) {
    Write-ColorOutput "`n📦 Step 2/6: Starting MusicBrainz Docker container..." "Cyan"
    Write-ColorOutput "  This will download the MusicBrainz data and import it." "Yellow"
    Write-ColorOutput "  Expected duration: 2-6 hours depending on hardware." "Yellow"
    
    Write-ColorOutput "`n  Do you want to start the import now? (Y/N)" "Yellow"
    $response = Read-Host
    
    if ($response -eq "Y" -or $response -eq "y") {
        Start-MBDocker
        
        Write-ColorOutput "`n  ⏳ Import started. Monitor progress with:" "Cyan"
        Write-ColorOutput "     Show-MBLogs" "White"
        Write-ColorOutput "     Get-MBImportProgress" "White"
        
        Write-ColorOutput "`n  ⏰ This script will now wait for import to complete..." "Yellow"
        Write-ColorOutput "     (You can press Ctrl+C to exit and resume later)" "Yellow"
        
        # Wait for import to complete (check every 5 minutes)
        $importComplete = $false
        $checkCount = 0
        while (-not $importComplete) {
            Start-Sleep -Seconds 300  # 5 minutes
            $checkCount++
            
            Write-ColorOutput "`n  ⏳ Import check #$checkCount (every 5 min)..." "Cyan"
            
            # Check if recording table has data
            $recordingCount = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -t -c "SELECT COUNT(*) FROM musicbrainz.recording;" 2>&1
            
            if ($LASTEXITCODE -eq 0 -and $recordingCount -match '\d+') {
                $count = [int]($recordingCount -replace '\D','')
                Write-ColorOutput "  📊 Recording count: $count" "Yellow"
                
                # Import considered complete if > 50 million recordings
                if ($count -gt 50000000) {
                    Write-ColorOutput "  ✅ Import appears complete!" "Green"
                    $importComplete = $true
                }
            }
        }
    } else {
        Write-ColorOutput "  ⏭️  Import skipped. Start manually with: Start-MBDocker" "Yellow"
        $SkipImport = $true
    }
} else {
    Write-ColorOutput "`n📦 Step 2/6: Skipped (import already done)" "Yellow"
}

# Step 3: Verify MusicBrainz database
Write-ColorOutput "`n🔍 Step 3/6: Verifying MusicBrainz database..." "Cyan"
Get-MBStatus

# Check if database has data
$recordingCount = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -t -c "SELECT COUNT(*) FROM musicbrainz.recording;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Database not accessible or not ready." "Red"
    Write-ColorOutput "💡 Wait for import to complete and run this script again." "Cyan"
    exit 1
}

$count = [int]($recordingCount -replace '\D','')
if ($count -lt 1000000) {
    Write-ColorOutput "⚠️  Recording count is low ($count). Import may not be complete." "Yellow"
    Write-ColorOutput "💡 Expected: > 50 million recordings" "Cyan"
}

# Step 4: Initialize Allfeat KPI schema
Write-ColorOutput "`n🔧 Step 4/6: Initializing Allfeat KPI schema..." "Cyan"
Initialize-AllfeatKPI

# Step 5: Apply KPI views
Write-ColorOutput "`n📊 Step 5/6: Applying KPI views..." "Cyan"
Apply-KPIViews

# Step 6: Run tests
if (-not $SkipTests) {
    Write-ColorOutput "`n🧪 Step 6/6: Running KPI tests..." "Cyan"
    Test-KPIViews
} else {
    Write-ColorOutput "`n🧪 Step 6/6: Skipped" "Yellow"
}

# Final summary
Write-ColorOutput "`n✅ Quick Start Complete!" "Green"
Write-ColorOutput "========================" "Green"

Write-ColorOutput "`n📋 Next steps:" "Cyan"
Write-ColorOutput "  1. Check KPI views: Enter-MBShell" "White"
Write-ColorOutput "  2. Connect Excel/ODBC: localhost:5432, user: musicbrainz, db: musicbrainz" "White"
Write-ColorOutput "  3. Query KPI data: SELECT * FROM allfeat_kpi.kpi_isrc_coverage;" "White"

Write-ColorOutput "`n💡 Useful commands:" "Cyan"
Write-ColorOutput "  Show-MBHelp           - Show all available commands" "White"
Write-ColorOutput "  Get-MBStatus          - Check database status" "White"
Write-ColorOutput "  Enter-MBShell         - Open PostgreSQL shell" "White"

Write-ColorOutput "`n📊 Database connection details:" "Cyan"
Write-ColorOutput "  Host:     localhost" "White"
Write-ColorOutput "  Port:     5432" "White"
Write-ColorOutput "  Database: musicbrainz" "White"
Write-ColorOutput "  User:     musicbrainz" "White"
Write-ColorOutput "  Password: musicbrainz" "White"
Write-ColorOutput "  Schema:   allfeat_kpi" "White"
Write-ColorOutput ""

