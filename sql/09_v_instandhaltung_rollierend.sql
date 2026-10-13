-- Rollierende 12-Monats-Summe je Objekt
CREATE OR REPLACE VIEW immo.v_instandhaltung_rollierend AS
WITH monatswerte AS (
    SELECT
        ih.objekt_id,
        DATE_TRUNC('month', 
            CASE
                WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$' THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
                WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
                ELSE NULL
            END
        )::date AS monat,
        SUM(ih.netto) AS kosten_netto_monat
    FROM immo.instandhaltung ih
    WHERE ih.kostenart IN ('Instandhaltung', 'Instandsetzung')
    AND ih.rechnungsdatum IS NOT NULL
    GROUP BY ih.objekt_id, 
        DATE_TRUNC('month', 
            CASE
                WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$' THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
                WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
                ELSE NULL
            END
        )
),
alle_monate AS (
    SELECT DISTINCT objekt_id, monat FROM monatswerte
)
SELECT
    m.objekt_id,
    o.bezeichnung,
    m.monat,
    ROUND(
        SUM(mw.kosten_netto_monat) FILTER (
            WHERE mw.monat BETWEEN m.monat - INTERVAL '11 months' AND m.monat
        )::numeric, 2
    ) AS kosten_rollierend_12m,
    o.wohnflaeche_gesamt_qm,
    ROUND(
        (SUM(mw.kosten_netto_monat) FILTER (
            WHERE mw.monat BETWEEN m.monat - INTERVAL '11 months' AND m.monat
        ) / NULLIF(o.wohnflaeche_gesamt_qm, 0))::numeric, 2
    ) AS euro_pro_qm_rollierend_12m
FROM alle_monate m
JOIN immo.objekt o ON o.objekt_id = m.objekt_id
LEFT JOIN monatswerte mw ON mw.objekt_id = m.objekt_id
GROUP BY m.objekt_id, o.bezeichnung, m.monat, o.wohnflaeche_gesamt_qm
ORDER BY m.objekt_id, m.monat;
