# Guide d'installation et d'utilisation - Allfeat MusicBrainz KPI

## Vue d'ensemble

Ce projet configure un environnement PostgreSQL local avec le dump MusicBrainz et crée des vues KPI pour analyser la qualité des métadonnées musicales. Il est conçu pour être utilisé par l'équipe Data Engineering Allfeat et les analystes qualité métadonnées.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Docker        │    │   PostgreSQL    │    │   Excel/ODBC    │
│   Compose       │───▶│   MusicBrainz   │───▶│   Power Query    │
│   (Postgres 15) │    │   + allfeat_kpi │    │   + PivotTables  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prérequis

### Logiciels requis
- **Docker Desktop** (Windows/Mac/Linux)
- **PostgreSQL Client** (`psql`)
- **Git** (pour cloner le repository)
- **Microsoft Excel** (avec Power Query)
- **Pilote ODBC PostgreSQL** (pour Excel)

### Ressources système
- **RAM** : Minimum 8GB (recommandé 16GB)
- **Stockage** : 50GB d'espace libre
- **CPU** : 4 cœurs minimum

## Installation étape par étape

### Étape 1 : Cloner le repository

```bash
git clone <repo-url>
cd allfeat-mb-kpi
```

### Étape 2 : Configuration de l'environnement

1. **Copier le fichier de configuration** :
   ```bash
   cp env.example .env
   ```

2. **Modifier les paramètres** (optionnel) :
   ```bash
   # Éditer .env selon vos besoins
   POSTGRES_PASSWORD=votre_mot_de_passe
   POSTGRES_PORT=5432
   ```

### Étape 3 : Démarrage de PostgreSQL

```bash
# Démarrer le conteneur PostgreSQL
docker compose up -d

# Vérifier que le conteneur fonctionne
docker compose ps

# Tester la connexion
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT version();"
```

### Étape 4 : Import du dump MusicBrainz

1. **Télécharger le dump** :
   - Aller sur https://musicbrainz.org/doc/MusicBrainz_Database/Download
   - Télécharger le dump complet (format `.dump`)
   - Placer le fichier dans le répertoire `./dumps/`

2. **Exécuter l'import** :
   
   **Linux/Mac** :
   ```bash
   ./scripts/import_mb.sh
   ```
   
   **Windows PowerShell** :
   ```powershell
   .\scripts\import_mb.ps1
   ```

   ⚠️ **Attention** : L'import peut prendre plusieurs heures selon la taille du dump.

### Étape 5 : Création du schéma KPI

```bash
# Créer le schéma allfeat_kpi
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f sql/init/00_schema.sql
```

### Étape 6 : Application des vues KPI

**Linux/Mac** :
```bash
./scripts/apply_views.sh
```

**Windows PowerShell** :
```powershell
.\scripts\apply_views.ps1
```

### Étape 7 : Tests de validation

```bash
# Exécuter les tests de validation
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/smoke_tests.sql
```

Tous les tests doivent afficher ✅ pour confirmer que l'installation est correcte.

## Configuration Excel/ODBC

### Installation du pilote ODBC PostgreSQL

1. **Télécharger le pilote** :
   - Aller sur https://www.postgresql.org/ftp/odbc/versions/msi/
   - Télécharger la version appropriée pour votre Windows

2. **Installer le pilote** :
   - Exécuter le fichier `.msi` téléchargé
   - Suivre les instructions d'installation

### Configuration de la source de données ODBC

1. **Ouvrir l'Administrateur ODBC** :
   - Windows : Rechercher "Sources de données ODBC"
   - Sélectionner "Administrateur ODBC"

2. **Créer une nouvelle source** :
   - Onglet "Sources de données utilisateur"
   - Bouton "Ajouter"
   - Sélectionner "PostgreSQL Unicode"
   - Cliquer "Terminer"

3. **Configurer la connexion** :
   ```
   Nom de la source de données : MB_ODBC
   Serveur : 127.0.0.1
   Port : 5432
   Base de données : musicbrainz
   Nom d'utilisateur : musicbrainz
   Mot de passe : musicbrainz
   ```

4. **Tester la connexion** :
   - Bouton "Test"
   - Vérifier que "Connexion réussie" s'affiche

### Configuration Excel

1. **Ouvrir Excel**
2. **Créer une nouvelle connexion Power Query** :
   - Onglet "Données"
   - "Obtenir des données" → "À partir d'autres sources" → "À partir d'ODBC"
   - Sélectionner "MB_ODBC"
   - Entrer une requête SQL de test :
     ```sql
     SELECT COUNT(*) as total_artists FROM musicbrainz.artist WHERE type = 1;
     ```

