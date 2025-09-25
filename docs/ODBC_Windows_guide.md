# Guide ODBC Windows - Allfeat MusicBrainz KPI (Version Corrigée)

## Vue d'ensemble

Ce guide détaille la configuration ODBC sur Windows pour connecter Excel à la base de données PostgreSQL MusicBrainz avec les vues KPI Allfeat.

## Prérequis

### Logiciels requis
- **Windows 10/11** (64-bit recommandé)
- **Microsoft Excel 2016+** (avec Power Query)
- **PostgreSQL démarré** via Docker
- **Pilote ODBC PostgreSQL** (à installer)

### Vérifications préalables
1. PostgreSQL accessible : `psql -h 127.0.0.1 -U musicbrainz -d musicbrainz`
2. Vues KPI créées : `psql -f scripts/smoke_tests.sql`
3. Excel installé et fonctionnel

## Installation du pilote ODBC PostgreSQL

### Étape 1 : Téléchargement

1. **Aller sur le site officiel** :
   - URL : https://www.postgresql.org/ftp/odbc/versions/msi/
   - Sélectionner la version la plus récente

2. **Choisir le bon pilote** :
   - **Windows 64-bit** : `psqlodbc_xx_xx_xxxx-x64.msi`
   - **Windows 32-bit** : `psqlodbc_xx_xx_xxxx-x86.msi`

3. **Télécharger le fichier** :
   - Sauvegarder dans un répertoire accessible
   - Noter la version téléchargée

### Étape 2 : Installation

1. **Exécuter l'installateur** :
   - Double-cliquer sur le fichier `.msi`
   - Accepter les termes de licence

2. **Configuration de l'installation** :
   - **Répertoire d'installation** : Laisser par défaut
   - **Composants** : Sélectionner "PostgreSQL Unicode Driver"
   - **Options** : Cocher "Install ODBC Driver Manager"

3. **Finaliser l'installation** :
   - Cliquer "Install"
   - Attendre la fin de l'installation
   - Cliquer "Finish"

### Étape 3 : Vérification

1. **Ouvrir l'Administrateur ODBC** :
   - Rechercher "ODBC" dans le menu Démarrer
   - Sélectionner "Sources de données ODBC (64-bit)"

2. **Vérifier le pilote** :
   - Onglet "Pilotes"
   - Chercher "PostgreSQL Unicode"
   - Vérifier que la version est correcte

## Configuration de la source de données ODBC

### Étape 1 : Création de la source

1. **Ouvrir l'Administrateur ODBC** :
   - Rechercher "ODBC" dans le menu Démarrer
   - Sélectionner "Sources de données ODBC (64-bit)"

2. **Créer une nouvelle source** :
   - Onglet "Sources de données utilisateur"
   - Bouton "Ajouter"
   - Sélectionner "PostgreSQL Unicode"
   - Cliquer "Terminer"

### Étape 2 : Configuration de la connexion

1. **Paramètres de base** :
   ```
   Nom de la source de données : MB_ODBC
   Description : MusicBrainz KPI Allfeat
   Serveur : 127.0.0.1
   Port : 5432
   Base de données : musicbrainz
   Nom d'utilisateur : musicbrainz
   Mot de passe : musicbrainz
   ```

2. **Paramètres avancés** (optionnel) :
   ```
   SSL Mode : Prefer
   Timeout : 30
   Read Only : Non coché
   ```

3. **Options de connexion** :
   - Cocher "Save password" si souhaité
   - Cocher "Use Declare/Fetch" pour de meilleures performances

### Étape 3 : Test de connexion

1. **Tester la connexion** :
   - Bouton "Test"
   - Vérifier que "Connexion réussie" s'affiche

2. **En cas d'erreur** :
   - Vérifier que PostgreSQL est démarré
   - Vérifier les paramètres de connexion
   - Consulter la section "Dépannage" ci-dessous

