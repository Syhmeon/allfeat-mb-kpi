# Script d'application des vues KPI Allfeat pour Windows PowerShell
# Usage: .\scripts\apply_views.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$SQL_DIR = ".\sql"
)

Write-Host "🚀 Application des vues KPI Allfeat..." -ForegroundColor Green

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

# Vérifier que le schéma existe
Write-Host "🗄️  Vérification du schéma allfeat_kpi..." -ForegroundColor Yellow
try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM allfeat_kpi.metadata LIMIT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Schéma introuvable"
    }
} catch {
    Write-Host "❌ Le schéma allfeat_kpi n'existe pas. Exécutez d'abord: psql -f sql/init/00_schema.sql" -ForegroundColor Red
    exit 1
}

# Appliquer les vues dans l'ordre
Write-Host "📊 Application des vues KPI..." -ForegroundColor Yellow

$views = @(
    "10_kpi_isrc_coverage.sql",
    "20_kpi_iswc_coverage.sql", 
    "30_party_missing_ids_artist.sql",
    "40_dup_isrc_candidates.sql",
    "50_rec_on_release_without_work.sql",
    "51_work_without_recording.sql",
    "60_confidence_artist.sql",
    "61_confidence_work.sql",
    "62_confidence_recording.sql",
    "63_confidence_release.sql"
)

foreach ($view in $views) {
    $viewPath = Join-Path $SQL_DIR "views" $view
    if (Test-Path $viewPath) {
        Write-Host "  - Application de $view..." -ForegroundColor Cyan
        try {
            psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $viewPath
            if ($LASTEXITCODE -ne 0) {
                throw "Erreur lors de l'application de $view"
            }
        } catch {
            Write-Host "❌ Erreur lors de l'application de $view" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "⚠️  Fichier $viewPath introuvable" -ForegroundColor Yellow
    }
}

# Mettre à jour les métadonnées
Write-Host "📝 Mise à jour des métadonnées..." -ForegroundColor Yellow
$updateQuery = @"
UPDATE allfeat_kpi.metadata 
SET value = NOW()::TEXT, updated_at = NOW() 
WHERE key = 'views_applied_at';

INSERT INTO allfeat_kpi.metadata (key, value) 
VALUES ('views_applied_at', NOW()::TEXT)
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = NOW();
"@

try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c $updateQuery
} catch {
    Write-Host "⚠️  Erreur lors de la mise à jour des métadonnées" -ForegroundColor Yellow
}

# Lister les vues créées
Write-Host "📋 Vues KPI créées:" -ForegroundColor Green
try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c @"
SELECT schemaname, viewname 
FROM pg_views 
WHERE schemaname = 'allfeat_kpi' 
ORDER BY viewname;
"@
} catch {
    Write-Host "⚠️  Impossible de lister les vues" -ForegroundColor Yellow
}

Write-Host "✅ Vues KPI appliquées avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant tester avec: psql -f scripts/smoke_tests.sql" -ForegroundColor Cyan
