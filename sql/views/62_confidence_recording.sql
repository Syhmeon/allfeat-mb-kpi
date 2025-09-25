-- KPI 6c: Niveaux de confiance - Enregistrements (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données enregistrements avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_recording;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE
-- ============================================================================
-- High = has ISRC + Work ISWC + Artist ID (ISNI/IPI) + Release
-- Medium = ISRC + (Work OR Artist ID) OR (Work ISWC + Release)  
-- Low = else

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS
-- ============================================================================
-- Score = 0.3 * has_isni + 0.3 * has_iswc + 0.2 * has_isrc + 0.2 * on_release
-- Seuils: >=0.8 High, >=0.4 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_recording AS
WITH recording_analysis AS (
    -- Analyser chaque enregistrement avec ses critères de confiance
    SELECT 
        r.id as recording_id,
        r.name as recording_name,
        r.gid as recording_gid,
        
        -- Critère 1: ISRC présent sur l'enregistrement
        CASE WHEN r.isrc IS NOT NULL THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 2: ISWC présent sur l'œuvre liée
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE rw.recording = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 3: Enregistrement présent sur une release
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.track t
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE t.recording = r.id
        ) THEN 1 ELSE 0 END as on_release,
        
        -- Critère 4: Artiste a un IPI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_credit ac
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_ipi ai ON acn.artist = ai.artist
            WHERE ac.id = r.artist_credit
        ) THEN 1 ELSE 0 END as has_ipi,
        
        -- Critère 5: Artiste a un ISNI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_credit ac
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_isni ai ON acn.artist = ai.artist
            WHERE ac.id = r.artist_credit
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.recording r
    WHERE r.edits_pending = 0
),
recording_confidence_calculation AS (
    SELECT 
        ra.recording_id,
        ra.recording_name,
        ra.recording_gid,
        ra.has_isrc,
        ra.has_iswc,
        ra.on_release,
        ra.has_ipi,
        ra.has_isni,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = has ISRC + Work ISWC + Artist ID (ISNI/IPI) + Release
            WHEN ra.has_isrc = 1 AND ra.has_iswc = 1 AND (ra.has_isni = 1 OR ra.has_ipi = 1) AND ra.on_release = 1 
            THEN 'High'
            -- Medium = ISRC + (Work OR Artist ID) OR (Work ISWC + Release)
            WHEN (ra.has_isrc = 1 AND (ra.has_iswc = 1 OR ra.has_isni = 1 OR ra.has_ipi = 1)) 
              OR (ra.has_iswc = 1 AND ra.on_release = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids
        -- Score = 0.3 * has_isni + 0.3 * has_iswc + 0.2 * has_isrc + 0.2 * on_release
        ROUND(
            (0.3 * ra.has_isni) + 
            (0.3 * ra.has_iswc) + 
            (0.2 * ra.has_isrc) + 
            (0.2 * ra.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ra.has_isni) + 
                (0.3 * ra.has_iswc) + 
                (0.2 * ra.has_isrc) + 
                (0.2 * ra.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ra.has_isni) + 
                (0.3 * ra.has_iswc) + 
                (0.2 * ra.has_isrc) + 
                (0.2 * ra.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM recording_analysis ra
),
recording_confidence_summary AS (
    SELECT 
        COUNT(*) as total_recordings,
        
        -- Statistiques Phase 1
        COUNT(*) FILTER (WHERE rcc.phase1_confidence_level = 'High') as phase1_high_count,
        COUNT(*) FILTER (WHERE rcc.phase1_confidence_level = 'Medium') as phase1_medium_count,
        COUNT(*) FILTER (WHERE rcc.phase1_confidence_level = 'Low') as phase1_low_count,
        
        -- Statistiques Phase 2
        COUNT(*) FILTER (WHERE rcc.phase2_confidence_level = 'High') as phase2_high_count,
        COUNT(*) FILTER (WHERE rcc.phase2_confidence_level = 'Medium') as phase2_medium_count,
        COUNT(*) FILTER (WHERE rcc.phase2_confidence_level = 'Low') as phase2_low_count,
        
        -- Scores moyens
        AVG(rcc.phase2_confidence_score) as average_phase2_score,
        
        -- Critères détaillés
        COUNT(*) FILTER (WHERE rcc.has_isrc = 1) as recordings_with_isrc,
        COUNT(*) FILTER (WHERE rcc.has_iswc = 1) as recordings_with_iswc,
        COUNT(*) FILTER (WHERE rcc.on_release = 1) as recordings_on_release,
        COUNT(*) FILTER (WHERE rcc.has_ipi = 1) as recordings_with_ipi,
        COUNT(*) FILTER (WHERE rcc.has_isni = 1) as recordings_with_isni
        
    FROM recording_confidence_calculation rcc
)
SELECT 
    -- Statistiques générales
    s.total_recordings,
    
    -- Phase 1: Résultats catégoriels
    s.phase1_high_count,
    s.phase1_medium_count,
    s.phase1_low_count,
    allfeat_kpi.format_percentage(s.phase1_high_count, s.total_recordings) as phase1_high_pct,
    allfeat_kpi.format_percentage(s.phase1_medium_count, s.total_recordings) as phase1_medium_pct,
    allfeat_kpi.format_percentage(s.phase1_low_count, s.total_recordings) as phase1_low_pct,
    
    -- Phase 2: Résultats numériques
    s.phase2_high_count,
    s.phase2_medium_count,
    s.phase2_low_count,
    allfeat_kpi.format_percentage(s.phase2_high_count, s.total_recordings) as phase2_high_pct,
    allfeat_kpi.format_percentage(s.phase2_medium_count, s.total_recordings) as phase2_medium_pct,
    allfeat_kpi.format_percentage(s.phase2_low_count, s.total_recordings) as phase2_low_pct,
    ROUND(s.average_phase2_score, 3) as average_phase2_score,
    
    -- Critères détaillés
    s.recordings_with_isrc,
    s.recordings_with_iswc,
    s.recordings_on_release,
    s.recordings_with_ipi,
    s.recordings_with_isni,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.recordings_with_isrc, s.total_recordings) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_iswc, s.total_recordings) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_on_release, s.total_recordings) as release_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_ipi, s.total_recordings) as ipi_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_isni, s.total_recordings) as isni_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite ISRC+ISWC+ArtistID+Release' as scope_note
