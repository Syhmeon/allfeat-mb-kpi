-- KPI 1: Couverture ISRC (International Standard Recording Code)
-- Mesure le pourcentage d'enregistrements avec codes ISRC
-- Usage: SELECT * FROM allfeat_kpi.kpi_isrc_coverage;

CREATE OR REPLACE VIEW allfeat_kpi.kpi_isrc_coverage AS
WITH isrc_stats AS (
    SELECT 
        COUNT(DISTINCT r.id) as total_recordings,
        COUNT(DISTINCT i.recording) as recordings_with_isrc,
        COUNT(DISTINCT i.isrc) as unique_isrcs,
        COUNT(DISTINCT r.id) - COUNT(DISTINCT i.recording) as recordings_without_isrc
    FROM musicbrainz.recording r
    LEFT JOIN musicbrainz.isrc i ON r.id = i.recording
    WHERE r.edits_pending = 0  -- Exclure les enregistrements en cours d'édition
),
isrc_duplicates AS (
    SELECT 
        i.isrc,
        COUNT(DISTINCT i.recording) as duplicate_count
    FROM musicbrainz.isrc i
    INNER JOIN musicbrainz.recording r ON i.recording = r.id
    WHERE i.isrc IS NOT NULL 
      AND r.edits_pending = 0
    GROUP BY i.isrc
    HAVING COUNT(DISTINCT i.recording) > 1
)
SELECT 
    -- Statistiques générales
    s.total_recordings,
    s.recordings_with_isrc,
    s.recordings_without_isrc,
    s.unique_isrcs,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.recordings_with_isrc::NUMERIC, s.total_recordings::NUMERIC) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_without_isrc::NUMERIC, s.total_recordings::NUMERIC) as missing_isrc_pct,
    
    -- Statistiques sur les doublons
    COALESCE(COUNT(d.isrc), 0) as duplicate_isrc_count,
    COALESCE(SUM(d.duplicate_count), 0) as total_duplicate_recordings,
    allfeat_kpi.format_percentage(COALESCE(SUM(d.duplicate_count), 0)::NUMERIC, s.recordings_with_isrc::NUMERIC) as duplicate_rate_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM isrc_stats s
LEFT JOIN isrc_duplicates d ON 1=1
GROUP BY s.total_recordings, s.recordings_with_isrc, s.recordings_without_isrc, s.unique_isrcs;

-- Vue détaillée pour les échantillons
CREATE OR REPLACE VIEW allfeat_kpi.kpi_isrc_coverage_samples AS
SELECT * FROM (
    SELECT 
        'Recordings without ISRC' as sample_type,
        r.id as recording_id,
        r.name as recording_name,
        r.gid as recording_gid,
        a.name as artist_name,
        a.gid as artist_gid
    FROM musicbrainz.recording r
    LEFT JOIN musicbrainz.isrc i ON r.id = i.recording
    LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
    LEFT JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
    LEFT JOIN musicbrainz.artist a ON acn.artist = a.id
    WHERE i.recording IS NULL 
      AND r.edits_pending = 0
      AND a.type = 1  -- Person only

    UNION ALL

    SELECT 
        'Duplicate ISRCs' as sample_type,
        r.id as recording_id,
        r.name as recording_name,
        r.gid as recording_gid,
        a.name as artist_name,
        a.gid as artist_gid
    FROM musicbrainz.recording r
    INNER JOIN musicbrainz.isrc i ON r.id = i.recording
    LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
    LEFT JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
    LEFT JOIN musicbrainz.artist a ON acn.artist = a.id
    WHERE i.isrc IN (
        SELECT isrc 
        FROM musicbrainz.isrc i2
        INNER JOIN musicbrainz.recording r2 ON i2.recording = r2.id
        WHERE i2.isrc IS NOT NULL 
          AND r2.edits_pending = 0
        GROUP BY i2.isrc 
        HAVING COUNT(DISTINCT i2.recording) > 1
    )
    AND r.edits_pending = 0
    AND a.type = 1  -- Person only
) sub
ORDER BY RANDOM()
LIMIT 20;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.kpi_isrc_coverage IS 'KPI principal: Couverture ISRC des enregistrements avec statistiques de doublons';
COMMENT ON VIEW allfeat_kpi.kpi_isrc_coverage_samples IS 'Échantillons d''enregistrements sans ISRC et avec ISRC dupliqués pour analyse détaillée';
