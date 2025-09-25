-- KPI 1: Couverture ISRC (International Standard Recording Code)
-- Mesure le pourcentage d'enregistrements avec codes ISRC
-- Usage: SELECT * FROM allfeat_kpi.kpi_isrc_coverage;

CREATE OR REPLACE VIEW allfeat_kpi.kpi_isrc_coverage AS
WITH isrc_stats AS (
    SELECT 
        COUNT(*) as total_recordings,
        COUNT(isrc) as recordings_with_isrc,
        COUNT(DISTINCT isrc) as unique_isrcs,
        COUNT(*) - COUNT(isrc) as recordings_without_isrc
    FROM musicbrainz.recording
    WHERE edits_pending = 0  -- Exclure les enregistrements en cours d'édition
),
isrc_duplicates AS (
    SELECT 
        isrc,
        COUNT(*) as duplicate_count
    FROM musicbrainz.recording
    WHERE isrc IS NOT NULL 
      AND edits_pending = 0
    GROUP BY isrc
    HAVING COUNT(*) > 1
)
SELECT 
    -- Statistiques générales
    s.total_recordings,
    s.recordings_with_isrc,
    s.recordings_without_isrc,
    s.unique_isrcs,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.recordings_with_isrc, s.total_recordings) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_without_isrc, s.total_recordings) as missing_isrc_pct,
    
    -- Statistiques sur les doublons
    COALESCE(COUNT(d.isrc), 0) as duplicate_isrc_count,
    COALESCE(SUM(d.duplicate_count), 0) as total_duplicate_recordings,
    allfeat_kpi.format_percentage(COALESCE(SUM(d.duplicate_count), 0), s.recordings_with_isrc) as duplicate_rate_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM isrc_stats s
LEFT JOIN isrc_duplicates d ON 1=1
GROUP BY s.total_recordings, s.recordings_with_isrc, s.recordings_without_isrc, s.unique_isrcs;

-- Vue détaillée pour les échantillons
CREATE OR REPLACE VIEW allfeat_kpi.kpi_isrc_coverage_samples AS
SELECT 
    'Recordings without ISRC' as sample_type,
    r.id as recording_id,
    r.name as recording_name,
    r.gid as recording_gid,
    a.name as artist_name,
    a.gid as artist_gid
FROM musicbrainz.recording r
LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
LEFT JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
LEFT JOIN musicbrainz.artist a ON acn.artist = a.id
WHERE r.isrc IS NULL 
  AND r.edits_pending = 0
  AND a.type = 1  -- Person only
ORDER BY RANDOM()
LIMIT 20

UNION ALL

SELECT 
    'Duplicate ISRCs' as sample_type,
    r.id as recording_id,
    r.name as recording_name,
    r.gid as recording_gid,
    a.name as artist_name,
    a.gid as artist_gid
FROM musicbrainz.recording r
LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
LEFT JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
LEFT JOIN musicbrainz.artist a ON acn.artist = a.id
WHERE r.isrc IN (
    SELECT isrc 
    FROM musicbrainz.recording 
    WHERE isrc IS NOT NULL 
      AND edits_pending = 0
    GROUP BY isrc 
    HAVING COUNT(*) > 1
)
AND r.edits_pending = 0
AND a.type = 1  -- Person only
ORDER BY RANDOM()
LIMIT 20;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.kpi_isrc_coverage IS 'KPI principal: Couverture ISRC des enregistrements avec statistiques de doublons';
COMMENT ON VIEW allfeat_kpi.kpi_isrc_coverage_samples IS 'Échantillons d''enregistrements sans ISRC et avec ISRC dupliqués pour analyse détaillée';
