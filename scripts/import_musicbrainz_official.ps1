# Script d'import complet officiel MusicBrainz pour Allfeat KPI
# Version: 1.0
# Date: 2025-01-XX
# Usage: .\scripts\import_musicbrainz_official.ps1
#
# ⚠️  IMPORTANT
# Ce script utilise createdb.sh (script officiel MetaBrainz) pour importer la base MusicBrainz complète.
# Durée estimée : 3-6 heures selon la configuration matérielle.
# Les dumps doivent être présents dans /media/dbdump (volume dbdump).

param(
    [string]$MusicBrainzContainer = "",
    [string]$DBContainer = "musicbrainz-db",
    [string]$DBName = "musicbrainz_db",
    [string]$DBUser = "musicbrainz"
)

# Détecter automatiquement le nom du container MusicBrainz si non fourni
if ([string]::IsNullOrEmpty($MusicBrainzContainer)) {
    $mbContainers = docker ps --filter "ancestor=metabrainz/musicbrainz-docker-musicbrainz" --format "{{.Names}}" 2>&1
    if ($LASTEXITCODE -eq 0 -and $mbContainers) {
        $MusicBrainzContainer = ($mbContainers -split "`n" | Select-Object -First 1).Trim()
        if ([string]::IsNullOrEmpty($MusicBrainzContainer)) {
            # Fallback: essayer avec le pattern standard
            $MusicBrainzContainer = "musicbrainzkpi-musicbrainz-1"
        }
    } else {
        # Fallback: essayer avec le pattern standard
        $MusicBrainzContainer = "musicbrainzkpi-musicbrainz-1"
    }
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

$startTime = Get-Date

Write-ColorOutput "`n🎯 Import Complet Officiel MusicBrainz pour Allfeat KPI" "Cyan"
Write-ColorOutput "========================================================" "Cyan"
Write-ColorOutput ""

# ============================================================================
# ÉTAPE 1/7: Vérification de l'environnement Docker
# ============================================================================

Write-ColorOutput "📋 Étape 1/7: Vérification de l'environnement Docker..." "Yellow"

# Vérifier Docker
$dockerCheck = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Docker n'est pas accessible. Démarrez Docker Desktop." "Red"
    exit 1
}
Write-ColorOutput "  ✅ Docker est accessible" "Green"

# Vérifier Docker Compose
$composeCheck = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Docker Compose n'est pas accessible." "Red"
    exit 1
}
Write-ColorOutput "  ✅ Docker Compose est accessible" "Green"

# ============================================================================
# ÉTAPE 2/7: Vérification des containers
# ============================================================================

Write-ColorOutput "`n📦 Étape 2/7: Vérification des containers..." "Yellow"

# Vérifier container MusicBrainz
$mbContainerStatus = docker inspect $MusicBrainzContainer --format='{{.State.Status}}' 2>&1
if ($LASTEXITCODE -ne 0 -or $mbContainerStatus -ne "running") {
    Write-ColorOutput "❌ Container $MusicBrainzContainer n'existe pas ou n'est pas en cours d'exécution." "Red"
    Write-ColorOutput "💡 Démarrez avec: docker compose up -d" "Cyan"
    exit 1
}
Write-ColorOutput "  ✅ Container $MusicBrainzContainer est en cours d'exécution" "Green"

# Vérifier container DB
$dbContainerStatus = docker inspect $DBContainer --format='{{.State.Status}}' 2>&1
if ($LASTEXITCODE -ne 0 -or $dbContainerStatus -ne "running") {
    Write-ColorOutput "❌ Container $DBContainer n'existe pas ou n'est pas en cours d'exécution." "Red"
    Write-ColorOutput "💡 Démarrez avec: docker compose up -d db" "Cyan"
    exit 1
}
Write-ColorOutput "  ✅ Container $DBContainer est en cours d'exécution" "Green"

# ============================================================================
# ÉTAPE 3/7: Vérification des dumps
# ============================================================================

Write-ColorOutput "`n📁 Étape 3/7: Vérification des dumps MusicBrainz..." "Yellow"

# Vérifier que le répertoire /media/dbdump existe
$dumpDirCheck = docker exec $MusicBrainzContainer test -d /media/dbdump 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Le répertoire /media/dbdump n'existe pas dans le container." "Red"
    Write-ColorOutput "💡 Vérifiez que le volume dbdump est correctement monté." "Cyan"
    exit 1
}
Write-ColorOutput "  ✅ Répertoire /media/dbdump existe" "Green"

# Vérifier présence de mbdump.tar.bz2 (fichier principal)
$mainDumpCheck = docker exec $MusicBrainzContainer test -f /media/dbdump/mbdump.tar.bz2 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Le fichier mbdump.tar.bz2 n'existe pas dans /media/dbdump." "Red"
    Write-ColorOutput "💡 Téléchargez les dumps MusicBrainz et placez-les dans le volume dbdump." "Cyan"
    exit 1
}
Write-ColorOutput "  ✅ Fichier mbdump.tar.bz2 trouvé" "Green"

