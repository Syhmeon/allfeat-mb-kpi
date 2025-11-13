@echo off
REM Script de test simple de connexion PostgreSQL
REM Usage: test_connection_simple.bat

echo === Test de connexion PostgreSQL MusicBrainz ===
echo.

REM Vérifier que le conteneur est actif
echo Test 1: Vérification du conteneur Docker...
docker ps --filter "name=musicbrainz-db" --format "{{.Status}}"
if errorlevel 1 (
    echo ERREUR: Conteneur musicbrainz-db non trouvé
    echo Démarrez avec: docker compose up -d db
    pause
    exit /b 1
)
echo.

REM Test de connexion
echo Test 2: Connexion avec psql.exe...
echo.

set PGPASSWORD=musicbrainz
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -p 5432 -U musicbrainz -d musicbrainz_db -c "SELECT 'Connexion réussie!' as status, current_user, current_database();"

if errorlevel 1 (
    echo.
    echo ERREUR: La connexion a échoué
    echo Vérifiez:
    echo   - Que le conteneur est démarré
    echo   - Que le port 5432 est accessible
    echo   - Les identifiants: musicbrainz / musicbrainz
    set PGPASSWORD=
    pause
    exit /b 1
) else (
    echo.
    echo SUCCES: La connexion fonctionne!
)

set PGPASSWORD=
pause

