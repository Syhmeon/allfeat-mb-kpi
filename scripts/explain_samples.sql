-- Exemples d'utilisation des vues KPI Allfeat
-- Usage: psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/explain_samples.sql

\echo '📊 Exemples d''utilisation des vues KPI Allfeat'
\echo '============================================='

-- Exemple 1: Vue d'ensemble des statistiques
\echo 'Exemple 1: Vue d''ensemble des statistiques générales'
SELECT * FROM allfeat_kpi.stats_overview;

-- Exemple 2: Couverture ISRC avec détails
\echo 'Exemple 2: Couverture ISRC'
SELECT 
    total_recordings,
    recordings_with_isrc,
    isrc_coverage_pct,
    duplicate_isrc_count,
    duplicate_rate_pct
FROM allfeat_kpi.kpi_isrc_coverage;

-- Exemple 3: Couverture ISWC avec détails
\echo 'Exemple 3: Couverture ISWC'
SELECT 
    total_works,
    works_with_iswc,
    iswc_coverage_pct,
    duplicate_iswc_count,
    duplicate_rate_pct
FROM allfeat_kpi.kpi_iswc_coverage;

-- Exemple 4: Identifiants manquants pour les artistes
\echo 'Exemple 4: Identifiants manquants - Artistes'
SELECT 
    total_artists,
    artists_missing_ipi,
    artists_missing_isni,
    overall_id_completeness_pct
FROM allfeat_kpi.party_missing_ids_artist;

-- Exemple 5: Candidats doublons ISRC (top 10 par risque)
\echo 'Exemple 5: Top 10 des candidats doublons ISRC par risque'
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level,
    sample_recording_names
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 10;

-- Exemple 6: Niveaux de confiance par entité
\echo 'Exemple 6: Niveaux de confiance par entité'
SELECT 
    'Artist' as entity_type,
    average_confidence_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_artist

UNION ALL

SELECT 
    'Work' as entity_type,
    average_confidence_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_work

UNION ALL

SELECT 
    'Recording' as entity_type,
    average_confidence_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_recording

UNION ALL

SELECT 
    'Release' as entity_type,
    average_confidence_score,
    overall_confidence_level
FROM allfeat_kpi.confidence_release;

-- Exemple 7: Incohérences Work-Recording
\echo 'Exemple 7: Incohérences Work-Recording'
SELECT * FROM allfeat_kpi.work_recording_inconsistencies;

-- Exemple 8: Échantillons d'artistes avec faible confiance
\echo 'Exemple 8: Échantillons d''artistes avec faible confiance'
SELECT 
    artist_name,
    confidence_score,
    confidence_level,
    begin_date,
    area
FROM allfeat_kpi.confidence_artist_samples
WHERE confidence_level = 'Low Confidence'
ORDER BY confidence_score ASC
LIMIT 10;

-- Exemple 9: Échantillons d'enregistrements sans ISRC
\echo 'Exemple 9: Échantillons d''enregistrements sans ISRC'
SELECT 
    recording_name,
    artist_name,
    recording_gid
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
LIMIT 10;

-- Exemple 10: Échantillons d'œuvres sans ISWC
\echo 'Exemple 10: Échantillons d''œuvres sans ISWC'
SELECT 
    work_name,
    work_type,
    language_code
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
LIMIT 10;

-- Exemple 11: Analyse des doublons ISRC par similarité
\echo 'Exemple 11: Analyse des doublons ISRC par similarité'
SELECT 
    name_similarity,
    artist_similarity,
    length_similarity,
    COUNT(*) as count,
    AVG(duplicate_risk_score) as avg_risk_score
FROM allfeat_kpi.dup_isrc_candidates
GROUP BY name_similarity, artist_similarity, length_similarity
ORDER BY avg_risk_score DESC;

-- Exemple 12: Détail des œuvres avec ISWC (vue détaillée)
\echo 'Exemple 12: Détail des œuvres avec ISWC'
SELECT 
    work_name,
    iswc,
    work_type,
    language_code,
    iswc_status
FROM allfeat_kpi.kpi_iswc_detailed
WHERE iswc_status = 'Unique ISWC'
ORDER BY last_updated DESC
LIMIT 10;

-- Exemple 13: Requêtes pour Excel/ODBC (format tabulaire)
\echo 'Exemple 13: Requêtes optimisées pour Excel/ODBC'
\echo '-- Pour Power Query, utilisez ces requêtes:'

\echo '-- 1. Résumé des KPI principaux'
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage
FROM allfeat_kpi.kpi_isrc_coverage

UNION ALL

SELECT 
    'ISWC Coverage' as kpi_name,
    iswc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage
FROM allfeat_kpi.kpi_iswc_coverage

UNION ALL

SELECT 
    'Artist ID Completeness' as kpi_name,
    overall_id_completeness_pct as coverage_percentage,
    0 as duplicate_percentage
FROM allfeat_kpi.party_missing_ids_artist;

\echo '-- 2. Top 20 des doublons ISRC à traiter'
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 20;

\echo '-- 3. Artistes avec identifiants manquants'
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    viaf_status,
    wikidata_status,
    imdb_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 50;

\echo '📈 Ces exemples montrent comment utiliser les vues KPI pour analyser la qualité des métadonnées MusicBrainz.'
\echo '💡 Pour Excel/ODBC, utilisez les requêtes marquées comme "optimisées pour Excel/ODBC".'
