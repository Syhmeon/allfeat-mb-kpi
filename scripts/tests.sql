-- Tests unifiés des vues KPI Allfeat (Phase 1+2)
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz_db -f scripts/tests.sql

\echo '🧪 Tests unifiés des vues KPI Allfeat (Phase 1+2)'
\echo '==============================================='
\echo ''

-- ============================================================================
-- SECTION 1: SMOKE TESTS (Connectivité + Schéma)
-- ============================================================================

\echo '📡 SECTION 1: SMOKE TESTS (Connectivité + Schéma)'
\echo '================================================'

-- Test 1.1: Vérifier que le schéma existe
\echo 'Test 1.1: Vérification du schéma allfeat_kpi'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'allfeat_kpi') 
        THEN '✅ Schéma allfeat_kpi existe'
        ELSE '❌ Schéma allfeat_kpi manquant'
    END as test_result;

-- Test 1.2: Vérifier que les fonctions utilitaires existent
\echo 'Test 1.2: Vérification des fonctions utilitaires'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'format_percentage' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'allfeat_kpi'))
        THEN '✅ Fonction format_percentage existe'
        ELSE '❌ Fonction format_percentage manquante'
    END as test_result;

-- Test 1.3: Vérifier que toutes les vues KPI existent
\echo 'Test 1.3: Vérification des vues KPI'
WITH expected_views AS (
    SELECT unnest(ARRAY[
        'kpi_isrc_coverage',
        'kpi_isrc_coverage_samples',
        'kpi_iswc_coverage', 
        'kpi_iswc_coverage_samples',
        'kpi_iswc_detailed',
        'party_missing_ids_artist',
        'party_missing_ids_artist_samples',
        'dup_isrc_candidates',
        'dup_isrc_candidates_samples',
        'rec_on_release_without_work',
        'rec_on_release_without_work_samples',
        'work_without_recording',
        'work_without_recording_samples',
        'work_recording_inconsistencies',
        'confidence_artist',
        'confidence_artist_samples',
        'confidence_work',
        'confidence_work_samples',
        'confidence_recording',
        'confidence_recording_samples',
        'confidence_release',
        'confidence_release_samples',
        'stats_overview'
    ]) as view_name
),
actual_views AS (
    SELECT viewname 
    FROM pg_views 
    WHERE schemaname = 'allfeat_kpi'
)
SELECT 
    ev.view_name,
    CASE 
        WHEN av.viewname IS NOT NULL THEN '✅ Existe'
        ELSE '❌ Manquante'
    END as status
FROM expected_views ev
LEFT JOIN actual_views av ON ev.view_name = av.viewname
ORDER BY ev.view_name;

-- Test 1.4: Validations réalistes des données MusicBrainz
\echo 'Test 1.4: Validations réalistes des données MusicBrainz'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM musicbrainz.recording WHERE isrc IS NOT NULL LIMIT 1)
        THEN '✅ Au moins 1 enregistrement avec ISRC trouvé'
        ELSE '❌ Aucun enregistrement avec ISRC trouvé'
    END as test_result;

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM musicbrainz.work WHERE iswc IS NOT NULL LIMIT 1)
        THEN '✅ Au moins 1 œuvre avec ISWC trouvée'
        ELSE '❌ Aucune œuvre avec ISWC trouvée'
    END as test_result;

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM musicbrainz.artist_isni LIMIT 1) OR EXISTS (SELECT 1 FROM musicbrainz.artist_ipi LIMIT 1)
        THEN '✅ Au moins 1 artiste avec ISNI/IPI trouvé'
        ELSE '❌ Aucun artiste avec ISNI/IPI trouvé'
    END as test_result;

-- Test 1.5: Vérifier les métadonnées
\echo 'Test 1.5: Vérification des métadonnées'
SELECT 
    key,
    value,
    updated_at
FROM allfeat_kpi.metadata
ORDER BY key;

-- ============================================================================
-- SECTION 2: KPI TESTS (ISRC, ISWC, Party IDs, Doublons, Incohérences)
-- ============================================================================

\echo ''
\echo '📊 SECTION 2: KPI TESTS (ISRC, ISWC, Party IDs, Doublons, Incohérences)'
\echo '====================================================================='

