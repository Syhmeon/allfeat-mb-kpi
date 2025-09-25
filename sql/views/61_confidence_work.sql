-- KPI 6b: Niveaux de confiance - Œuvres (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données œuvres avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_work;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE
-- ============================================================================
-- Règles basées uniquement sur la présence d'IDs et la cohérence des liens :
-- High = Œuvre a ISWC + Ses enregistrements ont ISRC + Artistes ont ISNI/IPI + Présent sur Release
-- Medium = (Œuvre a ISWC + Ses enregistrements ont ISRC) OU (Ses enregistrements ont ISRC + Présent sur Release)
-- Low = Tous les autres cas

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS EXPLICITES
-- ============================================================================
-- Score = 0.4 * has_iswc + 0.3 * has_artist_id + 0.2 * has_isrc + 0.1 * on_release
-- Seuils: >=0.8 High, 0.4-0.79 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_work AS
WITH work_criteria AS (
    -- Analyser chaque œuvre selon les critères de confiance
    SELECT 
        w.id as work_id,
        
        -- Critère 1: Œuvre a un ISWC
        CASE WHEN w.iswc IS NOT NULL THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 2: Enregistrements liés à l'œuvre ont des ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            WHERE rw.work = w.id AND r.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 3: Artistes des enregistrements liés ont des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE rw.work = w.id AND (
                EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = acn.artist) OR
                EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = acn.artist)
            )
        ) THEN 1 ELSE 0 END as has_artist_id,
        
        -- Critère 4: Enregistrements liés à l'œuvre sont présents sur des releases
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as on_release
        
    FROM musicbrainz.work w
    WHERE w.edits_pending = 0
),
work_confidence_calculation AS (
    SELECT 
        wc.work_id,
        wc.has_iswc,
        wc.has_isrc,
        wc.has_artist_id,
        wc.on_release,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Œuvre a ISWC + Ses enregistrements ont ISRC + Artistes ont ISNI/IPI + Présent sur Release
            WHEN wc.has_iswc = 1 AND wc.has_isrc = 1 AND wc.has_artist_id = 1 AND wc.on_release = 1 
            THEN 'High'
            -- Medium = (Œuvre a ISWC + Ses enregistrements ont ISRC) OU (Ses enregistrements ont ISRC + Présent sur Release)
            WHEN (wc.has_iswc = 1 AND wc.has_isrc = 1) OR (wc.has_isrc = 1 AND wc.on_release = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        -- Score = 0.4 * has_iswc + 0.3 * has_artist_id + 0.2 * has_isrc + 0.1 * on_release
        ROUND(
            (0.4 * wc.has_iswc) + 
            (0.3 * wc.has_artist_id) + 
            (0.2 * wc.has_isrc) + 
            (0.1 * wc.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.4 * wc.has_iswc) + 
                (0.3 * wc.has_artist_id) + 
                (0.2 * wc.has_isrc) + 
                (0.1 * wc.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.4 * wc.has_iswc) + 
                (0.3 * wc.has_artist_id) + 
                (0.2 * wc.has_isrc) + 
                (0.1 * wc.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM work_criteria wc
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
        COUNT(*) FILTER (WHERE wcc.has_artist_id = 1) as works_with_artist_id,
        COUNT(*) FILTER (WHERE wcc.on_release = 1) as works_on_release
        
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
    s.works_with_artist_id,
    s.works_on_release,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.works_with_iswc, s.total_works) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_isrc, s.total_works) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.works_with_artist_id, s.total_works) as artist_id_coverage_pct,
    allfeat_kpi.format_percentage(s.works_on_release, s.total_works) as release_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite IDs + cohérence des liens' as scope_note
FROM work_confidence_summary s;

-- Vue détaillée pour les échantillons d'œuvres par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_work_samples AS
WITH work_criteria AS (
    -- Analyser chaque œuvre selon les critères de confiance
    SELECT 
        w.id as work_id,
        w.name as work_name,
        w.gid as work_gid,
        w.type as work_type,
        w.language_code,
        w.iswc,
        
        -- Critère 1: Œuvre a un ISWC
        CASE WHEN w.iswc IS NOT NULL THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 2: Enregistrements liés à l'œuvre ont des ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            WHERE rw.work = w.id AND r.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 3: Artistes des enregistrements liés ont des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE rw.work = w.id AND (
                EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = acn.artist) OR
                EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = acn.artist)
            )
        ) THEN 1 ELSE 0 END as has_artist_id,
        
        -- Critère 4: Enregistrements liés à l'œuvre sont présents sur des releases
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording_work rw
            INNER JOIN musicbrainz.recording r ON rw.recording = r.id
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE rw.work = w.id
        ) THEN 1 ELSE 0 END as on_release
        
    FROM musicbrainz.work w
    WHERE w.edits_pending = 0
),
work_confidence_calculation AS (
    SELECT 
        wc.work_id,
        wc.work_name,
        wc.work_gid,
        wc.work_type,
        wc.language_code,
        wc.iswc,
        wc.has_iswc,
        wc.has_isrc,
        wc.has_artist_id,
        wc.on_release,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Œuvre a ISWC + Ses enregistrements ont ISRC + Artistes ont ISNI/IPI + Présent sur Release
            WHEN wc.has_iswc = 1 AND wc.has_isrc = 1 AND wc.has_artist_id = 1 AND wc.on_release = 1 
            THEN 'High'
            -- Medium = (Œuvre a ISWC + Ses enregistrements ont ISRC) OU (Ses enregistrements ont ISRC + Présent sur Release)
            WHEN (wc.has_iswc = 1 AND wc.has_isrc = 1) OR (wc.has_isrc = 1 AND wc.on_release = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        ROUND(
            (0.4 * wc.has_iswc) + 
            (0.3 * wc.has_artist_id) + 
            (0.2 * wc.has_isrc) + 
            (0.1 * wc.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.4 * wc.has_iswc) + 
                (0.3 * wc.has_artist_id) + 
                (0.2 * wc.has_isrc) + 
                (0.1 * wc.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.4 * wc.has_iswc) + 
                (0.3 * wc.has_artist_id) + 
                (0.2 * wc.has_isrc) + 
                (0.1 * wc.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM work_criteria wc
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
    wcc.has_artist_id,
    wcc.on_release,
    
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