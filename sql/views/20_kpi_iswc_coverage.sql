-- KPI 2: Couverture ISWC (International Standard Musical Work Code)
-- Mesure le pourcentage d'œuvres avec codes ISWC
-- Usage: SELECT * FROM allfeat_kpi.kpi_iswc_coverage;

CREATE OR REPLACE VIEW allfeat_kpi.kpi_iswc_coverage AS
WITH iswc_stats AS (
    SELECT 
        COUNT(DISTINCT w.id) as total_works,
        COUNT(DISTINCT i.work) as works_with_iswc,
        COUNT(DISTINCT i.iswc) as unique_iswcs,
        COUNT(DISTINCT w.id) - COUNT(DISTINCT i.work) as works_without_iswc
    FROM musicbrainz.work w
    LEFT JOIN musicbrainz.iswc i ON w.id = i.work
    WHERE w.edits_pending = 0  -- Exclure les œuvres en cours d'édition
),
iswc_duplicates AS (
    SELECT 
        i.iswc,
        COUNT(DISTINCT i.work) as duplicate_count
    FROM musicbrainz.iswc i
    INNER JOIN musicbrainz.work w ON i.work = w.id
    WHERE i.iswc IS NOT NULL 
      AND w.edits_pending = 0
    GROUP BY i.iswc
    HAVING COUNT(DISTINCT i.work) > 1
)
SELECT 
    -- Statistiques générales
    s.total_works,
    s.works_with_iswc,
    s.works_without_iswc,
    s.unique_iswcs,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.works_with_iswc::NUMERIC, s.total_works::NUMERIC) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_without_iswc::NUMERIC, s.total_works::NUMERIC) as missing_iswc_pct,
    
    -- Statistiques sur les doublons
    COALESCE(COUNT(d.iswc), 0) as duplicate_iswc_count,
    COALESCE(SUM(d.duplicate_count), 0) as total_duplicate_works,
    allfeat_kpi.format_percentage(COALESCE(SUM(d.duplicate_count), 0)::NUMERIC, s.works_with_iswc::NUMERIC) as duplicate_rate_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM iswc_stats s
LEFT JOIN iswc_duplicates d ON 1=1
GROUP BY s.total_works, s.works_with_iswc, s.works_without_iswc, s.unique_iswcs;

-- Vue détaillée pour les échantillons
CREATE OR REPLACE VIEW allfeat_kpi.kpi_iswc_coverage_samples AS
SELECT * FROM (
    SELECT 
        'Works without ISWC' as sample_type,
        w.id as work_id,
        w.name as work_name,
        w.gid as work_gid,
        w.type as work_type,
        NULL::integer as language_code
    FROM musicbrainz.work w
    LEFT JOIN musicbrainz.iswc i ON w.id = i.work
    WHERE i.work IS NULL 
      AND w.edits_pending = 0

    UNION ALL

    SELECT 
        'Duplicate ISWCs' as sample_type,
        w.id as work_id,
        w.name as work_name,
        w.gid as work_gid,
        w.type as work_type,
        NULL::integer as language_code
    FROM musicbrainz.work w
    INNER JOIN musicbrainz.iswc i ON w.id = i.work
    WHERE i.iswc IN (
        SELECT iswc 
        FROM musicbrainz.iswc i2
        INNER JOIN musicbrainz.work w2 ON i2.work = w2.id
        WHERE i2.iswc IS NOT NULL 
          AND w2.edits_pending = 0
        GROUP BY i2.iswc 
        HAVING COUNT(DISTINCT i2.work) > 1
    )
    AND w.edits_pending = 0
) sub
ORDER BY RANDOM()
LIMIT 20;

-- Vue alternative: ISWC par colonne (pour analyse détaillée)
CREATE OR REPLACE VIEW allfeat_kpi.kpi_iswc_detailed AS
SELECT 
    w.id as work_id,
    w.name as work_name,
    w.gid as work_gid,
    i.iswc,
    w.type as work_type,
    NULL::integer as language_code,
    w.comment,
    CASE 
        WHEN i.work IS NULL THEN 'Missing ISWC'
        WHEN i.iswc IN (
            SELECT iswc 
            FROM musicbrainz.iswc i2
            INNER JOIN musicbrainz.work w2 ON i2.work = w2.id
            WHERE i2.iswc IS NOT NULL 
              AND w2.edits_pending = 0
            GROUP BY i2.iswc 
            HAVING COUNT(DISTINCT i2.work) > 1
        ) THEN 'Duplicate ISWC'
        ELSE 'Unique ISWC'
    END as iswc_status,
    w.edits_pending,
    w.last_updated
FROM musicbrainz.work w
LEFT JOIN musicbrainz.iswc i ON w.id = i.work
WHERE w.edits_pending = 0
ORDER BY w.last_updated DESC;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.kpi_iswc_coverage IS 'KPI principal: Couverture ISWC des œuvres avec statistiques de doublons';
COMMENT ON VIEW allfeat_kpi.kpi_iswc_coverage_samples IS 'Échantillons d''œuvres sans ISWC et avec ISWC dupliqués pour analyse détaillée';
COMMENT ON VIEW allfeat_kpi.kpi_iswc_detailed IS 'Vue détaillée par œuvre avec statut ISWC pour analyse approfondie';
