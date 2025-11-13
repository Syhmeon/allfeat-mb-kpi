# Script de test de connexion PostgreSQL depuis Windows
# Usage: .\test_connection.ps1

Write-Host "=== Test de connexion PostgreSQL MusicBrainz ===" -ForegroundColor Cyan
Write-Host ""

# Paramètres de connexion
$host = "127.0.0.1"
$port = "5432"
$database = "musicbrainz_db"
$username = "musicbrainz"
$password = "musicbrainz"

# Chemin psql.exe (PostgreSQL 18)
$psqlPath = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

# Vérifier si psql.exe existe
if (-not (Test-Path $psqlPath)) {
    Write-Host "❌ psql.exe non trouvé à: $psqlPath" -ForegroundColor Red
    Write-Host "Veuillez installer PostgreSQL ou ajuster le chemin." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ psql.exe trouvé" -ForegroundColor Green
Write-Host ""

# Test 1: Vérifier que le conteneur Docker est actif
Write-Host "Test 1: Vérification du conteneur Docker..." -ForegroundColor Yellow
$containerStatus = docker ps --filter "name=musicbrainz-db" --format "{{.Status}}"
if ($containerStatus) {
    Write-Host "✓ Conteneur actif: $containerStatus" -ForegroundColor Green
} else {
    Write-Host "❌ Conteneur musicbrainz-db non trouvé ou arrêté" -ForegroundColor Red
    Write-Host "Démarrez le conteneur avec: docker compose up -d db" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 2: Test de connexion avec psql
Write-Host "Test 2: Connexion avec psql.exe..." -ForegroundColor Yellow
$env:PGPASSWORD = $password
$query = "SELECT 'Connexion réussie!' as status, current_user as user, current_database() as database, version() as version;"

try {
    $result = & $psqlPath -h $host -p $port -U $username -d $database -c $query 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Connexion réussie!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Résultat:" -ForegroundColor Cyan
        $result | Select-Object -Last 10
        Write-Host ""
        Write-Host "✅ Tous les tests sont passés!" -ForegroundColor Green
    } else {
        Write-Host "❌ Échec de la connexion" -ForegroundColor Red
        Write-Host "Erreur:" -ForegroundColor Red
        $result
        exit 1
    }
} catch {
    Write-Host "❌ Erreur lors de la connexion: $_" -ForegroundColor Red
    exit 1
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Test terminé ===" -ForegroundColor Cyan

