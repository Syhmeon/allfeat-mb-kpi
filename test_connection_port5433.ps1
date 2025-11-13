# Test de connexion PostgreSQL sur le port 5433
# Usage: .\test_connection_port5433.ps1

Write-Host "=== Test de connexion PostgreSQL (Port 5433) ===" -ForegroundColor Cyan
Write-Host ""

$host = "127.0.0.1"
$port = "5433"
$database = "musicbrainz_db"
$username = "musicbrainz"
$password = "musicbrainz"

$psqlPath = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

if (-not (Test-Path $psqlPath)) {
    Write-Host "❌ psql.exe non trouvé à: $psqlPath" -ForegroundColor Red
    exit 1
}

Write-Host "✓ psql.exe trouvé" -ForegroundColor Green
Write-Host ""

# Vérifier le conteneur Docker
Write-Host "Test 1: Vérification du conteneur Docker..." -ForegroundColor Yellow
$containerStatus = docker ps --filter "name=musicbrainz-db" --format "{{.Status}}"
if ($containerStatus) {
    Write-Host "✓ Conteneur actif: $containerStatus" -ForegroundColor Green
} else {
    Write-Host "❌ Conteneur musicbrainz-db non trouvé" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Vérifier le port mapping
Write-Host "Test 2: Vérification du port mapping..." -ForegroundColor Yellow
$portMapping = docker ps --filter "name=musicbrainz-db" --format "{{.Ports}}"
if ($portMapping -like "*5433*") {
    Write-Host "✓ Port mapping correct: $portMapping" -ForegroundColor Green
} else {
    Write-Host "❌ Port 5433 non trouvé dans le mapping" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test de connexion
Write-Host "Test 3: Connexion avec psql.exe (port 5433)..." -ForegroundColor Yellow
$env:PGPASSWORD = $password
$query = "SELECT 'Connexion réussie sur port 5433!' as status, current_user as user, current_database() as database;"

try {
    $result = & $psqlPath -h $host -p $port -U $username -d $database -c $query 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Connexion réussie!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Résultat:" -ForegroundColor Cyan
        $result | Select-Object -Last 10
        Write-Host ""
        Write-Host "✅ Tous les tests sont passés!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Vous pouvez maintenant configurer DBeaver avec:" -ForegroundColor Yellow
        Write-Host "  Host: 127.0.0.1" -ForegroundColor White
        Write-Host "  Port: 5433" -ForegroundColor White
        Write-Host "  Database: musicbrainz_db" -ForegroundColor White
        Write-Host "  Username: musicbrainz" -ForegroundColor White
        Write-Host "  Password: musicbrainz" -ForegroundColor White
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

