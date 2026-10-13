-- Ist-Miete gegen Marktmiete je Einheit (Wohnen und Gewerbe), Marktjahr = Stichtagsjahr
CREATE OR REPLACE VIEW immo.v_marktvergleich AS
 SELECT am.objekt_id,
    am.einheit_id,
    am.vertrag_id,
    am.nutzungsart,
    am.flaeche_qm,
    am.aktuelle_kaltmiete,
    round(am.aktuelle_kaltmiete / NULLIF(am.flaeche_qm, 0::numeric), 2) AS ist_eur_qm,
    mm.median_eur_qm AS markt_eur_qm,
    mm.spanne_unten,
    mm.spanne_oben,
    round(am.aktuelle_kaltmiete / NULLIF(am.flaeche_qm, 0::numeric) - mm.median_eur_qm, 2) AS abweichung_eur_qm,
    round((am.aktuelle_kaltmiete / NULLIF(am.flaeche_qm, 0::numeric) - mm.median_eur_qm) * 100.0 / NULLIF(mm.median_eur_qm, 0::numeric)::numeric, 2) AS abweichung_pct
   FROM immo.v_aktuelle_miete am
     JOIN immo.objekt o ON o.objekt_id = am.objekt_id
     JOIN immo.marktmiete mm ON mm.plz = o.plz AND mm.lagequalitaet = o.lagequalitaet AND mm.jahr = EXTRACT(YEAR FROM immo.stichtag())::int AND mm.nutzungsart = am.nutzungsart
  WHERE am.vertragsstatus = 'aktiv'::text AND am.flaeche_qm > 15::numeric;
