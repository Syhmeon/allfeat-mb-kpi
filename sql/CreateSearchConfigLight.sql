-- Création minimale des configurations de recherche MusicBrainz
-- S'assurer que le schéma musicbrainz existe
CREATE SCHEMA IF NOT EXISTS musicbrainz;

-- Créer les extensions nécessaires pour MusicBrainz
CREATE EXTENSION IF NOT EXISTS earthdistance;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Créer la fonction musicbrainz_unaccent
CREATE OR REPLACE FUNCTION musicbrainz_unaccent(text)
RETURNS text
AS $$
    SELECT unaccent($1);
$$ LANGUAGE sql IMMUTABLE;

-- Créer les configurations de recherche (PostgreSQL 15 ne supporte pas IF NOT EXISTS pour TEXT SEARCH CONFIGURATION)
DO $$
BEGIN
    -- Créer mb_simple si elle n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'mb_simple' AND cfgnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'musicbrainz')) THEN
        CREATE TEXT SEARCH CONFIGURATION musicbrainz.mb_simple ( COPY = pg_catalog.simple );
    END IF;
    
    -- Créer mb_position si elle n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'mb_position' AND cfgnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'musicbrainz')) THEN
        CREATE TEXT SEARCH CONFIGURATION musicbrainz.mb_position ( COPY = pg_catalog.simple );
    END IF;
END $$;

-- On pourrait ajouter d'autres dictionnaires si nécessaire, mais uniquement les bases pour KPI Phase 1