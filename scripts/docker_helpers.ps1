# MusicBrainz Docker Helper Commands for Windows
# Version: 1.0
# Date: 2025-10-15
# Usage: Import this file to access helper functions

# Color output helper
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# ============================================================================
# MONITORING & LOGS
# ============================================================================

function Show-MBLogs {
    <#
    .SYNOPSIS
    Monitor MusicBrainz container logs in real-time
    
    .DESCRIPTION
    Follows the Docker logs for the musicbrainz-db container
    
    .EXAMPLE
    Show-MBLogs
    #>
    Write-ColorOutput "📊 Monitoring MusicBrainz container logs (Ctrl+C to exit)..." "Cyan"
    docker logs -f musicbrainz-db
}

function Get-MBStatus {
    <#
    .SYNOPSIS
    Check MusicBrainz container health and database status
    
    .DESCRIPTION
    Displays container status, database connection, and table counts
    
    .EXAMPLE
    Get-MBStatus
    #>
    Write-ColorOutput "`n🔍 MusicBrainz Docker Status" "Green"
    Write-ColorOutput "============================" "Green"
    
    # Container status
    Write-ColorOutput "`n📦 Container Status:" "Yellow"
    docker ps -a --filter "name=musicbrainz-db" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Database connection test
    Write-ColorOutput "`n🔌 Database Connection:" "Yellow"
    $dbTest = docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c "SELECT version();" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ PostgreSQL is accessible" "Green"
    } else {
        Write-ColorOutput "❌ PostgreSQL not accessible" "Red"
        return
    }
    
    # Table counts
    Write-ColorOutput "`n📊 Database Statistics:" "Yellow"
    docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c @"
SELECT 
    schemaname,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname IN ('musicbrainz', 'allfeat_kpi')
GROUP BY schemaname
ORDER BY schemaname;
"@
    
    # Sample table row counts
    Write-ColorOutput "`n📈 Sample Table Counts:" "Yellow"
    docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c @"
SELECT 
    'recording' as table_name,
    COUNT(*) as row_count
FROM musicbrainz.recording
UNION ALL
SELECT 
    'artist' as table_name,
    COUNT(*) as row_count
FROM musicbrainz.artist
UNION ALL
SELECT 
    'work' as table_name,
    COUNT(*) as row_count
FROM musicbrainz.work
UNION ALL
SELECT 
    'release' as table_name,
    COUNT(*) as row_count
FROM musicbrainz.release;
"@
}


# ============================================================================
# DATABASE ACCESS
# ============================================================================

function Enter-MBShell {
    <#
    .SYNOPSIS
    Open interactive psql shell in the MusicBrainz database
    
    .DESCRIPTION
    Enters the PostgreSQL shell for manual queries
    
    .EXAMPLE
    Enter-MBShell
    #>
    Write-ColorOutput "🐚 Entering PostgreSQL shell (type \q to exit)..." "Cyan"
    docker exec -it musicbrainz-db psql -U musicbrainz -d musicbrainz_db
}

function Invoke-MBQuery {
    <#
    .SYNOPSIS
    Execute SQL query on MusicBrainz database
    
    .DESCRIPTION
    Runs a SQL query and displays results
    
    .PARAMETER Query
    SQL query to execute
    
    .EXAMPLE
    Invoke-MBQuery "SELECT COUNT(*) FROM musicbrainz.recording;"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query
    )
    
    docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c $Query
}

# ============================================================================
# ALLFEAT KPI OPERATIONS
# ============================================================================

function Initialize-AllfeatKPI {
    <#
    .SYNOPSIS
    Initialize Allfeat KPI schema
    
    .DESCRIPTION
    Creates the allfeat_kpi schema and base objects
    
    .EXAMPLE
    Initialize-AllfeatKPI
    #>
    Write-ColorOutput "🔧 Initializing Allfeat KPI schema..." "Cyan"
    
    if (Test-Path "sql\init\00_schema.sql") {
        Get-Content "sql\init\00_schema.sql" | docker exec -i musicbrainz-db psql -U musicbrainz -d musicbrainz_db
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Schema allfeat_kpi created successfully" "Green"
        } else {
            Write-ColorOutput "❌ Failed to create schema" "Red"
        }
    } else {
        Write-ColorOutput "❌ File sql/init/00_schema.sql not found" "Red"
    }
}

function Apply-KPIViews {
    <#
    .SYNOPSIS
    Apply all KPI views using apply_views.ps1
    
    .DESCRIPTION
    Runs the apply_views.ps1 script to create all 10 KPI views
    
    .EXAMPLE
    Apply-KPIViews
    #>
    Write-ColorOutput "📊 Applying KPI views..." "Cyan"
    
    if (Test-Path "scripts\apply_views.ps1") {
        & ".\scripts\apply_views.ps1" -DB_CONTAINER "musicbrainz-db" -DB_NAME "musicbrainz_db" -DB_USER "musicbrainz"
    } else {
        Write-ColorOutput "❌ File scripts/apply_views.ps1 not found" "Red"
    }
}

function Test-KPIViews {
    <#
    .SYNOPSIS
    Run all KPI tests
    
    .DESCRIPTION
    Executes tests.sql to validate KPI views
    
    .EXAMPLE
    Test-KPIViews
    #>
    Write-ColorOutput "🧪 Running KPI tests..." "Cyan"
    
    if (Test-Path "scripts\tests.sql") {
        Get-Content "scripts\tests.sql" | docker exec -i musicbrainz-db psql -U musicbrainz -d musicbrainz_db
    } else {
        Write-ColorOutput "❌ File scripts/tests.sql not found" "Red"
    }
}

