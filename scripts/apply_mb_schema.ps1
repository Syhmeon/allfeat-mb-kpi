# Script d'application du schéma MusicBrainz officiel (Windows PowerShell via Docker)
# Usage: .\scripts\apply_mb_schema.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$CONTAINER_NAME = "musicbrainz-postgres",
    [string]$MB_VERSION = "v-2025-05-23.0-schema-change"
)

Write-Host "🚀 Application du schéma MusicBrainz officiel (mode léger KPI - version $MB_VERSION)..." -ForegroundColor Green

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

# Créer la base de données si elle n'existe pas
Write-Host "🗄️  Création de la base de données..." -ForegroundColor Yellow
try {
    docker exec $CONTAINER_NAME psql -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Base de données créée" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Base de données existe déjà" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Erreur lors de la création de la base de données" -ForegroundColor Red
    exit 1
}

# Créer un répertoire temporaire pour les fichiers SQL
$tempDir = Join-Path $env:TEMP "musicbrainz-schema-$MB_VERSION"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null
Write-Host "📁 Répertoire temporaire créé: $tempDir" -ForegroundColor Green

# URLs des fichiers SQL officiels MusicBrainz (mode léger KPI - release v-2025-05-23.0-schema-change)
$schemaFiles = @{
    "CreateTypes.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateTypes.sql"
    "CreateTables.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateTables.sql"
    "CreatePrimaryKeys.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreatePrimaryKeys.sql"
    "CreateSearchConfigurations.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateSearchConfigurations.sql"
    "CreateFunctions.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateFunctions.sql"
    "CreateConstraints.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateConstraints.sql"
    "CreateFKConstraints.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateFKConstraints.sql"
    "CreateIndexes.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateIndexes.sql"
}

# Télécharger les fichiers SQL
Write-Host "📥 Téléchargement des fichiers SQL officiels MusicBrainz..." -ForegroundColor Yellow
$downloadedFiles = @()

foreach ($fileName in $schemaFiles.Keys) {
    $url = $schemaFiles[$fileName]
    $localPath = Join-Path $tempDir $fileName
    
    Write-Host "  📄 Téléchargement de $fileName..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
        if (Test-Path $localPath) {
            $downloadedFiles += $localPath
            Write-Host "    ✅ $fileName téléchargé" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Échec du téléchargement de $fileName" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "    ❌ Erreur lors du téléchargement de $fileName : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Copier les fichiers dans le conteneur
Write-Host "📋 Copie des fichiers SQL dans le conteneur..." -ForegroundColor Yellow
$containerFiles = @()

foreach ($localFile in $downloadedFiles) {
    $fileName = Split-Path $localFile -Leaf
    $containerPath = "/tmp/$fileName"
    
    Write-Host "  📄 Copie de $fileName vers le conteneur..." -ForegroundColor Cyan
    try {
        docker cp $localFile "${CONTAINER_NAME}:${containerPath}"
        if ($LASTEXITCODE -eq 0) {
            $containerFiles += $containerPath
            Write-Host "    ✅ $fileName copié dans le conteneur" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Échec de la copie de $fileName" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "    ❌ Erreur lors de la copie de $fileName : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}


# ⚙️ Préparation du schéma MusicBrainz
Write-Host "⚙️ Préparation du schéma MusicBrainz..." -ForegroundColor Yellow
try {
    # Créer le schéma musicbrainz s'il n'existe pas
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "CREATE SCHEMA IF NOT EXISTS musicbrainz;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Schéma musicbrainz créé/vérifié" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Avertissement création schéma: $result" -ForegroundColor Yellow
    }

    # Créer la collation musicbrainz dans le schéma musicbrainz
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "CREATE COLLATION IF NOT EXISTS musicbrainz.musicbrainz (provider = icu, locale = 'und-u-ks-level2', deterministic = false);" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Collation musicbrainz.musicbrainz créée/vérifiée" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Avertissement création collation: $result" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️ Exception lors de la préparation du schéma: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ⚙️ Création de l'extension cube (nécessaire pour MusicBrainz)
Write-Host "⚙️ Création de l'extension cube..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS cube;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Extension cube créée/vérifiée avec succès" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Avertissement lors de la création de l'extension cube: $result" -ForegroundColor Yellow
        Write-Host "💡 L'extension existe peut-être déjà ou il y a un problème de configuration" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠️ Exception lors de la création de l'extension cube: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 L'extension existe peut-être déjà" -ForegroundColor Cyan
}


# Exécuter les fichiers SQL dans l'ordre (mode léger KPI)
Write-Host "🔧 Application du schéma MusicBrainz (mode léger KPI)..." -ForegroundColor Yellow
$executionOrder = @("CreateTypes.sql", "CreateTables.sql", "CreatePrimaryKeys.sql", "CreateSearchConfigurations.sql", "CreateFunctions.sql", "CreateConstraints.sql", "CreateFKConstraints.sql", "CreateIndexes.sql")

foreach ($fileName in $executionOrder) {
    $containerPath = "/tmp/$fileName"
    
    if ($containerFiles -contains $containerPath) {
        Write-Host "  📄 Exécution de $fileName..." -ForegroundColor Cyan
        try {
            $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -f "${containerPath}" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✅ $fileName exécuté avec succès" -ForegroundColor Green
            } else {
                Write-Host "    ❌ Erreur lors de l'exécution de $fileName" -ForegroundColor Red
                Write-Host "    📝 Message d'erreur: $result" -ForegroundColor Red
                exit 1
            }
        } catch {
            Write-Host "    ❌ Exception lors de l'exécution de $fileName : $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

# Nettoyer les fichiers temporaires
Write-Host "🧹 Nettoyage des fichiers temporaires..." -ForegroundColor Yellow
try {
    Remove-Item -Recurse -Force $tempDir
    Write-Host "✅ Fichiers temporaires supprimés" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Impossible de supprimer les fichiers temporaires: $tempDir" -ForegroundColor Yellow
}

# Vérifier que le schéma a été créé
Write-Host "🔍 Vérification du schéma créé..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'musicbrainz';" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Schéma MusicBrainz créé avec succès" -ForegroundColor Green
        Write-Host "📊 Nombre de tables créées: $($result.Trim())" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors de la vérification du schéma" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Exception lors de la vérification du schéma: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Schéma MusicBrainz officiel v30 (mode léger KPI) appliqué avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant importer les données avec: .\scripts\import_mb.ps1" -ForegroundColor Cyan
