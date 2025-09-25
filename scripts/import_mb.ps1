# Script d'import MusicBrainz pour Windows PowerShell
# Usage: .\scripts\import_mb.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$DUMPS_DIR = ".\dumps"
)

Write-Host "🚀 Début de l'import MusicBrainz..." -ForegroundColor Green

# Vérifier que PostgreSQL est accessible
Write-Host "📡 Vérification de la connexion PostgreSQL..." -ForegroundColor Yellow
try {
    $env:PGPASSWORD = "musicbrainz"
    $result = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Connexion échouée"
    }
} catch {
    Write-Host "❌ PostgreSQL n'est pas accessible. Vérifiez que Docker est démarré." -ForegroundColor Red
    exit 1
}

# Vérifier la présence des dumps
Write-Host "📁 Vérification des fichiers dump..." -ForegroundColor Yellow
if (-not (Test-Path $DUMPS_DIR)) {
    Write-Host "❌ Répertoire $DUMPS_DIR introuvable" -ForegroundColor Red
    exit 1
}

# Trouver les fichiers dump
$dumpFiles = Get-ChildItem -Path $DUMPS_DIR -Filter "*.dump" -Recurse
if ($dumpFiles.Count -eq 0) {
    Write-Host "❌ Aucun fichier .dump trouvé dans $DUMPS_DIR" -ForegroundColor Red
    Write-Host "💡 Téléchargez le dump depuis https://musicbrainz.org/doc/MusicBrainz_Database/Download" -ForegroundColor Cyan
    exit 1
}

$DUMP_FILE = $dumpFiles[0].FullName
Write-Host "📦 Fichier dump trouvé: $DUMP_FILE" -ForegroundColor Green

# Créer la base de données si elle n'existe pas
Write-Host "🗄️  Création de la base de données..." -ForegroundColor Yellow
try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;" 2>$null
} catch {
    Write-Host "Base de données existe déjà" -ForegroundColor Gray
}

# Restaurer le dump
Write-Host "📥 Restauration du dump MusicBrainz (cela peut prendre plusieurs heures)..." -ForegroundColor Yellow
Write-Host "⏳ Cette étape peut prendre plusieurs heures selon la taille du dump..." -ForegroundColor Cyan

try {
    pg_restore -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v --no-owner --no-privileges $DUMP_FILE
    if ($LASTEXITCODE -ne 0) {
        throw "Restauration échouée"
    }
} catch {
    Write-Host "❌ Erreur lors de la restauration du dump" -ForegroundColor Red
    exit 1
}

# Créer les extensions nécessaires
Write-Host "🔧 Installation des extensions PostgreSQL..." -ForegroundColor Yellow
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c @"
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
"@

# Analyser les statistiques
Write-Host "📊 Mise à jour des statistiques..." -ForegroundColor Yellow
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "ANALYZE;"

Write-Host "✅ Import MusicBrainz terminé avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant créer les vues KPI avec: .\scripts\apply_views.ps1" -ForegroundColor Cyan
