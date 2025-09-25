-- KPI 6b: Niveaux de confiance - Œuvres (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données œuvres avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_work;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE ADAPTÉE AUX ŒUVRES
-- ============================================================================
-- High = has ISWC + Artist ID (ISNI/IPI) + Recording with ISRC + Release
-- Medium = ISWC + (Recording OR Artist ID) OR (Recording ISRC + Release)  
-- Low = else

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS ADAPTÉS AUX ŒUVRES
-- ============================================================================
-- Score = 0.4 * has_iswc + 0.3 * has_isni + 0.2 * has_isrc + 0.1 * on_release
-- Seuils: >=0.8 High, >=0.4 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_work AS
WITH work_analysis AS (
    -- Analyser chaque œuvre avec ses critères de confiance
    SELECT 
        w.id as work_id,
        w.name as work_name,
        w.gid as work_gid,
        w.type as work_type,
        w.language_code,
        
        -- Critère 1: ISWC présent sur l'œuvre
        CASE WHEN w.iswc IS NOT NULL THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 2: Œuvre liée à un enregistrement avec ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            WHERE rw.work = w.id AND r.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 3: Œuvre liée à un enregistrement sur une release
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as on_release,
        
        -- Critère 4: Artiste de l'enregistrement a un IPI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_ipi ai ON acn.artist = ai.artist
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as has_ipi,
        
        -- Critère 5: Artiste de l'enregistrement a un ISNI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_isni ai ON acn.artist = ai.artist
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.work w
    WHERE w.edits_pending = 0
),
work_confidence_calculation AS (
    SELECT 
        wa.work_id,
        wa.work_name,
        wa.work_gid,
        wa.work_type,
        wa.language_code,
        wa.has_iswc,
        wa.has_isrc,
        wa.on_release,
        wa.has_ipi,
        wa.has_isni,
        
        -- Phase 1: Logique catégorielle explicite adaptée aux œuvres
        CASE 
            -- High = has ISWC + Artist ID (ISNI/IPI) + Recording with ISRC + Release
            WHEN wa.has_iswc = 1 AND (wa.has_isni = 1 OR wa.has_ipi = 1) AND wa.has_isrc = 1 AND wa.on_release = 1 
            THEN 'High'
            -- Medium = ISWC + (Recording OR Artist ID) OR (Recording ISRC + Release)
            WHEN (wa.has_iswc = 1 AND (wa.has_isrc = 1 OR wa.has_isni = 1 OR wa.has_ipi = 1)) 
              OR (wa.has_isrc = 1 AND wa.on_release = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids adaptés aux œuvres
        -- Score = 0.4 * has_iswc + 0.3 * has_isni + 0.2 * has_isrc + 0.1 * on_release
        ROUND(
            (0.4 * wa.has_iswc) + 
            (0.3 * wa.has_isni) + 
            (0.2 * wa.has_isrc) + 
            (0.1 * wa.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.4 * wa.has_iswc) + 
                (0.3 * wa.has_isni) + 
                (0.2 * wa.has_isrc) + 
                (0.1 * wa.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.4 * wa.has_iswc) + 
                (0.3 * wa.has_isni) + 
                (0.2 * wa.has_isrc) + 
                (0.1 * wa.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM work_analysis wa
),
work_confidence_summary AS (
    SELECT 
        COUNT(*) as total_works,
        
        -- Statistiques Phase 1
        COUNT(*) FILTER (WHERE wcc.phase1_confidence_level = 'High') as phase1_high_count,
        COUNT(*) FILTER (WHERE wcc.phase1_confidence_level = 'Medium') as phase1_medium_count,
        COUNT(*) FILTER (WHERE wcc.phase1_confidence_level = 'Low') as phase1_low_count,
        
        -- Statistiques Phase 2
        COUNT(*) FILTER (WHERE wcc.phase2_confidence_level = 'High') as phase2_high_count,
        COUNT(*) FILTER (WHERE wcc.phase2_confidence_level = 'Medium') as phase2_medium_count,
        COUNT(*) FILTER (WHERE wcc.phase2_confidence_level = 'Low') as phase2_low_count,
        
        -- Scores moyens
        AVG(wcc.phase2_confidence_score) as average_phase2_score,
        
        -- Critères détaillés
        COUNT(*) FILTER (WHERE wcc.has_iswc = 1) as works_with_iswc,
        COUNT(*) FILTER (WHERE wcc.has_isrc = 1) as works_with_isrc,
        COUNT(*) FILTER (WHERE wcc.on_release = 1) as works_on_release,
        COUNT(*) FILTER (WHERE wcc.has_ipi = 1) as works_with_ipi,
        COUNT(*) FILTER (WHERE wcc.has_isni = 1) as works_with_isni
        
    FROM work_confidence_calculation wcc
)
SELECT 
    -- Statistiques générales
    s.total_works,
    
    -- Phase 1: Résultats catégoriels
    s.phase1_high_count,
    s.phase1_medium_count,
    s.phase1_low_count,
    allfeat_kpi.format_percentage(s.phase1_high_count, s.total_works) as phase1_high_pct,
    allfeat_kpi.format_percentage(s.phase1_medium_count, s.total_works) as phase1_medium_pct,
    allfeat_kpi.format_percentage(s.phase1_low_count, s.total_works) as phase1_low_pct,
    
    -- Phase 2: Résultats numériques
    s.phase2_high_count,
    s.phase2_medium_count,
    s.phase2_low_count,
    allfeat_kpi.format_percentage(s.phase2_high_count, s.total_works) as phase2_high_pct,
    allfeat_kpi.format_percentage(s.phase2_medium_count, s.total_works) as phase2_medium_pct,
    allfeat_kpi.format_percentage(s.phase2_low_count, s.total_works) as phase2_low_pct,
    ROUND(s.average_phase2_score, 3) as average_phase2_score,
    
    -- Critères détaillés
    s.works_with_iswc,
    s.works_with_isrc,
    s.works_on_release,
    s.works_with_ipi,
    s.works_with_isni,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.works_with_iswc, s.total_works) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_isrc, s.total_works) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_on_release, s.total_works) as release_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_ipi, s.total_works) as ipi_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_isni, s.total_works) as isni_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite ISWC+ISRC+ArtistID+Release' as scope_note
