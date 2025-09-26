# Allfeat – MusicBrainz KPI Profiling (Phase 1)

## 🎯 Vue d'ensemble

Ce projet configure un environnement PostgreSQL local (via Docker) avec le dump MusicBrainz, puis crée le schéma `allfeat_kpi` avec 10 vues KPI pour mesurer la qualité et complétude des métadonnées musicales.

### Objectifs
- **Couverture ISRC** : Mesurer le pourcentage d'enregistrements avec codes ISRC
- **Couverture ISWC** : Mesurer le pourcentage d'œuvres avec codes ISWC  
- **IDs manquants** : Identifier les artistes sans identifiants externes
- **Doublons ISRC** : Détecter les codes ISRC dupliqués
- **Incohérences** : Trouver les enregistrements sans œuvres associées
- **Niveaux de confiance** : Calculer des scores de confiance par entité (Artist, Work, Recording, Release) avec logique Phase 1 (catégorielle High/Medium/Low basée sur présence d'IDs + cohérence des liens) et Phase 2 (score numérique 0-1 avec poids explicites, mappé sur High/Medium/Low)

### Public cible
- Équipe Data Engineering Allfeat
- Analystes qualité métadonnées musicales
- Parties prenantes business/consulting

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Docker        │    │   PostgreSQL    │    │   Excel/ODBC    │
│   Compose       │───▶│   MusicBrainz   │───▶│   Power Query    │
│   (Postgres 15) │    │   + allfeat_kpi │    │   + PivotTables  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📊 KPI implémentés

### 1. Couverture ISRC (International Standard Recording Code)
- **Vue principale** : `allfeat_kpi.kpi_isrc_coverage`
- **Vue échantillons** : `allfeat_kpi.kpi_isrc_coverage_samples`
- **Métriques** : Pourcentage d'enregistrements avec ISRC, taux de doublons, analyse de similarité

### 2. Couverture ISWC (International Standard Musical Work Code)
- **Vue principale** : `allfeat_kpi.kpi_iswc_coverage`
- **Vue échantillons** : `allfeat_kpi.kpi_iswc_coverage_samples`
- **Vue détaillée** : `allfeat_kpi.kpi_iswc_detailed`
- **Métriques** : Pourcentage d'œuvres avec ISWC, taux de doublons

### 3. Identifiants manquants - Artistes
- **Vue principale** : `allfeat_kpi.party_missing_ids_artist`
- **Vue échantillons** : `allfeat_kpi.party_missing_ids_artist_samples`
- **Métriques** : Couverture IPI, ISNI, VIAF, Wikidata, IMDB

### 4. Candidats doublons ISRC
- **Vue principale** : `allfeat_kpi.dup_isrc_candidates`
- **Vue échantillons** : `allfeat_kpi.dup_isrc_candidates_samples`
- **Métriques** : Score de risque, analyse de similarité (noms, artistes, longueurs)

### 5. Incohérences Work-Recording
- **Vue principale** : `allfeat_kpi.rec_on_release_without_work`
- **Vue échantillons** : `allfeat_kpi.rec_on_release_without_work_samples`
- **Vue complémentaire** : `allfeat_kpi.work_without_recording`
- **Vue combinée** : `allfeat_kpi.work_recording_inconsistencies`
- **Métriques** : Enregistrements sans œuvres, œuvres sans enregistrements

### 6. Niveaux de confiance : Vues indépendantes par entité (Artist, Work, Recording, Release)
- **Artistes** : `allfeat_kpi.confidence_artist` + `allfeat_kpi.confidence_artist_samples`
- **Œuvres** : `allfeat_kpi.confidence_work` + `allfeat_kpi.confidence_work_samples`
- **Enregistrements** : `allfeat_kpi.confidence_recording` + `allfeat_kpi.confidence_recording_samples`
- **Releases** : `allfeat_kpi.confidence_release` + `allfeat_kpi.confidence_release_samples`
- **Métriques** : Niveau Phase 1 (High/Medium/Low basé sur présence d'IDs + cohérence des liens), Score Phase 2 (0–1 pondéré avec poids explicites), Niveau Phase 2 (High/Medium/Low dérivé du score)

## 📁 Structure du projet

```
allfeat-mb-kpi/
├── docker-compose.yml          # Configuration Docker PostgreSQL
├── env.example                 # Variables d'environnement
├── .gitignore                  # Exclusions Git
├── README.md                   # Documentation principale
├── quick_start.sh              # Script de démarrage rapide
├── scripts/                    # Scripts d'automatisation
│   ├── import_mb.sh           # Import MusicBrainz (Linux/Mac)
│   ├── import_mb.ps1          # Import MusicBrainz (Windows)
│   ├── apply_views.sh         # Application des vues KPI
│   ├── apply_views.ps1        # Application des vues KPI (Windows)
│   └── tests.sql              # Tests unifiés (smoke + confidence + Power Query)
├── sql/                       # Scripts SQL
│   ├── init/
│   │   └── 00_schema.sql     # Création du schéma allfeat_kpi
│   └── views/                # Vues KPI (10 fichiers)
│       ├── 10_kpi_isrc_coverage.sql
│       ├── 20_kpi_iswc_coverage.sql
│       ├── 30_party_missing_ids_artist.sql
│       ├── 40_dup_isrc_candidates.sql
│       ├── 50_rec_on_release_without_work.sql
│       ├── 51_work_without_recording.sql
│       ├── 60_confidence_artist.sql
│       ├── 61_confidence_work.sql
│       ├── 62_confidence_recording.sql
│       └── 63_confidence_release.sql
├── excel/                     # Templates et configuration Excel
│   └── PowerQuery_guide.md    # Guide Power Query unifié
├── docs/                      # Documentation spécialisée
│   └── ODBC_Windows_guide.md  # Guide ODBC Windows
└── dumps/                     # Répertoire pour les dumps MusicBrainz
```

## 🚀 Installation rapide

### Prérequis
- **Docker Desktop** (Windows/Mac/Linux)
- **PostgreSQL Client** (`psql`)
- **Git** (pour cloner le repository)
- **Microsoft Excel** (avec Power Query)
- **Pilote ODBC PostgreSQL** (pour Excel)

### Ressources système
- **RAM** : Minimum 8GB (recommandé 16GB)
- **Stockage** : 50GB d'espace libre
- **CPU** : 4 cœurs minimum

### Étapes d'installation

1. **Cloner le repository**
   ```bash
   git clone <repo-url>
   cd allfeat-mb-kpi
   ```

2. **Configuration de l'environnement**
   ```bash
   cp env.example .env
   # Modifier .env selon vos besoins (optionnel)
   ```

3. **Démarrage automatique**
   ```bash
   ./quick_start.sh
   ```

   Ou manuellement :
   ```bash
   # Démarrer PostgreSQL
   docker compose up -d
   
   # Vérifier que le conteneur fonctionne
   docker compose ps
   
   # Tester la connexion
   psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT version();"
   ```

4. **Import du dump MusicBrainz**
   - Télécharger le dump depuis https://musicbrainz.org/doc/MusicBrainz_Database/Download
   - Placer dans `./dumps/`
   
   **Linux/Mac** :
   ```bash
   ./scripts/import_mb.sh
   ```
   
   **Windows PowerShell** :
   ```powershell
   .\scripts\import_mb.ps1
   ```

5. **Création du schéma KPI**
   ```bash
   psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f sql/init/00_schema.sql
   ```

6. **Application des vues KPI**
   **Linux/Mac** :
   ```bash
   ./scripts/apply_views.sh
   ```
   
   **Windows PowerShell** :
   ```powershell
   .\scripts\apply_views.ps1
   ```

7. **Tests de validation**
   ```bash
   psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/tests.sql
   ```

## 📈 Utilisation

### Accès via Excel/ODBC

1. **Configuration ODBC** : Voir `docs/ODBC_Windows_guide.md`
2. **Guide Power Query** : Voir `excel/PowerQuery_guide.md`
3. **Connexion** : `MB_ODBC` → `127.0.0.1:5432/musicbrainz`
4. **Requêtes** : Utiliser les requêtes pré-configurées
5. **PivotTables** : Analyser les données selon les besoins

### Accès direct PostgreSQL

```bash
# Connexion
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz

# Requêtes KPI
SELECT * FROM allfeat_kpi.kpi_isrc_coverage;
SELECT * FROM allfeat_kpi.confidence_artist;
```

### Exemples de requêtes

```sql
-- Vue d'ensemble
SELECT * FROM allfeat_kpi.stats_overview;

-- Top 10 doublons ISRC
SELECT * FROM allfeat_kpi.dup_isrc_candidates 
ORDER BY duplicate_risk_score DESC LIMIT 10;

-- Artistes avec faible confiance
SELECT * FROM allfeat_kpi.confidence_artist_samples 
WHERE phase2_confidence_level = 'Low' LIMIT 20;

-- Statistiques générales
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage
FROM allfeat_kpi.kpi_isrc_coverage
UNION ALL
SELECT 
    'ISWC Coverage' as kpi_name,
    iswc_coverage_pct as coverage_percentage
FROM allfeat_kpi.kpi_iswc_coverage;

-- Analyse des doublons ISRC
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 10;

-- Identifiants manquants pour les artistes
SELECT 
    artist_name,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 20;

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

## 🔧 Maintenance et surveillance

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

## 🚨 Dépannage

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

## 📋 Contraintes Phase 1

### Scope limité
- **Artistes uniquement** (labels en backlog)
- **Logique confiance** : Phase 1 (catégorielle) + Phase 2 (numérique) par entité indépendante
- **Accès prioritaire** : Excel/ODBC (Parquet/CSV en Phase 2)

### Performance
- **Vues légères** : Comptes/ratios + petits échantillons
- **Limites** : `LIMIT` sur toutes les requêtes d'échantillons
- **Optimisation** : Utilisation des index existants

## 🚧 Évolutions futures (Phase 2)

### Fonctionnalités prévues
- **Support labels** : Extension aux labels et autres entités
- **Exports Parquet/CSV** : Formats d'export supplémentaires
- **API REST** : Accès programmatique aux KPI
- **Dashboard web** : Interface web pour les KPI
- **Alertes** : Notifications automatiques sur les seuils

### Améliorations techniques
- **Cache Redis** : Mise en cache des résultats
- **Index optimisés** : Index dédiés aux vues KPI
- **Partitioning** : Partitionnement des tables volumineuses
- **Monitoring** : Surveillance avancée des performances

## 📞 Support

### Documentation
- **Guide complet** : Ce README
- **Guide ODBC Windows** : `docs/ODBC_Windows_guide.md`
- **Configuration Excel** : `excel/PowerQuery_guide.md`

### Contact
- **Issues GitHub** : Pour les bugs et demandes de fonctionnalités
- **Documentation** : Consulter les guides dans `docs/` et `excel/`
- **Tests** : Utiliser `scripts/tests.sql` pour diagnostiquer

### Contribution
Pour contribuer au projet :
1. Fork le repository
2. Créer une branche feature
3. Implémenter les modifications
4. Tester avec `scripts/tests.sql`
5. Créer une pull request

---

**🎉 Le projet Allfeat MusicBrainz KPI Phase 1 est maintenant prêt à être utilisé !**