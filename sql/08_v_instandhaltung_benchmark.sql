-- Instandhaltung + Instandsetzung €/m² gegen VDIV-Richtwert, Modernisierung separat
CREATE OR REPLACE VIEW immo.v_instandhaltung_benchmark AS
SELECT
    objekt_id,
    bezeichnung,
    jahr::int AS jahr,
    (jahr::int = 2023) AS rumpfjahr,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart IN ('Instandhaltung','Instandsetzung'))::numeric, 2) AS kosten_benchmark,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart = 'Instandhaltung')::numeric, 2) AS kosten_instandhaltung,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart = 'Instandsetzung')::numeric, 2) AS kosten_instandsetzung,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart = 'Modernisierung')::numeric, 2) AS kosten_modernisierung,
    MAX(wohnflaeche_gesamt_qm) AS wohnflaeche_gesamt_qm,
    ROUND((SUM(kosten_netto) FILTER (WHERE kostenart IN ('Instandhaltung','Instandsetzung'))
           / NULLIF(MAX(wohnflaeche_gesamt_qm),0))::numeric, 2) AS euro_pro_qm_benchmark,
    (SUM(kosten_netto) FILTER (WHERE kostenart IN ('Instandhaltung','Instandsetzung'))
           / NULLIF(MAX(wohnflaeche_gesamt_qm),0)) > 15 AS ueber_richtwert
FROM immo.v_instandhaltung
GROUP BY objekt_id, bezeichnung, jahr::int;
