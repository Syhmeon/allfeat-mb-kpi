# Guide de Configuration DBeaver pour Allfeat KPI

## 📋 Prérequis

1. **DBeaver Community Edition** installé
   - Téléchargement : https://dbeaver.io/download/
   - Version recommandée : DBeaver Community Edition (gratuite)

2. **PostgreSQL accessible**
   - Container `musicbrainz-db` en cours d'exécution
   - Port 5432 exposé sur `localhost`

---

## 🔧 Configuration de la Connexion

### Étape 1 : Créer une Nouvelle Connexion

1. Ouvrir **DBeaver**
2. Menu : **Database → New Database Connection** (ou `Ctrl+Shift+N`)
3. Sélectionner **PostgreSQL** dans la liste des drivers
4. Cliquer sur **Next**

### Étape 2 : Paramètres de Connexion

Dans l'onglet **Main**, configurer :

```
Host:         127.0.0.1
Port:         5433
Database:     musicbrainz_db
Username:     musicbrainz
Password:     musicbrainz
```

**⚠️ IMPORTANT :** Le port est **5433** (pas 5432) car PostgreSQL Windows utilise le port 5432.

**Options avancées** (onglet **PostgreSQL**) :
- **Show all databases** : ✅ (optionnel, pour voir toutes les bases)
- **Show system schemas** : ❌ (recommandé : désactivé pour plus de clarté)

### Étape 3 : Test de Connexion

1. Cliquer sur **Test Connection**
2. Si c'est la première fois, DBeaver peut télécharger le driver PostgreSQL automatiquement
3. Vérifier que le message **"Connected"** s'affiche
4. Si erreur, vérifier que le container Docker est démarré : `docker compose ps`

### Étape 4 : Finaliser

1. Cliquer sur **Next**
2. **Nom de la connexion** : `Allfeat KPI – MusicBrainz`
3. **Description** (optionnel) : `Base de données MusicBrainz avec vues KPI Allfeat`
4. Cliquer sur **Finish**

---

## 📁 Organisation de l'Espace de Travail

### Étape 5 : Configurer le Schéma par Défaut

1. Clic droit sur la connexion **"Allfeat KPI – MusicBrainz"**
2. **Edit Connection**
3. Onglet **PostgreSQL**
4. **Default database** : `musicbrainz_db`
5. **Default schema** : `allfeat_kpi`
6. **Save**

### Étape 6 : Créer un Dossier pour les Vues

1. Clic droit sur la connexion → **SQL Editor → New SQL Script**
2. Ou utiliser le **Database Navigator** :
   - Développer : `Allfeat KPI – MusicBrainz → Schemas → allfeat_kpi → Views`
3. Créer un dossier personnalisé (optionnel) :
   - Clic droit sur la connexion → **Create → Folder**
   - Nom : `Views_Allfeat`

### Étape 7 : Marquer les Vues Importantes

**Vues principales à explorer** :

1. **Vues de Couverture** :
   - `allfeat_kpi.kpi_isrc_coverage` - Couverture ISRC
   - `allfeat_kpi.kpi_isrc_coverage_samples` - Échantillons ISRC
   - `allfeat_kpi.kpi_iswc_coverage` - Couverture ISWC
   - `allfeat_kpi.kpi_iswc_coverage_samples` - Échantillons ISWC

2. **Vues de Confiance** :
   - `allfeat_kpi.confidence_artist` - Niveaux de confiance artistes
   - `allfeat_kpi.confidence_artist_samples` - Échantillons artistes
   - `allfeat_kpi.confidence_work` - Niveaux de confiance œuvres
   - `allfeat_kpi.confidence_recording` - Niveaux de confiance enregistrements
   - `allfeat_kpi.confidence_release` - Niveaux de confiance releases

3. **Vues d'Analyse** :
   - `allfeat_kpi.party_missing_ids_artist` - Artistes sans identifiants
   - `allfeat_kpi.dup_isrc_candidates` - Doublons ISRC potentiels
   - `allfeat_kpi.rec_on_release_without_work` - Enregistrements sans œuvre
   - `allfeat_kpi.work_without_recording` - Œuvres sans enregistrement
   - `allfeat_kpi.work_recording_inconsistencies` - Incohérences Work-Recording

