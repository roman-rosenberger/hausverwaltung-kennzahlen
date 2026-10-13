-- Nicht zugeordnete Zahlungseingänge. Ohne Verwendungszweck (kann in Echtdaten Namen enthalten)
CREATE OR REPLACE VIEW immo.v_klaerfaelle AS
SELECT
    z.zahlung_id,
    z.buchungsdatum,
    z.betrag,
    z.zahlungsart,
    z.vertrag_id,
    CASE 
        WHEN z.vertrag_id IS NULL THEN 'Ohne Vertragszuordnung'
        ELSE 'Mit Vertrag, aber ohne Sollstellungszuordnung'
    END AS klaerfall_typ
FROM immo.zahlungseingang z
WHERE NOT EXISTS (
    SELECT 1 
    FROM immo.zahlungszuordnung zz 
    WHERE zz.zahlung_id = z.zahlung_id
)
AND z.betrag > 0;
