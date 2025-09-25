# Requêtes Power Query optimisées pour Allfeat MusicBrainz KPI

## Configuration de base

### Connexion ODBC
- **Nom de la source** : `MB_ODBC`
- **Serveur** : `127.0.0.1:5432`
- **Base de données** : `musicbrainz`
- **Utilisateur** : `musicbrainz`
- **Mot de passe** : `musicbrainz`

## Requêtes principales

### 1. KPI Overview (Tableau de bord principal)

```sql
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_recordings,
    recordings_with_isrc,
    recordings_without_isrc
FROM allfeat_kpi.kpi_isrc_coverage

UNION ALL

SELECT 
    'ISWC Coverage' as kpi_name,
    iswc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_works,
    works_with_iswc,
    works_without_iswc
FROM allfeat_kpi.kpi_iswc_coverage

UNION ALL

SELECT 
    'Artist ID Completeness' as kpi_name,
    overall_id_completeness_pct as coverage_percentage,
    0 as duplicate_percentage,
    total_artists,
    artists_with_ipi + artists_with_isni + artists_with_viaf + artists_with_wikidata + artists_with_imdb,
    total_artists - (artists_with_ipi + artists_with_isni + artists_with_viaf + artists_with_wikidata + artists_with_imdb)
FROM allfeat_kpi.party_missing_ids_artist;
```

### 2. ISRC Duplicates (Top 50 par risque)

```sql
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level,
    name_similarity,
    artist_similarity,
    length_similarity,
    sample_recording_names[1] as recording_1,
    sample_recording_names[2] as recording_2,
    sample_artist_credits[1] as artist_1,
    sample_artist_credits[2] as artist_2
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 50;
```

### 3. Missing Artist IDs (Top 100 par score de complétude)

```sql
SELECT 
    artist_name,
    artist_gid,
    sort_name,
    begin_date,
    end_date,
    area,
    ipi_status,
    isni_status,
    viaf_status,
    wikidata_status,
    imdb_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 100;
```

### 4. Confidence Levels (Résumé par entité)

```sql
SELECT 
    'Artist' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    ipi_coverage_pct,
    isni_coverage_pct,
    total_artists
FROM allfeat_kpi.confidence_artist

UNION ALL

SELECT 
    'Work' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    iswc_coverage_pct,
    0 as ipi_coverage_pct,
    total_works
FROM allfeat_kpi.confidence_work

UNION ALL

SELECT 
    'Recording' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    isrc_coverage_pct,
    0 as ipi_coverage_pct,
    total_recordings
FROM allfeat_kpi.confidence_recording

UNION ALL

SELECT 
    'Release' as entity_type,
    average_confidence_score,
    overall_confidence_level,
    gid_coverage_pct,
    name_coverage_pct,
    date_coverage_pct,
    0 as ipi_coverage_pct,
    total_releases
FROM allfeat_kpi.confidence_release;
```

### 5. Work-Recording Inconsistencies

```sql
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies
ORDER BY count DESC;
```

### 6. Samples - Recordings without ISRC

```sql
SELECT 
    recording_name,
    artist_name,
    recording_gid,
    length,
    comment
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
ORDER BY RANDOM()
LIMIT 50;
```

### 7. Samples - Works without ISWC

```sql
SELECT 
    work_name,
    work_type,
    language_code,
    work_gid,
    comment
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
ORDER BY RANDOM()
LIMIT 50;
```

### 8. Samples - Low Confidence Artists

```sql
SELECT 
    artist_name,
    artist_gid,
    sort_name,
    begin_date,
    end_date,
    area,
    confidence_score,
    confidence_level
FROM allfeat_kpi.confidence_artist_samples
WHERE confidence_level = 'Low Confidence'
ORDER BY confidence_score ASC
LIMIT 50;
```

## Requêtes pour PivotTables

### 9. ISRC Duplicates Analysis (pour PivotTable)

```sql
SELECT 
    risk_level,
    name_similarity,
    artist_similarity,
    length_similarity,
    duplicate_count,
    duplicate_risk_score
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC;
```

