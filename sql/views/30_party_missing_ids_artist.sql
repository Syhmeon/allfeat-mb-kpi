-- KPI 3: Artistes avec IDs manquants
-- Identifie les artistes sans identifiants externes (IPI, ISNI, etc.)
-- Usage: SELECT * FROM allfeat_kpi.party_missing_ids_artist;

CREATE OR REPLACE VIEW allfeat_kpi.party_missing_ids_artist AS
WITH artist_id_stats AS (
    SELECT 
        COUNT(*) as total_artists,
        COUNT(DISTINCT a.id) FILTER (WHERE ai.artist IS NOT NULL) as artists_with_ipi,
        COUNT(DISTINCT a.id) FILTER (WHERE ai2.artist IS NOT NULL) as artists_with_isni,
        COUNT(DISTINCT a.id) FILTER (WHERE u3.id IS NOT NULL) as artists_with_viaf,
        COUNT(DISTINCT a.id) FILTER (WHERE u4.id IS NOT NULL) as artists_with_wikidata,
        COUNT(DISTINCT a.id) FILTER (WHERE u5.id IS NOT NULL) as artists_with_imdb
    FROM musicbrainz.artist a
    LEFT JOIN musicbrainz.artist_ipi ai ON a.id = ai.artist
    LEFT JOIN musicbrainz.artist_isni ai2 ON a.id = ai2.artist
    LEFT JOIN musicbrainz.l_artist_url lau3 ON a.id = lau3.entity0
    LEFT JOIN musicbrainz.url u3 ON lau3.entity1 = u3.id AND u3.url LIKE '%viaf%'
    LEFT JOIN musicbrainz.l_artist_url lau4 ON a.id = lau4.entity0
    LEFT JOIN musicbrainz.url u4 ON lau4.entity1 = u4.id AND u4.url LIKE '%wikidata%'
    LEFT JOIN musicbrainz.l_artist_url lau5 ON a.id = lau5.entity0
    LEFT JOIN musicbrainz.url u5 ON lau5.entity1 = u5.id AND u5.url LIKE '%imdb%'
    WHERE a.type = 1  -- Person only
      AND a.edits_pending = 0
),
artist_missing_ids AS (
    SELECT 
        a.id,
        a.name,
        a.gid,
        a.sort_name,
        a.begin_date_year,
        a.end_date_year,
        a.area,
        a.type,
        CASE 
            WHEN ai.artist IS NULL THEN 'Missing IPI'
            ELSE 'Has IPI'
        END as ipi_status,
        CASE 
            WHEN ai2.artist IS NULL THEN 'Missing ISNI'
            ELSE 'Has ISNI'
        END as isni_status,
        CASE 
            WHEN u3.id IS NULL THEN 'Missing VIAF'
            ELSE 'Has VIAF'
        END as viaf_status,
        CASE 
            WHEN u4.id IS NULL THEN 'Missing Wikidata'
            ELSE 'Has Wikidata'
        END as wikidata_status,
        CASE 
            WHEN u5.id IS NULL THEN 'Missing IMDB'
            ELSE 'Has IMDB'
        END as imdb_status
    FROM musicbrainz.artist a
    LEFT JOIN musicbrainz.artist_ipi ai ON a.id = ai.artist
    LEFT JOIN musicbrainz.artist_isni ai2 ON a.id = ai2.artist
    LEFT JOIN musicbrainz.l_artist_url lau3 ON a.id = lau3.entity0
    LEFT JOIN musicbrainz.url u3 ON lau3.entity1 = u3.id AND u3.url LIKE '%viaf%'
    LEFT JOIN musicbrainz.l_artist_url lau4 ON a.id = lau4.entity0
    LEFT JOIN musicbrainz.url u4 ON lau4.entity1 = u4.id AND u4.url LIKE '%wikidata%'
    LEFT JOIN musicbrainz.l_artist_url lau5 ON a.id = lau5.entity0
    LEFT JOIN musicbrainz.url u5 ON lau5.entity1 = u5.id AND u5.url LIKE '%imdb%'
    WHERE a.type = 1  -- Person only
      AND a.edits_pending = 0
)
SELECT 
    -- Statistiques générales
    s.total_artists,
    s.artists_with_ipi,
    s.artists_with_isni,
    s.artists_with_viaf,
    s.artists_with_wikidata,
    s.artists_with_imdb,
    
    -- Calculs des manquants
    s.total_artists - s.artists_with_ipi as artists_missing_ipi,
    s.total_artists - s.artists_with_isni as artists_missing_isni,
    s.total_artists - s.artists_with_viaf as artists_missing_viaf,
    s.total_artists - s.artists_with_wikidata as artists_missing_wikidata,
    s.total_artists - s.artists_with_imdb as artists_missing_imdb,
    
    -- Pourcentages de couverture
    allfeat_kpi.format_percentage(s.artists_with_ipi, s.total_artists) as ipi_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_isni, s.total_artists) as isni_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_viaf, s.total_artists) as viaf_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_wikidata, s.total_artists) as wikidata_coverage_pct,
    allfeat_kpi.format_percentage(s.artists_with_imdb, s.total_artists) as imdb_coverage_pct,
    
    -- Score global de complétude des IDs
    ROUND(
        (s.artists_with_ipi + s.artists_with_isni + s.artists_with_viaf + 
         s.artists_with_wikidata + s.artists_with_imdb) * 100.0 / (s.total_artists * 5), 2
    ) as overall_id_completeness_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM artist_id_stats s;

