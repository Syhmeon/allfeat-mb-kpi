# Script d'import MusicBrainz pour Windows PowerShell (via Docker)
# Usage: .\scripts\import_mb.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$DUMPS_DIR = "E:\mbdump",
    [string]$CONTAINER_NAME = "musicbrainz-postgres"
)

Write-Host "🚀 Début de l'import MusicBrainz via Docker..." -ForegroundColor Green

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

# Vérifier la présence du répertoire DUMPS_DIR
Write-Host "📁 Vérification du répertoire $DUMPS_DIR..." -ForegroundColor Yellow
if (-not (Test-Path $DUMPS_DIR)) {
    Write-Host "❌ Répertoire $DUMPS_DIR introuvable" -ForegroundColor Red
    Write-Host "💡 Vérifiez le chemin vers vos fichiers MusicBrainz extraits" -ForegroundColor Cyan
    exit 1
}

# Trouver les fichiers MusicBrainz extraits (sans extension)
$dumpFiles = Get-ChildItem -Path $DUMPS_DIR -File | Where-Object { $_.Extension -eq "" }
if ($dumpFiles.Count -eq 0) {
    Write-Host "❌ Aucun fichier MusicBrainz trouvé dans $DUMPS_DIR" -ForegroundColor Red
    Write-Host "💡 Vérifiez que le répertoire MusicBrainz contient des fichiers sans extension" -ForegroundColor Cyan
    exit 1
}

Write-Host "📦 Trouvé $($dumpFiles.Count) fichiers à importer depuis $DUMPS_DIR" -ForegroundColor Green

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
            
            # Vérifier si c'est le bon répervoir monté
            if ($mount.Source -eq $DUMPS_DIR) {
                $correctMount = $true
                Write-Host "✅ Le bon répertoire est monté ($DUMPS_DIR)" -ForegroundColor Green
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

# Importer chaque fichier MusicBrainz
Write-Host "📥 Import des fichiers MusicBrainz (cela peut prendre plusieurs heures)..." -ForegroundColor Yellow
Write-Host "⏳ Cette étape peut prendre plusieurs heures selon la taille des fichiers..." -ForegroundColor Cyan

$totalFiles = $dumpFiles.Count
$successCount = 0
$failedFiles = @()

for ($i = 0; $i -lt $totalFiles; $i++) {
    $file = $dumpFiles[$i]
    $fileNumber = $i + 1
    
    Write-Host "📄 [$fileNumber/$totalFiles] Import en cours: $($file.Name)..." -ForegroundColor Cyan
    Write-Host "   📁 Chemin Windows: $($file.FullName)" -ForegroundColor DarkGray
    Write-Host "   🐳 Chemin conteneur: /dumps/$($file.Name)" -ForegroundColor DarkGray
    
    try {
        # Utiliser docker exec pour importer le fichier via psql dans le conteneur
        $result = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -f "/dumps/$($file.Name)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Host "✅ [$fileNumber/$totalFiles] $($file.Name) importé avec succès" -ForegroundColor Green
        } else {
            $failedFiles += $file.Name
            Write-Host "❌ [$fileNumber/$totalFiles] Erreur lors de l'import de $($file.Name)" -ForegroundColor Red
            Write-Host "   📝 Message d'erreur: $result" -ForegroundColor Red
            Write-Host "   🛑 Arrêt de l'importation..." -ForegroundColor Red
            exit 1
        }
    } catch {
        $failedFiles += $file.Name
        Write-Host "❌ [$fileNumber/$totalFiles] Exception lors de l'import de $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
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

# Analyser les statistiques
Write-Host "📊 Mise à jour des statistiques..." -ForegroundColor Yellow
try {
    docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "ANALYZE;"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Analyse terminée" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Avertissement: Erreur lors de l'analyse" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Avertissement: Exception lors de l'analyse" -ForegroundColor Yellow
}

Write-Host "✅ Import MusicBrainz terminé avec succès!" -ForegroundColor Green
Write-Host "🔍 Vous pouvez maintenant créer les vues KPI avec: .\scripts\apply_views.ps1" -ForegroundColor Cyan
Write-Host "📊 Base de données accessible via le conteneur: $CONTAINER_NAME" -ForegroundColor Cyan