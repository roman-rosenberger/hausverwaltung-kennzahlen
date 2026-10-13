-- Fluktuation je Objekt und Jahr (Stichtagsjahr und die drei Vorjahre)
CREATE OR REPLACE VIEW immo.v_fluktuation AS
SELECT
    o.objekt_id,
    o.bezeichnung,
    j.jahr,
    COUNT(DISTINCT e.einheit_id) AS einheiten_gesamt,
    COUNT(mv.vertrag_id) AS auszuege,
    ROUND(
        COUNT(mv.vertrag_id) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.einheit_id), 0), 2
    ) AS fluktuationsrate_pct
FROM immo.objekt o
CROSS JOIN generate_series(EXTRACT(YEAR FROM immo.stichtag())::int - 3,
                           EXTRACT(YEAR FROM immo.stichtag())::int) AS j(jahr)
JOIN immo.einheit e ON e.objekt_id = o.objekt_id
LEFT JOIN immo.mietvertrag mv 
    ON mv.einheit_id = e.einheit_id
    AND mv.vertragsende IS NOT NULL
    AND mv.vertragsstatus IN ('beendet', 'gekündigt')
    AND EXTRACT(YEAR FROM mv.vertragsende) = j.jahr
WHERE e.nutzungsart = 'Wohnen'
GROUP BY o.objekt_id, o.bezeichnung, j.jahr
ORDER BY j.jahr, fluktuationsrate_pct DESC;