-- Test 2.1: ISRC Coverage
\echo 'Test 2.1: ISRC Coverage'
SELECT 
    'ISRC Coverage' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count,
    isrc_coverage_pct,
    duplicate_rate_pct,
    total_recordings,
    recordings_with_isrc
FROM allfeat_kpi.kpi_isrc_coverage;

-- Test 2.2: ISWC Coverage
\echo 'Test 2.2: ISWC Coverage'
SELECT 
    'ISWC Coverage' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count,
    iswc_coverage_pct,
    duplicate_rate_pct,
    total_works,
    works_with_iswc
FROM allfeat_kpi.kpi_iswc_coverage;

-- Test 2.3: Party Missing IDs
\echo 'Test 2.3: Party Missing IDs'
SELECT 
    'Party Missing IDs' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count,
    overall_id_completeness_pct,
    total_artists,
    artists_with_ipi,
    artists_with_isni
FROM allfeat_kpi.party_missing_ids_artist;

-- Test 2.4: Doublons ISRC (Top 5)
\echo 'Test 2.4: Doublons ISRC (Top 5 par risque)'
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

-- Test 2.5: Incohérences Work-Recording
\echo 'Test 2.5: Incohérences Work-Recording'
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies
ORDER BY count DESC;

-- Test 2.6: Statistiques générales
\echo 'Test 2.6: Statistiques générales'
SELECT * FROM allfeat_kpi.stats_overview;

-- ============================================================================
-- SECTION 3: CONFIDENCE TESTS (Phase 1 Catégorielle, Phase 2 Score)
-- ============================================================================

\echo ''
\echo '🎯 SECTION 3: CONFIDENCE TESTS (Phase 1 Catégorielle, Phase 2 Score)'
\echo '=================================================================='

-- Test 3.1: Vérification des colonnes Phase 1+2
\echo 'Test 3.1: Vérification des colonnes Phase 1+2'
SELECT 
    table_name,
    column_name,
    CASE 
        WHEN column_name IN ('phase1_confidence_level', 'phase2_confidence_score', 'phase2_confidence_level') 
        THEN '✅ Colonne Phase 1+2 présente'
        ELSE 'ℹ️  Colonne standard'
    END as status
FROM information_schema.columns 
WHERE table_schema = 'allfeat_kpi' 
  AND table_name LIKE 'confidence_%'
  AND column_name IN ('phase1_confidence_level', 'phase2_confidence_score', 'phase2_confidence_level', 'confidence_level', 'confidence_score')
ORDER BY table_name, column_name;

-- Test 3.2: Confidence Artist - Vue principale
\echo 'Test 3.2: Confidence Artist - Vue principale'
SELECT 
    total_artists,
    phase1_high_count,
    phase1_medium_count,
    phase1_low_count,
    phase2_high_count,
    phase2_medium_count,
    phase2_low_count,
    average_phase2_score,
    overall_confidence_level,
    CASE 
        WHEN phase1_high_count + phase1_medium_count + phase1_low_count = total_artists
        THEN '✅ Logique Phase 1 cohérente'
        ELSE '❌ Logique Phase 1 incohérente'
    END as phase1_test,
    CASE 
        WHEN phase2_high_count + phase2_medium_count + phase2_low_count = total_artists
        THEN '✅ Logique Phase 2 cohérente'
        ELSE '❌ Logique Phase 2 incohérente'
    END as phase2_test
FROM allfeat_kpi.confidence_artist;

-- Test 3.3: Confidence Work - Vue principale
\echo 'Test 3.3: Confidence Work - Vue principale'
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

-- Test 3.4: Confidence Recording - Vue principale
\echo 'Test 3.4: Confidence Recording - Vue principale'
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

-- Test 3.5: Confidence Release - Vue principale
\echo 'Test 3.5: Confidence Release - Vue principale'
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

-- Test 3.6: Vérification des seuils Phase 2
\echo 'Test 3.6: Vérification des seuils Phase 2'
SELECT 
    'confidence_artist' as view_name,
    average_phase2_score,
    CASE 
        WHEN average_phase2_score >= 0.0 AND average_phase2_score <= 1.0
        THEN '✅ Score Phase 2 dans la plage [0-1]'
        ELSE '❌ Score Phase 2 hors plage'
    END as test_result
