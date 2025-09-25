# Allfeat – MusicBrainz KPI Profiling (Phase 1)

## Description du projet

Ce projet configure un environnement PostgreSQL local (via Docker) avec le dump MusicBrainz, puis crée le schéma `allfeat_kpi` avec 6 vues KPI pour mesurer la qualité et complétude des métadonnées musicales.

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

## Structure du projet

```
├── docker-compose.yml          # Configuration Docker Postgres
├── .env                       # Variables d'environnement DB
├── scripts/                   # Scripts d'import et utilitaires
│   ├── import_mb.sh          # Import MusicBrainz (Linux/Mac)
│   ├── import_mb.ps1         # Import MusicBrainz (Windows)
│   ├── apply_views.sh        # Application des vues KPI
│   ├── smoke_tests.sql       # Tests de validation
│   └── explain_samples.sql   # Exemples d'utilisation
├── sql/                      # Scripts SQL
│   ├── init/
│   │   └── 00_schema.sql     # Création du schéma allfeat_kpi
│   └── views/                # Vues KPI
│       ├── 10_kpi_isrc_coverage.sql
│       ├── 20_kpi_iswc_coverage.sql
│       ├── 30_party_missing_ids_artist.sql
│       ├── 40_dup_isrc_candidates.sql
│       ├── 50_rec_on_release_without_work.sql
│       ├── 51_work_without_recording.sql
│       └── 60-63_confidence_*.sql
├── excel/                    # Templates Excel
│   └── Allfeat_MB_KPI_Template.xlsx
└── docs/                     # Documentation
    ├── README.md
    └── ODBC_Windows_guide.md
```

## Installation rapide

1. **Cloner le repository**
   ```bash
   git clone <repo-url>
   cd allfeat-mb-kpi
   ```

2. **Démarrer PostgreSQL**
   ```bash
   docker compose up -d
   ```

3. **Importer MusicBrainz**
   ```bash
   # Télécharger le dump depuis https://musicbrainz.org/doc/MusicBrainz_Database/Download
   # Placer dans /dumps/
   ./scripts/import_mb.sh
   ```

4. **Créer les vues KPI**
   ```bash
   ./scripts/apply_views.sh
   ```

5. **Tester l'installation**
   ```bash
   psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/smoke_tests.sql
   ```

## Utilisation avec Excel

1. Configurer ODBC : `docs/ODBC_Windows_guide.md`
2. Ouvrir `excel/Allfeat_MB_KPI_Template.xlsx`
3. Rafraîchir les connexions Power Query

## Contraintes Phase 1

- **Scope** : Artistes uniquement (labels en backlog)
- **Logique confiance** : Phase 1 (catégorielle) + Phase 2 (numérique) par entité indépendante
- **Priorité** : Excel/ODBC (exports Parquet/CSV en Phase 2)
- **Performance** : Vues légères (comptes/ratios + petits échantillons)

## Support

Pour toute question ou problème, consulter la documentation dans `docs/` ou créer une issue sur GitHub.
