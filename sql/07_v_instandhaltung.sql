-- Instandhaltungskosten je Objekt, Jahr und Kostenart
CREATE OR REPLACE VIEW immo.v_instandhaltung AS
SELECT
    ih.objekt_id,
    o.bezeichnung,
    EXTRACT(YEAR FROM
        CASE
            WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$'
                THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
            WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$'
                THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
            ELSE NULL
        END
    ) AS jahr,
    ih.kostenart,
    COUNT(*) AS anzahl_auftraege,
    ROUND(SUM(ih.netto)::numeric, 2) AS kosten_netto,
    o.wohnflaeche_gesamt_qm,
    ROUND(
        SUM(ih.netto) / NULLIF(o.wohnflaeche_gesamt_qm, 0)::numeric, 2
    ) AS euro_pro_qm
FROM immo.instandhaltung ih
JOIN immo.objekt o ON o.objekt_id = ih.objekt_id
WHERE ih.rechnungsdatum IS NOT NULL
GROUP BY ih.objekt_id, o.bezeichnung, o.wohnflaeche_gesamt_qm,
    EXTRACT(YEAR FROM
        CASE
            WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$'
                THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
            WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$'
                THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
            ELSE NULL
        END
    ), ih.kostenart
ORDER BY ih.objekt_id, jahr, ih.kostenart;
