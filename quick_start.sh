#!/bin/bash
# Script de démarrage rapide Allfeat MusicBrainz KPI
# Usage: ./quick_start.sh

set -e

echo "🚀 Démarrage rapide Allfeat MusicBrainz KPI"
echo "============================================="

# Vérifier les prérequis
echo "📋 Vérification des prérequis..."

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez installer Docker Desktop."
    exit 1
fi

# Vérifier docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose n'est pas installé. Veuillez installer docker-compose."
    exit 1
fi

# Vérifier psql
if ! command -v psql &> /dev/null; then
    echo "❌ psql n'est pas installé. Veuillez installer PostgreSQL client."
    exit 1
fi

echo "✅ Prérequis vérifiés"

# Configuration
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-musicbrainz}
DB_USER=${DB_USER:-musicbrainz}

# Étape 1: Démarrer PostgreSQL
echo "🐳 Démarrage de PostgreSQL..."
if [ ! -f ".env" ]; then
    echo "📝 Création du fichier .env..."
    cp env.example .env
fi

docker compose up -d

# Attendre que PostgreSQL soit prêt
echo "⏳ Attente du démarrage de PostgreSQL..."
sleep 10

# Vérifier que PostgreSQL est accessible
echo "🔍 Vérification de la connexion PostgreSQL..."
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER >/dev/null 2>&1; then
        echo "✅ PostgreSQL est accessible"
        break
    fi
    echo "⏳ Tentative $attempt/$max_attempts..."
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ Impossible de se connecter à PostgreSQL après $max_attempts tentatives"
    echo "🔍 Vérifiez les logs: docker compose logs postgres"
    exit 1
fi

# Étape 2: Vérifier si le dump est importé
echo "🗄️  Vérification de l'import MusicBrainz..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM musicbrainz.artist LIMIT 1;" >/dev/null 2>&1; then
    echo "✅ Dump MusicBrainz détecté"
else
    echo "⚠️  Dump MusicBrainz non détecté"
    echo "📥 Veuillez importer le dump MusicBrainz:"
    echo "   1. Téléchargez le dump depuis https://musicbrainz.org/doc/MusicBrainz_Database/Download"
    echo "   2. Placez-le dans ./dumps/"
    echo "   3. Exécutez: ./scripts/import_mb.sh"
    echo ""
    echo "🔄 Continuons avec la configuration du schéma..."
fi

# Étape 3: Créer le schéma KPI
echo "📊 Création du schéma allfeat_kpi..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM allfeat_kpi.metadata LIMIT 1;" >/dev/null 2>&1; then
    echo "✅ Schéma allfeat_kpi existe déjà"
else
    echo "🔧 Création du schéma allfeat_kpi..."
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f sql/init/00_schema.sql
    echo "✅ Schéma allfeat_kpi créé"
fi

# Étape 4: Appliquer les vues KPI
echo "📈 Application des vues KPI..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM allfeat_kpi.kpi_isrc_coverage LIMIT 1;" >/dev/null 2>&1; then
    echo "✅ Vues KPI existent déjà"
else
    echo "🔧 Application des vues KPI..."
    ./scripts/apply_views.sh
    echo "✅ Vues KPI appliquées"
fi

# Étape 5: Tests de validation
echo "🧪 Tests de validation..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f scripts/tests.sql >/dev/null 2>&1; then
    echo "✅ Tests de validation réussis"
else
    echo "⚠️  Certains tests ont échoué. Vérifiez les logs."
fi

# Étape 6: Affichage des informations de connexion
echo ""
echo "🎉 Installation terminée!"
echo "========================="
echo ""
echo "📊 Informations de connexion:"
echo "   Host: $DB_HOST"
echo "   Port: $DB_PORT"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo "   Password: musicbrainz"
echo ""
echo "🔗 Commandes utiles:"
echo "   Connexion: psql -h $DB_HOST -U $DB_USER -d $DB_NAME"
echo "   Tests: psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f scripts/tests.sql"
echo ""
echo "📋 Vues KPI disponibles:"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT viewname 
FROM pg_views 
WHERE schemaname = 'allfeat_kpi' 
ORDER BY viewname;
" 2>/dev/null || echo "   (Vues non encore créées)"
echo ""
echo "📖 Documentation:"
echo "   - Guide complet: docs/README.md"
echo "   - Guide ODBC Windows: docs/ODBC_Windows_guide.md"
echo "   - Configuration Excel: excel/PowerQuery_Configuration.md"
echo ""
echo "🚀 Vous êtes prêt à utiliser les vues KPI Allfeat!"
