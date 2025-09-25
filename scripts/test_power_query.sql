-- Test des requêtes Power Query corrigées
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/test_power_query.sql

\echo '🧪 Test des requêtes Power Query corrigées'
\echo '=========================================='

-- Test 1: KPI Overview
\echo 'Test 1: KPI Overview'
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_recordings,
    recordings_with_isrc
FROM allfeat_kpi.kpi_isrc_coverage

UNION ALL

SELECT 
    'ISWC Coverage' as kpi_name,
    iswc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_works,
    works_with_iswc
FROM allfeat_kpi.kpi_iswc_coverage

UNION ALL

SELECT 
    'Artist ID Completeness' as kpi_name,
    overall_id_completeness_pct as coverage_percentage,
    0 as duplicate_percentage,
    total_artists,
    artists_with_ipi + artists_with_isni
FROM allfeat_kpi.party_missing_ids_artist;

-- Test 2: ISRC Duplicates
\echo 'Test 2: ISRC Duplicates'
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level,
    name_similarity,
    artist_similarity,
    length_similarity
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 5;

-- Test 3: Missing Artist IDs
\echo 'Test 3: Missing Artist IDs'
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 5;

-- Test 4: Missing Artist IDs avec détails
\echo 'Test 4: Missing Artist IDs avec détails'
SELECT 
    artist_name,
    artist_gid,
    sort_name,
    begin_date,
    end_date,
    ipi_status,
    isni_status,
    viaf_status,
    wikidata_status,
    imdb_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 5;

-- Test 5: Confidence Levels
\echo 'Test 5: Confidence Levels'
SELECT 
    'Artist' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    ipi_coverage_pct,
    isni_coverage_pct
FROM allfeat_kpi.confidence_artist

UNION ALL

SELECT 
    'Work' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    iswc_coverage_pct,
    0 as ipi_coverage_pct
FROM allfeat_kpi.confidence_work

UNION ALL

SELECT 
    'Recording' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    isrc_coverage_pct,
    0 as ipi_coverage_pct
FROM allfeat_kpi.confidence_recording

UNION ALL

SELECT 
    'Release' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    date_coverage_pct,
    0 as ipi_coverage_pct
FROM allfeat_kpi.confidence_release;

-- Test 6: Work-Recording Inconsistencies
\echo 'Test 6: Work-Recording Inconsistencies'
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies
ORDER BY count DESC;

-- Test 7: Samples - Recordings without ISRC
\echo 'Test 7: Samples - Recordings without ISRC'
SELECT 
    recording_name,
    artist_name,
    recording_gid
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
LIMIT 3;

-- Test 8: Samples - Works without ISWC
\echo 'Test 8: Samples - Works without ISWC'
SELECT 
    work_name,
    work_type,
    language_code,
    work_gid
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
LIMIT 3;

-- Test 9: Samples - Low Confidence Artists
\echo 'Test 9: Samples - Low Confidence Artists'
SELECT 
    artist_name,
    artist_gid,
    confidence_score,
    confidence_level
FROM allfeat_kpi.confidence_artist_samples
WHERE confidence_level = 'Low Confidence'
ORDER BY confidence_score ASC
LIMIT 3;

-- Test 10: Samples - High Confidence Artists
\echo 'Test 10: Samples - High Confidence Artists'
SELECT 
    artist_name,
    artist_gid,
    confidence_score,
    confidence_level
FROM allfeat_kpi.confidence_artist_samples
WHERE confidence_level = 'High Confidence'
ORDER BY confidence_score DESC
LIMIT 3;

-- Test 11: System Status
\echo 'Test 11: System Status'
SELECT 
    key,
    value,
    updated_at
FROM allfeat_kpi.metadata
ORDER BY key;

-- Test 12: View Statistics
\echo 'Test 12: View Statistics'
SELECT 
    schemaname,
    viewname
FROM pg_views 
WHERE schemaname = 'allfeat_kpi'
ORDER BY viewname;

-- Test 13: Overview Statistics
\echo 'Test 13: Overview Statistics'
SELECT * FROM allfeat_kpi.stats_overview;

\echo '✅ Tous les tests des requêtes Power Query terminés!'
\echo '💡 Si aucune erreur n''est apparue, toutes les requêtes sont valides.'
