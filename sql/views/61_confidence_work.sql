-- KPI 6b: Niveaux de confiance - Œuvres
-- Analyse la qualité et complétude des données œuvres selon la hiérarchie de confiance
-- Usage: SELECT * FROM allfeat_kpi.confidence_work;

CREATE OR REPLACE VIEW allfeat_kpi.confidence_work AS
WITH work_confidence_factors AS (
    SELECT 
        w.id,
        w.name,
        w.gid,
        w.type,
        w.language_code,
        w.comment,
        w.iswc,
        w.edits_pending,
        w.last_updated,
        
        -- Facteurs de confiance (score 0-100)
        CASE 
            WHEN w.gid IS NOT NULL THEN 25 ELSE 0 
        END as gid_score,
        
        CASE 
            WHEN w.name IS NOT NULL AND LENGTH(TRIM(w.name)) > 0 THEN 20 ELSE 0 
        END as name_score,
        
        CASE 
            WHEN w.type IS NOT NULL THEN 15 ELSE 0 
        END as type_score,
        
        CASE 
            WHEN w.language_code IS NOT NULL THEN 10 ELSE 0 
        END as language_score,
        
        CASE 
            WHEN w.iswc IS NOT NULL THEN 15 ELSE 0 
        END as iswc_score,
        
        CASE 
            WHEN w.comment IS NOT NULL AND LENGTH(TRIM(w.comment)) > 0 THEN 5 ELSE 0 
        END as comment_score,
        
        CASE 
            WHEN w.edits_pending = 0 THEN 10 ELSE 0 
        END as edits_pending_score
    FROM musicbrainz.work w
),
work_confidence_summary AS (
    SELECT 
        SUM(wcf.gid_score + wcf.name_score + wcf.type_score + 
            wcf.language_score + wcf.iswc_score + wcf.comment_score + 
            wcf.edits_pending_score) as total_confidence_score,
        COUNT(*) as total_works,
        COUNT(*) FILTER (WHERE wcf.gid_score > 0) as works_with_gid,
        COUNT(*) FILTER (WHERE wcf.name_score > 0) as works_with_name,
        COUNT(*) FILTER (WHERE wcf.type_score > 0) as works_with_type,
        COUNT(*) FILTER (WHERE wcf.language_score > 0) as works_with_language,
        COUNT(*) FILTER (WHERE wcf.iswc_score > 0) as works_with_iswc,
        COUNT(*) FILTER (WHERE wcf.comment_score > 0) as works_with_comment,
        COUNT(*) FILTER (WHERE wcf.edits_pending_score > 0) as works_without_pending_edits
    FROM work_confidence_factors wcf
)
SELECT 
    -- Statistiques générales
    s.total_works,
    s.total_confidence_score,
    ROUND(s.total_confidence_score / (s.total_works * 100.0), 2) as average_confidence_score,
    
    -- Détail des facteurs de confiance
    s.works_with_gid,
    s.works_with_name,
    s.works_with_type,
    s.works_with_language,
    s.works_with_iswc,
    s.works_with_comment,
    s.works_without_pending_edits,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.works_with_gid, s.total_works) as gid_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_name, s.total_works) as name_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_type, s.total_works) as type_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_language, s.total_works) as language_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_iswc, s.total_works) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_comment, s.total_works) as comment_coverage_pct,
    allfeat_kpi.format_percentage(s.works_without_pending_edits, s.total_works) as no_pending_edits_pct,
    
    -- Classification globale
    CASE 
        WHEN ROUND(s.total_confidence_score / (s.total_works * 100.0), 2) >= 80 THEN 'High Confidence'
        WHEN ROUND(s.total_confidence_score / (s.total_works * 100.0), 2) >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM work_confidence_summary s;

-- Vue détaillée pour les échantillons d'œuvres par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_work_samples AS
WITH work_confidence_factors AS (
    SELECT 
        w.id,
        w.name,
        w.gid,
        w.type,
        w.language_code,
        w.comment,
        w.iswc,
        w.edits_pending,
        w.last_updated,
        
        -- Calcul du score de confiance total
        (
            CASE WHEN w.gid IS NOT NULL THEN 25 ELSE 0 END +
            CASE WHEN w.name IS NOT NULL AND LENGTH(TRIM(w.name)) > 0 THEN 20 ELSE 0 END +
            CASE WHEN w.type IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN w.language_code IS NOT NULL THEN 10 ELSE 0 END +
            CASE WHEN w.iswc IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN w.comment IS NOT NULL AND LENGTH(TRIM(w.comment)) > 0 THEN 5 ELSE 0 END +
            CASE WHEN w.edits_pending = 0 THEN 10 ELSE 0 END
        ) as confidence_score
    FROM musicbrainz.work w
)
SELECT 
    wcf.id as work_id,
    wcf.name as work_name,
    wcf.gid as work_gid,
    wcf.type as work_type,
    wcf.language_code,
    wcf.comment,
    wcf.iswc,
    wcf.edits_pending,
    wcf.confidence_score,
    CASE 
        WHEN wcf.confidence_score >= 80 THEN 'High Confidence'
        WHEN wcf.confidence_score >= 60 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as confidence_level,
    wcf.last_updated
FROM work_confidence_factors wcf
ORDER BY wcf.confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_work IS 'KPI principal: Niveaux de confiance des données œuvres avec facteurs détaillés';
COMMENT ON VIEW allfeat_kpi.confidence_work_samples IS 'Échantillons d''œuvres classées par niveau de confiance pour analyse détaillée';
