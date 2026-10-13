-- Parameter: Stichtag, Karenztage, Mietanpassungs-Zyklus
-- Alle Views lesen den Stichtag über immo.stichtag(). Zum Wechseln des Stichtags
-- genügt: UPDATE immo.parameter_stichtag SET stichtag = DATE 'JJJJ-MM-TT';

CREATE TABLE IF NOT EXISTS immo.parameter_stichtag (
    id        INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    stichtag  DATE NOT NULL
);
INSERT INTO immo.parameter_stichtag (id, stichtag)
VALUES (1, DATE '2026-08-31')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION immo.stichtag() RETURNS date
LANGUAGE sql STABLE AS
$$ SELECT stichtag FROM immo.parameter_stichtag WHERE id = 1 $$;

CREATE TABLE IF NOT EXISTS immo.parameter_karenz (
    parameter_id  SERIAL PRIMARY KEY,
    objekt_id     TEXT REFERENCES immo.objekt(objekt_id),  -- NULL = globaler Standard
    karenztage    INTEGER NOT NULL CHECK (karenztage >= 0),
    gueltig_ab    DATE NOT NULL DEFAULT '2023-09-01',
    kommentar     TEXT
);
INSERT INTO immo.parameter_karenz (objekt_id, karenztage, kommentar)
SELECT NULL, 5, 'Globaler Standardwert'
WHERE NOT EXISTS (SELECT 1 FROM immo.parameter_karenz WHERE objekt_id IS NULL);

CREATE TABLE IF NOT EXISTS immo.parameter_mietzyklus (
    parameter_id        SERIAL PRIMARY KEY,
    soll_zyklus_monate  INTEGER NOT NULL,
    gueltig_ab          DATE NOT NULL DEFAULT '2023-09-01',
    kommentar           TEXT
);
INSERT INTO immo.parameter_mietzyklus (soll_zyklus_monate, kommentar)
SELECT 24, 'Soll-Anpassungszyklus in Monaten'
WHERE NOT EXISTS (SELECT 1 FROM immo.parameter_mietzyklus);
