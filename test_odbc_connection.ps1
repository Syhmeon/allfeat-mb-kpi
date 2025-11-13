# Script de test de connexion ODBC
# Usage: .\test_odbc_connection.ps1

Write-Host "=== Test de connexion ODBC PostgreSQL ===" -ForegroundColor Cyan
Write-Host ""

# Vérifier que le driver ODBC est disponible
Write-Host "Test 1: Vérification du driver ODBC..." -ForegroundColor Yellow
try {
    $drivers = [System.Data.Odbc.OdbcDataReader]::GetDataSources()
    $postgresDriver = $drivers | Where-Object { $_.Name -like "*PostgreSQL*" }
    
    if ($postgresDriver) {
        Write-Host "✓ Driver PostgreSQL trouvé: $($postgresDriver.Name)" -ForegroundColor Green
    } else {
        Write-Host "❌ Driver PostgreSQL non trouvé" -ForegroundColor Red
        Write-Host "Installez le driver depuis: https://www.postgresql.org/ftp/odbc/versions/msi/" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "⚠️  Impossible de vérifier les drivers (normal si ODBC n'est pas encore configuré)" -ForegroundColor Yellow
}
Write-Host ""

# Vérifier le conteneur Docker
Write-Host "Test 2: Vérification du conteneur Docker..." -ForegroundColor Yellow
$containerStatus = docker ps --filter "name=musicbrainz-db" --format "{{.Status}}"
if ($containerStatus) {
    Write-Host "✓ Conteneur actif: $containerStatus" -ForegroundColor Green
} else {
    Write-Host "❌ Conteneur musicbrainz-db non trouvé" -ForegroundColor Red
    Write-Host "Démarrez avec: docker compose up -d db" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Vérifier le port
Write-Host "Test 3: Vérification du port mapping..." -ForegroundColor Yellow
$portMapping = docker ps --filter "name=musicbrainz-db" --format "{{.Ports}}"
if ($portMapping -like "*5433*") {
    Write-Host "✓ Port mapping correct: $portMapping" -ForegroundColor Green
} else {
    Write-Host "❌ Port 5433 non trouvé" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test de connexion ODBC
Write-Host "Test 4: Connexion ODBC..." -ForegroundColor Yellow

$connectionString = @"
Driver={PostgreSQL Unicode};Server=127.0.0.1;Port=5433;Database=musicbrainz_db;Uid=musicbrainz;Pwd=musicbrainz;SSL Mode=disable;
"@

try {
    Add-Type -AssemblyName System.Data
    
    $connection = New-Object System.Data.Odbc.OdbcConnection($connectionString)
    $connection.Open()
    
    Write-Host "✓ Connexion ODBC réussie!" -ForegroundColor Green
    Write-Host ""
    
    # Test de requête
    $query = "SELECT 'Connexion ODBC OK!' as status, current_user as user, current_database() as database, version() as version;"
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()
    
    Write-Host "Résultat de la requête:" -ForegroundColor Cyan
    while ($reader.Read()) {
        Write-Host "  Status: $($reader['status'])" -ForegroundColor White
        Write-Host "  User: $($reader['user'])" -ForegroundColor White
        Write-Host "  Database: $($reader['database'])" -ForegroundColor White
        Write-Host "  Version: $($reader['version'])" -ForegroundColor White
    }
    
    $reader.Close()
    $connection.Close()
    
    Write-Host ""
    Write-Host "✅ Tous les tests sont passés!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration ODBC recommandée:" -ForegroundColor Yellow
    Write-Host "  Data Source: Allfeat KPI - MusicBrainz" -ForegroundColor White
    Write-Host "  Server: 127.0.0.1" -ForegroundColor White
    Write-Host "  Port: 5433" -ForegroundColor White
    Write-Host "  Database: musicbrainz_db" -ForegroundColor White
    Write-Host "  Username: musicbrainz" -ForegroundColor White
    Write-Host "  Password: musicbrainz" -ForegroundColor White
    
} catch {
    Write-Host "❌ Erreur de connexion ODBC" -ForegroundColor Red
    Write-Host "Détails: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Vérifiez:" -ForegroundColor Yellow
    Write-Host "  1. Que le driver ODBC PostgreSQL est installé" -ForegroundColor White
    Write-Host "  2. Que le conteneur Docker est démarré" -ForegroundColor White
    Write-Host "  3. Que le port 5433 est accessible" -ForegroundColor White
    Write-Host "  4. Les identifiants: musicbrainz / musicbrainz" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "=== Test terminé ===" -ForegroundColor Cyan

