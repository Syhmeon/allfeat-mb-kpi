# Guide ODBC Windows - Allfeat MusicBrainz KPI

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

1. **Entrer une requête SQL** :
   ```sql
   SELECT 
       'ISRC Coverage' as kpi_name,
       isrc_coverage_pct as coverage_percentage,
       duplicate_rate_pct as duplicate_percentage
   FROM allfeat_kpi.kpi_isrc_coverage;
   ```

2. **Tester la requête** :
   - Bouton "OK"
   - Vérifier que les données s'affichent dans l'aperçu

3. **Charger les données** :
   - Bouton "Charger" pour importer dans Excel
   - Ou "Transformer les données" pour modifier avant import

### Étape 3 : Création de requêtes Power Query

#### Requête 1 : KPI Overview
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

#### Requête 2 : ISRC Duplicates
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
LIMIT 100;
```

#### Requête 3 : Missing Artist IDs
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
ORDER BY id_completeness_score ASC
LIMIT 100;
```

#### Requête 4 : Confidence Levels
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

## Optimisation des performances

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

#### Logs ODBC
1. **Activer les logs ODBC** :
   - Éditeur de registre Windows
   - `HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\ODBC`
   - Créer `Trace` = 1
   - Créer `TraceFile` = "C:\temp\odbc.log"

2. **Analyser les logs** :
   - Reproduire l'erreur
   - Examiner le fichier de log
   - Identifier la cause du problème

#### Test de performance
```sql
-- Test de performance des vues
EXPLAIN ANALYZE SELECT * FROM allfeat_kpi.kpi_isrc_coverage;

-- Statistiques d'utilisation
SELECT 
    schemaname,
    viewname,
    definition
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
