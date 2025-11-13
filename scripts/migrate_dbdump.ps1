# Script de migration automatique des dumps MusicBrainz
# Version: 2.0 (optimisée - flux direct entre containers)
# Date: 2025-01-XX
# Usage: .\scripts\migrate_dbdump.ps1
#
# Migre les dumps depuis /data (ancien emplacement) vers /media/dbdump (volume partagé)
# Utilise un flux direct tar pour éviter les copies via le disque local

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n🔁 Migration des dumps MusicBrainz vers le volume partagé" "Cyan"
Write-ColorOutput "========================================================" "Cyan"
Write-ColorOutput ""

# ============================================================================
# 1. Détection des containers
# ============================================================================

Write-ColorOutput "📦 Étape 1/5: Détection des containers..." "Yellow"

# Détecter le container DB
$dbContainer = docker ps --filter "name=musicbrainz-db" --format "{{.Names}}" 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dbContainer)) {
    Write-ColorOutput "❌ Container musicbrainz-db non trouvé ou non en cours d'exécution." "Red"
    Write-ColorOutput "💡 Démarrez les containers avec: docker compose up -d" "Cyan"
    exit 10
}
$dbContainer = $dbContainer.Trim()
Write-ColorOutput "  ✅ Container DB trouvé: $dbContainer" "Green"

# Détecter le container MusicBrainz server
$serverContainer = docker ps --filter "ancestor=metabrainz/musicbrainz-docker-musicbrainz" --format "{{.Names}}" 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($serverContainer)) {
    Write-ColorOutput "❌ Container MusicBrainz server non trouvé ou non en cours d'exécution." "Red"
    Write-ColorOutput "💡 Démarrez les containers avec: docker compose up -d" "Cyan"
    exit 10
}
$serverContainer = ($serverContainer -split "`n" | Select-Object -First 1).Trim()
Write-ColorOutput "  ✅ Container server trouvé: $serverContainer" "Green"

# ============================================================================
# 2. Vérifications préalables
# ============================================================================

Write-ColorOutput "`n🔍 Étape 2/5: Vérifications préalables..." "Yellow"

# Vérifier que /data existe dans le container DB
$dataExists = docker exec $dbContainer bash -c "[ -d /data ]" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "  ℹ️  Le répertoire /data n'existe pas dans $dbContainer" "Cyan"
    Write-ColorOutput "  ✅ Aucune migration nécessaire" "Green"
    exit 0
}
Write-ColorOutput "  ✅ Répertoire /data existe dans $dbContainer" "Green"

# Vérifier que /media/dbdump existe dans le container server
$targetExists = docker exec $serverContainer bash -c "[ -d /media/dbdump ]" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "  ❌ Le répertoire /media/dbdump n'existe pas dans $serverContainer" "Red"
    Write-ColorOutput "  🔧 Création du répertoire..." "Cyan"
    docker exec $serverContainer bash -c "mkdir -p /media/dbdump" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "  ❌ Impossible de créer /media/dbdump" "Red"
        exit 10
    }
}
Write-ColorOutput "  ✅ Répertoire /media/dbdump existe dans $serverContainer" "Green"

# ============================================================================
# 3. Vérification idempotente
# ============================================================================

Write-ColorOutput "`n🔍 Étape 3/5: Vérification idempotente..." "Yellow"

# Lister les dumps dans /media/dbdump (destination)
$serverDumps = docker exec $serverContainer bash -c "ls /media/dbdump/*.tar.bz2 2>/dev/null" 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -and $serverDumps -match 'mbdump\.tar\.bz2') {
    Write-ColorOutput "  ✅ Dumps déjà présents dans /media/dbdump — migration ignorée" "Green"
    Write-ColorOutput "  📋 Dumps disponibles:" "Cyan"
    docker exec $serverContainer bash -c "ls -lh /media/dbdump/*.tar.bz2 2>/dev/null" 2>&1 | ForEach-Object {
        if ($_ -match '(\S+\.tar\.bz2)') {
            Write-ColorOutput "    - $($matches[1])" "Gray"
        }
    }
    Write-ColorOutput "`n✅ Migration non nécessaire — dumps déjà en place" "Green"
    exit 0
}

# Lister les dumps dans /data (source)
$dbDumps = docker exec $dbContainer bash -c "ls /data/*.tar.bz2 2>/dev/null" 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dbDumps)) {
    Write-ColorOutput "  ❌ Aucun dump trouvé dans /data — rien à migrer" "Red"
    exit 12
}

