# Allfeat – MusicBrainz KPI Profiling (Phase 1) - Résumé du projet

## 🎯 Objectif du projet

Mettre en place un environnement PostgreSQL local avec le dump MusicBrainz et créer des vues KPI pour analyser la qualité des métadonnées musicales, avec un accès prioritaire via Excel/ODBC pour les analystes Allfeat.

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

### 6. Niveaux de confiance (hiérarchie Artist > Work > Recording > Release)
- **Artistes** : `allfeat_kpi.confidence_artist` + `allfeat_kpi.confidence_artist_samples`
- **Œuvres** : `allfeat_kpi.confidence_work` + `allfeat_kpi.confidence_work_samples`
- **Enregistrements** : `allfeat_kpi.confidence_recording` + `allfeat_kpi.confidence_recording_samples`
- **Releases** : `allfeat_kpi.confidence_release` + `allfeat_kpi.confidence_release_samples`
- **Métriques** : Score de confiance (0-100), facteurs détaillés, classification par niveau

## 🏗️ Architecture technique

### Infrastructure
- **PostgreSQL 15** (via Docker)
- **Schéma dédié** : `allfeat_kpi`
- **Fonctions utilitaires** : `format_percentage()`, `random_sample()`
- **Métadonnées** : Table `allfeat_kpi.metadata`

### Accès aux données
- **Priorité 1** : Excel/ODBC (Power Query, PivotTables)
- **Priorité 2** : Accès direct PostgreSQL (`psql`)
- **Phase 2** : Exports Parquet/CSV (en backlog)

### Performance
- **Vues légères** : Comptes/ratios + petits échantillons uniquement
- **Limites** : `LIMIT` sur toutes les requêtes d'échantillons
- **Index** : Utilisation des index MusicBrainz existants

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
│   ├── smoke_tests.sql        # Tests de validation
│   └── explain_samples.sql    # Exemples d'utilisation
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
│   ├── PowerQuery_Configuration.md
│   ├── PowerQuery_Queries.md
│   └── README.md
├── docs/                      # Documentation complète
│   ├── README.md
│   └── ODBC_Windows_guide.md
└── dumps/                     # Répertoire pour les dumps MusicBrainz
```

## 🚀 Installation rapide

### Prérequis
- Docker Desktop
- PostgreSQL client (`psql`)
- Git
- Microsoft Excel (avec Power Query)
- Pilote ODBC PostgreSQL

### Étapes d'installation

1. **Cloner le repository**
   ```bash
   git clone <repo-url>
   cd allfeat-mb-kpi
   ```

2. **Démarrage automatique**
   ```bash
   ./quick_start.sh
   ```

3. **Configuration Excel/ODBC**
   - Installer le pilote ODBC PostgreSQL
   - Créer la source `MB_ODBC`
   - Configurer Power Query avec les requêtes fournies

## 📈 Utilisation

### Accès via Excel/ODBC
1. **Connexion ODBC** : `MB_ODBC` → `127.0.0.1:5432/musicbrainz`
2. **Requêtes Power Query** : Utiliser les requêtes pré-configurées
3. **PivotTables** : Analyser les données selon les besoins
4. **Actualisation** : Automatique à l'ouverture du fichier

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
WHERE confidence_level = 'Low Confidence' LIMIT 20;
```

## 🎯 Public cible

### Utilisateurs principaux
- **Équipe Data Engineering Allfeat** : Maintenance et évolution
- **Analystes qualité métadonnées** : Analyse quotidienne des KPI
- **Parties prenantes business/consulting** : Tableaux de bord et rapports

### Cas d'usage
- **Monitoring qualité** : Surveillance continue des métadonnées
- **Identification problèmes** : Détection des doublons et incohérences
- **Reporting** : Génération de rapports pour les stakeholders
- **Optimisation** : Amélioration des processus de curation

## 🔧 Maintenance

### Surveillance
- **Tests automatiques** : `scripts/smoke_tests.sql`
- **Logs Docker** : `docker compose logs postgres`
- **Métadonnées** : Table `allfeat_kpi.metadata`

### Mise à jour
- **Rafraîchissement données** : `ANALYZE;` dans PostgreSQL
- **Actualisation vues** : `./scripts/apply_views.sh`
- **Sauvegarde** : `pg_dump` régulier

### Dépannage
- **Documentation** : `docs/README.md` et `docs/ODBC_Windows_guide.md`
- **Tests** : `scripts/smoke_tests.sql`
- **Logs** : Docker et PostgreSQL

## 📋 Contraintes Phase 1

### Scope limité
- **Artistes uniquement** (labels en backlog)
- **Hiérarchie confiance** : Artist > Work > Recording > Release
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
- **Guide complet** : `docs/README.md`
- **Guide ODBC Windows** : `docs/ODBC_Windows_guide.md`
- **Configuration Excel** : `excel/PowerQuery_Configuration.md`

### Contact
- **Issues GitHub** : Pour les bugs et demandes de fonctionnalités
- **Documentation** : Consulter les guides dans `docs/`
- **Tests** : Utiliser `scripts/smoke_tests.sql` pour diagnostiquer

---

**🎉 Le projet Allfeat MusicBrainz KPI Phase 1 est maintenant prêt à être utilisé !**
