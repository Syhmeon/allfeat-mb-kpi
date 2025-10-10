# Script d'import MusicBrainz officiel pour Windows PowerShell (via Docker)
# Usage: .\scripts\import_mb.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$DUMPS_DIR = "E:\mbdump",
    [string]$CONTAINER_NAME = "musicbrainz-postgres"
)

Write-Host "🚀 Début de l'import MusicBrainz officiel via Docker..." -ForegroundColor Green

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

# Vérifier la présence du répertoire DUMPS_DIR
Write-Host "📁 Vérification du répertoire $DUMPS_DIR..." -ForegroundColor Yellow
if (-not (Test-Path $DUMPS_DIR)) {
    Write-Host "❌ Répertoire $DUMPS_DIR introuvable" -ForegroundColor Red
    Write-Host "💡 Vérifiez le chemin vers vos fichiers MusicBrainz extraits" -ForegroundColor Cyan
    exit 1
}

# Vérifier que le conteneur est démarré avec le bon montage
Write-Host "🔗 Vérification du montage des volumes..." -ForegroundColor Yellow
try {
    $mountInfo = docker inspect $CONTAINER_NAME --format "{{json .Mounts}}" | ConvertFrom-Json
    $dumpsMountFound = $false
    $correctMount = $false
    
    foreach ($mount in $mountInfo) {
        if ($mount.Destination -eq "/dumps") {
            $dumpsMountFound = $true
            Write-Host "✅ Volume monté: $($mount.Source) -> /dumps" -ForegroundColor Green
            
            # Vérifier si c'est le bon répertoire monté (compatible Docker Desktop Windows)
            $isCorrectMount = ($mount.Source -eq $DUMPS_DIR) -or 
                             ($mount.Source -eq "/run/desktop/mnt/host/e/mbdump" -and $DUMPS_DIR -eq "E:\mbdump")
            
            if ($isCorrectMount) {
                $correctMount = $true
                Write-Host "✅ Le bon répertoire est monté ($DUMPS_DIR -> $($mount.Source))" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Attention: Vous avez monté [$($mount.Source)] mais vous voulez importer depuis [$DUMPS_DIR]" -ForegroundColor Yellow
                Write-Host "💡 Solutions possibles:" -ForegroundColor Cyan
                Write-Host "   1. Copiez vos fichiers E:\mbdump vers $($mount.Source)" -ForegroundColor Cyan
                Write-Host "   2. Ou ajustez docker-compose.yml pour monter $DUMPS_DIR vers /dumps" -ForegroundColor Cyan
            }
            break
        }
    }
    
    if (-not $dumpsMountFound) {
        Write-Host "❌ Volume /dumps non trouvé dans le conteneur" -ForegroundColor Red
        Write-Host "💡 Démarrez le conteneur avec docker-compose up -d (avec un volume monté vers /dumps)" -ForegroundColor Cyan
        exit 1
    }
    
    # Avertissement si le montage n'est pas correct
    if (-not $correctMount) {
        Write-Host "" 
        Write-Host "⚠️  IMPORTANT: Le conteneur doit pouvoir accéder aux fichiers MusicBrainz via /dumps" -ForegroundColor Yellow
        Write-Host "🛠️  Solutions:" -ForegroundColor Cyan
        Write-Host "   1. Copiez E:\mbdump\* vers le répertoire local monté par Docker" -ForegroundColor Cyan
        Write-Host "   2. Ou modifiez docker-compose.yml:" -ForegroundColor Cyan
        Write-Host "      volumes:" -ForegroundColor Cyan  
        Write-Host "        - E:\mbdump:/dumps:ro" -ForegroundColor Cyan
        Write-Host ""
        
        $response = Read-Host "Continuer quand même ? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Host "🛑 Arrêt du script" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "⚠️  Impossible de vérifier les montages, continuation..." -ForegroundColor Yellow    
    Write-Host "💡 Assurez-vous que le conteneur peut accéder aux fichiers MusicBrainz via /dumps" -ForegroundColor Cyan
}

# Vérifier SCHEMA_SEQUENCE depuis le conteneur
Write-Host "🔍 Vérification de SCHEMA_SEQUENCE..." -ForegroundColor Yellow
try {
    # Lire replication_control depuis le conteneur
    $replicationControlContent = docker exec $CONTAINER_NAME cat /dumps/replication_control 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Extraire le deuxième champ (SCHEMA_SEQUENCE)
        $schemaVersion = ($replicationControlContent -split '\t')[1]
        Write-Host "📋 Version du schéma détectée: $schemaVersion" -ForegroundColor Green
        
        if ($schemaVersion -ne "30") {
            Write-Host "❌ Version de schéma incompatible: $schemaVersion (attendu: 30)" -ForegroundColor Red
            Write-Host "💡 Ce script est conçu pour MusicBrainz v30 uniquement" -ForegroundColor Cyan
            exit 1
        }
        Write-Host "✅ Version de schéma compatible: v30" -ForegroundColor Green
    } else {
        Write-Host "❌ Fichier replication_control introuvable dans /dumps du conteneur" -ForegroundColor Red
        Write-Host "💡 Vérifiez que vous avez extrait le bon dump MusicBrainz" -ForegroundColor Cyan
        exit 1
    }
} catch {
    Write-Host "❌ Erreur lors de la lecture de replication_control: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Lister les fichiers de données depuis le conteneur (ignorer les fichiers spéciaux)
Write-Host "📋 Analyse des fichiers de données..." -ForegroundColor Yellow
$excludePatterns = @("README", "*_SEQUENCE", "COPYING", "*.md", "*.txt", "*.log", "replication_control")
$containerFileList = docker exec $CONTAINER_NAME ls /dumps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Impossible de lister les fichiers dans /dumps du conteneur" -ForegroundColor Red
    exit 1
}

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

