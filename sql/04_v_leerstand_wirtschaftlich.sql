-- Wirtschaftlicher Leerstand: Summe Zähler / Summe Nenner
CREATE OR REPLACE VIEW immo.v_leerstand_wirtschaftlich AS
WITH leer AS (
    SELECT DISTINCT ON (l.einheit_id) l.einheit_id, l.sollmiete_potenziell
    FROM immo.leerstand l
    WHERE l.von <= immo.stichtag()
      AND (l.bis IS NULL OR l.bis >= immo.stichtag())
      AND l.grund <> 'sanierungsbedingt'
    ORDER BY l.einheit_id, l.von DESC
),
miete AS (
    SELECT einheit_id, MAX(aktuelle_kaltmiete) AS aktuelle_kaltmiete
    FROM immo.v_aktuelle_miete
    WHERE vertragsstatus = 'aktiv'
    GROUP BY einheit_id
)
SELECT
    e.objekt_id,
    o.bezeichnung,
    COUNT(*) AS einheiten_gesamt,
    COUNT(l.einheit_id) AS einheiten_leer,
    ROUND(SUM(l.sollmiete_potenziell)::numeric, 2) AS entgangene_miete,
    ROUND((100.0 * SUM(l.sollmiete_potenziell)
           / NULLIF(SUM(COALESCE(l.sollmiete_potenziell, m.aktuelle_kaltmiete, 0)), 0))::numeric, 2) AS quote_wirtschaftlich_pct
FROM immo.einheit e
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
LEFT JOIN leer l ON l.einheit_id = e.einheit_id
LEFT JOIN miete m ON m.einheit_id = e.einheit_id
WHERE e.nutzungsart = 'Wohnen'
GROUP BY e.objekt_id, o.bezeichnung;