### 10. Artist ID Coverage Analysis (pour PivotTable)

```sql
SELECT 
    ipi_status,
    isni_status,
    viaf_status,
    wikidata_status,
    imdb_status,
    id_completeness_score,
    artist_name
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC;
```

### 11. Confidence Analysis by Entity (pour PivotTable)

```sql
SELECT 
    entity_type,
    overall_confidence_level,
    average_confidence_score,
    gid_coverage_pct,
    name_coverage_pct
FROM (
    SELECT 
        'Artist' as entity_type,
        overall_confidence_level,
        average_confidence_score,
        gid_coverage_pct,
        name_coverage_pct
    FROM allfeat_kpi.confidence_artist
    
    UNION ALL
    
    SELECT 
        'Work' as entity_type,
        overall_confidence_level,
        average_confidence_score,
        gid_coverage_pct,
        name_coverage_pct
    FROM allfeat_kpi.confidence_work
    
    UNION ALL
    
    SELECT 
        'Recording' as entity_type,
        overall_confidence_level,
        average_confidence_score,
        gid_coverage_pct,
        name_coverage_pct
    FROM allfeat_kpi.confidence_recording
    
    UNION ALL
    
    SELECT 
        'Release' as entity_type,
        overall_confidence_level,
        average_confidence_score,
        gid_coverage_pct,
        name_coverage_pct
    FROM allfeat_kpi.confidence_release
) confidence_summary
ORDER BY entity_type, average_confidence_score DESC;
```

## Requêtes de monitoring

### 12. System Status

```sql
SELECT 
    key,
    value,
    updated_at
FROM allfeat_kpi.metadata
ORDER BY key;
```

### 13. View Statistics

```sql
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'allfeat_kpi'
ORDER BY viewname;
```

## Instructions d'utilisation dans Excel

### Configuration Power Query

1. **Ouvrir Excel**
2. **Onglet "Données"** → **"Obtenir des données"** → **"À partir d'autres sources"** → **"À partir d'ODBC"**
3. **Sélectionner "MB_ODBC"**
4. **Coller une des requêtes ci-dessus**
5. **Cliquer "OK"**
6. **"Charger"** ou **"Transformer les données"**

### Optimisations recommandées

1. **Limiter les résultats** : Toujours utiliser `LIMIT` dans les requêtes
2. **Actualisation automatique** : Configurer l'actualisation à l'ouverture du fichier
3. **Cache des données** : Activer le cache Power Query
4. **Filtres** : Utiliser des filtres dans Power Query plutôt que dans SQL

### PivotTables recommandées

1. **Doublons ISRC** :
   - Lignes : `risk_level`, `name_similarity`
   - Colonnes : `artist_similarity`
   - Valeurs : `COUNT(duplicate_count)`, `AVG(duplicate_risk_score)`

2. **Couverture IDs** :
   - Lignes : `ipi_status`, `isni_status`
   - Valeurs : `COUNT(artist_name)`, `AVG(id_completeness_score)`

3. **Confiance par entité** :
   - Lignes : `entity_type`, `overall_confidence_level`
   - Valeurs : `AVG(average_confidence_score)`, `AVG(gid_coverage_pct)`

### Graphiques recommandés

1. **Graphique en barres** : Couverture ISRC/ISWC par entité
2. **Graphique en secteurs** : Répartition des niveaux de confiance
3. **Graphique en aires** : Évolution des doublons ISRC par risque
4. **Graphique en colonnes** : Comparaison des identifiants manquants

## Dépannage

### Problèmes courants

1. **Erreur de connexion** : Vérifier que PostgreSQL est démarré
2. **Requêtes lentes** : Ajouter `LIMIT` et optimiser les requêtes
3. **Données manquantes** : Vérifier que les vues KPI sont créées
4. **Erreur ODBC** : Vérifier la configuration de la source de données

### Commandes de test

```bash
# Test de connexion
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT version();"

# Test des vues KPI
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT COUNT(*) FROM allfeat_kpi.kpi_isrc_coverage;"

# Tests complets
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/smoke_tests.sql
```
