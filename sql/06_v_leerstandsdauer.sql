-- Leerstandsdauer zwischen zwei Mietern
CREATE OR REPLACE VIEW immo.v_leerstandsdauer AS
SELECT
    e.objekt_id,
    o.bezeichnung,
    e.einheit_id,
    mv1.vertrag_id AS vertrag_alt,
    mv1.vertragsende AS auszug,
    mv2.vertrag_id AS vertrag_neu,
    mv2.vertragsbeginn AS einzug,
    mv2.vertragsbeginn - mv1.vertragsende AS tage_leer
FROM immo.mietvertrag mv1
JOIN immo.einheit e ON e.einheit_id = mv1.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
JOIN immo.mietvertrag mv2 
    ON mv2.einheit_id = mv1.einheit_id
    AND mv2.vertragsbeginn > mv1.vertragsende
    AND mv2.vertragsbeginn = (
        SELECT MIN(mv3.vertragsbeginn)
        FROM immo.mietvertrag mv3
        WHERE mv3.einheit_id = mv1.einheit_id
        AND mv3.vertragsbeginn > mv1.vertragsende
    )
WHERE mv1.vertragsende IS NOT NULL
AND e.nutzungsart = 'Wohnen';