# Lister les dumps présents
Write-ColorOutput "  📋 Dumps disponibles:" "Cyan"
$dumps = docker exec $MusicBrainzContainer sh -c "ls -lh /media/dbdump/*.tar.bz2 2>/dev/null || echo 'Aucun dump .tar.bz2 trouvé'" 2>&1
if ($LASTEXITCODE -eq 0 -and $dumps) {
    $dumps | Where-Object { $_ -notmatch 'Aucun dump' } | ForEach-Object { Write-ColorOutput "    $_" "Gray" }
} else {
    Write-ColorOutput "    ⚠️  Impossible de lister les dumps ou aucun dump trouvé" "Yellow"
}

# ============================================================================
# ÉTAPE 4/7: Vérification de la base existante
# ============================================================================

Write-ColorOutput "`n🔍 Étape 4/7: Vérification de la base de données existante..." "Yellow"

# Vérifier que PostgreSQL est accessible
$pgTest = docker exec $DBContainer psql -U $DBUser -d $DBName -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ PostgreSQL n'est pas accessible sur $DBName." "Red"
    Write-ColorOutput "💡 Vérifiez que la base de données existe et que le container est prêt." "Cyan"
    exit 1
}
Write-ColorOutput "  ✅ PostgreSQL est accessible" "Green"

# Vérifier si des données existent déjà
$recordingCountQuery = "SELECT COUNT(*) FROM musicbrainz.recording;"
$recordingCountRaw = docker exec $DBContainer psql -U $DBUser -d $DBName -t -A -c $recordingCountQuery 2>&1