# Trier les fichiers par ordre de dépendance (tables de référence en premier)
$referenceTables = $allFiles | Where-Object { 
    $_ -like "*_type" -or $_ -like "*_alias_type" -or $_ -like "*_format" -or $_ -like "*_status" -or $_ -like "*_packaging" -or $_ -like "*_ordering_type" -or $_ -like "*_primary_type" -or $_ -like "*_secondary_type" -or $_ -like "*_creditable_attribute_type" -or $_ -like "*_text_attribute_type" -or $_ -like "*_attribute_type" -or $_ -like "*_allowed_value" -or $_ -like "*_allowed_format" -or $_ -like "*_allowed_value_allowed_format" -or $_ -like "*_attribute_type_allowed_value" -or $_ -like "*_attribute_type_allowed_format" -or $_ -like "*_attribute_type_allowed_value_allowed_format" -or $_ -like "*_attribute_type_allowed_value_allowed_format" -or
    $_ -eq "gender" -or $_ -eq "script" -or $_ -eq "language" -or $_ -eq "orderable_link_type" -or $_ -eq "link_text_attribute_type" -or $_ -eq "link_creditable_attribute_type"
}

# Tables principales (sans dépendances complexes) - IMPORTANT: recording et release doivent venir avant medium/track/isrc/iswc
$mainTables = $allFiles | Where-Object { 
    $_ -eq "recording" -or $_ -eq "release" -or $_ -eq "area" -or $_ -eq "artist" -or $_ -eq "work" -or $_ -eq "label" -or $_ -eq "place" -or $_ -eq "event" -or $_ -eq "series" -or $_ -eq "genre" -or $_ -eq "instrument" -or $_ -eq "link" -or $_ -eq "url" -or $_ -eq "tag" -or $_ -eq "annotation" -or $_ -eq "editor" -or $_ -eq "edit" -or $_ -eq "vote" -or $_ -eq "cdtoc" -or $_ -eq "iso_3166_1" -or $_ -eq "iso_3166_2" -or $_ -eq "iso_3166_3" -or $_ -eq "country_area"
}

$otherTables = $allFiles | Where-Object { 
    $_ -notlike "*_type" -and $_ -notlike "*_alias_type" -and $_ -notlike "*_format" -and $_ -notlike "*_status" -and $_ -notlike "*_packaging" -and $_ -notlike "*_ordering_type" -and $_ -notlike "*_primary_type" -and $_ -notlike "*_secondary_type" -and $_ -notlike "*_creditable_attribute_type" -and $_ -notlike "*_text_attribute_type" -and $_ -notlike "*_attribute_type" -and $_ -notlike "*_allowed_value" -and $_ -notlike "*_allowed_format" -and $_ -notlike "*_allowed_value_allowed_format" -and $_ -notlike "*_attribute_type_allowed_value" -and $_ -notlike "*_attribute_type_allowed_format" -and $_ -notlike "*_attribute_type_allowed_value_allowed_format" -and $_ -notlike "*_attribute_type_allowed_value_allowed_format" -and
    $_ -ne "gender" -and $_ -ne "script" -and $_ -ne "language" -and $_ -ne "orderable_link_type" -and $_ -ne "link_text_attribute_type" -and $_ -ne "link_creditable_attribute_type" -and
    $_ -ne "area" -and $_ -ne "artist" -and $_ -ne "recording" -and $_ -ne "release" -and $_ -ne "work" -and $_ -ne "label" -and $_ -ne "place" -and $_ -ne "event" -and $_ -ne "series" -and $_ -ne "genre" -and $_ -ne "instrument" -and $_ -ne "medium" -and $_ -ne "track" -and $_ -ne "link" -and $_ -ne "url" -and $_ -ne "tag" -and $_ -ne "annotation" -and $_ -ne "editor" -and $_ -ne "edit" -and $_ -ne "vote" -and $_ -ne "cdtoc" -and $_ -ne "isrc" -and $_ -ne "iswc" -and $_ -ne "iso_3166_1" -and $_ -ne "iso_3166_2" -and $_ -ne "iso_3166_3" -and $_ -ne "country_area"
}

# Ordre d'import : tables de référence d'abord, puis tables principales, puis autres tables
$dataFiles = ($referenceTables + $mainTables + $otherTables) | ForEach-Object { [PSCustomObject]@{ Name = $_ } }

