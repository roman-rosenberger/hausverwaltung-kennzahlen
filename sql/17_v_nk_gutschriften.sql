-- NK-Gutschriften je Objekt (negative Nachforderungen)
CREATE OR REPLACE VIEW immo.v_nk_gutschriften AS
SELECT
    e.objekt_id,
    o.bezeichnung,
    COUNT(*) AS anzahl_gutschriften,
    ROUND(SUM(s.betrag)::numeric, 2) AS betrag_gutschriften
FROM immo.sollstellung s
JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE s.storno = false
  AND s.betrag < 0
  AND s."position" = 'NK-Nachforderung'
GROUP BY e.objekt_id, o.bezeichnung;
