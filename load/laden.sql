-- Gesamtlauf: Zwischenschicht anlegen, CSV laden, nach immo übernehmen.
-- Aufruf aus dem Paketordner (dort liegt auch der Ordner daten/):
--   psql -h localhost -U postgres -d hausverwaltung -f load/laden.sql
\set ON_ERROR_STOP on
\i load/01_stg_tabellen.sql
\i load/02_stg_laden.sql
\i load/03_nach_immo.sql