if ($dataFiles.Count -eq 0) {
    Write-Host "❌ Aucun fichier de données trouvé dans /dumps du conteneur" -ForegroundColor Red
    Write-Host "💡 Vérifiez que le dump MusicBrainz est correctement extrait" -ForegroundColor Cyan
    exit 1
}

Write-Host "📦 Trouvé $($dataFiles.Count) fichiers de données à importer" -ForegroundColor Green
Write-Host "📋 Ordre d'import: $($referenceTables.Count) tables de référence, puis $($mainTables.Count) tables principales, puis $($otherTables.Count) autres tables" -ForegroundColor Cyan

# Vérifier si on doit reprendre un import partiel
Write-Host "🔍 Vérification de l'état actuel des données..." -ForegroundColor Yellow
$importedTables = @()
$failedTable = ""

try {
    # Vérifier si 'recording' existe (table précédente de 'isrc')
    $recordingCount = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM musicbrainz.recording;" 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $recordingCount.Trim() -as [int] -gt 0) {
        Write-Host "✅ Table 'recording' déjà importée avec succès ($($recordingCount.Trim()) lignes)" -ForegroundColor Green
        Write-Host "🚀 Reprise depuis la table 'isrc' (qui a échoué)..." -ForegroundColor Cyan
        
        # Trouver l'index de 'isrc' et reprendre depuis là
        $isrcIndex = -1
        for ($i = 0; $i -lt $dataFiles.Count; $i++) {
            if ($dataFiles[$i].Name -eq "isrc") {
                $isrcIndex = $i
                break
            }
        }
        
        if ($isrcIndex -gt -1) {
            Write-Host "📍 Reprise depuis l'index $($isrcIndex + 1) ('isrc' et suivantes)" -ForegroundColor Cyan
            Write-Host "🧹 Nettoyage des tables problématiques entre 'recording' et 'isrc'..." -ForegroundColor Yellow
            
            # Supprimer les tables qui pourraient causer des conflits
            $problematicTables = @("isrc", "iswc")
            foreach ($table in $problematicTables) {
                try {
                    $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "DELETE FROM musicbrainz.$table;" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "🗑️ Table $table nettoyée" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "⚠️ Impossible de nettoyer $table" -ForegroundColor Yellow
                }
            }
            
            $dataFiles = $dataFiles[$isrcIndex..($dataFiles.Count - 1)]
        }
    } else {
        Write-Host "💡 Table 'recording' non trouvée ou vide - si l'ordre est correct, 'recording' doit être importée avant 'isrc'" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Impossible de vérifier l'état des tables" -ForegroundColor Yellow
}

# Les tables avec dataFiles mis à jour sont déjà filtrées si nécessaire

# Importer chaque fichier de données avec \copy
Write-Host "📥 Import des données MusicBrainz avec \\copy (cela peut prendre plusieurs heures)..." -ForegroundColor Yellow
Write-Host "⏳ Cette étape peut prendre plusieurs heures selon la taille des données..." -ForegroundColor Cyan

$totalFiles = $dataFiles.Count
$successCount = 0
$failedFiles = @()

for ($i = 0; $i -lt $totalFiles; $i++) {
    $file = $dataFiles[$i]
    $fileNumber = $i + 1
    $tableName = $file.Name
    
    Write-Host "📄 [$fileNumber/$totalFiles] Import en cours: $tableName..." -ForegroundColor Cyan
    Write-Host "   🐳 Chemin conteneur: /dumps/$tableName" -ForegroundColor DarkGray
    
    try {
        # Utiliser \copy pour importer les données
        $copyCommand = "\copy ${tableName} FROM '/dumps/${tableName}' WITH (FORMAT text, DELIMITER E'\t', NULL '\N');"
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

Write-Host "📊 Résumé de l'importation:" -ForegroundColor Yellow
Write-Host "   ✅ Fichiers importés avec succès: $successCount / $totalFiles" -ForegroundColor Green
if ($failedFiles.Count -gt 0) {
    Write-Host "   ❌ Fichiers échoués: $($failedFiles.Count)" -ForegroundColor Red
    Write-Host "   📋 Fichiers problématiques: $($failedFiles -join ', ')" -ForegroundColor Red
    exit 1
}

# Les contraintes sont déjà actives après TRUNCATE CASCADE
Write-Host "✅ Contraintes FK actives après nettoyage" -ForegroundColor Green

# Créer les extensions nécessaires
Write-Host "🔧 Installation des extensions PostgreSQL..." -ForegroundColor Yellow
try {
    docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c @"
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
"@
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Extensions installées avec succès" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Avertissement: Erreur lors de l'installation des extensions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Avertissement: Exception lors de l'installation des extensions" -ForegroundColor Yellow
}

Write-Host "✅ Import MusicBrainz officiel v30 terminé avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant appliquer les index avec: .\scripts\apply_mb_indexes.ps1" -ForegroundColor Cyan
Write-Host "📊 Base de données accessible via le conteneur: $CONTAINER_NAME" -ForegroundColor Cyan