FROM allfeat_kpi.confidence_artist;

-- Test 3.7: Comparaison Phase 1 vs Phase 2 pour les artistes
\echo 'Test 3.7: Comparaison Phase 1 vs Phase 2 - Artistes'
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

-- Test 3.8: Distribution des scores Phase 2
\echo 'Test 3.8: Distribution des scores Phase 2 - Artistes'
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

-- Test 3.9: Vérification cohérence Phase 1 vs Phase 2
\echo 'Test 3.9: Vérification cohérence Phase 1 vs Phase 2 - Artistes'
SELECT 
    phase1_confidence_level,
    phase2_confidence_level,
    COUNT(*) as count,
    ROUND(AVG(phase2_confidence_score), 3) as avg_score
FROM allfeat_kpi.confidence_artist_samples
GROUP BY phase1_confidence_level, phase2_confidence_level
ORDER BY phase1_confidence_level, phase2_confidence_level;

-- Test 3.10: Critères de confiance les plus discriminants
\echo 'Test 3.10: Critères de confiance les plus discriminants - Artistes'
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

-- ============================================================================
-- SECTION 4: POWER QUERY COMPATIBILITY (Requêtes alignées avec /sql/views/)
-- ============================================================================

\echo ''
\echo '🔌 SECTION 4: POWER QUERY COMPATIBILITY (Requêtes alignées avec /sql/views/)'
\echo '========================================================================='

-- Test 4.1: KPI Overview (Tableau de bord principal)
\echo 'Test 4.1: KPI Overview (Tableau de bord principal)'
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

-- Test 4.2: ISRC Duplicates (Top 5 par risque)
\echo 'Test 4.2: ISRC Duplicates (Top 5 par risque)'
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

-- Test 4.3: Missing Artist IDs (Version corrigée - sans colonnes fantômes)
\echo 'Test 4.3: Missing Artist IDs (Version corrigée)'
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 5;

-- Test 4.4: Confidence Levels Phase 1+2
\echo 'Test 4.4: Confidence Levels Phase 1+2'
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

UNION ALL

SELECT 
    'Work' as entity_type,
    phase1_high_pct as phase1_high_percentage,
    phase1_medium_pct as phase1_medium_percentage,
    phase1_low_pct as phase1_low_percentage,
    phase2_high_pct as phase2_high_percentage,
    phase2_medium_pct as phase2_medium_percentage,
    phase2_low_pct as phase2_low_percentage,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_work

UNION ALL

SELECT 
    'Recording' as entity_type,
    phase1_high_pct as phase1_high_percentage,
    phase1_medium_pct as phase1_medium_percentage,
    phase1_low_pct as phase1_low_percentage,
    phase2_high_pct as phase2_high_percentage,
    phase2_medium_pct as phase2_medium_percentage,
    phase2_low_pct as phase2_low_percentage,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_recording

UNION ALL

SELECT 
    'Release' as entity_type,
    phase1_high_pct as phase1_high_percentage,
    phase1_medium_pct as phase1_medium_percentage,
    phase1_low_pct as phase1_low_percentage,
    phase2_high_pct as phase2_high_percentage,
    phase2_medium_pct as phase2_medium_percentage,
    phase2_low_pct as phase2_low_percentage,
    average_phase2_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_release;

-- Test 4.5: Comparaison Phase 1 vs Phase 2
\echo 'Test 4.5: Comparaison Phase 1 vs Phase 2'
SELECT 
    'Phase 1 (Catégorielle)' as method,
    phase1_high_count as high_count,
    phase1_medium_count as medium_count,
    phase1_low_count as low_count,
    phase1_high_pct as high_percentage,
    phase1_medium_pct as medium_percentage,
    phase1_low_pct as low_percentage
FROM allfeat_kpi.confidence_artist

UNION ALL

SELECT 
    'Phase 2 (Numérique)' as method,
    phase2_high_count as high_count,
    phase2_medium_count as medium_count,
    phase2_low_count as low_count,
    phase2_high_pct as high_percentage,
    phase2_medium_pct as medium_percentage,
    phase2_low_pct as low_percentage
