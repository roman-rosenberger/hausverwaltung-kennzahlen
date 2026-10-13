-- Kontrollwerte je Objekt (Testdatensatz, Stichtag 2026-08-31)
-- Erwartet: KEINE Zeile. Jede Zeile = Abweichung vom Soll-Wert.
-- Nur gueltig fuer den mitgelieferten synthetischen Testbestand.
WITH soll(objekt_id, leerstand_pct, entgangene_miete, fluktuation_pct, forderungen_gesamt,
          forderungen_ueber_90, instandhaltung_eur_qm, leerstand_wirtschaftlich_pct,
          datenhinweise, nk_gutschriften_anzahl, nk_gutschriften_betrag) AS (
VALUES
 ('OBJ-01',  0.00,    0.00,  0.00,  1526.57,  1509.02, 11.10,  0.00, 0, 49, -16111.60),
 ('OBJ-02', 13.51, 1861.25, 35.14, 13225.98,  7944.93, 11.91, 12.22, 3, 79, -17345.28),
 ('OBJ-03',  0.00,    0.00,  7.14,  5235.36,  2375.00, 20.60,  0.00, 3, 46, -16209.62),
 ('OBJ-04',  0.00,    0.00,  0.00,    10.00,    10.00, 12.91,  0.00, 1, 12,  -4483.33),
 ('OBJ-05',  7.69,  686.00,  0.00,   188.50,    15.00,  4.62,  6.44, 1, 23,  -6724.98),
 ('OBJ-06',  0.00,    0.00,  8.33,  7112.21,  2950.00, 22.35,  0.00, 0, 58, -17325.76),
 ('OBJ-07',  0.00,    0.00, 15.15, 33048.36, 19643.50, 12.22,  0.00, 1, 70, -16161.32),
 ('OBJ-08',  0.00,    0.00,  9.09,  1400.00,  1322.00, 16.34,  0.00, 2,  9,   -624.52)
)
SELECT s.objekt_id, 'Abweichung' AS status,
       a.leerstand_pct, s.leerstand_pct AS soll_leerstand,
       a.forderungen_gesamt, s.forderungen_gesamt AS soll_forderungen,
       a.forderungen_ueber_90, s.forderungen_ueber_90 AS soll_ueber_90,
       a.nk_gutschriften_betrag, s.nk_gutschriften_betrag AS soll_nk
FROM soll s
LEFT JOIN immo.v_auffaelligkeiten a USING (objekt_id)
WHERE a.objekt_id IS NULL
   OR ROUND(a.leerstand_pct::numeric, 2)              IS DISTINCT FROM s.leerstand_pct
   OR ROUND(a.entgangene_miete::numeric, 2)           IS DISTINCT FROM s.entgangene_miete
   OR ROUND(a.fluktuation_2025_pct::numeric, 2)       IS DISTINCT FROM s.fluktuation_pct
   OR ROUND(a.forderungen_gesamt::numeric, 2)         IS DISTINCT FROM s.forderungen_gesamt
   OR ROUND(a.forderungen_ueber_90::numeric, 2)       IS DISTINCT FROM s.forderungen_ueber_90
   OR ROUND(a.instandhaltung_eur_qm_2025::numeric, 2) IS DISTINCT FROM s.instandhaltung_eur_qm
   OR ROUND(a.leerstand_wirtschaftlich_pct::numeric, 2) IS DISTINCT FROM s.leerstand_wirtschaftlich_pct
   OR a.datenhinweise                                 IS DISTINCT FROM s.datenhinweise
   OR a.nk_gutschriften_anzahl                        IS DISTINCT FROM s.nk_gutschriften_anzahl
   OR ROUND(a.nk_gutschriften_betrag::numeric, 2)     IS DISTINCT FROM s.nk_gutschriften_betrag;