# ============================================================================
# CONTAINER MANAGEMENT
# ============================================================================

function Start-MBDocker {
    <#
    .SYNOPSIS
    Start MusicBrainz Docker container
    
    .DESCRIPTION
    Starts the container and waits for it to be healthy
    
    .EXAMPLE
    Start-MBDocker
    #>
    Write-ColorOutput "🚀 Starting MusicBrainz Docker container..." "Cyan"
    docker compose up -d
    
    Write-ColorOutput "⏳ Waiting for container to be healthy..." "Yellow"
    Start-Sleep -Seconds 10
    
    Get-MBStatus
}

function Stop-MBDocker {
    <#
    .SYNOPSIS
    Stop MusicBrainz Docker container
    
    .DESCRIPTION
    Stops the container gracefully
    
    .EXAMPLE
    Stop-MBDocker
    #>
    Write-ColorOutput "🛑 Stopping MusicBrainz Docker container..." "Cyan"
    docker compose down
    Write-ColorOutput "✅ Container stopped" "Green"
}

function Restart-MBDocker {
    <#
    .SYNOPSIS
    Restart MusicBrainz Docker container
    
    .DESCRIPTION
    Restarts the container
    
    .EXAMPLE
    Restart-MBDocker
    #>
    Write-ColorOutput "🔄 Restarting MusicBrainz Docker container..." "Cyan"
    docker compose restart
    Start-Sleep -Seconds 10
    Get-MBStatus
}

# ============================================================================
# BACKUP & MAINTENANCE
# ============================================================================

function Backup-MBDatabase {
    <#
    .SYNOPSIS
    Create a backup of MusicBrainz database
    
    .DESCRIPTION
    Exports the database to a SQL dump file
    
    .PARAMETER OutputPath
    Path to save the backup file
    
    .EXAMPLE
    Backup-MBDatabase -OutputPath "backup_musicbrainz.sql"
    #>
    param(
        [string]$OutputPath = "backup_musicbrainz_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
    )
    
    Write-ColorOutput "💾 Creating database backup..." "Cyan"
    docker exec musicbrainz-db pg_dump -U musicbrainz musicbrainz > $OutputPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Backup created: $OutputPath" "Green"
    } else {
        Write-ColorOutput "❌ Backup failed" "Red"
    }
}

function Backup-KPISchema {
    <#
    .SYNOPSIS
    Create a backup of allfeat_kpi schema only
    
    .DESCRIPTION
    Exports only the KPI schema to a SQL dump file
    
    .PARAMETER OutputPath
    Path to save the backup file
    
    .EXAMPLE
    Backup-KPISchema -OutputPath "backup_kpi.sql"
    #>
    param(
        [string]$OutputPath = "backup_kpi_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
    )
    
    Write-ColorOutput "💾 Creating KPI schema backup..." "Cyan"
    docker exec musicbrainz-db pg_dump -U musicbrainz -n allfeat_kpi musicbrainz > $OutputPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ KPI backup created: $OutputPath" "Green"
    } else {
        Write-ColorOutput "❌ Backup failed" "Red"
    }
}

# ============================================================================
# HELP
# ============================================================================

function Show-MBHelp {
    <#
    .SYNOPSIS
    Display available MusicBrainz helper commands
    
    .DESCRIPTION
    Shows all available functions and their descriptions
    
    .EXAMPLE
    Show-MBHelp
    #>
    
    Write-ColorOutput "`n📚 MusicBrainz Docker Helper Commands" "Green"
    Write-ColorOutput "=====================================" "Green"
    
    Write-ColorOutput "`n🔍 Monitoring & Logs:" "Yellow"
    Write-ColorOutput "  Show-MBLogs              - Monitor container logs in real-time" "White"
    Write-ColorOutput "  Get-MBStatus             - Check container and database status" "White"
    
    Write-ColorOutput "`n🐚 Database Access:" "Yellow"
    Write-ColorOutput "  Enter-MBShell            - Open interactive psql shell" "White"
    Write-ColorOutput "  Invoke-MBQuery 'SQL'     - Execute a SQL query" "White"
    
    Write-ColorOutput "`n📊 Allfeat KPI Operations:" "Yellow"
    Write-ColorOutput "  Initialize-AllfeatKPI    - Create allfeat_kpi schema" "White"
    Write-ColorOutput "  Apply-KPIViews           - Apply all 10 KPI views" "White"
    Write-ColorOutput "  Test-KPIViews            - Run KPI validation tests" "White"
    
    Write-ColorOutput "`n🐳 Container Management:" "Yellow"
    Write-ColorOutput "  Start-MBDocker           - Start MusicBrainz container" "White"
    Write-ColorOutput "  Stop-MBDocker            - Stop container" "White"
    Write-ColorOutput "  Restart-MBDocker         - Restart container" "White"
    
    Write-ColorOutput "`n💾 Backup & Maintenance:" "Yellow"
    Write-ColorOutput "  Backup-MBDatabase        - Backup full database" "White"
    Write-ColorOutput "  Backup-KPISchema         - Backup KPI schema only" "White"
    
    Write-ColorOutput "`n💡 Quick Start:" "Cyan"
    Write-ColorOutput "  1. Start-MBDocker" "White"
    Write-ColorOutput "  2. .\scripts\import_musicbrainz_official.ps1 (import complet)" "White"
    Write-ColorOutput "  3. Initialize-AllfeatKPI" "White"
    Write-ColorOutput "  4. Apply-KPIViews" "White"
    Write-ColorOutput "  5. Test-KPIViews" "White"
    Write-ColorOutput ""
}

# Display help on import
Show-MBHelp

