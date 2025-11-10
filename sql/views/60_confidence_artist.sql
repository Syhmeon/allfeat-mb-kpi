-- KPI 6a: Niveaux de confiance - Artistes (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données artistes avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_artist;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE
-- ============================================================================
-- Règles basées uniquement sur la présence d'IDs et la cohérence des liens :
-- High = Artiste a ISNI/IPI + Ses enregistrements ont ISRC + Ses œuvres ont ISWC + Présent sur Release
-- Medium = (Artiste a ISNI/IPI + Ses enregistrements ont ISRC) OU (Ses œuvres ont ISWC + Présent sur Release)
-- Low = Tous les autres cas

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS EXPLICITES
-- ============================================================================
-- Score = 0.3 * has_isni + 0.3 * has_iswc + 0.2 * has_isrc + 0.2 * on_release
-- Seuils: >=0.8 High, 0.4-0.79 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_artist AS
WITH artist_criteria AS (
    -- Analyser chaque artiste selon les critères de confiance
    SELECT 
        a.id as artist_id,
        
        -- Critère 1: Artiste a des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_isni WHERE artist = a.id
        ) OR EXISTS (
            SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = a.id
        ) THEN 1 ELSE 0 END as has_artist_id,
        
        -- Critère 2: Enregistrements de l'artiste ont des ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.isrc i ON r.id = i.recording
            WHERE acn.artist = a.id AND i.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 3: Œuvres liées aux enregistrements de l'artiste ont des ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.l_recording_work lrw ON r.id = lrw.entity0
            INNER JOIN musicbrainz.work w ON lrw.entity1 = w.id
            INNER JOIN musicbrainz.iswc i ON w.id = i.work
            WHERE acn.artist = a.id AND i.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 4: Enregistrements de l'artiste sont présents sur des releases
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE acn.artist = a.id
        ) THEN 1 ELSE 0 END as on_release
        
    FROM musicbrainz.artist a
    WHERE a.type = 1  -- Person only
      AND a.edits_pending = 0
),
artist_confidence_calculation AS (
    SELECT 
        ac.artist_id,
        ac.has_artist_id,
        ac.has_isrc,
        ac.has_iswc,
        ac.on_release,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Artiste a ISNI/IPI + Ses enregistrements ont ISRC + Ses œuvres ont ISWC + Présent sur Release
            WHEN ac.has_artist_id = 1 AND ac.has_isrc = 1 AND ac.has_iswc = 1 AND ac.on_release = 1 
            THEN 'High'
            -- Medium = (Artiste a ISNI/IPI + Ses enregistrements ont ISRC) OU (Ses œuvres ont ISWC + Présent sur Release)
            WHEN (ac.has_artist_id = 1 AND ac.has_isrc = 1) OR (ac.has_iswc = 1 AND ac.on_release = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        -- Score = 0.3 * has_isni + 0.3 * has_iswc + 0.2 * has_isrc + 0.2 * on_release
        ROUND(
            (0.3 * ac.has_artist_id) + 
            (0.3 * ac.has_iswc) + 
            (0.2 * ac.has_isrc) + 
            (0.2 * ac.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ac.has_artist_id) + 
                (0.3 * ac.has_iswc) + 
                (0.2 * ac.has_isrc) + 
                (0.2 * ac.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ac.has_artist_id) + 
                (0.3 * ac.has_iswc) + 
                (0.2 * ac.has_isrc) + 
                (0.2 * ac.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM artist_criteria ac
),
artist_confidence_summary AS (
    SELECT 
        COUNT(*) as total_artists,
        
        -- Statistiques Phase 1
        COUNT(*) FILTER (WHERE acc.phase1_confidence_level = 'High') as phase1_high_count,
        COUNT(*) FILTER (WHERE acc.phase1_confidence_level = 'Medium') as phase1_medium_count,
        COUNT(*) FILTER (WHERE acc.phase1_confidence_level = 'Low') as phase1_low_count,
        
        -- Statistiques Phase 2
        COUNT(*) FILTER (WHERE acc.phase2_confidence_level = 'High') as phase2_high_count,
        COUNT(*) FILTER (WHERE acc.phase2_confidence_level = 'Medium') as phase2_medium_count,
        COUNT(*) FILTER (WHERE acc.phase2_confidence_level = 'Low') as phase2_low_count,
        
        -- Scores moyens
        AVG(acc.phase2_confidence_score) as average_phase2_score,
        
        -- Critères détaillés
        COUNT(*) FILTER (WHERE acc.has_artist_id = 1) as artists_with_artist_id,
        COUNT(*) FILTER (WHERE acc.has_isrc = 1) as artists_with_isrc,
        COUNT(*) FILTER (WHERE acc.has_iswc = 1) as artists_with_iswc,
        COUNT(*) FILTER (WHERE acc.on_release = 1) as artists_on_release
        
    FROM artist_confidence_calculation acc
)
SELECT 
    -- Statistiques générales
    s.total_artists,
    
    -- Phase 1: Résultats catégoriels
    s.phase1_high_count,
    s.phase1_medium_count,
    s.phase1_low_count,
    allfeat_kpi.format_percentage(s.phase1_high_count, s.total_artists) as phase1_high_pct,
    allfeat_kpi.format_percentage(s.phase1_medium_count, s.total_artists) as phase1_medium_pct,
    allfeat_kpi.format_percentage(s.phase1_low_count, s.total_artists) as phase1_low_pct,
    
    -- Phase 2: Résultats numériques
    s.phase2_high_count,
    s.phase2_medium_count,
    s.phase2_low_count,
    allfeat_kpi.format_percentage(s.phase2_high_count, s.total_artists) as phase2_high_pct,
    allfeat_kpi.format_percentage(s.phase2_medium_count, s.total_artists) as phase2_medium_pct,
    allfeat_kpi.format_percentage(s.phase2_low_count, s.total_artists) as phase2_low_pct,
    ROUND(s.average_phase2_score, 3) as average_phase2_score,
    
    -- Critères détaillés
    s.artists_with_artist_id,
    s.artists_with_isrc,
    s.artists_with_iswc,
    s.artists_on_release,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.artists_with_artist_id, s.total_artists) as artist_id_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_isrc, s.total_artists) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_iswc, s.total_artists) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_on_release, s.total_artists) as release_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite IDs + cohérence des liens' as scope_note