3. **Sauvegarder** :
   - Bouton "OK" pour sauvegarder la configuration
   - Bouton "OK" pour fermer l'Administrateur ODBC

## Configuration Excel avec Power Query

### Étape 1 : Création d'une connexion

1. **Ouvrir Excel**
2. **Créer une nouvelle connexion** :
   - Onglet "Données"
   - "Obtenir des données" → "À partir d'autres sources" → "À partir d'ODBC"

3. **Sélectionner la source** :
   - Dans la liste déroulante, sélectionner "MB_ODBC"
   - Cliquer "OK"

### Étape 2 : Configuration de la requête

1. **Entrer une requête SQL simple** :
   ```sql
   SELECT * FROM allfeat_kpi.kpi_isrc_coverage;
   ```

2. **Tester la requête** :
   - Bouton "OK"
   - Vérifier que les données s'affichent dans l'aperçu

3. **Charger les données** :
   - Bouton "Charger" pour importer dans Excel
   - Ou "Transformer les données" pour modifier avant import

## Requêtes Power Query Corrigées

### Requête 1 : KPI Overview (Tableau de bord principal)

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
    artists_with_ipi + artists_with_isni
FROM allfeat_kpi.party_missing_ids_artist;
```

### Requête 2 : ISRC Duplicates (Top 20 par risque)

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
ORDER BY duplicate_risk_score DESC
LIMIT 20;
```

### Requête 3 : Missing Artist IDs (Top 50 par score de complétude)

```sql
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 50;
```

### Requête 4 : Confidence Levels (Phase 1 + Phase 2 par entité)

```sql
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
```

### Requête 5 : Work-Recording Inconsistencies

```sql
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies
ORDER BY count DESC;
```

### Requête 6 : Samples - Recordings without ISRC

```sql
SELECT 
    recording_name,
    artist_name,
    recording_gid
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
LIMIT 20;
```

### Requête 7 : Samples - Works without ISWC

```sql
SELECT 
    work_name,
    work_type,
    language_code,
    work_gid
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
LIMIT 20;
```

### Requête 8 : Samples - Low Confidence Artists (Phase 2)

```sql
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
LIMIT 20;
```

### Requête 9 : Comparaison Phase 1 vs Phase 2 (Artistes)

```sql
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
```

## Logique de confiance Phase 1 + Phase 2

### Phase 1 : Logique catégorielle explicite
Chaque entité (Artist, Work, Recording, Release) est évaluée selon des règles catégorielles claires :

- **High** = Présence d'ISRC + ISWC + Identifiants artiste (ISNI/IPI) + Release
- **Medium** = ISRC + (ISWC OU Identifiants artiste) OU (ISWC + Release)  
- **Low** = Tous les autres cas

### Phase 2 : Score numérique avec poids
Chaque entité reçoit un score numérique (0-1) basé sur des poids explicites :

- **Artistes/Enregistrements** : `0.3 × ISNI + 0.3 × ISWC + 0.2 × ISRC + 0.2 × Release`
- **Œuvres** : `0.4 × ISWC + 0.3 × ISNI + 0.2 × ISRC + 0.1 × Release`
- **Releases** : `0.3 × Date + 0.3 × ISRC + 0.2 × ISWC + 0.2 × ISNI`

**Seuils** : ≥0.8 = High, ≥0.4 = Medium, <0.4 = Low

### Choix pour les analystes
- **Phase 1** : Pour des analyses catégorielles simples et rapides
- **Phase 2** : Pour des analyses numériques précises et des comparaisons
- **Les deux** : Pour valider la cohérence entre les approches

### Configuration ODBC avancée

1. **Ouvrir l'Administrateur ODBC**
2. **Sélectionner la source MB_ODBC**
3. **Bouton "Configurer"**
4. **Onglet "Options"** :
   ```
   Use Declare/Fetch : ✓
   Text as LongVarChar : ✓
   Unknown Sizes as LongVarChar : ✓
   Max Varchar Size : 1024
   Max LongVarChar Size : 8192
   ```

