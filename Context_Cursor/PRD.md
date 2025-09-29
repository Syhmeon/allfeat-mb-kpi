---
alwaysApply: false
---

# Allfeat – MusicBrainz KPI Profiling (Phase 1)

## Vue d'ensemble
Projet configurant un PostgreSQL local (via Docker) avec dump MusicBrainz et schéma `allfeat_kpi` pour générer 10 vues KPI.

### Objectifs
- Couverture ISRC  
- Couverture ISWC  
- IDs manquants  
- Doublons ISRC  
- Incohérences Work–Recording  
- Niveaux de confiance (Phase 1: catégoriel, Phase 2: score numérique pondéré)

### Public cible
- Data Engineers Allfeat  
- Analystes qualité  
- Parties prenantes business  

## Architecture
Docker Compose → PostgreSQL (MusicBrainz + allfeat_kpi) → Vues KPI → Excel/ODBC

## KPI implémentés
1. Couverture ISRC (vue + échantillons)  
2. Couverture ISWC (vue + échantillons + détaillée)  
3. IDs manquants artistes (vue + échantillons)  
4. Doublons ISRC (vue + échantillons)  
5. Incohérences Work–Recording (plusieurs vues)  
6. Niveaux de confiance (Artist, Work, Recording, Release, vues + échantillons)  

## Structure projet
- docker-compose.yml  
- scripts (import_mb.*, apply_views.*, tests.sql)  
- sql/init + sql/views (10 vues KPI)  
- excel/PowerQuery_guide.md  
- docs/ODBC_Windows_guide.md  
- dumps/  

## Installation rapide
- Prérequis : Docker, psql, Excel (ODBC), 8–16 GB RAM  
- Étapes : `git clone`, `./quick_start.sh`, importer dump, appliquer vues, lancer tests  

## Utilisation
- Excel via ODBC (DSN = MB_ODBC)  
- PostgreSQL direct : `SELECT * FROM allfeat_kpi.kpi_isrc_coverage;`  
- Exemples : top doublons, artistes faible confiance, stats globales  

## Maintenance
- EXPLAIN ANALYZE sur vues  
- ANALYZE pour rafraîchir stats  
- Backups (pg_dump base ou schéma KPI)  

## Dépannage
- Connexion : vérifier Docker/logs  
- Import : intégrité dump + espace disque  
- ODBC : pilote + DSN  
- Requêtes lentes : LIMIT + index  

## Contraintes Phase 1
- Scope limité : artistes  
- Confiance : Phase 1 catégorielle + Phase 2 numérique  
- Accès : Excel/ODBC en priorité  

## Évolutions Phase 2
- Multi-sources (Discogs, DDEX, PRO/CMO, DSP, UGC, ID3, AcoustID, Wikidata)  
- Schéma pivot + matching identifiants  
- Score pondéré 0–1  
- Exports Parquet, API REST, dashboard  

---