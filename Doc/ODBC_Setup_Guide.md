# Guide de Configuration ODBC pour Allfeat KPI

## 📋 Prérequis

1. **Driver ODBC PostgreSQL** installé
   - Téléchargement : https://www.postgresql.org/ftp/odbc/versions/msi/
   - Version recommandée : psqlODBC 13.x ou 14.x (64-bit)
   - Alternative : Utiliser le driver fourni avec PostgreSQL 18 si installé

2. **PostgreSQL accessible**
   - Container `musicbrainz-db` en cours d'exécution
   - Port **5433** exposé sur `localhost` (⚠️ pas 5432)

---

## 🔧 Configuration ODBC

### Étape 1 : Ouvrir l'Administrateur de Sources de Données ODBC

1. Appuyez sur `Windows + R`
2. Tapez : `odbcad32.exe` (pour 64-bit) ou `odbcad32.exe -32` (pour 32-bit)
3. Appuyez sur **Entrée**

**Ou via le Panneau de configuration :**
- Panneau de configuration → Outils d'administration → Sources de données ODBC (64 bits)

### Étape 2 : Créer une Nouvelle Source de Données

1. Cliquez sur l'onglet **Sources de données utilisateur** (ou **Sources de données système** pour tous les utilisateurs)
2. Cliquez sur **Ajouter...**
3. Sélectionnez **PostgreSQL Unicode** ou **PostgreSQL ANSI**
   - **Recommandé :** PostgreSQL Unicode (meilleure compatibilité)
4. Cliquez sur **Terminer**

### Étape 3 : Configurer les Paramètres de Connexion

Dans la fenêtre **PostgreSQL ODBC Driver (psqlODBC) Setup**, configurez :

```
Data Source:     Allfeat KPI - MusicBrainz
Description:     Base de données MusicBrainz avec vues KPI Allfeat
Database:        musicbrainz_db
Server:          127.0.0.1
Port:            5433                    ← IMPORTANT : Port 5433
Username:        musicbrainz
Password:        musicbrainz
SSL Mode:        disable                 (ou prefer selon votre config)
```

**Paramètres avancés (optionnel) :**
- **Read Only** : Non coché (pour permettre les requêtes)
- **Show System Tables** : Non coché (recommandé)
- **Bools as Char** : Non coché
- **Parse Statements** : Coché (recommandé)

### Étape 4 : Test de Connexion

1. Cliquez sur **Test** (ou **Test Connection**)
2. Vous devriez voir : **"Connection successful"**
3. Si erreur, vérifiez :
   - Que le conteneur Docker est démarré : `docker ps | grep musicbrainz-db`
   - Que le port est bien **5433** (pas 5432)
   - Les identifiants : `musicbrainz` / `musicbrainz`

### Étape 5 : Sauvegarder

1. Cliquez sur **Save** (ou **Enregistrer**)
2. Cliquez sur **OK**

---

## 📊 Utilisation avec Excel / Power Query

### Excel - Power Query

1. **Excel** → Onglet **Données** → **Obtenir des données** → **À partir d'autres sources** → **À partir d'ODBC**
2. Sélectionnez la source : **Allfeat KPI - MusicBrainz**
3. Cliquez sur **OK**
4. Entrez les identifiants si demandé :
   - Username: `musicbrainz`
   - Password: `musicbrainz`
5. Sélectionnez le schéma : `allfeat_kpi`
6. Choisissez les vues/tables à importer

### Exemple de Requête SQL dans Power Query

```sql
SELECT * FROM allfeat_kpi.kpi_isrc_coverage;
```

---

## 🔍 Vérification de la Connexion

### Test avec PowerShell

```powershell
$connectionString = "Driver={PostgreSQL Unicode};Server=127.0.0.1;Port=5433;Database=musicbrainz_db;Uid=musicbrainz;Pwd=musicbrainz;"
$connection = New-Object System.Data.Odbc.OdbcConnection($connectionString)
try {
    $connection.Open()
    Write-Host "✅ Connexion ODBC réussie!" -ForegroundColor Green
    $connection.Close()
} catch {
    Write-Host "❌ Erreur: $_" -ForegroundColor Red
}
```

### Test avec Python (pyodbc)

```python
import pyodbc

conn_str = (
    "Driver={PostgreSQL Unicode};"
    "Server=127.0.0.1;"
    "Port=5433;"
    "Database=musicbrainz_db;"
    "Uid=musicbrainz;"
    "Pwd=musicbrainz;"
)

try:
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    cursor.execute("SELECT current_user, current_database();")
    row = cursor.fetchone()
    print(f"✅ Connexion OK: {row[0]}@{row[1]}")
    conn.close()
except Exception as e:
    print(f"❌ Erreur: {e}")
```

---

## 🚨 Dépannage

### Erreur : "Data source name not found"

**Solution :**
- Vérifiez que le driver PostgreSQL est installé
- Utilisez `odbcad32.exe` (64-bit) si vous êtes sur Windows 64-bit
- Réinstallez le driver ODBC PostgreSQL

### Erreur : "Connection refused" ou "Could not connect to server"

**Solution :**
```powershell
# Vérifier que le conteneur est démarré
docker ps | grep musicbrainz-db

# Vérifier le port mapping
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep musicbrainz-db
# Doit afficher : 0.0.0.0:5433->5432/tcp
```

### Erreur : "password authentication failed"

**Solution :**
- Vérifiez les identifiants : `musicbrainz` / `musicbrainz`
- Vérifiez que vous utilisez le port **5433** (pas 5432)

### Erreur : "Driver does not support the requested properties"

**Solution :**
- Mettez à jour le driver ODBC PostgreSQL
- Utilisez "PostgreSQL Unicode" au lieu de "PostgreSQL ANSI"

---

## 📝 Chaîne de Connexion Complète

Pour référence, voici la chaîne de connexion complète :

```
Driver={PostgreSQL Unicode};Server=127.0.0.1;Port=5433;Database=musicbrainz_db;Uid=musicbrainz;Pwd=musicbrainz;SSL Mode=disable;
```

**Variantes :**

- **Avec SSL (si configuré) :**
```
Driver={PostgreSQL Unicode};Server=127.0.0.1;Port=5433;Database=musicbrainz_db;Uid=musicbrainz;Pwd=musicbrainz;SSL Mode=prefer;
```

- **Avec timeout :**
```
Driver={PostgreSQL Unicode};Server=127.0.0.1;Port=5433;Database=musicbrainz_db;Uid=musicbrainz;Pwd=musicbrainz;Connect Timeout=10;
```

---

## ✅ Checklist de Configuration

- [ ] Driver ODBC PostgreSQL installé (64-bit)
- [ ] Source de données ODBC créée : "Allfeat KPI - MusicBrainz"
- [ ] Port configuré : **5433** (pas 5432)
- [ ] Test de connexion réussi
- [ ] Excel/Power Query peut se connecter
- [ ] Les vues `allfeat_kpi.*` sont accessibles

---

## 🔗 Ressources

- **Driver ODBC PostgreSQL :** https://www.postgresql.org/ftp/odbc/versions/msi/
- **Documentation psqlODBC :** https://odbc.postgresql.org/
- **Guide Power Query :** Voir `excel/PowerQuery_guide.md`

---

**🎉 Configuration terminée ! Vous pouvez maintenant utiliser ODBC pour accéder aux données MusicBrainz depuis Excel, Python, ou tout autre outil compatible ODBC.**

