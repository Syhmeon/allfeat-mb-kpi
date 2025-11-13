-- Script SQL de test pour DBeaver ou autre client SQL
-- Copiez-collez ce script dans DBeaver et exécutez-le

-- Test 1: Vérification de la connexion
SELECT 
    'Connexion réussie!' as status,
    current_user as utilisateur,
    current_database() as base_de_donnees,
    version() as version_postgresql;

-- Test 2: Vérification des schémas disponibles
SELECT 
    schema_name,
    schema_owner
FROM information_schema.schemata
WHERE schema_name IN ('musicbrainz', 'allfeat_kpi')
ORDER BY schema_name;

-- Test 3: Vérification des vues KPI (si elles existent)
SELECT 
    schemaname,
    viewname,
    viewowner
FROM pg_views
WHERE schemaname = 'allfeat_kpi'
ORDER BY viewname
LIMIT 10;

-- Test 4: Comptage des enregistrements (exemple)
SELECT 
    'recordings' as table_name,
    COUNT(*) as count
FROM musicbrainz.recording
LIMIT 1;