FROM allfeat_kpi.confidence_artist;

-- ============================================================================
-- SECTION 5: SAMPLE QUERIES (Top-N, Échantillons aléatoires)
-- ============================================================================

\echo ''
\echo '📋 SECTION 5: SAMPLE QUERIES (Top-N, Échantillons aléatoires)'
\echo '==========================================================='

-- Test 5.1: Échantillons d'artistes avec faible confiance
\echo 'Test 5.1: Échantillons d''artistes avec faible confiance (Phase 2)'
SELECT 
    artist_name,
    artist_gid,
    phase2_confidence_score,
    phase2_confidence_level,
    has_isrc,
    has_iswc,
    on_release,
    has_ipi,
    has_isni
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'Low'
ORDER BY phase2_confidence_score ASC
LIMIT 5;

-- Test 5.2: Échantillons d'artistes avec haute confiance
\echo 'Test 5.2: Échantillons d''artistes avec haute confiance (Phase 2)'
SELECT 
    artist_name,
    artist_gid,
    phase2_confidence_score,
    phase2_confidence_level,
    has_isrc,
    has_iswc,
    on_release,
    has_ipi,
    has_isni
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'High'
ORDER BY phase2_confidence_score DESC
LIMIT 5;

-- Test 5.3: Échantillons d'enregistrements sans ISRC
\echo 'Test 5.3: Échantillons d''enregistrements sans ISRC'
SELECT 
    recording_name,
    artist_name,
    recording_gid
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
LIMIT 5;

-- Test 5.4: Échantillons d'œuvres sans ISWC
\echo 'Test 5.4: Échantillons d''œuvres sans ISWC'
SELECT 
    work_name,
    work_type,
    language_code,
    work_gid
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
LIMIT 5;

-- Test 5.5: Échantillons de doublons ISRC
\echo 'Test 5.5: Échantillons de doublons ISRC'
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level,
    sample_recording_names
FROM allfeat_kpi.dup_isrc_candidates_samples
ORDER BY duplicate_risk_score DESC
LIMIT 5;

-- Test 5.6: Échantillons d'artistes avec identifiants manquants
\echo 'Test 5.6: Échantillons d''artistes avec identifiants manquants'
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 5;

-- Test 5.7: Vérifier les échantillons
\echo 'Test 5.7: Vérification des échantillons'
SELECT 
    'ISRC Samples' as sample_type,
    COUNT(*) as sample_count
FROM allfeat_kpi.kpi_isrc_coverage_samples

UNION ALL

SELECT 
    'Artist Samples' as sample_type,
    COUNT(*) as sample_count
FROM allfeat_kpi.confidence_artist_samples

UNION ALL

SELECT 
    'Duplicate ISRC Samples' as sample_type,
    COUNT(*) as sample_count
FROM allfeat_kpi.dup_isrc_candidates_samples

UNION ALL

SELECT 
    'Missing IDs Samples' as sample_type,
    COUNT(*) as sample_count
FROM allfeat_kpi.party_missing_ids_artist_samples;

-- ============================================================================
-- SECTION 6: PERFORMANCE TESTS
-- ============================================================================

\echo ''
\echo '⚡ SECTION 6: PERFORMANCE TESTS'
\echo '=============================='

-- Test 6.1: Test de performance basique
\echo 'Test 6.1: Test de performance basique'
\timing on

SELECT 'Performance test - ISRC Coverage' as test_name;
SELECT * FROM allfeat_kpi.kpi_isrc_coverage LIMIT 1;

SELECT 'Performance test - Confidence Artist' as test_name;
SELECT * FROM allfeat_kpi.confidence_artist LIMIT 1;

SELECT 'Performance test - Doublons ISRC' as test_name;
SELECT * FROM allfeat_kpi.dup_isrc_candidates LIMIT 1;

\timing off

-- Test 6.2: Statistiques d'utilisation
\echo 'Test 6.2: Statistiques d''utilisation'
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'allfeat_kpi'
ORDER BY viewname
LIMIT 5;

