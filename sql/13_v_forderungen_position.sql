-- Offene Forderungen nach Position
CREATE OR REPLACE VIEW immo.v_forderungen_position AS
SELECT fa.objekt_id,
       fa.objekt_bezeichnung AS bezeichnung,
       fa.nutzungsart,
       fa."position",
       COUNT(*) AS anzahl_offene_posten,
       ROUND(SUM(fa.offen)::numeric, 2) AS offener_betrag
FROM immo.v_forderungen_aging fa
GROUP BY fa.objekt_id, fa.objekt_bezeichnung, fa.nutzungsart, fa."position";
