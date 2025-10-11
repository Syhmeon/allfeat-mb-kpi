---
alwaysApply: false
---

# Architecture

## Phase 1 (Architecture actuelle - post-migration Docker)

### Flux de données
```
MusicBrainz Docker officiel (v30)
    ↓
PostgreSQL 15 (conteneur musicbrainz-db)
    ↓
Schéma musicbrainz (375 tables, import automatisé 2-6h)
    ↓
Schéma allfeat_kpi (10 vues KPI)
    ↓
Excel/ODBC (connexion localhost:5432)
```

### Composants techniques
- **Base de données:** PostgreSQL 15 (via MusicBrainz Docker)
- **Schéma source:** `musicbrainz` (375 tables, ~50 GB)
- **Schéma analytique:** `allfeat_kpi` (10 vues + 1 fonction helper)
- **Tables utilisées:** 12 tables sur 375 (recording, work, artist, release, etc.)
- **Connexion:** localhost:5432, user: musicbrainz, db: musicbrainz_db
- **Gestion:** Docker Compose + scripts PowerShell  

## Phase 2
Sources externes → Schéma pivot → KPI multi-sources → Matching & Scoring → Mapping MIDDS  

---