FROM recording_confidence_summary s;

-- Vue détaillée pour les échantillons d'enregistrements par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_recording_samples AS
WITH recording_analysis AS (
    -- Analyser chaque enregistrement avec ses critères de confiance
    SELECT 
        r.id as recording_id,
        r.name as recording_name,
        r.gid as recording_gid,
        r.length,
        r.isrc,
        
        -- Critère 1: ISRC présent sur l'enregistrement
        CASE WHEN r.isrc IS NOT NULL THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 2: ISWC présent sur l'œuvre liée
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE rw.recording = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 3: Enregistrement présent sur une release
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.track t
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE t.recording = r.id
        ) THEN 1 ELSE 0 END as on_release,
        
        -- Critère 4: Artiste a un IPI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_credit ac
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_ipi ai ON acn.artist = ai.artist
            WHERE ac.id = r.artist_credit
        ) THEN 1 ELSE 0 END as has_ipi,
        
        -- Critère 5: Artiste a un ISNI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_credit ac
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_isni ai ON acn.artist = ai.artist
            WHERE ac.id = r.artist_credit
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.recording r
    WHERE r.edits_pending = 0
),
recording_confidence_calculation AS (
    SELECT 
        ra.recording_id,
        ra.recording_name,
        ra.recording_gid,
        ra.length,
        ra.isrc,
        ra.has_isrc,
        ra.has_iswc,
        ra.on_release,
        ra.has_ipi,
        ra.has_isni,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = has ISRC + Work ISWC + Artist ID (ISNI/IPI) + Release
            WHEN ra.has_isrc = 1 AND ra.has_iswc = 1 AND (ra.has_isni = 1 OR ra.has_ipi = 1) AND ra.on_release = 1 
            THEN 'High'
            -- Medium = ISRC + (Work OR Artist ID) OR (Work ISWC + Release)
            WHEN (ra.has_isrc = 1 AND (ra.has_iswc = 1 OR ra.has_isni = 1 OR ra.has_ipi = 1)) 
              OR (ra.has_iswc = 1 AND ra.on_release = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids
        ROUND(
            (0.3 * ra.has_isni) + 
            (0.3 * ra.has_iswc) + 
            (0.2 * ra.has_isrc) + 
            (0.2 * ra.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ra.has_isni) + 
                (0.3 * ra.has_iswc) + 
                (0.2 * ra.has_isrc) + 
                (0.2 * ra.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ra.has_isni) + 
                (0.3 * ra.has_iswc) + 
                (0.2 * ra.has_isrc) + 
                (0.2 * ra.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM recording_analysis ra
)
SELECT 
    rcc.recording_id,
    rcc.recording_name,
    rcc.recording_gid,
    rcc.length,
    rcc.isrc,
    
    -- Critères détaillés
    rcc.has_isrc,
    rcc.has_iswc,
    rcc.on_release,
    rcc.has_ipi,
    rcc.has_isni,
    
    -- Phase 1: Logique catégorielle
    rcc.phase1_confidence_level,
    
    -- Phase 2: Score numérique
    rcc.phase2_confidence_score,
    rcc.phase2_confidence_level,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    rcc.phase2_confidence_level as confidence_level,
    rcc.phase2_confidence_score as confidence_score
    
FROM recording_confidence_calculation rcc
ORDER BY rcc.phase2_confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_recording IS 'KPI principal: Niveaux de confiance enregistrements avec logique Phase 1 (catégorielle) + Phase 2 (numérique)';
COMMENT ON VIEW allfeat_kpi.confidence_recording_samples IS 'Échantillons d''enregistrements avec scores Phase 1 et Phase 2 pour analyse détaillée';