### Optimisation des requêtes Power Query

1. **Limiter les résultats** :
   - Toujours ajouter `LIMIT` aux requêtes
   - Utiliser des filtres dans Power Query

2. **Actualisation intelligente** :
   - Configurer l'actualisation automatique
   - Utiliser des requêtes incrémentielles si possible

3. **Cache des données** :
   - Activer le cache dans Power Query
   - Configurer la durée de cache appropriée

## Dépannage

### Problèmes courants

#### 1. Erreur de connexion ODBC
```
[Microsoft][ODBC Driver Manager] Data source name not found
```

**Solutions** :
- Vérifier que le pilote PostgreSQL est installé
- Recréer la source de données ODBC
- Vérifier que PostgreSQL est démarré : `docker compose ps`

#### 2. Erreur d'authentification
```
FATAL: password authentication failed for user "musicbrainz"
```

**Solutions** :
- Vérifier le mot de passe dans la configuration ODBC
- Tester la connexion avec `psql` d'abord
- Vérifier les paramètres dans `.env`

#### 3. Requêtes lentes
```
Query timeout expired
```

**Solutions** :
- Ajouter `LIMIT` aux requêtes
- Optimiser les requêtes SQL
- Vérifier les index PostgreSQL

#### 4. Erreur de pilote
```
[Microsoft][ODBC Driver Manager] Driver's SQLAllocHandle on SQL_HANDLE_ENV failed
```

**Solutions** :
- Réinstaller le pilote ODBC PostgreSQL
- Vérifier la compatibilité 32-bit/64-bit
- Redémarrer Excel après installation

### Diagnostic avancé

#### Test de connexion avec psql
```bash
# Test de base
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT version();"

# Test des vues KPI
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT COUNT(*) FROM allfeat_kpi.kpi_isrc_coverage;"
```

#### Test de performance
```sql
-- Test de performance des vues
EXPLAIN ANALYZE SELECT * FROM allfeat_kpi.kpi_isrc_coverage;

-- Statistiques d'utilisation
SELECT 
    schemaname,
    viewname
FROM pg_views 
WHERE schemaname = 'allfeat_kpi';
```

## Bonnes pratiques

### Sécurité
1. **Ne pas sauvegarder les mots de passe** en production
2. **Utiliser des connexions chiffrées** (SSL)
3. **Limiter les accès** aux utilisateurs autorisés

### Performance
1. **Limiter les requêtes** avec `LIMIT`
2. **Utiliser des index** appropriés
3. **Optimiser les requêtes** Power Query

### Maintenance
1. **Tester régulièrement** les connexions
2. **Surveiller les performances**
3. **Mettre à jour** les pilotes ODBC

## Support

### Ressources utiles
- **Documentation PostgreSQL ODBC** : https://www.postgresql.org/docs/current/odbc.html
- **Guide Power Query** : https://docs.microsoft.com/en-us/power-query/
- **Administrateur ODBC Windows** : https://docs.microsoft.com/en-us/sql/odbc/admin/

### Contact
Pour toute question spécifique à ce projet :
- Consulter `docs/README.md`
- Créer une issue sur GitHub
- Vérifier les logs et messages d'erreur

## Annexe : Mapping des colonnes supprimées

### Colonnes supprimées et raisons

