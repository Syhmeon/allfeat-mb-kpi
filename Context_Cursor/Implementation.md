---
alwaysApply: false
---

# Implementation — Plan

## ✅ Déjà fait (Phase 1 - avant migration Docker)
- ✅ Schéma `allfeat_kpi` + 10 vues KPI  
- ✅ Scripts apply_views.ps1  
- ✅ Guide ODBC + PowerQuery  
- ✅ Tests SQL complets (tests.sql)  
- ✅ Documentation complète (PRD, Architecture, Testing, UX)

## 🔄 En cours (Migration MusicBrainz Docker officiel)
**Date de migration:** 2025-10-11  
**Raison:** Import manuel trop lent (100h+) et instable → Migration vers solution officielle  
**Documentation:** Voir `Context_Cursor/Expert_Evaluation.md` pour analyse détaillée

### Étapes de migration
1. ✅ Créer branche Git `feature/musicbrainz-docker-migration`
2. ✅ Mettre à jour documentation (.cursor/rules + Context_Cursor)
3. 🔄 Configurer MusicBrainz Docker officiel (v30)
4. ⏳ Lancer import automatisé (2-6h estimées)
5. ⏳ Appliquer vues KPI sur base importée
6. ⏳ Valider avec tests.sql
7. ⏳ Mettre à jour README avec nouvelle procédure

## 📋 À faire (Phase 1 - après migration)
- Générer exports anomalies CSV/Parquet  
- Compléter guide analystes avec exemples concrets  
- Documenter procédure de mise à jour de la base MusicBrainz  

## Phase 2 (évolutions)
- Créer schéma pivot multi-sources  
- Ingestion/mapping par source (/sources/*)  
- Réutiliser KPI sur pivot  
- Score Phase 2 numérique pondéré  
- API REST + dashboard  

---