3. **Importer les données** :
   - Cliquer "Charger"
   - Vérifier que les données s'affichent

## Utilisation des vues KPI

### Vue d'ensemble des KPI

```sql
-- Statistiques générales
SELECT * FROM allfeat_kpi.stats_overview;

-- Résumé des KPI principaux
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage
FROM allfeat_kpi.kpi_isrc_coverage
UNION ALL
SELECT 
    'ISWC Coverage' as kpi_name,
    iswc_coverage_pct as coverage_percentage
FROM allfeat_kpi.kpi_iswc_coverage;
```

### Analyse des doublons ISRC

```sql
-- Top 10 des doublons ISRC par risque
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 10;
```

### Analyse des identifiants manquants

```sql
-- Artistes avec identifiants manquants
SELECT 
    artist_name,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 20;
```

### Analyse des niveaux de confiance

```sql
-- Niveaux de confiance par entité
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
FROM allfeat_kpi.confidence_work;
```

## Maintenance et surveillance

### Surveillance des performances

```sql
-- Vérifier les performances des vues
EXPLAIN ANALYZE SELECT * FROM allfeat_kpi.kpi_isrc_coverage;

-- Statistiques d'utilisation
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'allfeat_kpi';
```

### Mise à jour des données

1. **Rafraîchir les statistiques PostgreSQL** :
   ```sql
   ANALYZE;
   ```

2. **Mettre à jour les métadonnées** :
   ```sql
   UPDATE allfeat_kpi.metadata 
   SET value = NOW()::TEXT, updated_at = NOW() 
   WHERE key = 'last_updated';
   ```

### Sauvegarde

```bash
# Sauvegarde de la base de données
docker exec musicbrainz-postgres pg_dump -U musicbrainz musicbrainz > backup_$(date +%Y%m%d).sql

# Sauvegarde du schéma KPI uniquement
docker exec musicbrainz-postgres pg_dump -U musicbrainz -n allfeat_kpi musicbrainz > kpi_backup_$(date +%Y%m%d).sql
```

## Dépannage

### Problèmes courants

#### 1. Erreur de connexion PostgreSQL
```
psql: error: connection to server at "127.0.0.1", port 5432 failed
```

**Solutions** :
- Vérifier que Docker est démarré : `docker compose ps`
- Redémarrer le conteneur : `docker compose restart`
- Vérifier les logs : `docker compose logs postgres`

#### 2. Erreur d'import du dump
```
pg_restore: error: could not execute query
```

**Solutions** :
- Vérifier que le fichier dump n'est pas corrompu
- Vérifier l'espace disque disponible
- Réessayer l'import avec `--verbose` pour plus de détails

#### 3. Erreur ODBC dans Excel
```
[Microsoft][ODBC Driver Manager] Data source name not found
```

**Solutions** :
- Vérifier que le pilote ODBC PostgreSQL est installé
- Recréer la source de données ODBC
- Tester la connexion avec `psql` d'abord

#### 4. Requêtes lentes
```
Query took too long to execute
```

**Solutions** :
- Ajouter des filtres LIMIT aux requêtes
- Vérifier que les index existent : `\di` dans psql
- Optimiser les requêtes Power Query

### Logs et diagnostic

```bash
# Logs Docker
docker compose logs postgres

# Logs PostgreSQL
docker exec musicbrainz-postgres tail -f /var/log/postgresql/postgresql-15-main.log

# Statistiques de performance
docker exec musicbrainz-postgres psql -U musicbrainz -d musicbrainz -c "
SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del
FROM pg_stat_user_tables 
WHERE schemaname IN ('musicbrainz', 'allfeat_kpi')
ORDER BY n_tup_ins DESC;
"
```

## Support et contribution

### Documentation supplémentaire
- `docs/ODBC_Windows_guide.md` : Guide détaillé ODBC Windows
- `excel/PowerQuery_Configuration.md` : Configuration Power Query
- `scripts/explain_samples.sql` : Exemples d'utilisation

### Contact
Pour toute question ou problème :
- Créer une issue sur GitHub
- Consulter la documentation dans `docs/`
- Vérifier les logs et messages d'erreur

### Contribution
Pour contribuer au projet :
1. Fork le repository
2. Créer une branche feature
3. Implémenter les modifications
4. Tester avec `scripts/smoke_tests.sql`
5. Créer une pull request
