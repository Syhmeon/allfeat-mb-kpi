-- KPI 6d: Niveaux de confiance - Releases (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données releases avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_release;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE
-- ============================================================================
-- Règles basées uniquement sur la présence d'IDs et la cohérence des liens :
-- High = Release a Date + Pays + Enregistrements ont ISRC + Œuvres ont ISWC + Artistes ont ISNI/IPI
-- Medium = (Release a Date + Enregistrements ont ISRC) OU (Release a Pays + Enregistrements ont ISRC)
-- Low = Tous les autres cas

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS EXPLICITES
-- ============================================================================
-- Score = 0.3 * has_date + 0.3 * has_isrc + 0.2 * has_iswc + 0.2 * has_artist_id
-- Seuils: >=0.8 High, 0.4-0.79 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_release AS
WITH release_criteria AS (
    -- Analyser chaque release selon les critères de confiance
    SELECT 
        r.id as release_id,
        
        -- Critère 1: Release a une date
        CASE WHEN r.date_year IS NOT NULL THEN 1 ELSE 0 END as has_date,
        
        -- Critère 2: Release a un pays
        CASE WHEN r.country IS NOT NULL THEN 1 ELSE 0 END as has_country,
        
        -- Critère 3: Enregistrements de la release ont des ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            WHERE m.release = r.id AND rec.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 4: Œuvres liées aux enregistrements de la release ont des ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.recording_work rw ON rec.id = rw.recording
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE m.release = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 5: Artistes des enregistrements de la release ont des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.artist_credit ac ON rec.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE m.release = r.id AND (
                EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = acn.artist) OR
                EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = acn.artist)
            )
        ) THEN 1 ELSE 0 END as has_artist_id
        
    FROM musicbrainz.release r
    WHERE r.edits_pending = 0
),
release_confidence_calculation AS (
    SELECT 
        rc.release_id,
        rc.has_date,
        rc.has_country,
        rc.has_isrc,
        rc.has_iswc,
        rc.has_artist_id,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Release a Date + Pays + Enregistrements ont ISRC + Œuvres ont ISWC + Artistes ont ISNI/IPI
            WHEN rc.has_date = 1 AND rc.has_country = 1 AND rc.has_isrc = 1 AND rc.has_iswc = 1 AND rc.has_artist_id = 1 
            THEN 'High'
            -- Medium = (Release a Date + Enregistrements ont ISRC) OU (Release a Pays + Enregistrements ont ISRC)
            WHEN (rc.has_date = 1 AND rc.has_isrc = 1) OR (rc.has_country = 1 AND rc.has_isrc = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        -- Score = 0.3 * has_date + 0.3 * has_isrc + 0.2 * has_iswc + 0.2 * has_artist_id
        ROUND(
            (0.3 * rc.has_date) + 
            (0.3 * rc.has_isrc) + 
            (0.2 * rc.has_iswc) + 
            (0.2 * rc.has_artist_id), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * rc.has_date) + 
                (0.3 * rc.has_isrc) + 
                (0.2 * rc.has_iswc) + 
                (0.2 * rc.has_artist_id), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * rc.has_date) + 
                (0.3 * rc.has_isrc) + 
                (0.2 * rc.has_iswc) + 
                (0.2 * rc.has_artist_id), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM release_criteria rc
),
release_confidence_summary AS (
    SELECT 
        COUNT(*) as total_releases,
        
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
        COUNT(*) FILTER (WHERE rcc.has_date = 1) as releases_with_date,
        COUNT(*) FILTER (WHERE rcc.has_country = 1) as releases_with_country,
        COUNT(*) FILTER (WHERE rcc.has_isrc = 1) as releases_with_isrc,
        COUNT(*) FILTER (WHERE rcc.has_iswc = 1) as releases_with_iswc,
        COUNT(*) FILTER (WHERE rcc.has_artist_id = 1) as releases_with_artist_id
        
    FROM release_confidence_calculation rcc
)
SELECT 
    -- Statistiques générales
    s.total_releases,
    
    -- Phase 1: Résultats catégoriels
    s.phase1_high_count,
    s.phase1_medium_count,
    s.phase1_low_count,
    allfeat_kpi.format_percentage(s.phase1_high_count, s.total_releases) as phase1_high_pct,
    allfeat_kpi.format_percentage(s.phase1_medium_count, s.total_releases) as phase1_medium_pct,
    allfeat_kpi.format_percentage(s.phase1_low_count, s.total_releases) as phase1_low_pct,
    
    -- Phase 2: Résultats numériques
    s.phase2_high_count,
    s.phase2_medium_count,
    s.phase2_low_count,
    allfeat_kpi.format_percentage(s.phase2_high_count, s.total_releases) as phase2_high_pct,
    allfeat_kpi.format_percentage(s.phase2_medium_count, s.total_releases) as phase2_medium_pct,
    allfeat_kpi.format_percentage(s.phase2_low_count, s.total_releases) as phase2_low_pct,
    ROUND(s.average_phase2_score, 3) as average_phase2_score,
    
    -- Critères détaillés
    s.releases_with_date,
    s.releases_with_country,
    s.releases_with_isrc,
    s.releases_with_iswc,
    s.releases_with_artist_id,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.releases_with_date, s.total_releases) as date_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_country, s.total_releases) as country_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_isrc, s.total_releases) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_iswc, s.total_releases) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_artist_id, s.total_releases) as artist_id_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite IDs + cohérence des liens' as scope_note
