# Template Excel Allfeat MusicBrainz KPI

## Instructions d'utilisation

### Prérequis
1. PostgreSQL démarré avec Docker (`docker compose up -d`)
2. Dump MusicBrainz importé
3. Vues KPI créées (`psql -f scripts/apply_views.sh`)
4. Source de données ODBC configurée (`MB_ODBC`)

### Configuration Power Query

#### 1. Connexion ODBC
- **Nom** : `MB_ODBC`
- **Serveur** : `127.0.0.1:5432`
- **Base** : `musicbrainz`
- **Utilisateur** : `musicbrainz`
- **Mot de passe** : `musicbrainz`

#### 2. Requêtes principales

**KPI Overview** :
```sql
SELECT 'ISRC Coverage' as kpi_name, isrc_coverage_pct as coverage_pct, duplicate_rate_pct as duplicate_pct FROM allfeat_kpi.kpi_isrc_coverage
UNION ALL
SELECT 'ISWC Coverage' as kpi_name, iswc_coverage_pct as coverage_pct, duplicate_rate_pct as duplicate_pct FROM allfeat_kpi.kpi_iswc_coverage
UNION ALL
SELECT 'Artist IDs' as kpi_name, overall_id_completeness_pct as coverage_pct, 0 as duplicate_pct FROM allfeat_kpi.party_missing_ids_artist;
```

**ISRC Duplicates** :
```sql
SELECT isrc, duplicate_count, duplicate_risk_score, risk_level FROM allfeat_kpi.dup_isrc_candidates ORDER BY duplicate_risk_score DESC LIMIT 100;
```

**Missing Artist IDs** :
```sql
SELECT artist_name, ipi_status, isni_status, id_completeness_score FROM allfeat_kpi.party_missing_ids_artist_samples ORDER BY id_completeness_score ASC LIMIT 100;
```

**Confidence Levels** :
```sql
SELECT 'Artist' as entity, average_confidence_score, overall_confidence_level FROM allfeat_kpi.confidence_artist
UNION ALL
SELECT 'Work' as entity, average_confidence_score, overall_confidence_level FROM allfeat_kpi.confidence_work
UNION ALL
SELECT 'Recording' as entity, average_confidence_score, overall_confidence_level FROM allfeat_kpi.confidence_recording
UNION ALL
SELECT 'Release' as entity, average_confidence_score, overall_confidence_level FROM allfeat_kpi.confidence_release;
```

### Feuilles Excel

1. **Dashboard** : Vue d'ensemble avec métriques clés
2. **KPI Overview** : Tableau de bord principal
3. **ISRC Analysis** : Analyse des codes ISRC et doublons
4. **Artist IDs** : Analyse des identifiants manquants
5. **Confidence** : Niveaux de confiance par entité
6. **Samples** : Échantillons pour analyse détaillée

### PivotTables recommandées

- **Doublons ISRC** : Par niveau de risque et similarité
- **Couverture IDs** : Par type d'identifiant et statut
- **Confiance** : Par entité et niveau de confiance

### Graphiques recommandés

- Barres : Couverture ISRC/ISWC
- Secteurs : Répartition niveaux de confiance
- Aires : Doublons ISRC par risque
- Colonnes : Identifiants manquants

### Automatisation

1. Actualisation automatique à l'ouverture
2. Intervalle de rafraîchissement configurable
3. Notifications en cas d'erreur

### Support

Pour toute question :
- Consulter `docs/ODBC_Windows_guide.md`
- Vérifier les logs PostgreSQL
- Tester les requêtes directement avec `psql`
