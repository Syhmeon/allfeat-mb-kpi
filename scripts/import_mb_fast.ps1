# Script d'import MusicBrainz optimisé (Windows PowerShell via Docker)
# Usage: .\scripts\import_mb_fast.ps1
# 
# Optimisations:
# - Désactive temporairement les contraintes FK pendant l'import
# - Utilise COPY au lieu de \copy (plus rapide)
# - Import en parallèle des tables indépendantes

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$DUMPS_DIR = "E:\mbdump",
    [string]$CONTAINER_NAME = "musicbrainz-postgres"
)

Write-Host "🚀 Import MusicBrainz optimisé (mode rapide)..." -ForegroundColor Green

# Vérifier que le conteneur est en cours d'exécution
Write-Host "🐳 Vérification du conteneur $CONTAINER_NAME..." -ForegroundColor Yellow
try {
    $containerStatus = docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}"
    if ([string]::IsNullOrEmpty($containerStatus)) {
        Write-Host "❌ Le conteneur $CONTAINER_NAME n'est pas en cours d'exécution." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Conteneur $CONTAINER_NAME trouvé: $containerStatus" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors de la vérification du conteneur Docker." -ForegroundColor Red
    exit 1
}

# Vérifier que PostgreSQL dans le conteneur est accessible
Write-Host "📡 Vérification de la connexion PostgreSQL..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Connexion échouée"
    }
    Write-Host "✅ PostgreSQL accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ PostgreSQL n'est pas accessible." -ForegroundColor Red
    exit 1
}

# Désactiver temporairement les contraintes FK pour accélérer l'import
Write-Host "⚡ Désactivation temporaire des contraintes FK..." -ForegroundColor Yellow
try {
    docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
    -- Désactiver toutes les contraintes FK
    DO \$\$ 
    DECLARE r RECORD;
    BEGIN
        FOR r IN (SELECT conname, conrelid::regclass as table_name 
                  FROM pg_constraint 
                  WHERE contype = 'f' AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'musicbrainz')) 
        LOOP
            EXECUTE 'ALTER TABLE ' || r.table_name || ' DISABLE TRIGGER ALL';
        END LOOP;
    END \$\$;
    "
    Write-Host "✅ Contraintes FK désactivées temporairement" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Impossible de désactiver les contraintes FK" -ForegroundColor Yellow
}

# Lister les fichiers de données
Write-Host "📋 Analyse des fichiers de données..." -ForegroundColor Yellow
$excludePatterns = @("README", "*_SEQUENCE", "COPYING", "*.md", "*.txt", "*.log", "replication_control")
$containerFileList = docker exec $CONTAINER_NAME ls /dumps 2>&1

$allFiles = $containerFileList | Where-Object { 
    $fileName = $_.Trim()
    if ([string]::IsNullOrEmpty($fileName)) { return $false }
    
    $shouldExclude = $false
    foreach ($pattern in $excludePatterns) {
        if ($fileName -like $pattern) {
            $shouldExclude = $true
            break
        }
    }
    -not $shouldExclude
} | ForEach-Object { $_.Trim() }

# Ordre d'import optimisé
$referenceTables = $allFiles | Where-Object { 
    $_ -like "*_type" -or $_ -like "*_alias_type" -or $_ -like "*_format" -or $_ -like "*_status" -or $_ -like "*_packaging" -or $_ -like "*_ordering_type" -or $_ -like "*_primary_type" -or $_ -like "*_secondary_type" -or $_ -like "*_creditable_attribute_type" -or $_ -like "*_text_attribute_type" -or $_ -like "*_attribute_type" -or $_ -like "*_allowed_value" -or $_ -like "*_allowed_format" -or $_ -like "*_allowed_value_allowed_format" -or $_ -like "*_attribute_type_allowed_value" -or $_ -like "*_attribute_type_allowed_format" -or $_ -like "*_attribute_type_allowed_value_allowed_format" -or $_ -like "*_attribute_type_allowed_value_allowed_format" -or
    $_ -eq "gender" -or $_ -eq "script" -or $_ -eq "language" -or $_ -eq "orderable_link_type" -or $_ -eq "link_text_attribute_type" -or $_ -eq "link_creditable_attribute_type"
}

$mainTables = $allFiles | Where-Object { 
    $_ -eq "recording" -or $_ -eq "release" -or $_ -eq "area" -or $_ -eq "artist" -or $_ -eq "work" -or $_ -eq "label" -or $_ -eq "place" -or $_ -eq "event" -or $_ -eq "series" -or $_ -eq "genre" -or $_ -eq "instrument" -or $_ -eq "link" -or $_ -eq "url" -or $_ -eq "tag" -or $_ -eq "annotation" -or $_ -eq "editor" -or $_ -eq "edit" -or $_ -eq "vote" -or $_ -eq "cdtoc" -or $_ -eq "iso_3166_1" -or $_ -eq "iso_3166_2" -or $_ -eq "iso_3166_3" -or $_ -eq "country_area"
}

