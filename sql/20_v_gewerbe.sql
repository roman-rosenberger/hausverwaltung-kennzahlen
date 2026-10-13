-- Gewerbe: Nettomiete, Indexpotenzial, Befristung
CREATE OR REPLACE VIEW immo.v_gewerbe AS
SELECT
    mv.vertrag_id,
    mv.einheit_id,
    e.objekt_id,
    o.bezeichnung,
    e.flaeche_qm,
    mv.mietart,
    mv.ust_option,
    mv.vertragsstatus,
    mv.vertragsbeginn,
    mv.vertragsende,
    mv.befristet_bis,
    -- Aktuelle Kaltmiete
    COALESCE(
        (SELECT ma.kaltmiete_neu
         FROM immo.mietanpassung ma
         WHERE ma.vertrag_id = mv.vertrag_id
         AND ma.gueltig_ab <= immo.stichtag()
         ORDER BY ma.gueltig_ab DESC
         LIMIT 1),
        mv.kaltmiete
    ) AS aktuelle_kaltmiete,
    -- Nettokaltmiete
    CASE
        WHEN mv.ust_option = true THEN
            ROUND(COALESCE(
                (SELECT ma.kaltmiete_neu
                 FROM immo.mietanpassung ma
                 WHERE ma.vertrag_id = mv.vertrag_id
                 AND ma.gueltig_ab <= immo.stichtag()
                 ORDER BY ma.gueltig_ab DESC
                 LIMIT 1),
                mv.kaltmiete
            ) / 1.19, 2)
        ELSE COALESCE(
                (SELECT ma.kaltmiete_neu
                 FROM immo.mietanpassung ma
                 WHERE ma.vertrag_id = mv.vertrag_id
                 AND ma.gueltig_ab <= immo.stichtag()
                 ORDER BY ma.gueltig_ab DESC
                 LIMIT 1),
                mv.kaltmiete
            )
    END AS nettokaltmiete,
    -- EUR/m netto
    CASE
        WHEN e.flaeche_qm > 0 THEN
            ROUND(CASE
                WHEN mv.ust_option = true THEN
                    COALESCE(
                        (SELECT ma.kaltmiete_neu
                         FROM immo.mietanpassung ma
                         WHERE ma.vertrag_id = mv.vertrag_id
                         AND ma.gueltig_ab <= immo.stichtag()
                         ORDER BY ma.gueltig_ab DESC
                         LIMIT 1),
                        mv.kaltmiete
                    ) / 1.19
                ELSE COALESCE(
                        (SELECT ma.kaltmiete_neu
                         FROM immo.mietanpassung ma
                         WHERE ma.vertrag_id = mv.vertrag_id
                         AND ma.gueltig_ab <= immo.stichtag()
                         ORDER BY ma.gueltig_ab DESC
                         LIMIT 1),
                        mv.kaltmiete
                    )
            END / e.flaeche_qm, 2)
        ELSE NULL
    END AS eur_pro_qm_netto,
    -- Letzte Anpassung
    (SELECT ma.gueltig_ab
     FROM immo.mietanpassung ma
     WHERE ma.vertrag_id = mv.vertrag_id
     ORDER BY ma.gueltig_ab DESC
     LIMIT 1) AS letzte_anpassung,
    -- VPI aktuell
    (SELECT v.indexwert FROM immo.vpi_index v
     WHERE v.monat = TO_CHAR(immo.stichtag(), 'YYYY-MM')) AS vpi_aktuell,
    -- VPI bei letzter Anpassung
    (SELECT v.indexwert
     FROM immo.vpi_index v
     WHERE v.monat = TO_CHAR(
         (SELECT ma.gueltig_ab FROM immo.mietanpassung ma
          WHERE ma.vertrag_id = mv.vertrag_id
          ORDER BY ma.gueltig_ab DESC LIMIT 1),
         'YYYY-MM')) AS vpi_bei_letzter_anpassung,
    -- Indexanpassungspotenzial in Prozent
    CASE
        WHEN (SELECT v.indexwert FROM immo.vpi_index v
              WHERE v.monat = TO_CHAR(
                  (SELECT ma.gueltig_ab FROM immo.mietanpassung ma
                   WHERE ma.vertrag_id = mv.vertrag_id
                   ORDER BY ma.gueltig_ab DESC LIMIT 1),
                  'YYYY-MM')) IS NOT NULL
        THEN ROUND(
            ((SELECT v.indexwert FROM immo.vpi_index v
              WHERE v.monat = TO_CHAR(immo.stichtag(), 'YYYY-MM')) /
             (SELECT v.indexwert FROM immo.vpi_index v
              WHERE v.monat = TO_CHAR(
                  (SELECT ma.gueltig_ab FROM immo.mietanpassung ma
                   WHERE ma.vertrag_id = mv.vertrag_id
                   ORDER BY ma.gueltig_ab DESC LIMIT 1),
                  'YYYY-MM')) - 1) * 100, 2)
        ELSE NULL
    END AS index_potenzial_pct,
    -- Vertrag abgelaufen?
    CASE
        WHEN mv.befristet_bis < immo.stichtag() THEN true
        ELSE false
    END AS befristung_abgelaufen
FROM immo.mietvertrag mv
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE e.nutzungsart = 'Gewerbe'
AND mv.vertragsstatus = 'aktiv';
