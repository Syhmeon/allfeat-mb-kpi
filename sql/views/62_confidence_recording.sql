-- KPI 6c: Niveaux de confiance - Enregistrements
-- Analyse la qualité et complétude des données enregistrements selon la hiérarchie de confiance
-- Usage: SELECT * FROM allfeat_kpi.confidence_recording;

CREATE OR REPLACE VIEW allfeat_kpi.confidence_recording AS
WITH recording_confidence_factors AS (
    SELECT 
        r.id,
        r.name,
        r.gid,
        r.length,
        r.comment,
        r.isrc,
        r.edits_pending,
        r.last_updated,
        
        -- Facteurs de confiance (score 0-100)
        CASE 
            WHEN r.gid IS NOT NULL THEN 25 ELSE 0 
        END as gid_score,
        
        CASE 
            WHEN r.name IS NOT NULL AND LENGTH(TRIM(r.name)) > 0 THEN 20 ELSE 0 
        END as name_score,
        
        CASE 
            WHEN r.length IS NOT NULL AND r.length > 0 THEN 15 ELSE 0 
        END as length_score,
        
        CASE 
            WHEN r.isrc IS NOT NULL THEN 20 ELSE 0 
        END as isrc_score,
        
        CASE 
            WHEN r.comment IS NOT NULL AND LENGTH(TRIM(r.comment)) > 0 THEN 5 ELSE 0 
        END as comment_score,
        
        CASE 
            WHEN r.edits_pending = 0 THEN 10 ELSE 0 
        END as edits_pending_score,
        
        -- Score pour les œuvres associées
        CASE 
            WHEN EXISTS (SELECT 1 FROM musicbrainz.recording_work WHERE recording = r.id) THEN 5 ELSE 0 
        END as work_link_score
    FROM musicbrainz.recording r
),
recording_confidence_summary AS (
    SELECT 
        SUM(rcf.gid_score + rcf.name_score + rcf.length_score + 
            rcf.isrc_score + rcf.comment_score + rcf.edits_pending_score + 
            rcf.work_link_score) as total_confidence_score,
        COUNT(*) as total_recordings,
        COUNT(*) FILTER (WHERE rcf.gid_score > 0) as recordings_with_gid,
        COUNT(*) FILTER (WHERE rcf.name_score > 0) as recordings_with_name,
        COUNT(*) FILTER (WHERE rcf.length_score > 0) as recordings_with_length,
        COUNT(*) FILTER (WHERE rcf.isrc_score > 0) as recordings_with_isrc,
        COUNT(*) FILTER (WHERE rcf.comment_score > 0) as recordings_with_comment,
        COUNT(*) FILTER (WHERE rcf.edits_pending_score > 0) as recordings_without_pending_edits,
        COUNT(*) FILTER (WHERE rcf.work_link_score > 0) as recordings_with_work_link
    FROM recording_confidence_factors rcf
)
SELECT 
    -- Statistiques générales
    s.total_recordings,
    s.total_confidence_score,
    ROUND(s.total_confidence_score / (s.total_recordings * 100.0), 2) as average_confidence_score,
    
    -- Détail des facteurs de confiance
    s.recordings_with_gid,
    s.recordings_with_name,
    s.recordings_with_length,
    s.recordings_with_isrc,
    s.recordings_with_comment,
    s.recordings_without_pending_edits,
    s.recordings_with_work_link,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.recordings_with_gid, s.total_recordings) as gid_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_name, s.total_recordings) as name_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_length, s.total_recordings) as length_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_isrc, s.total_recordings) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_comment, s.total_recordings) as comment_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_without_pending_edits, s.total_recordings) as no_pending_edits_pct,
    allfeat_kpi.format_percentage(s.recordings_with_work_link, s.total_recordings) as work_link_coverage_pct,
    
    -- Classification globale
    CASE 
        WHEN ROUND(s.total_confidence_score / (s.total_recordings * 100.0), 2) >= 80 THEN 'High Confidence'
        WHEN ROUND(s.total_confidence_score / (s.total_recordings * 100.0), 2) >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM recording_confidence_summary s;

-- Vue détaillée pour les échantillons d'enregistrements par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_recording_samples AS
WITH recording_confidence_factors AS (
    SELECT 
        r.id,
        r.name,
        r.gid,
        r.length,
        r.comment,
        r.isrc,
        r.edits_pending,
        r.last_updated,
        
        -- Calcul du score de confiance total
        (
            CASE WHEN r.gid IS NOT NULL THEN 25 ELSE 0 END +
            CASE WHEN r.name IS NOT NULL AND LENGTH(TRIM(r.name)) > 0 THEN 20 ELSE 0 END +
            CASE WHEN r.length IS NOT NULL AND r.length > 0 THEN 15 ELSE 0 END +
            CASE WHEN r.isrc IS NOT NULL THEN 20 ELSE 0 END +
            CASE WHEN r.comment IS NOT NULL AND LENGTH(TRIM(r.comment)) > 0 THEN 5 ELSE 0 END +
            CASE WHEN r.edits_pending = 0 THEN 10 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM musicbrainz.recording_work WHERE recording = r.id) THEN 5 ELSE 0 END
        ) as confidence_score
    FROM musicbrainz.recording r
)
SELECT 
    rcf.id as recording_id,
    rcf.name as recording_name,
    rcf.gid as recording_gid,
    rcf.length,
    rcf.comment,
    rcf.isrc,
    rcf.edits_pending,
    rcf.confidence_score,
    CASE 
        WHEN rcf.confidence_score >= 80 THEN 'High Confidence'
        WHEN rcf.confidence_score >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as confidence_level,
    rcf.last_updated
FROM recording_confidence_factors rcf
ORDER BY rcf.confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_recording IS 'KPI principal: Niveaux de confiance des données enregistrements avec facteurs détaillés';
COMMENT ON VIEW allfeat_kpi.confidence_recording_samples IS 'Échantillons d''enregistrements classés par niveau de confiance pour analyse détaillée';
