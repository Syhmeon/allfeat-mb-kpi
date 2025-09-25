-- Test des vues de confiance Phase 1 + Phase 2
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/test_confidence_views.sql

\echo '🧪 Test des vues de confiance Phase 1 + Phase 2'
\echo '=============================================='

-- Test 1: Confidence Artist - Vue principale
\echo 'Test 1: Confidence Artist - Vue principale'
SELECT 
    total_artists,
    phase1_high_count,
    phase1_medium_count,
    phase1_low_count,
    phase2_high_count,
    phase2_medium_count,
    phase2_low_count,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_artist;

-- Test 2: Confidence Artist - Échantillons
\echo 'Test 2: Confidence Artist - Échantillons (5 premiers)'
SELECT 
    artist_name,
    has_isrc,
    has_iswc,
    on_release,
    has_ipi,
    has_isni,
    phase1_confidence_level,
    phase2_confidence_score,
    phase2_confidence_level,
    confidence_level,
    confidence_score
FROM allfeat_kpi.confidence_artist_samples
LIMIT 5;

-- Test 3: Confidence Recording - Vue principale
\echo 'Test 3: Confidence Recording - Vue principale'
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
FROM allfeat_kpi.confidence_recording;

-- Test 4: Confidence Recording - Échantillons
\echo 'Test 4: Confidence Recording - Échantillons (5 premiers)'
SELECT 
    recording_name,
    has_isrc,
    has_iswc,
    on_release,
    has_ipi,
    has_isni,
    phase1_confidence_level,
    phase2_confidence_score,
    phase2_confidence_level,
    confidence_level,
    confidence_score
FROM allfeat_kpi.confidence_recording_samples
LIMIT 5;

-- Test 5: Confidence Work - Vue principale
\echo 'Test 5: Confidence Work - Vue principale'
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
FROM allfeat_kpi.confidence_work;

-- Test 6: Confidence Work - Échantillons
\echo 'Test 6: Confidence Work - Échantillons (5 premiers)'
SELECT 
    work_name,
    has_iswc,
    has_isrc,
    on_release,
    has_ipi,
    has_isni,
    phase1_confidence_level,
    phase2_confidence_score,
    phase2_confidence_level,
    confidence_level,
    confidence_score
FROM allfeat_kpi.confidence_work_samples
LIMIT 5;

-- Test 7: Confidence Release - Vue principale
\echo 'Test 7: Confidence Release - Vue principale'
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
FROM allfeat_kpi.confidence_release;

-- Test 8: Confidence Release - Échantillons
\echo 'Test 8: Confidence Release - Échantillons (5 premiers)'
SELECT 
    release_name,
    has_date,
    has_country,
    has_isrc,
    has_iswc,
    has_ipi,
    has_isni,
    phase1_confidence_level,
    phase2_confidence_score,
    phase2_confidence_level,
    confidence_level,
    confidence_score
FROM allfeat_kpi.confidence_release_samples
LIMIT 5;

-- Test 9: Comparaison Phase 1 vs Phase 2 pour les artistes
\echo 'Test 9: Comparaison Phase 1 vs Phase 2 - Artistes'
SELECT 
    'Phase 1' as phase,
    phase1_high_count as high_count,
    phase1_medium_count as medium_count,
    phase1_low_count as low_count,
    phase1_high_pct as high_pct,
    phase1_medium_pct as medium_pct,
    phase1_low_pct as low_pct
FROM allfeat_kpi.confidence_artist

UNION ALL

SELECT 
    'Phase 2' as phase,
    phase2_high_count as high_count,
    phase2_medium_count as medium_count,
    phase2_low_count as low_count,
    phase2_high_pct as high_pct,
    phase2_medium_pct as medium_pct,
    phase2_low_pct as low_pct
FROM allfeat_kpi.confidence_artist;

-- Test 10: Distribution des scores Phase 2
\echo 'Test 10: Distribution des scores Phase 2 - Artistes'
SELECT 
    CASE 
        WHEN phase2_confidence_score >= 0.8 THEN '0.8-1.0 (High)'
        WHEN phase2_confidence_score >= 0.6 THEN '0.6-0.8'
        WHEN phase2_confidence_score >= 0.4 THEN '0.4-0.6 (Medium)'
        WHEN phase2_confidence_score >= 0.2 THEN '0.2-0.4'
        ELSE '0.0-0.2 (Low)'
    END as score_range,
    COUNT(*) as count
FROM allfeat_kpi.confidence_artist_samples
GROUP BY 
    CASE 
        WHEN phase2_confidence_score >= 0.8 THEN '0.8-1.0 (High)'
        WHEN phase2_confidence_score >= 0.6 THEN '0.6-0.8'
        WHEN phase2_confidence_score >= 0.4 THEN '0.4-0.6 (Medium)'
        WHEN phase2_confidence_score >= 0.2 THEN '0.2-0.4'
        ELSE '0.0-0.2 (Low)'
    END
ORDER BY score_range;

-- Test 11: Vérification cohérence Phase 1 vs Phase 2
\echo 'Test 11: Vérification cohérence Phase 1 vs Phase 2 - Artistes'
SELECT 
    phase1_confidence_level,
    phase2_confidence_level,
    COUNT(*) as count,
    ROUND(AVG(phase2_confidence_score), 3) as avg_score
FROM allfeat_kpi.confidence_artist_samples
GROUP BY phase1_confidence_level, phase2_confidence_level
ORDER BY phase1_confidence_level, phase2_confidence_level;

-- Test 12: Critères de confiance les plus discriminants
\echo 'Test 12: Critères de confiance les plus discriminants - Artistes'
SELECT 
    'has_isrc' as criterion,
    SUM(has_isrc) as total_with_criterion,
    ROUND(AVG(CASE WHEN has_isrc = 1 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_with,
    ROUND(AVG(CASE WHEN has_isrc = 0 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_without
FROM allfeat_kpi.confidence_artist_samples

UNION ALL

SELECT 
    'has_iswc' as criterion,
    SUM(has_iswc) as total_with_criterion,
    ROUND(AVG(CASE WHEN has_iswc = 1 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_with,
    ROUND(AVG(CASE WHEN has_iswc = 0 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_without
FROM allfeat_kpi.confidence_artist_samples

UNION ALL

SELECT 
    'has_isni' as criterion,
    SUM(has_isni) as total_with_criterion,
    ROUND(AVG(CASE WHEN has_isni = 1 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_with,
    ROUND(AVG(CASE WHEN has_isni = 0 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_without
FROM allfeat_kpi.confidence_artist_samples

UNION ALL

SELECT 
    'on_release' as criterion,
    SUM(on_release) as total_with_criterion,
    ROUND(AVG(CASE WHEN on_release = 1 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_with,
    ROUND(AVG(CASE WHEN on_release = 0 THEN phase2_confidence_score ELSE NULL END), 3) as avg_score_without
FROM allfeat_kpi.confidence_artist_samples;

\echo '✅ Tests des vues de confiance Phase 1 + Phase 2 terminés!'
\echo '💡 Vérifiez que :'
\echo '   - Les totaux Phase 1 et Phase 2 correspondent'
\echo '   - Les scores moyens sont cohérents avec les seuils (0.4, 0.8)'
\echo '   - La logique catégorielle Phase 1 est cohérente avec les scores Phase 2'
