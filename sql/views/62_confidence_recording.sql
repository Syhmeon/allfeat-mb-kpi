-- KPI 6c: Niveaux de confiance - Enregistrements (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données enregistrements avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_recording;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE
-- ============================================================================
-- Règles basées uniquement sur la présence d'IDs et la cohérence des liens :
-- High = Enregistrement a ISRC + Œuvre liée a ISWC + Artiste a ISNI/IPI + Présent sur Release
-- Medium = (Enregistrement a ISRC + Œuvre liée a ISWC) OU (Enregistrement a ISRC + Présent sur Release)
-- Low = Tous les autres cas

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS EXPLICITES
-- ============================================================================
-- Score = 0.3 * has_isrc + 0.3 * has_iswc + 0.3 * has_artist_id + 0.1 * on_release
-- Seuils: >=0.8 High, 0.4-0.79 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_recording AS
WITH recording_criteria AS (
    -- Analyser chaque enregistrement selon les critères de confiance
    SELECT 
        r.id as recording_id,
        
        -- Critère 1: Enregistrement a un ISRC
        CASE WHEN r.isrc IS NOT NULL THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 2: Œuvre liée à l'enregistrement a un ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE rw.recording = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 3: Artiste de l'enregistrement a des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_credit ac
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE ac.id = r.artist_credit AND (
                EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = acn.artist) OR
                EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = acn.artist)
            )
        ) THEN 1 ELSE 0 END as has_artist_id,
        
        -- Critère 4: Enregistrement est présent sur une release
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.track t
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE t.recording = r.id
        ) THEN 1 ELSE 0 END as on_release
        
    FROM musicbrainz.recording r
    WHERE r.edits_pending = 0
),
recording_confidence_calculation AS (
    SELECT 
        rc.recording_id,
        rc.has_isrc,
        rc.has_iswc,
        rc.has_artist_id,
        rc.on_release,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Enregistrement a ISRC + Œuvre liée a ISWC + Artiste a ISNI/IPI + Présent sur Release
            WHEN rc.has_isrc = 1 AND rc.has_iswc = 1 AND rc.has_artist_id = 1 AND rc.on_release = 1 
            THEN 'High'
            -- Medium = (Enregistrement a ISRC + Œuvre liée a ISWC) OU (Enregistrement a ISRC + Présent sur Release)
            WHEN (rc.has_isrc = 1 AND rc.has_iswc = 1) OR (rc.has_isrc = 1 AND rc.on_release = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        -- Score = 0.3 * has_isrc + 0.3 * has_iswc + 0.3 * has_artist_id + 0.1 * on_release
        ROUND(
            (0.3 * rc.has_isrc) + 
            (0.3 * rc.has_iswc) + 
            (0.3 * rc.has_artist_id) + 
            (0.1 * rc.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * rc.has_isrc) + 
                (0.3 * rc.has_iswc) + 
                (0.3 * rc.has_artist_id) + 
                (0.1 * rc.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * rc.has_isrc) + 
                (0.3 * rc.has_iswc) + 
                (0.3 * rc.has_artist_id) + 
                (0.1 * rc.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM recording_criteria rc
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
        COUNT(*) FILTER (WHERE rcc.has_artist_id = 1) as recordings_with_artist_id,
        COUNT(*) FILTER (WHERE rcc.on_release = 1) as recordings_on_release
        
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
    s.recordings_with_artist_id,
    s.recordings_on_release,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.recordings_with_isrc, s.total_recordings) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_iswc, s.total_recordings) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_with_artist_id, s.total_recordings) as artist_id_coverage_pct,
    allfeat_kpi.format_percentage(s.recordings_on_release, s.total_recordings) as release_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite IDs + cohérence des liens' as scope_note
FROM recording_confidence_summary s;

-- Vue détaillée pour les échantillons d'enregistrements par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_recording_samples AS
WITH recording_criteria AS (
    -- Analyser chaque enregistrement selon les critères de confiance
    SELECT 
        r.id as recording_id,
        r.name as recording_name,
        r.gid as recording_gid,
        r.length,
        r.isrc,
        
        -- Critère 1: Enregistrement a un ISRC
        CASE WHEN r.isrc IS NOT NULL THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 2: Œuvre liée à l'enregistrement a un ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE rw.recording = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 3: Artiste de l'enregistrement a des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_credit ac
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE ac.id = r.artist_credit AND (
                EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = acn.artist) OR
                EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = acn.artist)
            )
        ) THEN 1 ELSE 0 END as has_artist_id,
        
        -- Critère 4: Enregistrement est présent sur une release
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.track t
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE t.recording = r.id
        ) THEN 1 ELSE 0 END as on_release
        
    FROM musicbrainz.recording r
    WHERE r.edits_pending = 0
),
recording_confidence_calculation AS (
    SELECT 
        rc.recording_id,
        rc.recording_name,
        rc.recording_gid,
        rc.length,
        rc.isrc,
        rc.has_isrc,
        rc.has_iswc,
        rc.has_artist_id,
        rc.on_release,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Enregistrement a ISRC + Œuvre liée a ISWC + Artiste a ISNI/IPI + Présent sur Release
            WHEN rc.has_isrc = 1 AND rc.has_iswc = 1 AND rc.has_artist_id = 1 AND rc.on_release = 1 
            THEN 'High'
            -- Medium = (Enregistrement a ISRC + Œuvre liée a ISWC) OU (Enregistrement a ISRC + Présent sur Release)
            WHEN (rc.has_isrc = 1 AND rc.has_iswc = 1) OR (rc.has_isrc = 1 AND rc.on_release = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        ROUND(
            (0.3 * rc.has_isrc) + 
            (0.3 * rc.has_iswc) + 
            (0.3 * rc.has_artist_id) + 
            (0.1 * rc.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * rc.has_isrc) + 
                (0.3 * rc.has_iswc) + 
                (0.3 * rc.has_artist_id) + 
                (0.1 * rc.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * rc.has_isrc) + 
                (0.3 * rc.has_iswc) + 
                (0.3 * rc.has_artist_id) + 
                (0.1 * rc.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM recording_criteria rc
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
    rcc.has_artist_id,
    rcc.on_release,
    
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