if ($LASTEXITCODE -eq 0) {
    # Extraire la valeur numérique (gérer le cas où c'est un tableau)
    $recordingCountStr = if ($recordingCountRaw -is [array]) { 
        ($recordingCountRaw | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim() 
    } else { 
        $recordingCountRaw.ToString().Trim() 
    }
    $count = [int]($recordingCountStr -replace '\D','')
    if ($count -gt 0) {
        Write-ColorOutput "  ✅ Base de données contient déjà $count enregistrements" "Green"
        Write-ColorOutput "  ⏭️  Import déjà effectué - passage à l'étape suivante" "Yellow"
        
        # Afficher résumé rapide
        Write-ColorOutput "`n📊 État actuel de la base:" "Cyan"
        $summaryQuery = @"
SELECT 
    'recording' as table_name, COUNT(*) as row_count FROM musicbrainz.recording
UNION ALL SELECT 'artist', COUNT(*) FROM musicbrainz.artist
UNION ALL SELECT 'work', COUNT(*) FROM musicbrainz.work
UNION ALL SELECT 'release', COUNT(*) FROM musicbrainz.release;
"@
        docker exec $DBContainer psql -U $DBUser -d $DBName -c $summaryQuery
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        $durationFormatted = "{0:mm} min {0:ss} sec" -f $duration
        
        Write-ColorOutput "`n✅ Import déjà terminé - Aucune action nécessaire" "Green"
        Write-ColorOutput "⏱️  Durée de vérification: $durationFormatted" "Cyan"
        Write-ColorOutput ""
        exit 0
    } else {
        Write-ColorOutput "  ℹ️  Base de données vide - import nécessaire" "Cyan"
    }
} else {
    Write-ColorOutput "  ⚠️  Impossible de vérifier les données existantes" "Yellow"
    Write-ColorOutput "  ℹ️  Procédure d'import lancée" "Cyan"
}

# ============================================================================
# ÉTAPE 5/7: Lancement de l'import officiel
# ============================================================================

Write-ColorOutput "`n🚀 Étape 5/7: Lancement de l'import officiel MusicBrainz..." "Yellow"
Write-ColorOutput "  ⏱️  Durée estimée: 3-6 heures" "Cyan"
Write-ColorOutput "  📝 Les logs seront enregistrés dans /logs/import_musicbrainz_official.log" "Cyan"
Write-ColorOutput ""

# Créer le répertoire de logs si nécessaire
docker exec $MusicBrainzContainer bash -c "mkdir -p /logs" 2>&1 | Out-Null

# Exécuter createdb.sh (script officiel MetaBrainz)
# Note: createdb.sh utilise les dumps dans /media/dbdump par défaut si présents
# Ne pas utiliser -fetch pour éviter de retélécharger
Write-ColorOutput "  🔄 Exécution de createdb.sh (script officiel MetaBrainz)..." "Cyan"
Write-ColorOutput "  (Cette étape peut prendre plusieurs heures)" "Yellow"
Write-ColorOutput "  📝 Suivez la progression avec: docker exec $MusicBrainzContainer tail -f /logs/import_musicbrainz_official.log" "Cyan"
Write-ColorOutput "  ℹ️  Utilisation des dumps dans /media/dbdump..." "Cyan"
Write-ColorOutput ""

# Vérifier si les schémas existent mais sont vides
Write-ColorOutput "  🔍 Vérification de l'état de la base..." "Cyan"
$hasData = docker exec $DBContainer psql -U $DBUser -d $DBName -t -A -c "SELECT COUNT(*) FROM musicbrainz.recording;" 2>&1
$hasDataInt = 0
if ($LASTEXITCODE -eq 0 -and $hasData) {
    $hasDataStr = if ($hasData -is [array]) { 
        ($hasData | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim() 
    } else { 
        $hasData.ToString().Trim() 
    }
    $hasDataInt = [int]($hasDataStr -replace '\D','')
}

# Si les schémas existent mais sont vides, utiliser MBImport.pl directement
if ($hasDataInt -eq 0) {
    Write-ColorOutput "  ℹ️  Schémas existants mais vides - utilisation de MBImport.pl directement..." "Cyan"
    
    # Créer le répertoire tmp dans un volume en écriture
    docker exec $MusicBrainzContainer bash -c "mkdir -p /tmp/mbimport" 2>&1 | Out-Null
    
    # Importer tous les dumps un par un
    $dumpFiles = @(
        "mbdump.tar.bz2",
        "mbdump-cdstubs.tar.bz2",
        "mbdump-cover-art-archive.tar.bz2",
        "mbdump-event-art-archive.tar.bz2",
        "mbdump-derived.tar.bz2",
        "mbdump-stats.tar.bz2",
        "mbdump-wikidocs.tar.bz2"
    )
    
    $importSuccess = $true
    foreach ($dumpFile in $dumpFiles) {
        Write-ColorOutput "  📦 Import de $dumpFile..." "Cyan"
        $importCmd = "cd /media/dbdump && carton exec -- /musicbrainz-server/admin/MBImport.pl --tmp-dir /tmp/mbimport --skip-editor $dumpFile 2>&1 | tee -a /logs/import_musicbrainz_official.log"
        $importResult = docker exec $MusicBrainzContainer bash -c $importCmd
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "    ⚠️  Erreur lors de l'import de $dumpFile" "Yellow"
            if ($importResult) {
                $importResult | Select-Object -Last 5 | ForEach-Object { Write-ColorOutput "      $_" "Gray" }
            }
            # Continuer avec les autres dumps (certains peuvent être optionnels)
        } else {
            Write-ColorOutput "    ✅ $dumpFile importé" "Green"
        }
    }
    
    # Nettoyer le répertoire temporaire
    docker exec $MusicBrainzContainer bash -c "rm -rf /tmp/mbimport" 2>&1 | Out-Null
    
    Write-ColorOutput "`n  ✅ Import terminé" "Green"
} else {
    # Utiliser createdb.sh normalement
    Write-ColorOutput "  🔄 Démarrage de createdb.sh (script officiel MetaBrainz)..." "Cyan"
    Write-ColorOutput "  ℹ️  Utilisation des dumps dans /media/dbdump..." "Cyan"
    Write-ColorOutput ""
    
    $importCmd = "cd /media/dbdump && /usr/local/bin/createdb.sh 2>&1 | tee /logs/import_musicbrainz_official.log"
    $importResult = docker exec $MusicBrainzContainer bash -c $importCmd
    
    # Afficher les dernières lignes de la sortie
    if ($importResult) {
        Write-ColorOutput "`n  📋 Dernières lignes de la sortie:" "Cyan"
        $importResult | Select-Object -Last 10 | ForEach-Object { Write-ColorOutput "    $_" "Gray" }
    }
    
    $importExitCode = $LASTEXITCODE
    if ($importExitCode -eq 0) {
        Write-ColorOutput "`n  ✅ Commande createdb.sh terminée avec succès" "Green"
    } else {
        Write-ColorOutput "`n  ⚠️  Commande createdb.sh terminée avec code: $importExitCode" "Yellow"
    }
}

Write-ColorOutput "  ℹ️  Vérification des données importées..." "Cyan"

# ============================================================================
# ÉTAPE 6/7: Vérification de la taille et du comptage
# ============================================================================

Write-ColorOutput "`n📊 Étape 6/7: Vérification de l'import..." "Yellow"

# Attendre quelques secondes pour que PostgreSQL finalise les écritures
Start-Sleep -Seconds 5

# Vérifier la taille du volume
Write-ColorOutput "  📦 Vérification de la taille du volume PostgreSQL..." "Cyan"
$volumeSize = docker exec $DBContainer du -sh /var/lib/postgresql/data 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "    $volumeSize" "White"
    # Extraire la taille en Go pour vérification
    if ($volumeSize -match '(\d+(?:\.\d+)?)G') {
        $sizeGB = [double]$matches[1]
        if ($sizeGB -lt 60) {
            Write-ColorOutput "    ⚠️  Taille inférieure à 60 Go - l'import peut être incomplet" "Yellow"
        } else {
            Write-ColorOutput "    ✅ Taille supérieure à 60 Go" "Green"
        }
    }
} else {
    Write-ColorOutput "    ⚠️  Impossible de déterminer la taille" "Yellow"
}