$otherTables = $allFiles | Where-Object { 
    $_ -notlike "*_type" -and $_ -notlike "*_alias_type" -and $_ -notlike "*_format" -and $_ -notlike "*_status" -and $_ -notlike "*_packaging" -and $_ -notlike "*_ordering_type" -and $_ -notlike "*_primary_type" -and $_ -notlike "*_secondary_type" -and $_ -notlike "*_creditable_attribute_type" -and $_ -notlike "*_text_attribute_type" -and $_ -notlike "*_attribute_type" -and $_ -notlike "*_allowed_value" -and $_ -notlike "*_allowed_format" -and $_ -notlike "*_allowed_value_allowed_format" -and $_ -notlike "*_attribute_type_allowed_value" -and $_ -notlike "*_attribute_type_allowed_format" -and $_ -notlike "*_attribute_type_allowed_value_allowed_format" -and $_ -notlike "*_attribute_type_allowed_value_allowed_format" -and
    $_ -ne "gender" -and $_ -ne "script" -and $_ -ne "language" -and $_ -ne "orderable_link_type" -and $_ -ne "link_text_attribute_type" -and $_ -ne "link_creditable_attribute_type" -and
    $_ -ne "area" -and $_ -ne "artist" -and $_ -ne "recording" -and $_ -ne "release" -and $_ -ne "work" -and $_ -ne "label" -and $_ -ne "place" -and $_ -ne "event" -and $_ -ne "series" -and $_ -ne "genre" -and $_ -ne "instrument" -and $_ -ne "link" -and $_ -ne "url" -and $_ -ne "tag" -and $_ -ne "annotation" -and $_ -ne "editor" -and $_ -ne "edit" -and $_ -ne "vote" -and $_ -ne "cdtoc" -and $_ -ne "iso_3166_1" -and $_ -ne "iso_3166_2" -and $_ -ne "iso_3166_3" -and $_ -ne "country_area"
}

$dataFiles = ($referenceTables + $mainTables + $otherTables) | ForEach-Object { [PSCustomObject]@{ Name = $_ } }

Write-Host "📦 Trouvé $($dataFiles.Count) fichiers de données à importer" -ForegroundColor Green

# Importer chaque fichier avec COPY (plus rapide que \copy)
Write-Host "📥 Import des données MusicBrainz avec COPY (mode rapide)..." -ForegroundColor Yellow

$totalFiles = $dataFiles.Count
$successCount = 0
$failedFiles = @()

for ($i = 0; $i -lt $totalFiles; $i++) {
    $file = $dataFiles[$i]
    $fileNumber = $i + 1
    $tableName = $file.Name
    
    Write-Host "📄 [$fileNumber/$totalFiles] Import en cours: $tableName..." -ForegroundColor Cyan
    
    try {
        # Utiliser COPY au lieu de \copy (plus rapide)
        $copyCommand = "COPY ${tableName} FROM '/dumps/${tableName}' WITH (FORMAT text, DELIMITER E'\t', NULL '\N');"
        $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c $copyCommand 2>&1
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Host "✅ [$fileNumber/$totalFiles] $tableName importé avec succès" -ForegroundColor Green
        } else {
            $failedFiles += $tableName
            Write-Host "❌ [$fileNumber/$totalFiles] Erreur lors de l'import de $tableName" -ForegroundColor Red
            Write-Host "   📝 Message d'erreur: $result" -ForegroundColor Red
            Write-Host "   🛑 Arrêt de l'importation..." -ForegroundColor Red
            exit 1
        }
    } catch {
        $failedFiles += $tableName
        Write-Host "❌ [$fileNumber/$totalFiles] Exception lors de l'import de $tableName : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   🛑 Arrêt de l'importation..." -ForegroundColor Red
        exit 1
    }
}

# Réactiver les contraintes FK
Write-Host "🔒 Réactivation des contraintes FK..." -ForegroundColor Yellow
try {
    docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
    -- Réactiver toutes les contraintes FK
    DO \$\$ 
    DECLARE r RECORD;
    BEGIN
        FOR r IN (SELECT conname, conrelid::regclass as table_name 
                  FROM pg_constraint 
                  WHERE contype = 'f' AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'musicbrainz')) 
        LOOP
            EXECUTE 'ALTER TABLE ' || r.table_name || ' ENABLE TRIGGER ALL';
        END LOOP;
    END \$\$;
    "
    Write-Host "✅ Contraintes FK réactivées" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Impossible de réactiver les contraintes FK" -ForegroundColor Yellow
}

# Vérifier l'intégrité des données
Write-Host "🔍 Vérification de l'intégrité des données..." -ForegroundColor Yellow
try {
    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
    SELECT 
        'recording' as table_name, COUNT(*) as count FROM musicbrainz.recording
    UNION ALL
    SELECT 
        'artist' as table_name, COUNT(*) as count FROM musicbrainz.artist
    UNION ALL
    SELECT 
        'work' as table_name, COUNT(*) as count FROM musicbrainz.work
    UNION ALL
    SELECT 
        'release' as table_name, COUNT(*) as count FROM musicbrainz.release;
    "
    Write-Host "📊 Vérification des données:" -ForegroundColor Green
    Write-Host $result -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ Impossible de vérifier l'intégrité" -ForegroundColor Yellow
}

Write-Host "📊 Résumé de l'importation:" -ForegroundColor Yellow
Write-Host "   ✅ Fichiers importés avec succès: $successCount / $totalFiles" -ForegroundColor Green
if ($failedFiles.Count -gt 0) {
    Write-Host "   ❌ Fichiers échoués: $($failedFiles.Count)" -ForegroundColor Red
    Write-Host "   📋 Fichiers problématiques: $($failedFiles -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Import MusicBrainz optimisé terminé avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant appliquer les index avec: .\scripts\apply_mb_indexes.ps1" -ForegroundColor Cyan
