-- Création minimale des configurations de recherche MusicBrainz
CREATE TEXT SEARCH CONFIGURATION IF NOT EXISTS musicbrainz.mb_simple ( COPY = pg_catalog.simple );
CREATE TEXT SEARCH CONFIGURATION IF NOT EXISTS musicbrainz.mb_position ( COPY = pg_catalog.simple );

-- On pourrait ajouter d'autres dictionnaires si nécessaire, mais uniquement les bases pour KPI Phase 1