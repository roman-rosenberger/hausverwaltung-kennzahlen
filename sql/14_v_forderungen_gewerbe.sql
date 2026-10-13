-- Offene Forderungen Gewerbe je Aging-Klasse
CREATE OR REPLACE VIEW immo.v_forderungen_gewerbe AS
SELECT
    fa.objekt_id,
    fa.objekt_bezeichnung,
    fa.aging_bucket,
    ROUND(SUM(fa.offen)::numeric, 2) AS offener_betrag
FROM immo.v_forderungen_aging fa
JOIN immo.einheit e ON e.einheit_id = fa.einheit_id
WHERE e.nutzungsart = 'Gewerbe'
GROUP BY fa.objekt_id, fa.objekt_bezeichnung, fa.aging_bucket
ORDER BY fa.objekt_id, fa.aging_bucket;
