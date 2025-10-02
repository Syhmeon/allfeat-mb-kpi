# Script de réinitialisation de la base MusicBrainz (Windows PowerShell via Docker)
# Usage: .\scripts\reset_mb.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$CONTAINER_NAME = "musicbrainz-postgres"
)

Write-Host "🚀 Réinitialisation de la base MusicBrainz..." -ForegroundColor Green

# Vérifier que le conteneur est en cours d'exécution
Write-Host "🐳 Vérification du conteneur $CONTAINER_NAME..." -ForegroundColor Yellow
try {
    $containerStatus = docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}"
    if ([string]::IsNullOrEmpty($containerStatus)) {
        Write-Host "❌ Le conteneur $CONTAINER_NAME n'est pas en cours d'exécution." -ForegroundColor Red
        Write-Host "💡 Démarrez d'abord le conteneur avec: docker-compose up -d" -ForegroundColor Cyan
        exit 1
    }
    Write-Host "✅ Conteneur $CONTAINER_NAME trouvé: $containerStatus" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors de la vérification du conteneur Docker." -ForegroundColor Red
    Write-Host "💡 Vérifiez que Docker Desktop est démarré." -ForegroundColor Cyan
    exit 1
}

# Vérifier que PostgreSQL dans le conteneur est accessible
Write-Host "📡 Vérification de la connexion PostgreSQL dans le conteneur..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d postgres -c "SELECT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Connexion échouée"
    }
    Write-Host "✅ PostgreSQL accessible dans le conteneur" -ForegroundColor Green
} catch {
    Write-Host "❌ PostgreSQL n'est pas accessible dans le conteneur." -ForegroundColor Red
    Write-Host "💡 Attendez que PostgreSQL soit complètement démarré dans le conteneur." -ForegroundColor Cyan
    exit 1
}

# Étape 1: Supprimer la base de données si elle existe
Write-Host "🗑️  Suppression de la base de données $DB_NAME..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Base de données $DB_NAME supprimée avec succès" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Avertissement lors de la suppression: $result" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Erreur lors de la suppression de la base de données: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Étape 2: Recréer la base de données
Write-Host "🆕 Création de la base de données $DB_NAME..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Base de données $DB_NAME créée avec succès" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors de la création de la base de données: $result" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Exception lors de la création de la base de données: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Étape 3: Créer la collation ICU musicbrainz
Write-Host "🔤 Création de la collation ICU musicbrainz..." -ForegroundColor Yellow
try {
    $collationQuery = "CREATE COLLATION IF NOT EXISTS musicbrainz (provider = icu, locale = 'und-u-ks-level2', deterministic = false);"
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c $collationQuery 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Collation ICU musicbrainz créée avec succès" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Avertissement lors de la création de la collation: $result" -ForegroundColor Yellow
        Write-Host "💡 La collation existe peut-être déjà ou il y a un problème de configuration ICU" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠️  Exception lors de la création de la collation: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 La collation existe peut-être déjà" -ForegroundColor Cyan
}

# Vérifier que la base de données est vide et prête
Write-Host "🔍 Vérification de la base de données réinitialisée..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $tableCount = $result.Trim()
        Write-Host "📊 Nombre de tables dans la base: $tableCount" -ForegroundColor Green
        
        if ([int]$tableCount -eq 0) {
            Write-Host "✅ Base de données vide et prête pour l'import" -ForegroundColor Green
        } else {
            Write-Host "⚠️  La base de données contient $tableCount tables" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Erreur lors de la vérification de la base de données" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Exception lors de la vérification: $($_.Exception.Message)" -ForegroundColor Red
}

# Vérifier la collation
Write-Host "🔤 Vérification de la collation musicbrainz..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT collname FROM pg_collation WHERE collname = 'musicbrainz';" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $collationExists = $result.Trim() -ne ""
        if ($collationExists) {
            Write-Host "✅ Collation musicbrainz disponible" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Collation musicbrainz non trouvée" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Erreur lors de la vérification de la collation" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Exception lors de la vérification de la collation: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "✅ Réinitialisation de la base MusicBrainz terminée avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant appliquer le schéma avec: .\scripts\apply_mb_schema.ps1" -ForegroundColor Cyan
Write-Host "📊 Base de données prête pour l'import MusicBrainz v30" -ForegroundColor Cyan