FROM work_confidence_summary s;

-- Vue détaillée pour les échantillons d'œuvres par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_work_samples AS
WITH work_analysis AS (
    -- Analyser chaque œuvre avec ses critères de confiance
    SELECT 
        w.id as work_id,
        w.name as work_name,
        w.gid as work_gid,
        w.type as work_type,
        w.language_code,
        w.iswc,
        
        -- Critère 1: ISWC présent sur l'œuvre
        CASE WHEN w.iswc IS NOT NULL THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 2: Œuvre liée à un enregistrement avec ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            WHERE rw.work = w.id AND r.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 3: Œuvre liée à un enregistrement sur une release
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as on_release,
        
        -- Critère 4: Artiste de l'enregistrement a un IPI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_ipi ai ON acn.artist = ai.artist
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as has_ipi,
        
        -- Critère 5: Artiste de l'enregistrement a un ISNI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_isni ai ON acn.artist = ai.artist
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.work w
    WHERE w.edits_pending = 0
),
work_confidence_calculation AS (
    SELECT 
        wa.work_id,
        wa.work_name,
        wa.work_gid,
        wa.work_type,
        wa.language_code,
        wa.iswc,
        wa.has_iswc,
        wa.has_isrc,
        wa.on_release,
        wa.has_ipi,
        wa.has_isni,
        
        -- Phase 1: Logique catégorielle explicite adaptée aux œuvres
        CASE 
            -- High = has ISWC + Artist ID (ISNI/IPI) + Recording with ISRC + Release
            WHEN wa.has_iswc = 1 AND (wa.has_isni = 1 OR wa.has_ipi = 1) AND wa.has_isrc = 1 AND wa.on_release = 1 
            THEN 'High'
            -- Medium = ISWC + (Recording OR Artist ID) OR (Recording ISRC + Release)
            WHEN (wa.has_iswc = 1 AND (wa.has_isrc = 1 OR wa.has_isni = 1 OR wa.has_ipi = 1)) 
              OR (wa.has_isrc = 1 AND wa.on_release = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids adaptés aux œuvres
        ROUND(
            (0.4 * wa.has_iswc) + 
            (0.3 * wa.has_isni) + 
            (0.2 * wa.has_isrc) + 
            (0.1 * wa.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.4 * wa.has_iswc) + 
                (0.3 * wa.has_isni) + 
                (0.2 * wa.has_isrc) + 
                (0.1 * wa.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.4 * wa.has_iswc) + 
                (0.3 * wa.has_isni) + 
                (0.2 * wa.has_isrc) + 
                (0.1 * wa.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM work_analysis wa
)
SELECT 
    wcc.work_id,
    wcc.work_name,
    wcc.work_gid,
    wcc.work_type,
    wcc.language_code,
    wcc.iswc,
    
    -- Critères détaillés
    wcc.has_iswc,
    wcc.has_isrc,
    wcc.on_release,
    wcc.has_ipi,
    wcc.has_isni,
    
    -- Phase 1: Logique catégorielle
    wcc.phase1_confidence_level,
    
    -- Phase 2: Score numérique
    wcc.phase2_confidence_score,
    wcc.phase2_confidence_level,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    wcc.phase2_confidence_level as confidence_level,
    wcc.phase2_confidence_score as confidence_score
    
FROM work_confidence_calculation wcc
ORDER BY wcc.phase2_confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_work IS 'KPI principal: Niveaux de confiance œuvres avec logique Phase 1 (catégorielle) + Phase 2 (numérique)';
COMMENT ON VIEW allfeat_kpi.confidence_work_samples IS 'Échantillons d''œuvres avec scores Phase 1 et Phase 2 pour analyse détaillée';