-- Création du schéma allfeat_kpi pour les KPI MusicBrainz
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f sql/init/00_schema.sql

-- Créer le schéma allfeat_kpi
CREATE SCHEMA IF NOT EXISTS allfeat_kpi;

-- Commentaire sur le schéma
COMMENT ON SCHEMA allfeat_kpi IS 'Schéma dédié aux KPI Allfeat pour analyser la qualité des métadonnées MusicBrainz';

-- Créer une table de métadonnées pour tracker les versions des vues
CREATE TABLE IF NOT EXISTS allfeat_kpi.metadata (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insérer les métadonnées initiales
INSERT INTO allfeat_kpi.metadata (key, value) VALUES 
    ('schema_version', '1.0.0'),
    ('created_at', NOW()::TEXT),
    ('description', 'Phase 1: KPI Artistes uniquement (labels en backlog)')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = NOW();

-- Créer une vue utilitaire pour les statistiques générales
CREATE OR REPLACE VIEW allfeat_kpi.stats_overview AS
SELECT 
    'Artists' as entity_type,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE gid IS NOT NULL) as with_gid,
    ROUND(COUNT(*) FILTER (WHERE gid IS NOT NULL) * 100.0 / COUNT(*), 2) as gid_coverage_pct
FROM musicbrainz.artist
WHERE type = 1  -- Person only
UNION ALL
SELECT 
    'Works' as entity_type,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE gid IS NOT NULL) as with_gid,
    ROUND(COUNT(*) FILTER (WHERE gid IS NOT NULL) * 100.0 / COUNT(*), 2) as gid_coverage_pct
FROM musicbrainz.work
UNION ALL
SELECT 
    'Recordings' as entity_type,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE gid IS NOT NULL) as with_gid,
    ROUND(COUNT(*) FILTER (WHERE gid IS NOT NULL) * 100.0 / COUNT(*), 2) as gid_coverage_pct
FROM musicbrainz.recording
UNION ALL
SELECT 
    'Releases' as entity_type,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE gid IS NOT NULL) as with_gid,
    ROUND(COUNT(*) FILTER (WHERE gid IS NOT NULL) * 100.0 / COUNT(*), 2) as gid_coverage_pct
FROM musicbrainz.release;

-- Commentaire sur la vue
COMMENT ON VIEW allfeat_kpi.stats_overview IS 'Vue d''ensemble des statistiques générales par type d''entité';

-- Créer une fonction utilitaire pour formater les pourcentages
CREATE OR REPLACE FUNCTION allfeat_kpi.format_percentage(numerator BIGINT, denominator BIGINT)
RETURNS DECIMAL(5,2) AS $$
BEGIN
    IF denominator = 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(numerator * 100.0 / denominator, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Commentaire sur la fonction
COMMENT ON FUNCTION allfeat_kpi.format_percentage(BIGINT, BIGINT) IS 'Fonction utilitaire pour calculer et formater les pourcentages';

-- Créer une fonction pour obtenir un échantillon aléatoire
CREATE OR REPLACE FUNCTION allfeat_kpi.random_sample(table_name TEXT, sample_size INTEGER DEFAULT 10)
RETURNS TABLE(sample_data TEXT) AS $$
BEGIN
    RETURN QUERY EXECUTE format('
        SELECT row_to_json(t)::TEXT 
        FROM (
            SELECT * FROM %I 
            ORDER BY RANDOM() 
            LIMIT %s
        ) t', table_name, sample_size);
END;
$$ LANGUAGE plpgsql;

-- Commentaire sur la fonction
COMMENT ON FUNCTION allfeat_kpi.random_sample(TEXT, INTEGER) IS 'Fonction utilitaire pour obtenir un échantillon aléatoire d''une table';

-- Afficher un message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Schéma allfeat_kpi créé avec succès!';
    RAISE NOTICE '📊 Vue stats_overview disponible pour les statistiques générales';
    RAISE NOTICE '🔧 Fonctions utilitaires format_percentage et random_sample créées';
END $$;