# Vérifier le nombre d'enregistrements
Write-ColorOutput "  📈 Vérification du nombre d'enregistrements..." "Cyan"
$finalCountRaw = docker exec $DBContainer psql -U $DBUser -d $DBName -t -A -c $recordingCountQuery 2>&1

if ($LASTEXITCODE -eq 0) {
    # Extraire la valeur numérique (gérer le cas où c'est un tableau)
    $finalCountStr = if ($finalCountRaw -is [array]) { 
        ($finalCountRaw | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim() 
    } else { 
        $finalCountRaw.ToString().Trim() 
    }
    $finalCountInt = [int]($finalCountStr -replace '\D','')
    if ($finalCountInt -gt 0) {
        $formatted = if ($finalCountInt -ge 1000000) { 
            "{0:N1}M" -f ($finalCountInt / 1000000) 
        } elseif ($finalCountInt -ge 1000) { 
            "{0:N0}K" -f ($finalCountInt / 1000) 
        } else { 
            $finalCountInt.ToString() 
        }
        Write-ColorOutput "    ✅ Enregistrements: $formatted ($finalCountInt)" "Green"
        
        if ($finalCountInt -lt 1000000) {
            Write-ColorOutput "    ⚠️  Nombre d'enregistrements faible - l'import peut être incomplet" "Yellow"
        }
    } else {
        Write-ColorOutput "    ❌ Aucun enregistrement trouvé - l'import a probablement échoué" "Red"
        Write-ColorOutput "    💡 Consultez les logs: docker exec $MusicBrainzContainer cat /logs/import_musicbrainz_official.log" "Cyan"
        exit 1
    }
} else {
    Write-ColorOutput "    ❌ Erreur lors de la vérification" "Red"
    exit 1
}

# Afficher quelques statistiques supplémentaires
Write-ColorOutput "`n  📊 Statistiques supplémentaires:" "Cyan"
$statsQuery = @"
SELECT 
    'artist' as table_name, COUNT(*) as row_count FROM musicbrainz.artist
UNION ALL SELECT 'work', COUNT(*) FROM musicbrainz.work
UNION ALL SELECT 'release', COUNT(*) FROM musicbrainz.release
UNION ALL SELECT 'isrc', COUNT(*) FROM musicbrainz.isrc
UNION ALL SELECT 'iswc', COUNT(*) FROM musicbrainz.iswc;
"@
docker exec $DBContainer psql -U $DBUser -d $DBName -c $statsQuery

# ============================================================================
# ÉTAPE 7/7: Résumé final
# ============================================================================

$endTime = Get-Date
$duration = $endTime - $startTime
$hours = [math]::Floor($duration.TotalHours)
$minutes = $duration.Minutes
$seconds = $duration.Seconds
$durationFormatted = if ($hours -gt 0) { 
    "$hours h $minutes min $seconds sec" 
} else { 
    "$minutes min $seconds sec" 
}

Write-ColorOutput "`n✅ Import Complet MusicBrainz terminé avec succès!" "Green"
Write-ColorOutput "========================================================" "Green"
Write-ColorOutput ""
Write-ColorOutput "📊 Résumé:" "Cyan"
Write-ColorOutput "  - Enregistrements: $formatted ($finalCountInt)" "White"
Write-ColorOutput "  - Taille volume: $volumeSize" "White"
Write-ColorOutput "  - Durée d'exécution: $durationFormatted" "White"
Write-ColorOutput ""
Write-ColorOutput "📂 Logs disponibles:" "Cyan"
Write-ColorOutput "  docker exec $MusicBrainzContainer cat /logs/import_musicbrainz_official.log" "White"
Write-ColorOutput ""
Write-ColorOutput "🚀 Prochaines étapes:" "Cyan"
Write-ColorOutput "  1. Créer le schéma KPI: Get-Content sql\init\00_schema.sql | docker exec -i $DBContainer psql -U $DBUser -d $DBName" "White"
Write-ColorOutput "  2. Appliquer les vues: .\scripts\apply_views.ps1" "White"
Write-ColorOutput "  3. Tester les vues: Get-Content scripts\tests.sql | docker exec -i $DBContainer psql -U $DBUser -d $DBName" "White"
Write-ColorOutput ""
Write-ColorOutput "✅ Base de données prête pour les vues allfeat_kpi." "Green"
Write-ColorOutput ""

