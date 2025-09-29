---
alwaysApply: false
---

# Implementation — Plan

## Déjà fait
- Import MB via Docker/Postgres  
- Schéma `allfeat_kpi` + 10 vues KPI  
- Scripts apply_views (Linux + Windows)  
- Guide ODBC + PowerQuery  

## À faire (Phase 1)
- Finaliser tests.sql (smoke, golden, perf)  
- Générer exports anomalies CSV/Parquet  
- Compléter guide analystes  

## Phase 2 (évolutions)
- Créer schéma pivot multi-sources  
- Ingestion/mapping par source (/sources/*)  
- Réutiliser KPI sur pivot  
- Score Phase 2 numérique pondéré  
- API REST + dashboard  

---