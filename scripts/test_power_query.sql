-- Test des requêtes Power Query corrigées (Phase 1+2)
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/test_power_query.sql

\echo '🧪 Test des requêtes Power Query corrigées (Phase 1+2)'
\echo '====================================================='

-- Test 1: KPI Overview
\echo 'Test 1: KPI Overview'
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_recordings,
    recordings_with_isrc
FROM allfeat_kpi.kpi_isrc_coverage
LIMIT 1;

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
LIMIT 1;

-- Test 3: Missing Artist IDs (Version corrigée - sans colonnes fantômes)
\echo 'Test 3: Missing Artist IDs (Version corrigée)'
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 1;

-- Test 4: Confidence Levels Phase 1+2
\echo 'Test 4: Confidence Levels Phase 1+2'
SELECT 
    'Artist' as entity_type,
    phase1_high_pct as phase1_high_percentage,
    phase1_medium_pct as phase1_medium_percentage,
    phase1_low_pct as phase1_low_percentage,
    phase2_high_pct as phase2_high_percentage,
    phase2_medium_pct as phase2_medium_percentage,
    phase2_low_pct as phase2_low_percentage,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_artist
LIMIT 1;

-- Test 5: Work-Recording Inconsistencies
\echo 'Test 5: Work-Recording Inconsistencies'
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies
ORDER BY count DESC
LIMIT 1;

-- Test 6: Samples - Recordings without ISRC
\echo 'Test 6: Samples - Recordings without ISRC'
SELECT 
    recording_name,
    artist_name,
    recording_gid
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
LIMIT 1;

-- Test 7: Samples - Works without ISWC
\echo 'Test 7: Samples - Works without ISWC'
SELECT 
    work_name,
    work_type,
    language_code,
    work_gid
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
LIMIT 1;

-- Test 8: Samples - Low Confidence Artists (Phase 2)
\echo 'Test 8: Samples - Low Confidence Artists (Phase 2)'
SELECT 
    artist_name,
    artist_gid,
    phase2_confidence_score,
    phase2_confidence_level,
    has_artist_id,
    has_isrc,
    has_iswc,
    on_release
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'Low'
ORDER BY phase2_confidence_score ASC
LIMIT 1;

-- Test 9: Comparaison Phase 1 vs Phase 2
\echo 'Test 9: Comparaison Phase 1 vs Phase 2'
SELECT 
    'Phase 1 (Catégorielle)' as method,
    phase1_high_count as high_count,
    phase1_medium_count as medium_count,
    phase1_low_count as low_count,
    phase1_high_pct as high_percentage,
    phase1_medium_pct as medium_percentage,
    phase1_low_pct as low_percentage
FROM allfeat_kpi.confidence_artist
LIMIT 1;

-- Test 10: Samples - High Confidence Artists (Phase 2)
\echo 'Test 10: Samples - High Confidence Artists (Phase 2)'
SELECT 
    artist_name,
    artist_gid,
    phase2_confidence_score,
    phase2_confidence_level,
    has_artist_id,
    has_isrc,
    has_iswc,
    on_release
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'High'
ORDER BY phase2_confidence_score DESC
LIMIT 1;

-- Test 11: Confidence Work (Phase 1+2)
\echo 'Test 11: Confidence Work (Phase 1+2)'
SELECT 
    total_works,
    phase1_high_count,
    phase1_medium_count,
    phase1_low_count,
    phase2_high_count,
    phase2_medium_count,
    phase2_low_count,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_work
LIMIT 1;

-- Test 12: Confidence Recording (Phase 1+2)
\echo 'Test 12: Confidence Recording (Phase 1+2)'
SELECT 
    total_recordings,
    phase1_high_count,
    phase1_medium_count,
    phase1_low_count,
    phase2_high_count,
    phase2_medium_count,
    phase2_low_count,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_recording
LIMIT 1;

-- Test 13: Confidence Release (Phase 1+2)
\echo 'Test 13: Confidence Release (Phase 1+2)'
SELECT 
    total_releases,
    phase1_high_count,
    phase1_medium_count,
    phase1_low_count,
    phase2_high_count,
    phase2_medium_count,
    phase2_low_count,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_release
LIMIT 1;

-- Test 14: System Status
\echo 'Test 14: System Status'
SELECT 
    key,
    value,
    updated_at
FROM allfeat_kpi.metadata
ORDER BY key
LIMIT 3;

-- Test 15: View Statistics
\echo 'Test 15: View Statistics'
SELECT 
    schemaname,
    viewname
FROM pg_views
WHERE schemaname = 'allfeat_kpi'
ORDER BY viewname
LIMIT 5;

\echo '✅ Tests des requêtes Power Query Phase 1+2 terminés!'
\echo '💡 Toutes les requêtes utilisent uniquement les colonnes réelles des vues'
\echo '🔍 Aucune colonne fantôme (viaf_status, wikidata_status, etc.)'