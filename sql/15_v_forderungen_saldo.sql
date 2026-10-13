-- Forderungen brutto, NK-Gutschriften und Saldo je Objekt
CREATE OR REPLACE VIEW immo.v_forderungen_saldo AS
WITH pos AS (
    SELECT objekt_id, SUM(offen) AS forderungen
    FROM immo.v_forderungen_aging
    GROUP BY objekt_id
),
gut AS (
    SELECT e.objekt_id,
           SUM(s.betrag - COALESCE(zz.gezahlt, 0)) AS gutschriften,
           COUNT(*) AS anzahl_gutschriften
    FROM immo.sollstellung s
    JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
    JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
    LEFT JOIN (SELECT sollstellung_id, SUM(betrag) AS gezahlt
               FROM immo.zahlungszuordnung GROUP BY sollstellung_id) zz
           ON zz.sollstellung_id = s.sollstellung_id
    WHERE s.storno = false AND s.betrag < 0 AND s."position" = 'NK-Nachforderung'
    GROUP BY e.objekt_id
)
SELECT
    o.objekt_id,
    o.bezeichnung,
    ROUND(COALESCE(p.forderungen, 0)::numeric, 2) AS forderungen_brutto,
    ROUND(COALESCE(g.gutschriften, 0)::numeric, 2) AS nk_gutschriften,
    ROUND((COALESCE(p.forderungen, 0) + COALESCE(g.gutschriften, 0))::numeric, 2) AS saldo_netto,
    COALESCE(g.anzahl_gutschriften, 0) AS anzahl_gutschriften
FROM immo.objekt o
LEFT JOIN pos p ON p.objekt_id = o.objekt_id
LEFT JOIN gut g ON g.objekt_id = o.objekt_id;