-- Vue détaillée pour les échantillons d'artistes avec IDs manquants
CREATE OR REPLACE VIEW allfeat_kpi.party_missing_ids_artist_samples AS
SELECT 
    a.id as artist_id,
    a.name as artist_name,
    a.gid as artist_gid,
    a.sort_name,
    a.begin_date_year,
    a.end_date_year,
    a.area,
    CASE 
        WHEN ai.artist IS NULL THEN 'Missing IPI'
        ELSE 'Has IPI'
    END as ipi_status,
    CASE 
        WHEN ai2.artist IS NULL THEN 'Missing ISNI'
        ELSE 'Has ISNI'
    END as isni_status,
    CASE 
        WHEN u3.id IS NULL THEN 'Missing VIAF'
        ELSE 'Has VIAF'
    END as viaf_status,
    CASE 
        WHEN u4.id IS NULL THEN 'Missing Wikidata'
        ELSE 'Has Wikidata'
    END as wikidata_status,
    CASE 
        WHEN u5.id IS NULL THEN 'Missing IMDB'
        ELSE 'Has IMDB'
    END as imdb_status,
    -- Score de complétude pour cet artiste
    (
        CASE WHEN ai.artist IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN ai2.artist IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN u3.id IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN u4.id IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN u5.id IS NOT NULL THEN 1 ELSE 0 END
    ) as id_completeness_score
FROM musicbrainz.artist a
LEFT JOIN musicbrainz.artist_ipi ai ON a.id = ai.artist
LEFT JOIN musicbrainz.artist_isni ai2 ON a.id = ai2.artist
LEFT JOIN musicbrainz.l_artist_url lau3 ON a.id = lau3.entity0
LEFT JOIN musicbrainz.url u3 ON lau3.entity1 = u3.id AND u3.url LIKE '%viaf%'
LEFT JOIN musicbrainz.l_artist_url lau4 ON a.id = lau4.entity0
LEFT JOIN musicbrainz.url u4 ON lau4.entity1 = u4.id AND u4.url LIKE '%wikidata%'
LEFT JOIN musicbrainz.l_artist_url lau5 ON a.id = lau5.entity0
LEFT JOIN musicbrainz.url u5 ON lau5.entity1 = u5.id AND u5.url LIKE '%imdb%'
WHERE a.type = 1  -- Person only
  AND a.edits_pending = 0
  AND (
    ai.artist IS NULL OR 
    ai2.artist IS NULL OR 
    u3.id IS NULL OR 
    u4.id IS NULL OR 
    u5.id IS NULL
  )
ORDER BY id_completeness_score ASC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.party_missing_ids_artist IS 'KPI principal: Couverture des identifiants externes pour les artistes';
COMMENT ON VIEW allfeat_kpi.party_missing_ids_artist_samples IS 'Échantillons d''artistes avec identifiants manquants pour analyse détaillée';