FROM release_confidence_summary s;

-- Vue détaillée pour les échantillons de releases par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_release_samples AS
WITH release_criteria AS (
    -- Analyser chaque release selon les critères de confiance
    SELECT 
        r.id as release_id,
        r.name as release_name,
        r.gid as release_gid,
        r.date_year,
        r.date_month,
        r.date_day,
        r.country,
        
        -- Critère 1: Release a une date
        CASE WHEN r.date_year IS NOT NULL THEN 1 ELSE 0 END as has_date,
        
        -- Critère 2: Release a un pays
        CASE WHEN r.country IS NOT NULL THEN 1 ELSE 0 END as has_country,
        
        -- Critère 3: Enregistrements de la release ont des ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            WHERE m.release = r.id AND rec.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 4: Œuvres liées aux enregistrements de la release ont des ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.recording_work rw ON rec.id = rw.recording
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE m.release = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 5: Artistes des enregistrements de la release ont des identifiants externes (ISNI ou IPI)
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.artist_credit ac ON rec.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            WHERE m.release = r.id AND (
                EXISTS (SELECT 1 FROM musicbrainz.artist_isni WHERE artist = acn.artist) OR
                EXISTS (SELECT 1 FROM musicbrainz.artist_ipi WHERE artist = acn.artist)
            )
        ) THEN 1 ELSE 0 END as has_artist_id
        
    FROM musicbrainz.release r
    WHERE r.edits_pending = 0
),
release_confidence_calculation AS (
    SELECT 
        rc.release_id,
        rc.release_name,
        rc.release_gid,
        rc.date_year,
        rc.date_month,
        rc.date_day,
        rc.country,
        rc.has_date,
        rc.has_country,
        rc.has_isrc,
        rc.has_iswc,
        rc.has_artist_id,
        
        -- Phase 1: Logique catégorielle explicite
        CASE 
            -- High = Release a Date + Pays + Enregistrements ont ISRC + Œuvres ont ISWC + Artistes ont ISNI/IPI
            WHEN rc.has_date = 1 AND rc.has_country = 1 AND rc.has_isrc = 1 AND rc.has_iswc = 1 AND rc.has_artist_id = 1 
            THEN 'High'
            -- Medium = (Release a Date + Enregistrements ont ISRC) OU (Release a Pays + Enregistrements ont ISRC)
            WHEN (rc.has_date = 1 AND rc.has_isrc = 1) OR (rc.has_country = 1 AND rc.has_isrc = 1)
            THEN 'Medium'
            -- Low = Tous les autres cas
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids explicites
        ROUND(
            (0.3 * rc.has_date) + 
            (0.3 * rc.has_isrc) + 
            (0.2 * rc.has_iswc) + 
            (0.2 * rc.has_artist_id), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * rc.has_date) + 
                (0.3 * rc.has_isrc) + 
                (0.2 * rc.has_iswc) + 
                (0.2 * rc.has_artist_id), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * rc.has_date) + 
                (0.3 * rc.has_isrc) + 
                (0.2 * rc.has_iswc) + 
                (0.2 * rc.has_artist_id), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM release_criteria rc
)
SELECT 
    rcc.release_id,
    rcc.release_name,
    rcc.release_gid,
    rcc.date_year,
    rcc.date_month,
    rcc.date_day,
    rcc.country,
    
    -- Critères détaillés
    rcc.has_date,
    rcc.has_country,
    rcc.has_isrc,
    rcc.has_iswc,
    rcc.has_artist_id,
    
    -- Phase 1: Logique catégorielle
    rcc.phase1_confidence_level,
    
    -- Phase 2: Score numérique
    rcc.phase2_confidence_score,
    rcc.phase2_confidence_level,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    rcc.phase2_confidence_level as confidence_level,
    rcc.phase2_confidence_score as confidence_score
    
FROM release_confidence_calculation rcc
ORDER BY rcc.phase2_confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_release IS 'KPI principal: Niveaux de confiance releases avec logique Phase 1 (catégorielle) + Phase 2 (numérique)';
COMMENT ON VIEW allfeat_kpi.confidence_release_samples IS 'Échantillons de releases avec scores Phase 1 et Phase 2 pour analyse détaillée';