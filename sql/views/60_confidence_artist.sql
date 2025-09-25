-- KPI 6a: Niveaux de confiance - Artistes (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données artistes avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_artist;

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

CREATE OR REPLACE VIEW allfeat_kpi.confidence_artist AS
WITH artist_recording_analysis AS (
    -- Analyser les enregistrements liés à chaque artiste
    SELECT 
        a.id as artist_id,
        -- Critères Phase 1: Présence/Absence
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE acn.artist = a.id AND r.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.recording_work rw ON r.id = rw.recording
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE acn.artist = a.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE acn.artist = a.id
        ) THEN 1 ELSE 0 END as on_release,
        
        -- Critères Phase 2: Identifiants artiste
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = a.id
        ) THEN 1 ELSE 0 END as has_ipi,
        
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_isni WHERE artist = a.id
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.artist a
    WHERE a.type = 1  -- Person only
      AND a.edits_pending = 0
),
artist_confidence_calculation AS (
    SELECT 
        ara.artist_id,
        ara.has_isrc,
        ara.has_iswc,
        ara.on_release,
        ara.has_ipi,
        ara.has_isni,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = has ISRC + Work ISWC + Artist ID (ISNI/IPI) + Release
            WHEN ara.has_isrc = 1 AND ara.has_iswc = 1 AND (ara.has_isni = 1 OR ara.has_ipi = 1) AND ara.on_release = 1 
            THEN 'High'
            -- Medium = ISRC + (Work OR Artist ID) OR (Work ISWC + Release)
            WHEN (ara.has_isrc = 1 AND (ara.has_iswc = 1 OR ara.has_isni = 1 OR ara.has_ipi = 1)) 
              OR (ara.has_iswc = 1 AND ara.on_release = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids
        -- Score = 0.3 * has_isni + 0.3 * has_iswc + 0.2 * has_isrc + 0.2 * on_release
        ROUND(
            (0.3 * ara.has_isni) + 
            (0.3 * ara.has_iswc) + 
            (0.2 * ara.has_isrc) + 
            (0.2 * ara.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ara.has_isni) + 
                (0.3 * ara.has_iswc) + 
                (0.2 * ara.has_isrc) + 
                (0.2 * ara.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ara.has_isni) + 
                (0.3 * ara.has_iswc) + 
                (0.2 * ara.has_isrc) + 
                (0.2 * ara.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM artist_recording_analysis ara
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
        COUNT(*) FILTER (WHERE acc.has_isrc = 1) as artists_with_isrc,
        COUNT(*) FILTER (WHERE acc.has_iswc = 1) as artists_with_iswc,
        COUNT(*) FILTER (WHERE acc.on_release = 1) as artists_on_release,
        COUNT(*) FILTER (WHERE acc.has_ipi = 1) as artists_with_ipi,
        COUNT(*) FILTER (WHERE acc.has_isni = 1) as artists_with_isni
        
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
    s.artists_with_isrc,
    s.artists_with_iswc,
    s.artists_on_release,
    s.artists_with_ipi,
    s.artists_with_isni,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.artists_with_isrc, s.total_artists) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_iswc, s.total_artists) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_on_release, s.total_artists) as release_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_ipi, s.total_artists) as ipi_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_isni, s.total_artists) as isni_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite ISRC+ISWC+ArtistID+Release' as scope_note
FROM artist_confidence_summary s;

-- Vue détaillée pour les échantillons d'artistes par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_artist_samples AS
WITH artist_recording_analysis AS (
    -- Analyser les enregistrements liés à chaque artiste
    SELECT 
        a.id as artist_id,
        a.name as artist_name,
        a.gid as artist_gid,
        a.sort_name,
        a.begin_date,
        a.end_date,
        a.area,
        
        -- Critères Phase 1: Présence/Absence
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE acn.artist = a.id AND r.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.recording_work rw ON r.id = rw.recording
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE acn.artist = a.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.recording r
            INNER JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.track t ON r.id = t.recording
            INNER JOIN musicbrainz.medium m ON t.medium = m.id
            INNER JOIN musicbrainz.release rel ON m.release = rel.id
            WHERE acn.artist = a.id
        ) THEN 1 ELSE 0 END as on_release,
        
        -- Critères Phase 2: Identifiants artiste
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = a.id
        ) THEN 1 ELSE 0 END as has_ipi,
        
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.artist_isni WHERE artist = a.id
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.artist a
    WHERE a.type = 1  -- Person only
      AND a.edits_pending = 0
),
artist_confidence_calculation AS (
    SELECT 
        ara.artist_id,
        ara.artist_name,
        ara.artist_gid,
        ara.sort_name,
        ara.begin_date,
        ara.end_date,
        ara.area,
        ara.has_isrc,
        ara.has_iswc,
        ara.on_release,
        ara.has_ipi,
        ara.has_isni,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = has ISRC + Work ISWC + Artist ID (ISNI/IPI) + Release
            WHEN ara.has_isrc = 1 AND ara.has_iswc = 1 AND (ara.has_isni = 1 OR ara.has_ipi = 1) AND ara.on_release = 1 
            THEN 'High'
            -- Medium = ISRC + (Work OR Artist ID) OR (Work ISWC + Release)
            WHEN (ara.has_isrc = 1 AND (ara.has_iswc = 1 OR ara.has_isni = 1 OR ara.has_ipi = 1)) 
              OR (ara.has_iswc = 1 AND ara.on_release = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids
        ROUND(
            (0.3 * ara.has_isni) + 
            (0.3 * ara.has_iswc) + 
            (0.2 * ara.has_isrc) + 
            (0.2 * ara.on_release), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ara.has_isni) + 
                (0.3 * ara.has_iswc) + 
                (0.2 * ara.has_isrc) + 
                (0.2 * ara.on_release), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ara.has_isni) + 
                (0.3 * ara.has_iswc) + 
                (0.2 * ara.has_isrc) + 
                (0.2 * ara.on_release), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM artist_recording_analysis ara
)
SELECT 
    acc.artist_id,
    acc.artist_name,
    acc.artist_gid,
    acc.sort_name,
    acc.begin_date,
    acc.end_date,
    acc.area,
    
    -- Critères détaillés
    acc.has_isrc,
    acc.has_iswc,
    acc.on_release,
    acc.has_ipi,
    acc.has_isni,
    
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