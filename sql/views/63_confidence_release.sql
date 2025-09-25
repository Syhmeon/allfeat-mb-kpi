-- KPI 6d: Niveaux de confiance - Releases
-- Analyse la qualité et complétude des données releases selon la hiérarchie de confiance
-- Usage: SELECT * FROM allfeat_kpi.confidence_release;

CREATE OR REPLACE VIEW allfeat_kpi.confidence_release AS
WITH release_confidence_factors AS (
    SELECT 
        r.id,
        r.name,
        r.gid,
        r.date_year,
        r.date_month,
        r.date_day,
        r.country,
        r.comment,
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
            WHEN r.date_year IS NOT NULL THEN 15 ELSE 0 
        END as date_score,
        
        CASE 
            WHEN r.country IS NOT NULL THEN 10 ELSE 0 
        END as country_score,
        
        CASE 
            WHEN r.comment IS NOT NULL AND LENGTH(TRIM(r.comment)) > 0 THEN 5 ELSE 0 
        END as comment_score,
        
        CASE 
            WHEN r.edits_pending = 0 THEN 10 ELSE 0 
        END as edits_pending_score,
        
        -- Score pour les mediums associés
        CASE 
            WHEN EXISTS (SELECT 1 FROM musicbrainz.medium WHERE release = r.id) THEN 10 ELSE 0 
        END as medium_score,
        
        -- Score pour le release group associé
        CASE 
            WHEN r.release_group IS NOT NULL THEN 5 ELSE 0 
        END as release_group_score
    FROM musicbrainz.release r
),
release_confidence_summary AS (
    SELECT 
        SUM(rcf.gid_score + rcf.name_score + rcf.date_score + 
            rcf.country_score + rcf.comment_score + rcf.edits_pending_score + 
            rcf.medium_score + rcf.release_group_score) as total_confidence_score,
        COUNT(*) as total_releases,
        COUNT(*) FILTER (WHERE rcf.gid_score > 0) as releases_with_gid,
        COUNT(*) FILTER (WHERE rcf.name_score > 0) as releases_with_name,
        COUNT(*) FILTER (WHERE rcf.date_score > 0) as releases_with_date,
        COUNT(*) FILTER (WHERE rcf.country_score > 0) as releases_with_country,
        COUNT(*) FILTER (WHERE rcf.comment_score > 0) as releases_with_comment,
        COUNT(*) FILTER (WHERE rcf.edits_pending_score > 0) as releases_without_pending_edits,
        COUNT(*) FILTER (WHERE rcf.medium_score > 0) as releases_with_medium,
        COUNT(*) FILTER (WHERE rcf.release_group_score > 0) as releases_with_release_group
    FROM release_confidence_factors rcf
)
SELECT 
    -- Statistiques générales
    s.total_releases,
    s.total_confidence_score,
    ROUND(s.total_confidence_score / (s.total_releases * 100.0), 2) as average_confidence_score,
    
    -- Détail des facteurs de confiance
    s.releases_with_gid,
    s.releases_with_name,
    s.releases_with_date,
    s.releases_with_country,
    s.releases_with_comment,
    s.releases_without_pending_edits,
    s.releases_with_medium,
    s.releases_with_release_group,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.releases_with_gid, s.total_releases) as gid_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_name, s.total_releases) as name_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_date, s.total_releases) as date_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_country, s.total_releases) as country_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_comment, s.total_releases) as comment_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_without_pending_edits, s.total_releases) as no_pending_edits_pct,
    allfeat_kpi.format_percentage(s.releases_with_medium, s.total_releases) as medium_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_release_group, s.total_releases) as release_group_coverage_pct,
    
    -- Classification globale
    CASE 
        WHEN ROUND(s.total_confidence_score / (s.total_releases * 100.0), 2) >= 80 THEN 'High Confidence'
        WHEN ROUND(s.total_confidence_score / (s.total_releases * 100.0), 2) >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM release_confidence_summary s;

-- Vue détaillée pour les échantillons de releases par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_release_samples AS
WITH release_confidence_factors AS (
    SELECT 
        r.id,
        r.name,
        r.gid,
        r.date_year,
        r.date_month,
        r.date_day,
        r.country,
        r.comment,
        r.edits_pending,
        r.last_updated,
        
        -- Calcul du score de confiance total
        (
            CASE WHEN r.gid IS NOT NULL THEN 25 ELSE 0 END +
            CASE WHEN r.name IS NOT NULL AND LENGTH(TRIM(r.name)) > 0 THEN 20 ELSE 0 END +
            CASE WHEN r.date_year IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN r.country IS NOT NULL THEN 10 ELSE 0 END +
            CASE WHEN r.comment IS NOT NULL AND LENGTH(TRIM(r.comment)) > 0 THEN 5 ELSE 0 END +
            CASE WHEN r.edits_pending = 0 THEN 10 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM musicbrainz.medium WHERE release = r.id) THEN 10 ELSE 0 END +
            CASE WHEN r.release_group IS NOT NULL THEN 5 ELSE 0 END
        ) as confidence_score
    FROM musicbrainz.release r
)
SELECT 
    rcf.id as release_id,
    rcf.name as release_name,
    rcf.gid as release_gid,
    rcf.date_year,
    rcf.date_month,
    rcf.date_day,
    rcf.country,
    rcf.comment,
    rcf.edits_pending,
    rcf.confidence_score,
    CASE 
        WHEN rcf.confidence_score >= 80 THEN 'High Confidence'
        WHEN rcf.confidence_score >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as confidence_level,
    rcf.last_updated
FROM release_confidence_factors rcf
ORDER BY rcf.confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_release IS 'KPI principal: Niveaux de confiance des données releases avec facteurs détaillés';
COMMENT ON VIEW allfeat_kpi.confidence_release_samples IS 'Échantillons de releases classées par niveau de confiance pour analyse détaillée';
