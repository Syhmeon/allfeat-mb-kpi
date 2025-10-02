# Script de vérification du schéma MusicBrainz (Windows PowerShell via Docker)
# Usage: .\scripts\verify_mb_schema.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$CONTAINER_NAME = "musicbrainz-postgres"
)

Write-Host "🚀 Vérification du schéma MusicBrainz..." -ForegroundColor Green

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

# Vérifier la version du schéma
Write-Host "🔍 Vérification de la version du schéma..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT current_schema_sequence FROM musicbrainz.replication_control;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $schemaVersion = $result.Trim()
        Write-Host "📋 Version du schéma détectée: $schemaVersion" -ForegroundColor Green
        
        if ($schemaVersion -eq "30") {
            Write-Host "✅ Version de schéma correcte: v30" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Version de schéma inattendue: $schemaVersion (attendu: 30)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Impossible de lire la version du schéma" -ForegroundColor Red
        Write-Host "💡 Vérifiez que le schéma MusicBrainz est correctement installé" -ForegroundColor Cyan
        exit 1
    }
} catch {
    Write-Host "❌ Erreur lors de la vérification de la version du schéma: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Vérifier les tables principales
Write-Host "📊 Vérification des tables principales..." -ForegroundColor Yellow
$keyTables = @("artist", "recording", "release", "work", "release_group", "area", "label", "place")

foreach ($table in $keyTables) {
    try {
        $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM musicbrainz.$table;" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $count = $result.Trim()
            Write-Host "  📋 Table $table : $count lignes" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Table $table : Erreur lors du comptage" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ Table $table : Exception lors du comptage: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Vérifier les index
Write-Host "🔍 Vérification des index..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'musicbrainz';" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $indexCount = $result.Trim()
        Write-Host "📊 Nombre d'index MusicBrainz: $indexCount" -ForegroundColor Green
        
        if ([int]$indexCount -gt 100) {
            Write-Host "✅ Nombre d'index suffisant" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Nombre d'index faible, les index pourraient ne pas être appliqués" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Impossible de compter les index" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors de la vérification des index: $($_.Exception.Message)" -ForegroundColor Red
}

# Vérifier les contraintes de clés primaires
Write-Host "🔑 Vérification des clés primaires..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema = 'musicbrainz' AND constraint_type = 'PRIMARY KEY';" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $pkCount = $result.Trim()
        Write-Host "📊 Nombre de clés primaires: $pkCount" -ForegroundColor Green
        
        if ([int]$pkCount -gt 50) {
            Write-Host "✅ Clés primaires correctement définies" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Nombre de clés primaires faible, les contraintes pourraient ne pas être appliquées" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Impossible de compter les clés primaires" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors de la vérification des clés primaires: $($_.Exception.Message)" -ForegroundColor Red
}

# Vérifier les extensions
Write-Host "🔧 Vérification des extensions PostgreSQL..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT extname FROM pg_extension WHERE extname IN ('cube', 'earthdistance');" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $extensions = $result.Trim() -split "`n" | Where-Object { $_.Trim() -ne "" }
        Write-Host "📊 Extensions installées: $($extensions -join ', ')" -ForegroundColor Green
        
        if ($extensions -contains "cube" -and $extensions -contains "earthdistance") {
            Write-Host "✅ Extensions requises installées" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Certaines extensions requises manquent" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Impossible de vérifier les extensions" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors de la vérification des extensions: $($_.Exception.Message)" -ForegroundColor Red
}

# Statistiques générales
Write-Host "📈 Statistiques générales..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c @"
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables 
WHERE schemaname = 'musicbrainz' 
ORDER BY n_tup_ins DESC 
LIMIT 10;
"@ 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "📊 Top 10 des tables par nombre d'insertions:" -ForegroundColor Green
        Write-Host $result -ForegroundColor Cyan
    } else {
        Write-Host "❌ Impossible d'obtenir les statistiques des tables" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors de l'obtention des statistiques: $($_.Exception.Message)" -ForegroundColor Red
}

# Test de connectivité avec les vues KPI
Write-Host "🔍 Test de compatibilité avec les vues KPI..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM musicbrainz.artist WHERE type = 1 LIMIT 1;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Données artistes accessibles pour les vues KPI" -ForegroundColor Green
    } else {
        Write-Host "❌ Problème d'accès aux données artistes" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors du test de compatibilité KPI: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "✅ Vérification du schéma MusicBrainz terminée!" -ForegroundColor Green
Write-Host "🔍 Le schéma est prêt pour l'utilisation avec les vues KPI Allfeat" -ForegroundColor Cyan
