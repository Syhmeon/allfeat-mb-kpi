#!/bin/bash
# Script d'application des vues KPI Allfeat
# Usage: ./scripts/apply_views.sh

set -e

# Configuration
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-musicbrainz}
DB_USER=${DB_USER:-musicbrainz}
SQL_DIR=${SQL_DIR:-./sql}

echo "🚀 Application des vues KPI Allfeat..."

# Vérifier que PostgreSQL est accessible
echo "📡 Vérification de la connexion PostgreSQL..."
if ! pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; then
    echo "❌ PostgreSQL n'est pas accessible. Vérifiez que Docker est démarré."
    exit 1
fi

# Vérifier que le schéma existe
echo "🗄️  Vérification du schéma allfeat_kpi..."
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM allfeat_kpi.metadata LIMIT 1;" >/dev/null 2>&1; then
    echo "❌ Le schéma allfeat_kpi n'existe pas. Exécutez d'abord: psql -f sql/init/00_schema.sql"
    exit 1
fi

# Appliquer les vues dans l'ordre
echo "📊 Application des vues KPI..."

echo "  - Couverture ISRC..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/10_kpi_isrc_coverage.sql

echo "  - Couverture ISWC..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/20_kpi_iswc_coverage.sql

echo "  - IDs manquants artistes..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/30_party_missing_ids_artist.sql

echo "  - Candidats doublons ISRC..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/40_dup_isrc_candidates.sql

echo "  - Enregistrements sans œuvres..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/50_rec_on_release_without_work.sql

echo "  - Œuvres sans enregistrements..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/51_work_without_recording.sql

echo "  - Confiance artistes..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/60_confidence_artist.sql

echo "  - Confiance œuvres..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/61_confidence_work.sql

echo "  - Confiance enregistrements..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/62_confidence_recording.sql

echo "  - Confiance releases..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/views/63_confidence_release.sql

# Mettre à jour les métadonnées
echo "📝 Mise à jour des métadonnées..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
UPDATE allfeat_kpi.metadata 
SET value = NOW()::TEXT, updated_at = NOW() 
WHERE key = 'views_applied_at';

INSERT INTO allfeat_kpi.metadata (key, value) 
VALUES ('views_applied_at', NOW()::TEXT)
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = NOW();
"

# Lister les vues créées
echo "📋 Vues KPI créées:"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT schemaname, viewname, definition 
FROM pg_views 
WHERE schemaname = 'allfeat_kpi' 
ORDER BY viewname;
"

echo "✅ Vues KPI appliquées avec succès!"
echo "🔍 Vous pouvez maintenant tester avec: psql -f scripts/smoke_tests.sql"
