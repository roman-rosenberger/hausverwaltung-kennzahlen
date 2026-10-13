-- Gesamtübersicht je Objekt (Vorjahr = Stichtagsjahr minus 1)
CREATE OR REPLACE VIEW immo.v_auffaelligkeiten AS
SELECT
    o.objekt_id,
    o.bezeichnung,
    ls.quote_einheiten_pct AS leerstand_pct,
    ls.entgangene_miete,
    sa.einheiten_sanierung,
    sa.entgangene_miete_monat AS entgangene_miete_sanierung,
    fl.fluktuationsrate_pct AS fluktuation_2025_pct,
    COALESCE(fa.forderungen_gesamt, 0) AS forderungen_gesamt,
    COALESCE(fa.forderungen_ueber_90, 0) AS forderungen_ueber_90,
    ih.euro_pro_qm AS instandhaltung_eur_qm_2025,
    mk.markt_abweichung_pct,
    COALESCE(lw.quote_wirtschaftlich_pct, 0) AS leerstand_wirtschaftlich_pct,
    ib.euro_pro_qm_benchmark AS instandhaltung_benchmark_eur_qm_2025,
    ib.kosten_modernisierung AS modernisierung_2025,
    COALESCE(dk.anzahl_hinweise, 0) AS datenhinweise,
    COALESCE(nk.anzahl_gutschriften, 0) AS nk_gutschriften_anzahl,
    COALESCE(nk.betrag_gutschriften, 0) AS nk_gutschriften_betrag
FROM immo.objekt o
LEFT JOIN immo.v_leerstand ls ON ls.objekt_id = o.objekt_id
LEFT JOIN immo.v_leerstand_sanierung sa ON sa.objekt_id = o.objekt_id
LEFT JOIN immo.v_fluktuation fl ON fl.objekt_id = o.objekt_id AND fl.jahr = EXTRACT(YEAR FROM immo.stichtag())::int - 1
LEFT JOIN (
    SELECT fa.objekt_id,
           ROUND(SUM(fa.offen)::numeric, 2) AS forderungen_gesamt,
           ROUND(SUM(CASE WHEN fa.aging_bucket = 'über 90 Tage' THEN fa.offen ELSE 0 END)::numeric, 2) AS forderungen_ueber_90
    FROM immo.v_forderungen_aging fa
    JOIN immo.einheit e ON e.einheit_id = fa.einheit_id
    WHERE e.nutzungsart = 'Wohnen'
    GROUP BY fa.objekt_id
) fa ON fa.objekt_id = o.objekt_id
LEFT JOIN (
    SELECT objekt_id, euro_pro_qm
    FROM immo.v_instandhaltung
    WHERE jahr = EXTRACT(YEAR FROM immo.stichtag())::int - 1 AND kostenart = 'Instandsetzung'
) ih ON ih.objekt_id = o.objekt_id
LEFT JOIN (
    SELECT objekt_id, ROUND(AVG(abweichung_pct)::numeric, 2) AS markt_abweichung_pct
    FROM immo.v_marktvergleich
    WHERE nutzungsart = 'Wohnen'
    GROUP BY objekt_id
) mk ON mk.objekt_id = o.objekt_id
LEFT JOIN immo.v_leerstand_wirtschaftlich lw ON lw.objekt_id = o.objekt_id
LEFT JOIN immo.v_instandhaltung_benchmark ib ON ib.objekt_id = o.objekt_id AND ib.jahr = EXTRACT(YEAR FROM immo.stichtag())::int - 1
LEFT JOIN (
    SELECT objekt_id, COUNT(*) AS anzahl_hinweise
    FROM immo.v_datenkonsistenz
    WHERE objekt_id IS NOT NULL
    GROUP BY objekt_id
) dk ON dk.objekt_id = o.objekt_id
LEFT JOIN immo.v_nk_gutschriften nk ON nk.objekt_id = o.objekt_id
ORDER BY forderungen_gesamt DESC NULLS LAST;