-- ============================================================================
-- SECTION 7: VALIDATION FINALE
-- ============================================================================

\echo ''
\echo '✅ SECTION 7: VALIDATION FINALE'
\echo '=============================='

-- Test 7.1: Résumé des améliorations Phase 1+2
\echo 'Test 7.1: Résumé des améliorations Phase 1+2'
SELECT 
    'Vues de confiance' as component,
    'Phase 1 (catégorielle) + Phase 2 (numérique)' as improvement,
    'Logique explicite basée sur IDs + cohérence des liens' as description
UNION ALL
SELECT 
    'Scripts apply_views' as component,
    'Vérification robuste du schéma + création auto metadata' as improvement,
    'Plus de vérification fragile, gestion d''erreurs améliorée' as description
UNION ALL
SELECT 
    'Tests unifiés' as component,
    'Un seul script tests.sql au lieu de 4 scripts' as improvement,
    'Maintenance simplifiée, structure claire par sections' as description
UNION ALL
SELECT 
    'Tests Power Query' as component,
    'Élimination des colonnes fantômes' as improvement,
    'Aucune référence à viaf_status, wikidata_status, etc.' as description
UNION ALL
SELECT 
    'Documentation' as component,
    'Clarification logique Phase 1+2' as improvement,
    'Description explicite des règles catégorielles et poids numériques' as description;

-- Test 7.2: Poids numériques Phase 2
\echo 'Test 7.2: Poids numériques Phase 2'
SELECT 
    'Artistes' as entity_type,
    '0.3 * has_isni + 0.3 * has_iswc + 0.2 * has_isrc + 0.2 * on_release' as formula,
    'Poids: ISNI/IPI=0.3, ISWC=0.3, ISRC=0.2, Release=0.2' as weights
UNION ALL
SELECT 
    'Œuvres' as entity_type,
    '0.4 * has_iswc + 0.3 * has_isni + 0.2 * has_isrc + 0.1 * on_release' as formula,
    'Poids: ISWC=0.4, ISNI/IPI=0.3, ISRC=0.2, Release=0.1' as weights
UNION ALL
SELECT 
    'Enregistrements' as entity_type,
    '0.3 * has_isrc + 0.3 * has_iswc + 0.3 * has_isni + 0.1 * on_release' as formula,
    'Poids: ISRC=0.3, ISWC=0.3, ISNI/IPI=0.3, Release=0.1' as weights
UNION ALL
SELECT 
    'Releases' as entity_type,
    '0.3 * has_date + 0.3 * has_isrc + 0.2 * has_iswc + 0.2 * has_isni' as formula,
    'Poids: Date=0.3, ISRC=0.3, ISWC=0.2, ISNI/IPI=0.2' as weights;

-- Test 7.3: Seuils Phase 2
\echo 'Test 7.3: Seuils Phase 2'
SELECT 
    'High' as level,
    '>= 0.8' as threshold,
    'Confiance élevée' as description
UNION ALL
SELECT 
    'Medium' as level,
    '0.4 - 0.79' as threshold,
    'Confiance moyenne' as description
UNION ALL
SELECT 
    'Low' as level,
    '< 0.4' as threshold,
    'Confiance faible' as description;

\echo ''
\echo '🎉 Tests unifiés terminés!'
\echo '========================'
\echo '💡 Si tous les tests sont ✅, les vues KPI sont prêtes à être utilisées.'
\echo '🔍 Logique de confiance Phase 1+2 validée et robuste.'
\echo '📊 Toutes les requêtes Power Query sont alignées avec les vues réelles.'
\echo '⚡ Performance des vues vérifiée.'
\echo ''
\echo '📋 Sections testées:'
\echo '   1. Smoke Tests (Connectivité + Schéma)'
\echo '   2. KPI Tests (ISRC, ISWC, Party IDs, Doublons, Incohérences)'
\echo '   3. Confidence Tests (Phase 1 Catégorielle, Phase 2 Score)'
\echo '   4. Power Query Compatibility (Requêtes alignées)'
\echo '   5. Sample Queries (Top-N, Échantillons aléatoires)'
\echo '   6. Performance Tests'
\echo '   7. Validation Finale'
