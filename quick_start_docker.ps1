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
Write-ColorOutput "`n📋 Step 1/7: Verifying prerequisites..." "Cyan"

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

# Step 2: Start MusicBrainz Docker containers
Write-ColorOutput "`n📦 Step 2/7: Starting MusicBrainz Docker containers..." "Cyan"
Start-MBDocker

# Step 2b: Migrate dumps if necessary
Write-ColorOutput "`n🔁 Step 2b/7: Checking for legacy dumps migration..." "Cyan"
if (Test-Path "scripts\migrate_dbdump.ps1") {
    & ".\scripts\migrate_dbdump.ps1"
    # Continue même si la migration n'était pas nécessaire (exit code 0)
} else {
    Write-ColorOutput "  ⚠️  Script migrate_dbdump.ps1 non trouvé - migration ignorée" "Yellow"
}

# Step 3: Run official MusicBrainz import
if (-not $SkipImport) {
    Write-ColorOutput "`n📥 Step 3/7: Running official MusicBrainz import..." "Cyan"
    Write-ColorOutput "  This will import the complete MusicBrainz database using createdb.sh." "Yellow"
    Write-ColorOutput "  Expected duration: 3-6 hours depending on hardware." "Yellow"
    
    if (Test-Path "scripts\import_musicbrainz_official.ps1") {
        & ".\scripts\import_musicbrainz_official.ps1"
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Import failed. Check the logs above." "Red"
            exit 1
        }
    } else {
        Write-ColorOutput "❌ Script import_musicbrainz_official.ps1 not found" "Red"
        exit 1
    }
} else {
    Write-ColorOutput "`n📥 Step 3/7: Skipped (import already done)" "Yellow"
}

# Step 4: Verify MusicBrainz database
Write-ColorOutput "`n🔍 Step 4/7: Verifying MusicBrainz database..." "Cyan"
Get-MBStatus

# Check if database has data
$recordingCount = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -t -c "SELECT COUNT(*) FROM musicbrainz.recording;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Database not accessible or not ready." "Red"
    Write-ColorOutput "💡 Wait for import to complete and run this script again." "Cyan"
    exit 1
}

$count = [int]($recordingCount -replace '\D','')
if ($count -eq 0) {
    Write-ColorOutput "⚠️  No recordings found. Import may have failed." "Yellow"
    Write-ColorOutput "💡 Run import_musicbrainz_official.ps1 manually to troubleshoot." "Cyan"
}

# Step 5: Initialize Allfeat KPI schema
Write-ColorOutput "`n🔧 Step 5/7: Initializing Allfeat KPI schema..." "Cyan"
Initialize-AllfeatKPI

# Step 6: Apply KPI views
Write-ColorOutput "`n📊 Step 6/7: Applying KPI views..." "Cyan"
Apply-KPIViews

# Step 7: Run tests
if (-not $SkipTests) {
    Write-ColorOutput "`n🧪 Step 7/7: Running KPI tests..." "Cyan"
    Test-KPIViews
} else {
    Write-ColorOutput "`n🧪 Step 7/7: Skipped" "Yellow"
}

# Final summary
Write-ColorOutput "`n✅ Quick Start Complete!" "Green"
Write-ColorOutput "========================" "Green"

Write-ColorOutput "`n📋 Next steps:" "Cyan"
Write-ColorOutput "  1. Check KPI views: Enter-MBShell" "White"
Write-ColorOutput "  2. Connect Excel/ODBC: localhost:5432, user: musicbrainz, db: musicbrainz_db" "White"
Write-ColorOutput "  3. Query KPI data: SELECT * FROM allfeat_kpi.kpi_isrc_coverage;" "White"

Write-ColorOutput "`n💡 Useful commands:" "Cyan"
Write-ColorOutput "  Show-MBHelp           - Show all available commands" "White"
Write-ColorOutput "  Get-MBStatus          - Check database status" "White"
Write-ColorOutput "  Enter-MBShell        - Open PostgreSQL shell" "White"
Write-ColorOutput "  .\scripts\check_import_status.ps1 - Quick data count check" "White"

Write-ColorOutput "`n📊 Database connection details:" "Cyan"
Write-ColorOutput "  Host:     localhost" "White"
Write-ColorOutput "  Port:     5432" "White"
Write-ColorOutput "  Database: musicbrainz_db" "White"
Write-ColorOutput "  User:     musicbrainz" "White"
Write-ColorOutput "  Password: musicbrainz" "White"
Write-ColorOutput "  Schema:   allfeat_kpi" "White"
Write-ColorOutput ""

