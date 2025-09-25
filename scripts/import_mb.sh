#!/bin/bash
# Script d'import MusicBrainz pour Linux/Mac
# Usage: ./scripts/import_mb.sh

set -e

# Configuration
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-musicbrainz}
DB_USER=${DB_USER:-musicbrainz}
DUMPS_DIR=${DUMPS_DIR:-./dumps}

echo "🚀 Début de l'import MusicBrainz..."

# Vérifier que PostgreSQL est accessible
echo "📡 Vérification de la connexion PostgreSQL..."
if ! pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; then
    echo "❌ PostgreSQL n'est pas accessible. Vérifiez que Docker est démarré."
    exit 1
fi

# Vérifier la présence des dumps
echo "📁 Vérification des fichiers dump..."
if [ ! -d "$DUMPS_DIR" ]; then
    echo "❌ Répertoire $DUMPS_DIR introuvable"
    exit 1
fi

# Trouver les fichiers dump
DUMP_FILE=$(find $DUMPS_DIR -name "*.dump" | head -1)
if [ -z "$DUMP_FILE" ]; then
    echo "❌ Aucun fichier .dump trouvé dans $DUMPS_DIR"
    echo "💡 Téléchargez le dump depuis https://musicbrainz.org/doc/MusicBrainz_Database/Download"
    exit 1
fi

echo "📦 Fichier dump trouvé: $DUMP_FILE"

# Créer la base de données si elle n'existe pas
echo "🗄️  Création de la base de données..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Base de données existe déjà"

# Restaurer le dump
echo "📥 Restauration du dump MusicBrainz (cela peut prendre plusieurs heures)..."
pg_restore -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v --no-owner --no-privileges "$DUMP_FILE"

# Créer les extensions nécessaires
echo "🔧 Installation des extensions PostgreSQL..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
"

# Analyser les statistiques
echo "📊 Mise à jour des statistiques..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "ANALYZE;"

echo "✅ Import MusicBrainz terminé avec succès!"
echo "🔍 Vous pouvez maintenant créer les vues KPI avec: ./scripts/apply_views.sh"