# Compter les dumps à migrer
$dumpList = ($dbDumps -split "`n" | Where-Object { $_.Trim() -ne "" })
$dumpCount = $dumpList.Count
Write-ColorOutput "  ✅ $dumpCount dump(s) trouvé(s) dans /data" "Green"
Write-ColorOutput "  📋 Dumps à migrer:" "Cyan"
$dumpList | ForEach-Object {
    $fileName = Split-Path $_.Trim() -Leaf
    Write-ColorOutput "    - $fileName" "Gray"
}

# ============================================================================
# 4. Migration via flux direct
# ============================================================================

Write-ColorOutput "`n📦 Étape 4/5: Migration des dumps via flux direct..." "Yellow"
Write-ColorOutput "  🔄 Copie de ${dbContainer}:/data → ${serverContainer}:/media/dbdump" "Cyan"
Write-ColorOutput "  ⚡ Utilisation d'un flux direct (pas de fichiers temporaires)" "Cyan"
Write-ColorOutput "  ⏳ Cette opération peut prendre quelques minutes..." "Yellow"
Write-ColorOutput ""

# Migration via flux tar direct (stream entre containers)
# tar -cf - crée une archive et l'envoie sur stdout
# tar -xf - extrait depuis stdin
Write-ColorOutput "  🔄 Création du flux depuis /data..." "Cyan"
$migrationCmd = "cd /data && tar -cf - . 2>/dev/null"
$extractCmd = "cd /media/dbdump && tar -xf - 2>/dev/null"

# Exécuter la migration via pipe PowerShell
$migrationResult = docker exec $dbContainer bash -c $migrationCmd 2>&1 | docker exec -i $serverContainer bash -c $extractCmd 2>&1

# Vérifier le résultat
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "  ✅ Migration terminée avec succès" "Green"
} else {
    Write-ColorOutput "  ❌ Erreur lors de la migration" "Red"
    Write-ColorOutput "  💡 Vérifiez les logs ci-dessus" "Cyan"
    exit 13
}

# ============================================================================
# 5. Vérification post-migration
# ============================================================================

Write-ColorOutput "`n✅ Étape 5/5: Vérification post-migration..." "Yellow"

# Vérifier depuis le container server
Write-ColorOutput "  🔍 Vérification depuis $serverContainer..." "Cyan"
$serverCheck = docker exec $serverContainer bash -c "ls -lh /media/dbdump/*.tar.bz2 2>/dev/null" 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($serverCheck)) {
    Write-ColorOutput "  ❌ Aucun dump trouvé dans /media/dbdump après migration" "Red"
    exit 13
}

$serverDumpCount = ($serverCheck -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
Write-ColorOutput "    ✅ $serverDumpCount dump(s) visible(s) depuis $serverContainer" "Green"

# Vérifier depuis le container DB
Write-ColorOutput "  🔍 Vérification depuis $dbContainer..." "Cyan"
$dbCheck = docker exec $dbContainer bash -c "ls -lh /media/dbdump/*.tar.bz2 2>/dev/null" 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dbCheck)) {
    Write-ColorOutput "    ⚠️  Dumps non encore visibles depuis $dbContainer" "Yellow"
    Write-ColorOutput "    ℹ️  Normal si le container n'a pas été redémarré après le montage" "Cyan"
} else {
    $dbDumpCount = ($dbCheck -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
    Write-ColorOutput "    ✅ $dbDumpCount dump(s) visible(s) depuis $dbContainer" "Green"
}

# Afficher la liste des dumps migrés
Write-ColorOutput "`n  📋 Dumps disponibles dans /media/dbdump:" "Cyan"
$serverCheck | ForEach-Object {
    if ($_ -match '(\S+\.tar\.bz2)') {
        Write-ColorOutput "    - $($matches[1])" "Gray"
    }
}

# ============================================================================
# Résumé final
# ============================================================================

Write-ColorOutput "`n🎯 Migration terminée avec succès!" "Green"
Write-ColorOutput "========================================================" "Green"
Write-ColorOutput ""
Write-ColorOutput "✅ Les dumps sont désormais accessibles aux deux containers via /media/dbdump" "Green"
Write-ColorOutput ""
Write-ColorOutput "🚀 Prochaine étape:" "Cyan"
Write-ColorOutput "  .\scripts\import_musicbrainz_official.ps1" "White"
Write-ColorOutput ""

exit 0
