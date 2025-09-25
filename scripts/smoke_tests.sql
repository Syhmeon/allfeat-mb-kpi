-- Tests de validation des vues KPI Allfeat
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/smoke_tests.sql

\echo '🧪 Tests de validation des vues KPI Allfeat'
\echo '=========================================='

-- Test 1: Vérifier que le schéma existe
\echo 'Test 1: Vérification du schéma allfeat_kpi'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'allfeat_kpi') 
        THEN '✅ Schéma allfeat_kpi existe'
        ELSE '❌ Schéma allfeat_kpi manquant'
    END as test_result;

-- Test 2: Vérifier que les fonctions utilitaires existent
\echo 'Test 2: Vérification des fonctions utilitaires'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'format_percentage' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'allfeat_kpi'))
        THEN '✅ Fonction format_percentage existe'
        ELSE '❌ Fonction format_percentage manquante'
    END as test_result;

-- Test 3: Vérifier que toutes les vues KPI existent
\echo 'Test 3: Vérification des vues KPI'
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

-- Test 4: Vérifier que les vues principales retournent des données
\echo 'Test 4: Vérification des données dans les vues principales'

-- Test ISRC Coverage
SELECT 
    'ISRC Coverage' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count
FROM allfeat_kpi.kpi_isrc_coverage;

-- Test ISWC Coverage  
SELECT 
    'ISWC Coverage' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count
FROM allfeat_kpi.kpi_iswc_coverage;

-- Test Party Missing IDs
SELECT 
    'Party Missing IDs' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count
FROM allfeat_kpi.party_missing_ids_artist;

-- Test Confidence Artist
SELECT 
    'Confidence Artist' as kpi_name,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Données présentes'
        ELSE '❌ Aucune donnée'
    END as test_result,
    COUNT(*) as record_count
FROM allfeat_kpi.confidence_artist;

-- Test 5: Validations réalistes des données MusicBrainz
\echo 'Test 5: Validations réalistes des données MusicBrainz'
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

-- Test 6: Vérification des nouvelles colonnes Phase 1+2
\echo 'Test 6: Vérification des colonnes Phase 1+2'
SELECT 
    'confidence_artist' as view_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'allfeat_kpi' AND table_name = 'confidence_artist' AND column_name = 'phase1_confidence_level')
        THEN '✅ Colonnes Phase 1+2 présentes'
        ELSE '❌ Colonnes Phase 1+2 manquantes'
    END as test_result;

-- Test 7: Vérifier les métadonnées
\echo 'Test 7: Vérification des métadonnées'
SELECT 
    key,
    value,
    updated_at
FROM allfeat_kpi.metadata
ORDER BY key;

-- Test 8: Test de performance basique
\echo 'Test 8: Test de performance basique'
\timing on

SELECT 'Performance test - ISRC Coverage' as test_name;
SELECT * FROM allfeat_kpi.kpi_isrc_coverage LIMIT 1;

SELECT 'Performance test - Confidence Artist' as test_name;
SELECT * FROM allfeat_kpi.confidence_artist LIMIT 1;

\timing off

-- Test 9: Vérifier les échantillons
\echo 'Test 9: Vérification des échantillons'
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
FROM allfeat_kpi.dup_isrc_candidates_samples;

-- Test 10: Vérifier les statistiques générales
\echo 'Test 10: Statistiques générales'
SELECT * FROM allfeat_kpi.stats_overview;

\echo '🎉 Tests de validation terminés!'
\echo 'Si tous les tests sont ✅, les vues KPI sont prêtes à être utilisées.'
