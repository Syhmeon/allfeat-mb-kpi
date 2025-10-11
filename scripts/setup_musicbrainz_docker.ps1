# Setup MusicBrainz Docker Official pour KPI Analysis
# Version: 1.0
# Date: 2025-10-11
# Usage: .\scripts\setup_musicbrainz_docker.ps1

param(
    [switch]$SkipEnvCheck = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Setup MusicBrainz Docker Officiel (v30)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Vérifier Docker Desktop
Write-Host "🐳 Vérification de Docker Desktop..." -ForegroundColor Yellow
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if (-not $dockerVersion) {
        throw "Docker non détecté"
    }
    Write-Host "✅ Docker version: $dockerVersion" -ForegroundColor Green
    
    $composeVersion = docker compose version --short 2>$null
    Write-Host "✅ Docker Compose version: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Desktop n'est pas démarré" -ForegroundColor Red
    Write-Host "   Veuillez démarrer Docker Desktop et réessayer" -ForegroundColor Yellow
    exit 1
}

# Vérifier l'espace disque
Write-Host ""
Write-Host "💾 Vérification de l'espace disque..." -ForegroundColor Yellow
$drive = (Get-Location).Drive
$freeSpace = (Get-PSDrive $drive.Name).Free / 1GB
Write-Host "   Espace libre sur $($drive.Name): : $([math]::Round($freeSpace, 2)) GB" -ForegroundColor Cyan

if ($freeSpace -lt 100) {
    Write-Host "⚠️  Avertissement: Espace disque faible (<100 GB)" -ForegroundColor Yellow
    Write-Host "   Recommandé: 100+ GB pour MusicBrainz complet" -ForegroundColor Yellow
    if (-not $Force) {
        $continue = Read-Host "   Continuer quand même? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "   Installation annulée" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "✅ Espace disque suffisant" -ForegroundColor Green
}

# Vérifier/Créer fichier .env
Write-Host ""
Write-Host "📝 Configuration de l'environnement..." -ForegroundColor Yellow
if (-not (Test-Path ".env") -or $Force) {
    Write-Host "   Création du fichier .env depuis env.example..." -ForegroundColor Cyan
    Copy-Item "env.example" ".env" -Force
    Write-Host "✅ Fichier .env créé" -ForegroundColor Green
} else {
    Write-Host "✅ Fichier .env existe déjà" -ForegroundColor Green
}

# Arrêter les conteneurs existants
Write-Host ""
Write-Host "🛑 Arrêt des conteneurs existants..." -ForegroundColor Yellow
try {
    $existing = docker ps -a --filter "name=musicbrainz" --format "{{.Names}}" 2>$null
    if ($existing) {
        Write-Host "   Conteneurs trouvés: $existing" -ForegroundColor Cyan
        docker compose down 2>$null
        Write-Host "✅ Conteneurs arrêtés" -ForegroundColor Green
    } else {
        Write-Host "✅ Aucun conteneur existant" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Erreur lors de l'arrêt des conteneurs (ignorée)" -ForegroundColor Yellow
}

# Pull de l'image MusicBrainz
Write-Host ""
Write-Host "📥 Téléchargement de l'image MusicBrainz Docker..." -ForegroundColor Yellow
Write-Host "   Cela peut prendre quelques minutes..." -ForegroundColor Cyan
try {
    docker compose pull
    Write-Host "✅ Image téléchargée" -ForegroundColor Green
} catch {
    Write-Host "❌ Échec du téléchargement de l'image" -ForegroundColor Red
    Write-Host "   Vérifiez votre connexion Internet et réessayez" -ForegroundColor Yellow
    exit 1
}

# Démarrer les conteneurs
Write-Host ""
Write-Host "🚀 Démarrage de MusicBrainz Docker..." -ForegroundColor Yellow
Write-Host "   ⏳ L'import initial prendra 2-6 heures" -ForegroundColor Cyan
Write-Host "   📊 Taille finale: ~80 GB" -ForegroundColor Cyan
Write-Host ""
try {
    docker compose up -d
    Write-Host "✅ Conteneurs démarrés" -ForegroundColor Green
} catch {
    Write-Host "❌ Échec du démarrage des conteneurs" -ForegroundColor Red
    Write-Host "   Consultez les logs avec: docker compose logs" -ForegroundColor Yellow
    exit 1
}

# Afficher le statut
Write-Host ""
Write-Host "📊 Statut des conteneurs:" -ForegroundColor Yellow
docker compose ps

# Instructions finales
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "✅ Setup MusicBrainz Docker terminé!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "📌 Prochaines étapes:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  Suivre la progression de l'import:" -ForegroundColor White
Write-Host "   docker compose logs -f musicbrainz-db" -ForegroundColor Gray
Write-Host ""
Write-Host "2️⃣  Vérifier l'état de la base (après import):" -ForegroundColor White
Write-Host "   docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c 'SELECT version();'" -ForegroundColor Gray
Write-Host ""
Write-Host "3️⃣  Appliquer les vues KPI (après import):" -ForegroundColor White
Write-Host "   docker exec -i musicbrainz-db psql -U musicbrainz -d musicbrainz_db < sql/init/00_schema.sql" -ForegroundColor Gray
Write-Host "   .\scripts\apply_views.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "4️⃣  Lancer les tests:" -ForegroundColor White
Write-Host "   docker exec -i musicbrainz-db psql -U musicbrainz -d musicbrainz_db < scripts/tests.sql" -ForegroundColor Gray
Write-Host ""
Write-Host "⏱️  Estimation de l'import: 2-6 heures" -ForegroundColor Yellow
Write-Host "💾 Espace utilisé final: ~80 GB" -ForegroundColor Yellow
Write-Host "🌐 Connexion PostgreSQL: localhost:5432" -ForegroundColor Yellow
Write-Host ""
Write-Host "📚 Documentation complète: README.md" -ForegroundColor Cyan
Write-Host ""