| Colonne supprimée | Vue concernée | Raison |
|-------------------|---------------|---------|
| `viaf_status` | Requêtes Power Query | N'existe que dans `party_missing_ids_artist_samples`, pas dans la vue principale |
| `wikidata_status` | Requêtes Power Query | N'existe que dans `party_missing_ids_artist_samples`, pas dans la vue principale |
| `imdb_status` | Requêtes Power Query | N'existe que dans `party_missing_ids_artist_samples`, pas dans la vue principale |
| `sample_recording_names[1]` | Requêtes Power Query | Syntaxe PostgreSQL non supportée par ODBC |
| `sample_recording_names[2]` | Requêtes Power Query | Syntaxe PostgreSQL non supportée par ODBC |
| `sample_artist_credits[1]` | Requêtes Power Query | Syntaxe PostgreSQL non supportée par ODBC |
| `sample_artist_credits[2]` | Requêtes Power Query | Syntaxe PostgreSQL non supportée par ODBC |
| `total_works` | Requête confidence_work | Colonne n'existe pas dans la vue |
| `total_recordings` | Requête confidence_recording | Colonne n'existe pas dans la vue |
| `total_releases` | Requête confidence_release | Colonne n'existe pas dans la vue |
| `length` | Requête samples ISRC | Colonne n'existe pas dans la vue samples |
| `comment` | Requêtes samples | Colonnes n'existent pas dans les vues samples |

### Colonnes disponibles par vue

#### allfeat_kpi.kpi_isrc_coverage
- `total_recordings`, `recordings_with_isrc`, `recordings_without_isrc`, `unique_isrcs`
- `isrc_coverage_pct`, `missing_isrc_pct`
- `duplicate_isrc_count`, `total_duplicate_recordings`, `duplicate_rate_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.kpi_isrc_coverage_samples
- `sample_type`, `recording_id`, `recording_name`, `recording_gid`
- `artist_name`, `artist_gid`

#### allfeat_kpi.kpi_iswc_coverage
- `total_works`, `works_with_iswc`, `works_without_iswc`, `unique_iswcs`
- `iswc_coverage_pct`, `missing_iswc_pct`
- `duplicate_iswc_count`, `total_duplicate_works`, `duplicate_rate_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.kpi_iswc_coverage_samples
- `sample_type`, `work_id`, `work_name`, `work_gid`
- `work_type`, `language_code`

