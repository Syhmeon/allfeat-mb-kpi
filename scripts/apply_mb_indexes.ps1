# Script d'application des index MusicBrainz officiels (Windows PowerShell via Docker)
# Usage: .\scripts\apply_mb_indexes.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$CONTAINER_NAME = "musicbrainz-postgres",
    [string]$MB_VERSION = "v-2025-05-23.0-schema-change"
)

Write-Host "🚀 Application des index MusicBrainz officiels (version $MB_VERSION)..." -ForegroundColor Green

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
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Connexion échouée"
    }
    Write-Host "✅ PostgreSQL accessible dans le conteneur" -ForegroundColor Green
} catch {
    Write-Host "❌ PostgreSQL n'est pas accessible dans le conteneur." -ForegroundColor Red
    Write-Host "💡 Attendez que PostgreSQL soit complètement démarré dans le conteneur." -ForegroundColor Cyan
    exit 1
}

# Vérifier que les données sont importées
Write-Host "🔍 Vérification de la présence des données..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM musicbrainz.artist LIMIT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Aucune donnée trouvée dans la base musicbrainz" -ForegroundColor Red
        Write-Host "💡 Importez d'abord les données avec: .\scripts\import_mb.ps1" -ForegroundColor Cyan
        exit 1
    }
    Write-Host "✅ Données MusicBrainz détectées" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors de la vérification des données: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Créer un répertoire temporaire pour les fichiers SQL
$tempDir = Join-Path $env:TEMP "musicbrainz-indexes-$MB_VERSION"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null
Write-Host "📁 Répertoire temporaire créé: $tempDir" -ForegroundColor Green

# URLs des fichiers SQL officiels MusicBrainz pour les index (release v-2025-05-23.0-schema-change)
$indexFiles = @{
    "CreatePrimaryKeys.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreatePrimaryKeys.sql"
    "CreateIndexes.sql" = "https://raw.githubusercontent.com/metabrainz/musicbrainz-server/$MB_VERSION/admin/sql/CreateIndexes.sql"
}

# Télécharger les fichiers SQL
Write-Host "📥 Téléchargement des fichiers SQL d'index MusicBrainz..." -ForegroundColor Yellow
$downloadedFiles = @()

foreach ($fileName in $indexFiles.Keys) {
    $url = $indexFiles[$fileName]
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

# Exécuter les fichiers SQL dans l'ordre
Write-Host "🔧 Application des index MusicBrainz..." -ForegroundColor Yellow
$executionOrder = @("CreatePrimaryKeys.sql", "CreateIndexes.sql")

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

# Vérifier que les index ont été créés
Write-Host "🔍 Vérification des index créés..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'musicbrainz';" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Index MusicBrainz créés avec succès" -ForegroundColor Green
        Write-Host "📊 Nombre d'index créés: $($result.Trim())" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors de la vérification des index" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Exception lors de la vérification des index: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Exécuter VACUUM ANALYZE
Write-Host "📊 Optimisation des statistiques (VACUUM ANALYZE)..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "VACUUM ANALYZE;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ VACUUM ANALYZE terminé avec succès" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Avertissement: Erreur lors de VACUUM ANALYZE" -ForegroundColor Yellow
        Write-Host "📝 Message: $result" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Avertissement: Exception lors de VACUUM ANALYZE: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "✅ Index MusicBrainz officiels v30 appliqués avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant appliquer les vues KPI avec: .\scripts\apply_views.ps1" -ForegroundColor Cyan
Write-Host "📊 Base de données optimisée et prête pour les requêtes KPI" -ForegroundColor Cyan
