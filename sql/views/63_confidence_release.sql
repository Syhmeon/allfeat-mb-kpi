-- KPI 6d: Niveaux de confiance - Releases (Phase 1 + Phase 2)
-- Analyse la qualité et complétude des données releases avec logique explicite
-- Usage: SELECT * FROM allfeat_kpi.confidence_release;

-- ============================================================================
-- PHASE 1: LOGIQUE CATÉGORIELLE EXPLICITE ADAPTÉE AUX RELEASES
-- ============================================================================
-- High = has Date + Country + Recording with ISRC + Work ISWC + Artist ID
-- Medium = Date + (Recording ISRC OR Work ISWC) OR (Country + Recording)  
-- Low = else

-- ============================================================================
-- PHASE 2: LOGIQUE NUMÉRIQUE AVEC POIDS ADAPTÉS AUX RELEASES
-- ============================================================================
-- Score = 0.3 * has_date + 0.3 * has_isrc + 0.2 * has_iswc + 0.2 * has_isni
-- Seuils: >=0.8 High, >=0.4 Medium, <0.4 Low

CREATE OR REPLACE VIEW allfeat_kpi.confidence_release AS
WITH release_analysis AS (
    -- Analyser chaque release avec ses critères de confiance
    SELECT 
        r.id as release_id,
        r.name as release_name,
        r.gid as release_gid,
        r.date_year,
        r.date_month,
        r.date_day,
        r.country,
        
        -- Critère 1: Date présente sur la release
        CASE WHEN r.date_year IS NOT NULL THEN 1 ELSE 0 END as has_date,
        
        -- Critère 2: Pays présent sur la release
        CASE WHEN r.country IS NOT NULL THEN 1 ELSE 0 END as has_country,
        
        -- Critère 3: Release contient des enregistrements avec ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            WHERE m.release = r.id AND rec.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 4: Release contient des enregistrements liés à des œuvres avec ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.recording_work rw ON rec.id = rw.recording
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE m.release = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 5: Artistes de la release ont des IPI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.artist_credit ac ON rec.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_ipi ai ON acn.artist = ai.artist
            WHERE m.release = r.id
        ) THEN 1 ELSE 0 END as has_ipi,
        
        -- Critère 6: Artistes de la release ont des ISNI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.artist_credit ac ON rec.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_isni ai ON acn.artist = ai.artist
            WHERE m.release = r.id
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.release r
    WHERE r.edits_pending = 0
),
release_confidence_calculation AS (
    SELECT 
        ra.release_id,
        ra.release_name,
        ra.release_gid,
        ra.date_year,
        ra.date_month,
        ra.date_day,
        ra.country,
        ra.has_date,
        ra.has_country,
        ra.has_isrc,
        ra.has_iswc,
        ra.has_ipi,
        ra.has_isni,
        
        -- Phase 1: Logique catégorielle explicite adaptée aux releases
        CASE 
            -- High = has Date + Country + Recording with ISRC + Work ISWC + Artist ID
            WHEN ra.has_date = 1 AND ra.has_country = 1 AND ra.has_isrc = 1 AND ra.has_iswc = 1 AND (ra.has_isni = 1 OR ra.has_ipi = 1)
            THEN 'High'
            -- Medium = Date + (Recording ISRC OR Work ISWC) OR (Country + Recording)
            WHEN (ra.has_date = 1 AND (ra.has_isrc = 1 OR ra.has_iswc = 1)) 
              OR (ra.has_country = 1 AND ra.has_isrc = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids adaptés aux releases
        -- Score = 0.3 * has_date + 0.3 * has_isrc + 0.2 * has_iswc + 0.2 * has_isni
        ROUND(
            (0.3 * ra.has_date) + 
            (0.3 * ra.has_isrc) + 
            (0.2 * ra.has_iswc) + 
            (0.2 * ra.has_isni), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ra.has_date) + 
                (0.3 * ra.has_isrc) + 
                (0.2 * ra.has_iswc) + 
                (0.2 * ra.has_isni), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ra.has_date) + 
                (0.3 * ra.has_isrc) + 
                (0.2 * ra.has_iswc) + 
                (0.2 * ra.has_isni), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM release_analysis ra
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
        COUNT(*) FILTER (WHERE rcc.has_ipi = 1) as releases_with_ipi,
        COUNT(*) FILTER (WHERE rcc.has_isni = 1) as releases_with_isni
        
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
    s.releases_with_ipi,
    s.releases_with_isni,
    
    -- Pourcentages de couverture des critères
    allfeat_kpi.format_percentage(s.releases_with_date, s.total_releases) as date_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_country, s.total_releases) as country_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_isrc, s.total_releases) as isrc_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_iswc, s.total_releases) as iswc_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_ipi, s.total_releases) as ipi_coverage_pct,
    allfeat_kpi.format_percentage(s.releases_with_isni, s.total_releases) as isni_coverage_pct,
    
    -- Compatibilité ascendante: utiliser Phase 2 comme niveau principal
    CASE 
        WHEN s.average_phase2_score >= 0.8 THEN 'High Confidence'
        WHEN s.average_phase2_score >= 0.4 THEN 'Medium Confidence'
        ELSE 'Low Confidence'
    END as overall_confidence_level,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1+2: Logique explicite Date+Country+ISRC+ISWC+ArtistID' as scope_note
