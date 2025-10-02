@echo off
REM Script de démarrage rapide Allfeat MusicBrainz KPI (Windows)
REM Usage: quick_start_windows.bat

echo 🚀 Démarrage rapide Allfeat MusicBrainz KPI
echo =============================================

REM Vérifier les prérequis
echo 📋 Vérification des prérequis...

REM Vérifier Docker
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker n'est pas installé. Veuillez installer Docker Desktop.
    pause
    exit /b 1
)

REM Vérifier docker-compose
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ docker-compose n'est pas installé. Veuillez installer docker-compose.
    pause
    exit /b 1
)

echo ✅ Prérequis vérifiés

REM Configuration
set DB_HOST=127.0.0.1
set DB_PORT=5432
set DB_NAME=musicbrainz
set DB_USER=musicbrainz

REM Étape 1: Démarrer PostgreSQL
echo 🐳 Démarrage de PostgreSQL...
docker-compose up -d
if %errorlevel% neq 0 (
    echo ❌ Erreur lors du démarrage de PostgreSQL
    pause
    exit /b 1
)

echo ✅ PostgreSQL démarré

REM Attendre que PostgreSQL soit prêt
echo ⏳ Attente que PostgreSQL soit prêt...
timeout /t 10 /nobreak >nul

REM Étape 2: Vérifier la connexion
echo 🔍 Vérification de la connexion...
docker exec musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME% -c "SELECT version();" >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  PostgreSQL n'est pas encore prêt. Attente supplémentaire...
    timeout /t 15 /nobreak >nul
    docker exec musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME% -c "SELECT version();" >nul 2>&1
    if %errorlevel% neq 0 (
        echo ❌ Impossible de se connecter à PostgreSQL
        pause
        exit /b 1
    )
)

echo ✅ Connexion PostgreSQL réussie

REM Étape 3: Appliquer le schéma MusicBrainz officiel
echo 📊 Application du schéma MusicBrainz officiel...
powershell -ExecutionPolicy Bypass -File scripts/apply_mb_schema.ps1
if %errorlevel% neq 0 (
    echo ❌ Erreur lors de l'application du schéma MusicBrainz
    pause
    exit /b 1
)

echo ✅ Schéma MusicBrainz appliqué

REM Étape 4: Importer les données MusicBrainz
echo 📥 Import des données MusicBrainz...
powershell -ExecutionPolicy Bypass -File scripts/import_mb.ps1
if %errorlevel% neq 0 (
    echo ❌ Erreur lors de l'import des données
    pause
    exit /b 1
)

echo ✅ Données MusicBrainz importées

REM Étape 5: Appliquer les index MusicBrainz
echo 🔧 Application des index MusicBrainz...
powershell -ExecutionPolicy Bypass -File scripts/apply_mb_indexes.ps1
if %errorlevel% neq 0 (
    echo ❌ Erreur lors de l'application des index
    pause
    exit /b 1
)

echo ✅ Index MusicBrainz appliqués

REM Étape 6: Vérifier le schéma MusicBrainz
echo 🔍 Vérification du schéma MusicBrainz...
powershell -ExecutionPolicy Bypass -File scripts/verify_mb_schema.ps1
if %errorlevel% neq 0 (
    echo ⚠️  Avertissements lors de la vérification du schéma
) else (
    echo ✅ Schéma MusicBrainz vérifié
)

REM Étape 7: Créer le schéma KPI
echo 📊 Création du schéma KPI...
docker exec -i musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME% < sql/init/00_schema.sql
if %errorlevel% neq 0 (
    echo ❌ Erreur lors de la création du schéma KPI
    pause
    exit /b 1
)

echo ✅ Schéma KPI créé

REM Étape 8: Appliquer les vues KPI
echo 🔧 Application des vues KPI...
powershell -ExecutionPolicy Bypass -File scripts/apply_views.ps1
if %errorlevel% neq 0 (
    echo ❌ Erreur lors de l'application des vues
    pause
    exit /b 1
)

echo ✅ Vues KPI appliquées

REM Étape 9: Tests de validation
echo 🧪 Tests de validation...
docker exec -i musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME% < scripts/tests.sql >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  Certains tests ont échoué. Vérifiez les logs.
) else (
    echo ✅ Tests de validation réussis
)

REM Résumé final
echo.
echo 🎉 Installation terminée!
echo ========================
echo.
echo 📊 Informations de connexion:
echo    Host: %DB_HOST%
echo    Port: %DB_PORT%
echo    Database: %DB_NAME%
echo    User: %DB_USER%
echo    Password: musicbrainz
echo.
echo 🔗 Commandes utiles:
echo    Connexion: docker exec -it musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME%
echo    Tests: docker exec -i musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME% -f scripts/tests.sql
echo.
echo 📋 Vues KPI disponibles:
docker exec musicbrainz-postgres psql -U %DB_USER% -d %DB_NAME% -c "SELECT viewname FROM pg_views WHERE schemaname = 'allfeat_kpi' ORDER BY viewname;"
echo.
echo 💡 Prochaines étapes:
echo    1. Configurer Excel/ODBC (voir excel/PowerQuery_guide.md)
echo    2. Utiliser les vues KPI pour analyser les données
echo    3. Vérifier les résultats avec: .\scripts\verify_mb_schema.ps1
echo.
pause
