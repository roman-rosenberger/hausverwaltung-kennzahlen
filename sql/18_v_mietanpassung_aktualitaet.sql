-- Monate seit letzter Mietanpassung gegen Soll-Zyklus
CREATE OR REPLACE VIEW immo.v_mietanpassung_aktualitaet AS
WITH letzte_anpassung AS (
    SELECT DISTINCT ON (ma.vertrag_id)
        ma.vertrag_id,
        ma.gueltig_ab AS letzte_anpassung_am
    FROM immo.mietanpassung ma
    ORDER BY ma.vertrag_id, ma.gueltig_ab DESC
),
basis AS (
    SELECT
        mv.vertrag_id,
        e.objekt_id,
        mv.vertragsbeginn,
        COALESCE(la.letzte_anpassung_am, mv.vertragsbeginn) AS bezugsdatum,
        (immo.stichtag() - COALESCE(la.letzte_anpassung_am, mv.vertragsbeginn)) / 30.44 AS monate_seit_anpassung
    FROM immo.mietvertrag mv
    JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
    LEFT JOIN letzte_anpassung la ON la.vertrag_id = mv.vertrag_id
    WHERE mv.vertragsstatus = 'aktiv'
      AND e.nutzungsart = 'Wohnen'
)
SELECT
    b.objekt_id,
    COUNT(*) AS anzahl_vertraege,
    ROUND(AVG(b.monate_seit_anpassung)::numeric, 1) AS oe_monate_seit_anpassung,
    pm.soll_zyklus_monate,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE b.monate_seit_anpassung > pm.soll_zyklus_monate) / COUNT(*), 1
    ) AS anteil_ueberfaellig_pct
FROM basis b
CROSS JOIN (
    SELECT soll_zyklus_monate FROM immo.parameter_mietzyklus
    ORDER BY gueltig_ab DESC LIMIT 1
) pm
GROUP BY b.objekt_id, pm.soll_zyklus_monate
ORDER BY oe_monate_seit_anpassung DESC;
