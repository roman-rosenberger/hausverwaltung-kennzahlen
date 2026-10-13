-- Aktuelle Kaltmiete, NK und HK je Vertrag zum Stichtag
CREATE OR REPLACE VIEW immo.v_aktuelle_miete AS
SELECT 
    mv.vertrag_id,
    mv.einheit_id,
    e.objekt_id,
    e.nutzungsart,
    e.flaeche_qm,
    mv.kaltmiete AS anfangsmiete,
    COALESCE(
        (SELECT ma.kaltmiete_neu 
         FROM immo.mietanpassung ma
         WHERE ma.vertrag_id = mv.vertrag_id
         AND ma.gueltig_ab <= immo.stichtag()
         ORDER BY ma.gueltig_ab DESC
         LIMIT 1),
        mv.kaltmiete
    ) AS aktuelle_kaltmiete,
    mv.nk_vorauszahlung AS anfangs_nk,
    COALESCE(
        (SELECT vz.nk_neu
         FROM immo.vz_anpassung vz
         WHERE vz.vertrag_id = mv.vertrag_id
         AND vz.gueltig_ab <= immo.stichtag()
         ORDER BY vz.gueltig_ab DESC
         LIMIT 1),
        mv.nk_vorauszahlung
    ) AS aktuelle_nk,
    mv.hk_vorauszahlung AS anfangs_hk,
    COALESCE(
        (SELECT vz.hk_neu
         FROM immo.vz_anpassung vz
         WHERE vz.vertrag_id = mv.vertrag_id
         AND vz.gueltig_ab <= immo.stichtag()
         ORDER BY vz.gueltig_ab DESC
         LIMIT 1),
        mv.hk_vorauszahlung
    ) AS aktuelle_hk,
    mv.ust_option,
    mv.vertragsstatus,
    mv.mietart
FROM immo.mietvertrag mv
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id;