4. **Vue de Statistiques** :
   - `allfeat_kpi.stats_overview` - Vue d'ensemble des statistiques

**Pour marquer une vue** :
- Clic droit sur la vue → **Add to Bookmarks** (ou `Ctrl+Shift+B`)
- Les favoris apparaissent dans le dossier **Bookmarks**

---

## 🔍 Requêtes de Test

### Test 1 : Vérifier les Vues Disponibles

```sql
SELECT 
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'allfeat_kpi'
ORDER BY viewname;
```

### Test 2 : Vue d'Ensemble des Statistiques

```sql
SELECT * FROM allfeat_kpi.stats_overview;
```

### Test 3 : Couverture ISRC

```sql
SELECT 
    total_recordings,
    recordings_with_isrc,
    isrc_coverage_pct,
    duplicate_rate_pct
FROM allfeat_kpi.kpi_isrc_coverage;
```

### Test 4 : Niveaux de Confiance Artistes

```sql
SELECT 
    total_artists,
    phase1_high_count,
    phase1_medium_count,
    phase1_low_count,
    phase2_high_count,
    phase2_medium_count,
    phase2_low_count,
    average_phase2_score
FROM allfeat_kpi.confidence_artist;
```

### Test 5 : Échantillons d'Artistes avec Haute Confiance

```sql
SELECT 
    artist_name,
    phase1_confidence_level,
    phase2_confidence_score,
    phase2_confidence_level,
    has_artist_id,
    has_isrc,
    has_iswc,
    on_release
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'High'
ORDER BY phase2_confidence_score DESC
LIMIT 20;
```

---

## 💾 Sauvegarder l'Espace de Travail

1. Menu : **File → Save Workspace** (ou `Ctrl+S`)
2. DBeaver sauvegarde automatiquement :
   - Les connexions
   - Les scripts SQL ouverts
   - Les favoris
   - Les préférences

---

## 🚨 Dépannage

### Erreur : "Connection refused"

**Solution** :
```powershell
# Vérifier que le container est démarré
docker compose ps

# Si non démarré
docker compose up -d db
```

### Erreur : "Authentication failed"

**Solution** :
- Vérifier les identifiants : `musicbrainz` / `musicbrainz`
- Vérifier la base : `musicbrainz_db`

### Erreur : "Database does not exist"

**Solution** :
```powershell
# Vérifier que la base existe
docker exec musicbrainz-db psql -U musicbrainz -l | grep musicbrainz_db
```

### Le schéma `allfeat_kpi` n'apparaît pas

**Solution** :
1. Vérifier que les vues sont créées :
```powershell
docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM pg_views WHERE schemaname = 'allfeat_kpi';"
```

2. Si le schéma est vide, exécuter :
```powershell
.\scripts\apply_views.ps1
```

---

## 📊 Utilisation Avancée

### Créer des Requêtes Personnalisées

1. **Nouveau Script SQL** : `Ctrl+Alt+S`
2. Sauvegarder dans un projet DBeaver pour réutilisation

### Exporter des Données

1. Clic droit sur une vue/table → **Export Data**
2. Formats disponibles : CSV, Excel, JSON, SQL, etc.

### Visualiser les Données

1. Double-clic sur une vue pour voir les données
2. Utiliser les filtres intégrés de DBeaver
3. Créer des graphiques (si extension installée)

---

## ✅ Checklist de Configuration

- [ ] DBeaver Community Edition installé
- [ ] Connexion "Allfeat KPI – MusicBrainz" créée
- [ ] Test de connexion réussi
- [ ] Schéma par défaut configuré : `allfeat_kpi`
- [ ] Vues principales explorées
- [ ] Favoris créés pour les vues importantes
- [ ] Espace de travail sauvegardé
- [ ] Requêtes de test exécutées avec succès

---

**🎉 Configuration terminée ! Vous pouvez maintenant explorer les vues KPI Allfeat dans DBeaver.**