FROM release_confidence_summary s;

-- Vue détaillée pour les échantillons de releases par niveau de confiance
CREATE OR REPLACE VIEW allfeat_kpi.confidence_release_samples AS
WITH release_analysis AS (
    -- Analyser chaque release avec ses critères de confiance
    SELECT 
        r.id as release_id,
        r.name as release_name,
        r.gid as release_gid,
        r.date_year,
        r.date_month,
        r.date_day,
        r.country,
        
        -- Critère 1: Date présente sur la release
        CASE WHEN r.date_year IS NOT NULL THEN 1 ELSE 0 END as has_date,
        
        -- Critère 2: Pays présent sur la release
        CASE WHEN r.country IS NOT NULL THEN 1 ELSE 0 END as has_country,
        
        -- Critère 3: Release contient des enregistrements avec ISRC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            WHERE m.release = r.id AND rec.isrc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_isrc,
        
        -- Critère 4: Release contient des enregistrements liés à des œuvres avec ISWC
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.recording_work rw ON rec.id = rw.recording
            INNER JOIN musicbrainz.work w ON rw.work = w.id
            WHERE m.release = r.id AND w.iswc IS NOT NULL
        ) THEN 1 ELSE 0 END as has_iswc,
        
        -- Critère 5: Artistes de la release ont des IPI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.artist_credit ac ON rec.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_ipi ai ON acn.artist = ai.artist
            WHERE m.release = r.id
        ) THEN 1 ELSE 0 END as has_ipi,
        
        -- Critère 6: Artistes de la release ont des ISNI
        CASE WHEN EXISTS (
            SELECT 1 FROM musicbrainz.medium m
            INNER JOIN musicbrainz.track t ON m.id = t.medium
            INNER JOIN musicbrainz.recording rec ON t.recording = rec.id
            INNER JOIN musicbrainz.artist_credit ac ON rec.artist_credit = ac.id
            INNER JOIN musicbrainz.artist_credit_name acn ON ac.id = acn.artist_credit
            INNER JOIN musicbrainz.artist_isni ai ON acn.artist = ai.artist
            WHERE m.release = r.id
        ) THEN 1 ELSE 0 END as has_isni
        
    FROM musicbrainz.release r
    WHERE r.edits_pending = 0
),
release_confidence_calculation AS (
    SELECT 
        ra.release_id,
        ra.release_name,
        ra.release_gid,
        ra.date_year,
        ra.date_month,
        ra.date_day,
        ra.country,
        ra.has_date,
        ra.has_country,
        ra.has_isrc,
        ra.has_iswc,
        ra.has_ipi,
        ra.has_isni,
        
        -- Phase 1: Logique catégorielle explicite adaptée aux releases
        CASE 
            -- High = has Date + Country + Recording with ISRC + Work ISWC + Artist ID
            WHEN ra.has_date = 1 AND ra.has_country = 1 AND ra.has_isrc = 1 AND ra.has_iswc = 1 AND (ra.has_isni = 1 OR ra.has_ipi = 1)
            THEN 'High'
            -- Medium = Date + (Recording ISRC OR Work ISWC) OR (Country + Recording)
            WHEN (ra.has_date = 1 AND (ra.has_isrc = 1 OR ra.has_iswc = 1)) 
              OR (ra.has_country = 1 AND ra.has_isrc = 1)
            THEN 'Medium'
            -- Low = else
            ELSE 'Low'
        END as phase1_confidence_level,
        
        -- Phase 2: Score numérique avec poids adaptés aux releases
        ROUND(
            (0.3 * ra.has_date) + 
            (0.3 * ra.has_isrc) + 
            (0.2 * ra.has_iswc) + 
            (0.2 * ra.has_isni), 3
        ) as phase2_confidence_score,
        
        -- Phase 2: Classification basée sur le score
        CASE 
            WHEN ROUND(
                (0.3 * ra.has_date) + 
                (0.3 * ra.has_isrc) + 
                (0.2 * ra.has_iswc) + 
                (0.2 * ra.has_isni), 3
            ) >= 0.8 THEN 'High'
            WHEN ROUND(
                (0.3 * ra.has_date) + 
                (0.3 * ra.has_isrc) + 
                (0.2 * ra.has_iswc) + 
                (0.2 * ra.has_isni), 3
            ) >= 0.4 THEN 'Medium'
            ELSE 'Low'
        END as phase2_confidence_level
        
    FROM release_analysis ra
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
    
FROM release_confidence_calculation rcc
ORDER BY rcc.phase2_confidence_score DESC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.confidence_release IS 'KPI principal: Niveaux de confiance releases avec logique Phase 1 (catégorielle) + Phase 2 (numérique)';
COMMENT ON VIEW allfeat_kpi.confidence_release_samples IS 'Échantillons de releases avec scores Phase 1 et Phase 2 pour analyse détaillée';