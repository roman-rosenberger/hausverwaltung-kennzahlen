-- Sanierungsbedingter Leerstand, getrennt ausgewiesen
CREATE OR REPLACE VIEW immo.v_leerstand_sanierung AS
SELECT
    e.objekt_id,
    o.bezeichnung,
    COUNT(l.leerstand_id) AS einheiten_sanierung,
    ROUND(SUM(l.sollmiete_potenziell)::numeric, 2) AS entgangene_miete_monat,
    MIN(l.von) AS aeltester_sanierungsbeginn,
    MAX(immo.stichtag() - l.von) AS laengste_sanierungsphase_tage
FROM immo.leerstand l
JOIN immo.einheit e ON e.einheit_id = l.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE l.grund = 'sanierungsbedingt'
AND l.von <= immo.stichtag()
AND l.bis IS NULL
GROUP BY e.objekt_id, o.bezeichnung
ORDER BY einheiten_sanierung DESC;
