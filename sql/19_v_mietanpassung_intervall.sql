-- Gemessener Abstand zwischen Mietanpassungen
CREATE OR REPLACE VIEW immo.v_mietanpassung_intervall AS
WITH anpassungen_sortiert AS (
    SELECT
        ma.vertrag_id,
        ma.gueltig_ab,
        LAG(ma.gueltig_ab) OVER (PARTITION BY ma.vertrag_id ORDER BY ma.gueltig_ab) AS vorherige_anpassung
    FROM immo.mietanpassung ma
),
intervalle AS (
    SELECT
        a.vertrag_id,
        e.objekt_id,
        (a.gueltig_ab - a.vorherige_anpassung) / 30.44 AS monate_zwischen_anpassungen
    FROM anpassungen_sortiert a
    JOIN immo.mietvertrag mv ON mv.vertrag_id = a.vertrag_id
    JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
    WHERE a.vorherige_anpassung IS NOT NULL
      AND e.nutzungsart = 'Wohnen'
)
SELECT
    objekt_id,
    COUNT(*) AS anzahl_intervalle,
    ROUND(AVG(monate_zwischen_anpassungen)::numeric, 1) AS oe_monate_zwischen_anpassungen,
    ROUND((AVG(monate_zwischen_anpassungen) / 12)::numeric, 2) AS oe_jahre_zwischen_anpassungen
FROM intervalle
GROUP BY objekt_id
ORDER BY oe_monate_zwischen_anpassungen;
