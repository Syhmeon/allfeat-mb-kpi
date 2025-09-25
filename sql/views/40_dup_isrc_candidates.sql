-- KPI 4: Candidats doublons ISRC
-- Détecte les codes ISRC potentiellement dupliqués avec analyse de similarité
-- Usage: SELECT * FROM allfeat_kpi.dup_isrc_candidates;

CREATE OR REPLACE VIEW allfeat_kpi.dup_isrc_candidates AS
WITH isrc_groups AS (
    SELECT 
        isrc,
        COUNT(*) as duplicate_count,
        ARRAY_AGG(r.id ORDER BY r.id) as recording_ids,
        ARRAY_AGG(r.name ORDER BY r.id) as recording_names,
        ARRAY_AGG(r.gid ORDER BY r.id) as recording_gids,
        ARRAY_AGG(ac.name ORDER BY r.id) as artist_credits,
        ARRAY_AGG(r.length ORDER BY r.id) as lengths,
        ARRAY_AGG(r.comment ORDER BY r.id) as comments
    FROM musicbrainz.recording r
    LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
    WHERE r.isrc IS NOT NULL 
      AND r.edits_pending = 0
    GROUP BY isrc
    HAVING COUNT(*) > 1
),
isrc_analysis AS (
    SELECT 
        ig.isrc,
        ig.duplicate_count,
        ig.recording_ids,
        ig.recording_names,
        ig.artist_credits,
        ig.lengths,
        ig.comments,
        
        -- Analyse de similarité des noms (simplifiée)
        CASE 
            WHEN ig.duplicate_count = 2 THEN
                CASE 
                    WHEN LOWER(ig.recording_names[1]) = LOWER(ig.recording_names[2]) THEN 'Exact Match'
                    WHEN LOWER(ig.recording_names[1]) LIKE '%' || LOWER(ig.recording_names[2]) || '%' 
                      OR LOWER(ig.recording_names[2]) LIKE '%' || LOWER(ig.recording_names[1]) || '%' THEN 'Partial Match'
                    ELSE 'Different Names'
                END
            ELSE 'Multiple Duplicates'
        END as name_similarity,
        
        -- Analyse de similarité des artistes
        CASE 
            WHEN ig.duplicate_count = 2 THEN
                CASE 
                    WHEN LOWER(ig.artist_credits[1]) = LOWER(ig.artist_credits[2]) THEN 'Same Artist'
                    WHEN LOWER(ig.artist_credits[1]) LIKE '%' || LOWER(ig.artist_credits[2]) || '%' 
                      OR LOWER(ig.artist_credits[2]) LIKE '%' || LOWER(ig.artist_credits[1]) || '%' THEN 'Similar Artist'
                    ELSE 'Different Artists'
                END
            ELSE 'Multiple Artists'
        END as artist_similarity,
        
        -- Analyse des longueurs
        CASE 
            WHEN ig.duplicate_count = 2 THEN
                CASE 
                    WHEN ig.lengths[1] IS NULL OR ig.lengths[2] IS NULL THEN 'Unknown Length'
                    WHEN ABS(ig.lengths[1] - ig.lengths[2]) <= 5000 THEN 'Similar Length'  -- 5 secondes
                    ELSE 'Different Length'
                END
            ELSE 'Multiple Lengths'
        END as length_similarity,
        
        -- Score de risque de doublon (0-100)
        CASE 
            WHEN ig.duplicate_count = 2 THEN
                (
                    CASE WHEN LOWER(ig.recording_names[1]) = LOWER(ig.recording_names[2]) THEN 40 ELSE 0 END +
                    CASE WHEN LOWER(ig.artist_credits[1]) = LOWER(ig.artist_credits[2]) THEN 30 ELSE 0 END +
                    CASE WHEN ig.lengths[1] IS NOT NULL AND ig.lengths[2] IS NOT NULL 
                         AND ABS(ig.lengths[1] - ig.lengths[2]) <= 5000 THEN 20 ELSE 0 END +
                    CASE WHEN ig.comments[1] = ig.comments[2] THEN 10 ELSE 0 END
                )
            ELSE 50  -- Score par défaut pour plus de 2 doublons
        END as duplicate_risk_score
    FROM isrc_groups ig
)
SELECT 
    ia.isrc,
    ia.duplicate_count,
    ia.name_similarity,
    ia.artist_similarity,
    ia.length_similarity,
    ia.duplicate_risk_score,
    
    -- Classification du risque
    CASE 
        WHEN ia.duplicate_risk_score >= 80 THEN 'High Risk'
        WHEN ia.duplicate_risk_score >= 50 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_level,
    
    -- Données détaillées (limitées pour les vues légères)
    ia.recording_ids[1:3] as sample_recording_ids,  -- Limite à 3 pour éviter les vues trop lourdes
    ia.recording_names[1:3] as sample_recording_names,
    ia.artist_credits[1:3] as sample_artist_credits,
    ia.lengths[1:3] as sample_lengths,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM isrc_analysis ia
ORDER BY ia.duplicate_risk_score DESC, ia.duplicate_count DESC;

-- Vue détaillée pour les échantillons de doublons ISRC
CREATE OR REPLACE VIEW allfeat_kpi.dup_isrc_candidates_samples AS
SELECT 
    r.isrc,
    r.id as recording_id,
    r.name as recording_name,
    r.gid as recording_gid,
    ac.name as artist_credit,
    r.length,
    r.comment,
    r.last_updated,
    -- Informations sur le groupe de doublons
    COUNT(*) OVER (PARTITION BY r.isrc) as group_size,
    ROW_NUMBER() OVER (PARTITION BY r.isrc ORDER BY r.id) as group_rank
FROM musicbrainz.recording r
LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
WHERE r.isrc IN (
    SELECT isrc 
    FROM musicbrainz.recording 
    WHERE isrc IS NOT NULL 
      AND edits_pending = 0
    GROUP BY isrc 
    HAVING COUNT(*) > 1
)
AND r.edits_pending = 0
ORDER BY r.isrc, r.id
LIMIT 100;  -- Limite pour éviter les vues trop lourdes

-- Commentaires
COMMENT ON VIEW allfeat_kpi.dup_isrc_candidates IS 'KPI principal: Candidats doublons ISRC avec analyse de similarité et score de risque';
COMMENT ON VIEW allfeat_kpi.dup_isrc_candidates_samples IS 'Échantillons détaillés de doublons ISRC pour analyse manuelle';
