# Configuration Power Query pour Allfeat MusicBrainz KPI

## Instructions de configuration

### 1. Configuration ODBC

Avant d'utiliser ce template Excel, vous devez configurer une source de données ODBC :

1. **Installer le pilote PostgreSQL ODBC** :
   - Télécharger depuis : https://www.postgresql.org/ftp/odbc/versions/msi/
   - Installer le pilote approprié pour votre version Windows

2. **Créer une source de données ODBC** :
   - Ouvrir "Sources de données ODBC" (Administrateur ODBC)
   - Onglet "Sources de données utilisateur" → "Ajouter"
   - Sélectionner "PostgreSQL Unicode"
   - Configuration :
     - **Nom** : `MB_ODBC`
     - **Serveur** : `127.0.0.1`
     - **Port** : `5432`
     - **Base de données** : `musicbrainz`
     - **Nom d'utilisateur** : `musicbrainz`
     - **Mot de passe** : `musicbrainz`

### 2. Requêtes Power Query pré-configurées

Le template Excel contient les requêtes Power Query suivantes :

#### Requête 1: KPI_Overview
```sql
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
    artists_with_ipi + artists_with_isni + artists_with_viaf + artists_with_wikidata + artists_with_imdb
FROM allfeat_kpi.party_missing_ids_artist;
```

#### Requête 2: ISRC_Duplicates
```sql
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level,
    name_similarity,
    artist_similarity,
    length_similarity
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC;
```

#### Requête 3: Missing_Artist_IDs
```sql
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
ORDER BY id_completeness_score ASC;
```

#### Requête 4: Confidence_Levels
```sql
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
```

#### Requête 5: Work_Recording_Inconsistencies
```sql
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies;
```

### 3. Feuilles Excel pré-configurées

Le template contient les feuilles suivantes :

1. **Dashboard** : Vue d'ensemble avec graphiques
2. **KPI Overview** : Tableau de bord principal
3. **ISRC Analysis** : Analyse des codes ISRC
4. **Artist IDs** : Analyse des identifiants artistes
5. **Confidence Levels** : Niveaux de confiance par entité
6. **Inconsistencies** : Incohérences Work-Recording
7. **Samples** : Échantillons pour analyse détaillée

### 4. Instructions d'utilisation

1. **Ouvrir le template Excel**
2. **Configurer les connexions Power Query** :
   - Aller dans "Données" → "Obtenir des données" → "À partir d'autres sources" → "À partir d'ODBC"
   - Sélectionner la source `MB_ODBC`
   - Coller les requêtes SQL ci-dessus
3. **Rafraîchir les données** :
   - Bouton "Actualiser tout" dans l'onglet "Données"
4. **Personnaliser les graphiques** selon vos besoins

### 5. PivotTables recommandées

#### PivotTable 1: Analyse des doublons ISRC
- **Lignes** : risk_level, name_similarity
- **Colonnes** : artist_similarity
- **Valeurs** : COUNT(duplicate_count), AVG(duplicate_risk_score)

#### PivotTable 2: Couverture des identifiants artistes
- **Lignes** : ipi_status, isni_status
- **Valeurs** : COUNT(artist_name), AVG(id_completeness_score)

#### PivotTable 3: Niveaux de confiance par entité
- **Lignes** : entity_type, overall_confidence_level
- **Valeurs** : AVG(average_confidence_score), AVG(gid_coverage_pct)

### 6. Graphiques recommandés

1. **Graphique en barres** : Couverture ISRC/ISWC
2. **Graphique en secteurs** : Répartition des niveaux de confiance
3. **Graphique en aires** : Évolution des doublons ISRC par risque
4. **Graphique en colonnes** : Comparaison des identifiants manquants

### 7. Automatisation

Pour automatiser le rafraîchissement :
1. Aller dans "Données" → "Propriétés de la requête"
2. Cocher "Actualiser les données lors de l'ouverture du fichier"
3. Définir un intervalle de rafraîchissement automatique

### 8. Dépannage

**Problème** : Erreur de connexion ODBC
- Vérifier que PostgreSQL est démarré (`docker compose up -d`)
- Tester la connexion avec `psql -h 127.0.0.1 -U musicbrainz -d musicbrainz`

**Problème** : Requêtes lentes
- Vérifier que les vues KPI sont créées (`psql -f scripts/smoke_tests.sql`)
- Optimiser les requêtes en ajoutant des filtres LIMIT

**Problème** : Données manquantes
- Vérifier que le dump MusicBrainz est importé
- Exécuter `psql -f scripts/apply_views.sh`