FROM artist_confidence_summary s;

-- Vue détaillée pour les échantillons d'artistes par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_artist_samples AS
WITH artist_criteria AS (
    -- Analyser chaque artiste selon les critères de confiance
    SELECT 
        a.id as artist_id,
        a.name as artist_name,
        a.gid as artist_gid,
        a.sort_name,
        a.begin_date_year,
        a.end_date_year,
        a.area,
        
        -- Critère 1: Artiste a des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_isni WHERE artist = a.id
        ) OR EXISTS (
            SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = a.id
        ) THEN 1 ELSE 0 END as has_artist_id,
        
        -- Critère 2: Enregistrements de l'artiste ont des ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.isrc i ON r.id = i.recording
            WHERE acn.artist = a.id AND i.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 3: Œuvres liées aux enregistrements de l'artiste ont des ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.l_recording_work lrw ON r.id = lrw.entity0
            INNER JOIN musicbrainz.work w ON lrw.entity1 = w.id
            INNER JOIN musicbrainz.iswc i ON w.id = i.work
            WHERE acn.artist = a.id AND i.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 4: Enregistrements de l'artiste sont présents sur des releases
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE acn.artist = a.id
        ) THEN 1 ELSE 0 END as on_release
        
    FROM musicbrainz.artist a
    WHERE a.type = 1  -- Person only
      AND a.edits_pending = 0
),
artist_confidence_calculation AS (
    SELECT 
        ac.artist_id,
        ac.artist_name,
        ac.artist_gid,
        ac.sort_name,
        NULL::smallint as begin_date,
        NULL::smallint as end_date,
        ac.area,
        ac.has_artist_id,
        ac.has_isrc,
        ac.has_iswc,
        ac.on_release,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Artiste a ISNI/IPI + Ses enregistrements ont ISRC + Ses œuvres ont ISWC + Présent sur Release
            WHEN ac.has_artist_id = 1 AND ac.has_isrc = 1 AND ac.has_iswc = 1 AND ac.on_release = 1 
            THEN 'High'
            -- Medium = (Artiste a ISNI/IPI + Ses enregistrements ont ISRC) OU (Ses œuvres ont ISWC + Présent sur Release)
            WHEN (ac.has_artist_id = 1 AND ac.has_isrc = 1) OR (ac.has_iswc = 1 AND ac.on_release = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        ROUND(
            (0.3 * ac.has_artist_id) + 
            (0.3 * ac.has_iswc) + 
            (0.2 * ac.has_isrc) + 
            (0.2 * ac.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ac.has_artist_id) + 
                (0.3 * ac.has_iswc) + 
                (0.2 * ac.has_isrc) + 
                (0.2 * ac.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ac.has_artist_id) + 
                (0.3 * ac.has_iswc) + 
                (0.2 * ac.has_isrc) + 
                (0.2 * ac.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM artist_criteria ac
)
SELECT 
    acc.artist_id,
    acc.artist_name,
    acc.artist_gid,
    acc.sort_name,
    NULL::smallint as begin_date,
    NULL::smallint as end_date,
    acc.area,
    
    -- Critères détaillés
    acc.has_artist_id,
    acc.has_isrc,
    acc.has_iswc,
    acc.on_release,
    
    -- Phase 1: Logique catégorielle
    acc.phase1_confidence_level,
    
    -- Phase 2: Score numérique
    acc.phase2_confidence_score,
    acc.phase2_confidence_level,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    acc.phase2_confidence_level as confidence_level,
    acc.phase2_confidence_score as confidence_score
    
FROM artist_confidence_calculation acc
ORDER BY acc.phase2_confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_artist IS 'KPI principal: Niveaux de confiance artistes avec logique Phase 1 (catégorielle) + Phase 2 (numérique)';
COMMENT ON VIEW allfeat_kpi.confidence_artist_samples IS 'Échantillons d''artistes avec scores Phase 1 et Phase 2 pour analyse détaillée';