-- Einzelaufträge über 1.500 € netto
CREATE OR REPLACE VIEW immo.v_instandhaltung_ausreisser AS
SELECT
    ih.auftrag_id,
    ih.objekt_id,
    o.bezeichnung,
    ih.kostenart,
    ih.netto,
    ih.brutto,
    CASE
        WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$' THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
        WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
        ELSE NULL
    END AS rechnungsdatum,
    CASE WHEN ih.netto > 1500 THEN true ELSE false END AS ausreisser
FROM immo.instandhaltung ih
JOIN immo.objekt o ON o.objekt_id = ih.objekt_id
WHERE ih.kostenart IN ('Instandhaltung', 'Instandsetzung')
ORDER BY ih.netto DESC;
