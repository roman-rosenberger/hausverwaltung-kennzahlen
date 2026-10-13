-- Stellplätze und Garagen
CREATE OR REPLACE VIEW immo.v_stellplaetze AS
SELECT
    mv.vertrag_id,
    mv.einheit_id,
    e.objekt_id,
    o.bezeichnung,
    e.nutzungsart,
    e.flaeche_qm,
    mv.vertragsstatus,
    mv.vertragsbeginn,
    mv.vertragsende,
    COALESCE(
        (SELECT ma.kaltmiete_neu
         FROM immo.mietanpassung ma
         WHERE ma.vertrag_id = mv.vertrag_id
         AND ma.gueltig_ab <= immo.stichtag()
         ORDER BY ma.gueltig_ab DESC
         LIMIT 1),
        mv.kaltmiete
    ) AS aktuelle_miete,
    -- Leerstand
    CASE
        WHEN EXISTS (
            SELECT 1 FROM immo.leerstand l
            WHERE l.einheit_id = e.einheit_id
            AND l.von <= immo.stichtag()
            AND (l.bis IS NULL OR l.bis >= immo.stichtag())
        ) THEN true
        ELSE false
    END AS leer
FROM immo.mietvertrag mv
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE e.nutzungsart IN ('Stellplatz', 'Garage')
AND mv.vertragsstatus = 'aktiv'
ORDER BY e.nutzungsart, e.objekt_id;