#### allfeat_kpi.party_missing_ids_artist
- `total_artists`, `artists_with_ipi`, `artists_with_isni`
- `artists_missing_ipi`, `artists_missing_isni`
- `ipi_coverage_pct`, `isni_coverage_pct`
- `overall_id_completeness_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.party_missing_ids_artist_samples
- `artist_id`, `artist_name`, `artist_gid`, `sort_name`
- `begin_date`, `end_date`, `area`
- `ipi_status`, `isni_status`, `viaf_status`, `wikidata_status`, `imdb_status`
- `id_completeness_score`

#### allfeat_kpi.dup_isrc_candidates
- `isrc`, `duplicate_count`, `duplicate_risk_score`, `risk_level`
- `name_similarity`, `artist_similarity`, `length_similarity`
- `sample_recording_ids`, `sample_recording_names`, `sample_artist_credits`, `sample_lengths`
- `calculated_at`, `scope_note`

#### allfeat_kpi.confidence_artist (Phase 1 + Phase 2)
- `total_artists`, `phase1_high_count`, `phase1_medium_count`, `phase1_low_count`
- `phase2_high_count`, `phase2_medium_count`, `phase2_low_count`
- `phase1_high_pct`, `phase1_medium_pct`, `phase1_low_pct`
- `phase2_high_pct`, `phase2_medium_pct`, `phase2_low_pct`
- `average_phase2_score`, `overall_confidence_level`
- `artists_with_isrc`, `artists_with_iswc`, `artists_on_release`
- `artists_with_ipi`, `artists_with_isni`
- `isrc_coverage_pct`, `iswc_coverage_pct`, `release_coverage_pct`
- `ipi_coverage_pct`, `isni_coverage_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.confidence_work (Phase 1 + Phase 2)
- `total_works`, `phase1_high_count`, `phase1_medium_count`, `phase1_low_count`
- `phase2_high_count`, `phase2_medium_count`, `phase2_low_count`
- `phase1_high_pct`, `phase1_medium_pct`, `phase1_low_pct`
- `phase2_high_pct`, `phase2_medium_pct`, `phase2_low_pct`
- `average_phase2_score`, `overall_confidence_level`
- `works_with_iswc`, `works_with_isrc`, `works_on_release`
- `works_with_ipi`, `works_with_isni`
- `iswc_coverage_pct`, `isrc_coverage_pct`, `release_coverage_pct`
- `ipi_coverage_pct`, `isni_coverage_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.confidence_recording (Phase 1 + Phase 2)
- `total_recordings`, `phase1_high_count`, `phase1_medium_count`, `phase1_low_count`
- `phase2_high_count`, `phase2_medium_count`, `phase2_low_count`
- `phase1_high_pct`, `phase1_medium_pct`, `phase1_low_pct`
- `phase2_high_pct`, `phase2_medium_pct`, `phase2_low_pct`
- `average_phase2_score`, `overall_confidence_level`
- `recordings_with_isrc`, `recordings_with_iswc`, `recordings_on_release`
- `recordings_with_ipi`, `recordings_with_isni`
- `isrc_coverage_pct`, `iswc_coverage_pct`, `release_coverage_pct`
- `ipi_coverage_pct`, `isni_coverage_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.confidence_release (Phase 1 + Phase 2)
- `total_releases`, `phase1_high_count`, `phase1_medium_count`, `phase1_low_count`
- `phase2_high_count`, `phase2_medium_count`, `phase2_low_count`
- `phase1_high_pct`, `phase1_medium_pct`, `phase1_low_pct`
- `phase2_high_pct`, `phase2_medium_pct`, `phase2_low_pct`
- `average_phase2_score`, `overall_confidence_level`
- `releases_with_date`, `releases_with_country`, `releases_with_isrc`
- `releases_with_iswc`, `releases_with_ipi`, `releases_with_isni`
- `date_coverage_pct`, `country_coverage_pct`, `isrc_coverage_pct`
- `iswc_coverage_pct`, `ipi_coverage_pct`, `isni_coverage_pct`
- `calculated_at`, `scope_note`

#### allfeat_kpi.confidence_artist_samples (Phase 1 + Phase 2)
- `artist_id`, `artist_name`, `artist_gid`, `sort_name`
- `begin_date`, `end_date`, `area`
- `has_isrc`, `has_iswc`, `on_release`, `has_ipi`, `has_isni`
- `phase1_confidence_level`, `phase2_confidence_score`, `phase2_confidence_level`
- `confidence_level` (compatibilité), `confidence_score` (compatibilité)

#### allfeat_kpi.confidence_work_samples (Phase 1 + Phase 2)
- `work_id`, `work_name`, `work_gid`, `work_type`, `language_code`, `iswc`
- `has_iswc`, `has_isrc`, `on_release`, `has_ipi`, `has_isni`
- `phase1_confidence_level`, `phase2_confidence_score`, `phase2_confidence_level`
- `confidence_level` (compatibilité), `confidence_score` (compatibilité)

#### allfeat_kpi.confidence_recording_samples (Phase 1 + Phase 2)
- `recording_id`, `recording_name`, `recording_gid`, `length`, `isrc`
- `has_isrc`, `has_iswc`, `on_release`, `has_ipi`, `has_isni`
- `phase1_confidence_level`, `phase2_confidence_score`, `phase2_confidence_level`
- `confidence_level` (compatibilité), `confidence_score` (compatibilité)

#### allfeat_kpi.confidence_release_samples (Phase 1 + Phase 2)
- `release_id`, `release_name`, `release_gid`, `date_year`, `date_month`, `date_day`, `country`
- `has_date`, `has_country`, `has_isrc`, `has_iswc`, `has_ipi`, `has_isni`
- `phase1_confidence_level`, `phase2_confidence_score`, `phase2_confidence_level`
- `confidence_level` (compatibilité), `confidence_score` (compatibilité)