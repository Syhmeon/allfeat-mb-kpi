-- KPI 6a: Niveaux de confiance - Artistes
-- Analyse la qualité et complétude des données artistes selon la hiérarchie de confiance
-- Usage: SELECT * FROM allfeat_kpi.confidence_artist;

CREATE OR REPLACE VIEW allfeat_kpi.confidence_artist AS
WITH artist_confidence_factors AS (
    SELECT 
        a.id,
        a.name,
        a.gid,
        a.sort_name,
        a.type,
        a.begin_date,
        a.end_date,
        a.area,
        a.edits_pending,
        a.last_updated,
        
        -- Facteurs de confiance (score 0-100)
        CASE 
            WHEN a.gid IS NOT NULL THEN 20 ELSE 0 
        END as gid_score,
        
        CASE 
            WHEN a.name IS NOT NULL AND LENGTH(TRIM(a.name)) > 0 THEN 15 ELSE 0 
        END as name_score,
        
        CASE 
            WHEN a.sort_name IS NOT NULL AND LENGTH(TRIM(a.sort_name)) > 0 THEN 10 ELSE 0 
        END as sort_name_score,
        
        CASE 
            WHEN a.begin_date IS NOT NULL THEN 10 ELSE 0 
        END as begin_date_score,
        
        CASE 
            WHEN a.area IS NOT NULL THEN 10 ELSE 0 
        END as area_score,
        
        CASE 
            WHEN a.comment IS NOT NULL AND LENGTH(TRIM(a.comment)) > 0 THEN 5 ELSE 0 
        END as comment_score,
        
        CASE 
            WHEN a.edits_pending = 0 THEN 10 ELSE 0 
        END as edits_pending_score,
        
        -- Score pour les identifiants externes
        CASE 
            WHEN EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = a.id) THEN 10 ELSE 0 
        END as ipi_score,
        
        CASE 
            WHEN EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = a.id) THEN 10 ELSE 0 
        END as isni_score
    FROM musicbrainz.artist a
    WHERE a.type = 1  -- Person only
),
artist_confidence_summary AS (
    SELECT 
        SUM(acf.gid_score + acf.name_score + acf.sort_name_score + 
            acf.begin_date_score + acf.area_score + acf.comment_score + 
            acf.edits_pending_score + acf.ipi_score + acf.isni_score) as total_confidence_score,
        COUNT(*) as total_artists,
        COUNT(*) FILTER (WHERE acf.gid_score > 0) as artists_with_gid,
        COUNT(*) FILTER (WHERE acf.name_score > 0) as artists_with_name,
        COUNT(*) FILTER (WHERE acf.sort_name_score > 0) as artists_with_sort_name,
        COUNT(*) FILTER (WHERE acf.begin_date_score > 0) as artists_with_begin_date,
        COUNT(*) FILTER (WHERE acf.area_score > 0) as artists_with_area,
        COUNT(*) FILTER (WHERE acf.comment_score > 0) as artists_with_comment,
        COUNT(*) FILTER (WHERE acf.edits_pending_score > 0) as artists_without_pending_edits,
        COUNT(*) FILTER (WHERE acf.ipi_score > 0) as artists_with_ipi,
        COUNT(*) FILTER (WHERE acf.isni_score > 0) as artists_with_isni
    FROM artist_confidence_factors acf
)
SELECT 
    -- Statistiques générales
    s.total_artists,
    s.total_confidence_score,
    ROUND(s.total_confidence_score / (s.total_artists * 100.0), 2) as average_confidence_score,
    
    -- Détail des facteurs de confiance
    s.artists_with_gid,
    s.artists_with_name,
    s.artists_with_sort_name,
    s.artists_with_begin_date,
    s.artists_with_area,
    s.artists_with_comment,
    s.artists_without_pending_edits,
    s.artists_with_ipi,
    s.artists_with_isni,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.artists_with_gid, s.total_artists) as gid_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_name, s.total_artists) as name_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_sort_name, s.total_artists) as sort_name_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_begin_date, s.total_artists) as begin_date_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_area, s.total_artists) as area_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_comment, s.total_artists) as comment_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_without_pending_edits, s.total_artists) as no_pending_edits_pct,
    allfeat_kpi.format_percentage(s.artists_with_ipi, s.total_artists) as ipi_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_isni, s.total_artists) as isni_coverage_pct,
    
    -- Classification globale
    CASE 
        WHEN ROUND(s.total_confidence_score / (s.total_artists * 100.0), 2) >= 80 THEN 'High Confidence'
        WHEN ROUND(s.total_confidence_score / (s.total_artists * 100.0), 2) >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM artist_confidence_summary s;

-- Vue détaillée pour les échantillons d'artistes par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_artist_samples AS
WITH artist_confidence_factors AS (
    SELECT 
        a.id,
        a.name,
        a.gid,
        a.sort_name,
        a.type,
        a.begin_date,
        a.end_date,
        a.area,
        a.comment,
        a.edits_pending,
        a.last_updated,
        
        -- Calcul du score de confiance total
        (
            CASE WHEN a.gid IS NOT NULL THEN 20 ELSE 0 END +
            CASE WHEN a.name IS NOT NULL AND LENGTH(TRIM(a.name)) > 0 THEN 15 ELSE 0 END +
            CASE WHEN a.sort_name IS NOT NULL AND LENGTH(TRIM(a.sort_name)) > 0 THEN 10 ELSE 0 END +
            CASE WHEN a.begin_date IS NOT NULL THEN 10 ELSE 0 END +
            CASE WHEN a.area IS NOT NULL THEN 10 ELSE 0 END +
            CASE WHEN a.comment IS NOT NULL AND LENGTH(TRIM(a.comment)) > 0 THEN 5 ELSE 0 END +
            CASE WHEN a.edits_pending = 0 THEN 10 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = a.id) THEN 10 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = a.id) THEN 10 ELSE 0 END
        ) as confidence_score
    FROM musicbrainz.artist a
    WHERE a.type = 1  -- Person only
)
SELECT 
    acf.id as artist_id,
    acf.name as artist_name,
    acf.gid as artist_gid,
    acf.sort_name,
    acf.begin_date,
    acf.end_date,
    acf.area,
    acf.comment,
    acf.edits_pending,
    acf.confidence_score,
    CASE 
        WHEN acf.confidence_score >= 80 THEN 'High Confidence'
        WHEN acf.confidence_score >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as confidence_level,
    acf.last_updated
FROM artist_confidence_factors acf
ORDER BY acf.confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_artist IS 'KPI principal: Niveaux de confiance des données artistes avec facteurs détaillés';
COMMENT ON VIEW allfeat_kpi.confidence_artist_samples IS 'Échantillons d''artistes classés par niveau de confiance pour analyse détaillée';
