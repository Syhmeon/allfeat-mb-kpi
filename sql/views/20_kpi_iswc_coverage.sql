-- KPI 2: Couverture ISWC (International Standard Musical Work Code)
-- Mesure le pourcentage d'œuvres avec codes ISWC
-- Usage: SELECT * FROM allfeat_kpi.kpi_iswc_coverage;

CREATE OR REPLACE VIEW allfeat_kpi.kpi_iswc_coverage AS
WITH iswc_stats AS (
    SELECT 
        COUNT(*) as total_works,
        COUNT(iswc) as works_with_iswc,
        COUNT(DISTINCT iswc) as unique_iswcs,
        COUNT(*) - COUNT(iswc) as works_without_iswc
    FROM musicbrainz.work
    WHERE edits_pending = 0  -- Exclure les œuvres en cours d'édition
),
iswc_duplicates AS (
    SELECT 
        iswc,
        COUNT(*) as duplicate_count
    FROM musicbrainz.work
    WHERE iswc IS NOT NULL 
      AND edits_pending = 0
    GROUP BY iswc
    HAVING COUNT(*) > 1
)
SELECT 
    -- Statistiques générales
    s.total_works,
    s.works_with_iswc,
    s.works_without_iswc,
    s.unique_iswcs,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.works_with_iswc, s.total_works) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_without_iswc, s.total_works) as missing_iswc_pct,
    
    -- Statistiques sur les doublons
    COALESCE(COUNT(d.iswc), 0) as duplicate_iswc_count,
    COALESCE(SUM(d.duplicate_count), 0) as total_duplicate_works,
    allfeat_kpi.format_percentage(COALESCE(SUM(d.duplicate_count), 0), s.works_with_iswc) as duplicate_rate_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM iswc_stats s
LEFT JOIN iswc_duplicates d ON 1=1
GROUP BY s.total_works, s.works_with_iswc, s.works_without_iswc, s.unique_iswcs;

-- Vue détaillée pour les échantillons
CREATE OR REPLACE VIEW allfeat_kpi.kpi_iswc_coverage_samples AS
SELECT 
    'Works without ISWC' as sample_type,
    w.id as work_id,
    w.name as work_name,
    w.gid as work_gid,
    w.type as work_type,
    w.language_code
FROM musicbrainz.work w
WHERE w.iswc IS NULL 
  AND w.edits_pending = 0
ORDER BY RANDOM()
LIMIT 20

UNION ALL

SELECT 
    'Duplicate ISWCs' as sample_type,
    w.id as work_id,
    w.name as work_name,
    w.gid as work_gid,
    w.type as work_type,
    w.language_code
FROM musicbrainz.work w
WHERE w.iswc IN (
    SELECT iswc 
    FROM musicbrainz.work 
    WHERE iswc IS NOT NULL 
      AND edits_pending = 0
    GROUP BY iswc 
    HAVING COUNT(*) > 1
)
AND w.edits_pending = 0
ORDER BY RANDOM()
LIMIT 20;

-- Vue alternative: ISWC par colonne (pour analyse détaillée)
CREATE OR REPLACE VIEW allfeat_kpi.kpi_iswc_detailed AS
SELECT 
    w.id as work_id,
    w.name as work_name,
    w.gid as work_gid,
    w.iswc,
    w.type as work_type,
    w.language_code,
    w.comment,
    CASE 
        WHEN w.iswc IS NULL THEN 'Missing ISWC'
        WHEN w.iswc IN (
            SELECT iswc 
            FROM musicbrainz.work 
            WHERE iswc IS NOT NULL 
              AND edits_pending = 0
            GROUP BY iswc 
            HAVING COUNT(*) > 1
        ) THEN 'Duplicate ISWC'
        ELSE 'Unique ISWC'
    END as iswc_status,
    w.edits_pending,
    w.last_updated
FROM musicbrainz.work w
WHERE w.edits_pending = 0
ORDER BY w.last_updated DESC;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.kpi_iswc_coverage IS 'KPI principal: Couverture ISWC des œuvres avec statistiques de doublons';
COMMENT ON VIEW allfeat_kpi.kpi_iswc_coverage_samples IS 'Échantillons d''œuvres sans ISWC et avec ISWC dupliqués pour analyse détaillée';
COMMENT ON VIEW allfeat_kpi.kpi_iswc_detailed IS 'Vue détaillée par œuvre avec statut ISWC pour analyse approfondie';
