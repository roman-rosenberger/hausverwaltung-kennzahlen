-- Offene Posten nach Karenz mit Aging-Klassen, ohne Storno
CREATE OR REPLACE VIEW immo.v_forderungen_aging AS
WITH karenz_effektiv AS (
    SELECT o.objekt_id,
        COALESCE(
            (SELECT p.karenztage FROM immo.parameter_karenz p
             WHERE p.objekt_id = o.objekt_id ORDER BY p.gueltig_ab DESC LIMIT 1),
            (SELECT p.karenztage FROM immo.parameter_karenz p
             WHERE p.objekt_id IS NULL ORDER BY p.gueltig_ab DESC LIMIT 1),
            5
        ) AS karenztage
    FROM immo.objekt o
)
SELECT
    s.vertrag_id,
    mv.einheit_id,
    e.objekt_id,
    o.bezeichnung AS objekt_bezeichnung,
    s.sollstellung_id,
    s.periode,
    s.faelligkeit,
    s."position",
    s.betrag AS soll,
    COALESCE(zz_sum.gezahlt, 0::numeric) AS gezahlt,
    s.betrag - COALESCE(zz_sum.gezahlt, 0::numeric) AS offen,
    ke.karenztage,
    (immo.stichtag() - s.faelligkeit - ke.karenztage) AS tage_ueberfaellig,
    CASE
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 0 THEN 'nicht überfällig'
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 30 THEN '01-30 Tage'
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 60 THEN '31-60 Tage'
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 90 THEN '61-90 Tage'
        ELSE 'über 90 Tage'
    END AS aging_bucket,
    e.nutzungsart
FROM immo.sollstellung s
JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
JOIN immo.einheit e       ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o        ON o.objekt_id = e.objekt_id
JOIN karenz_effektiv ke   ON ke.objekt_id = o.objekt_id
LEFT JOIN (
    SELECT sollstellung_id, SUM(betrag) AS gezahlt
    FROM immo.zahlungszuordnung GROUP BY sollstellung_id
) zz_sum ON zz_sum.sollstellung_id = s.sollstellung_id
WHERE s.storno = false
AND s.betrag > 0
AND (s.betrag - COALESCE(zz_sum.gezahlt, 0::numeric)) > 0::numeric;
