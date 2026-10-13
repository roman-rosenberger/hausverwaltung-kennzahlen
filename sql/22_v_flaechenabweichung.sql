-- Stammdatenfläche gegen Summe der Einheitenflächen
CREATE OR REPLACE VIEW immo.v_flaechenabweichung AS
SELECT
    o.objekt_id,
    o.bezeichnung,
    o.wohnflaeche_gesamt_qm AS flaeche_stammdaten,
    ROUND(SUM(e.flaeche_qm)::numeric, 2) AS flaeche_summe_einheiten,
    ROUND((o.wohnflaeche_gesamt_qm - SUM(e.flaeche_qm))::numeric, 2) AS abweichung_qm,
    ROUND(
        ((o.wohnflaeche_gesamt_qm - SUM(e.flaeche_qm)) * 100.0 / NULLIF(o.wohnflaeche_gesamt_qm, 0))::numeric, 2
    ) AS abweichung_pct
FROM immo.objekt o
JOIN immo.einheit e ON e.objekt_id = o.objekt_id
WHERE e.nutzungsart = 'Wohnen'
GROUP BY o.objekt_id, o.bezeichnung, o.wohnflaeche_gesamt_qm
ORDER BY abweichung_pct DESC;
