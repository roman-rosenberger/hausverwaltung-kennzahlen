-- Kontrollwerte auf dem synthetischen Testbestand
-- Stichtag 31.08.2026, Karenz 5 Tage (Standard aus 00_parameter.sql)
-- Jede Zeile soll den Sollwert in der Spalte "soll" zeigen.

SELECT 'Objekte'                    AS kennzahl, COUNT(*)::numeric AS ist, 8        AS soll FROM immo.objekt
UNION ALL SELECT 'Einheiten gesamt',          COUNT(*), 205   FROM immo.einheit
UNION ALL SELECT 'Wohneinheiten',             COUNT(*), 170   FROM immo.einheit WHERE nutzungsart = 'Wohnen'
UNION ALL SELECT 'Offene Forderungen gesamt (EUR)', ROUND(SUM(offen), 0), 72687 FROM immo.v_forderungen_aging
UNION ALL SELECT 'Offene Forderungen Wohnen (EUR)', ROUND(SUM(offen), 0), 61747 FROM immo.v_forderungen_aging WHERE nutzungsart = 'Wohnen'
UNION ALL SELECT 'Offene Forderungen Gewerbe (EUR)', ROUND(SUM(offen), 0), 10940 FROM immo.v_forderungen_aging WHERE nutzungsart = 'Gewerbe'
UNION ALL SELECT 'Klärfälle Anzahl',          COUNT(*), 10    FROM immo.v_klaerfaelle
UNION ALL SELECT 'Klärfälle Betrag (EUR)',    ROUND(SUM(betrag), 0), 5843 FROM immo.v_klaerfaelle
UNION ALL SELECT 'Entgangene Miete wirtschaftlich (EUR/Monat)', ROUND(SUM(entgangene_miete), 0), 2547 FROM immo.v_leerstand_wirtschaftlich
UNION ALL SELECT 'NK-Gutschriften (EUR)',     ROUND(SUM(betrag_gutschriften), 0), -94986 FROM immo.v_nk_gutschriften;

-- Zusätzliche Prüfung nach dem Fix von v_leerstand:
-- Die wirtschaftliche Quote muss in beiden Views identisch sein.
SELECT a.objekt_id,
       a.quote_wirtschaftlich_pct AS v_leerstand,
       b.quote_wirtschaftlich_pct AS v_leerstand_wirtschaftlich
FROM immo.v_leerstand a
JOIN immo.v_leerstand_wirtschaftlich b USING (objekt_id)
WHERE a.quote_wirtschaftlich_pct IS DISTINCT FROM b.quote_wirtschaftlich_pct;
-- Erwartet: keine Zeile.

-- Zusätzliche Prüfung Fläche: Summe der Flächen je Objekt gegen direkte Summe
SELECT o.objekt_id, l.flaeche_gesamt_qm,
       (SELECT ROUND(SUM(e.flaeche_qm)::numeric, 2) FROM immo.einheit e
        WHERE e.objekt_id = o.objekt_id AND e.nutzungsart = 'Wohnen') AS flaeche_direkt
FROM immo.objekt o JOIN immo.v_leerstand l USING (objekt_id)
WHERE l.flaeche_gesamt_qm IS DISTINCT FROM
      (SELECT ROUND(SUM(e.flaeche_qm)::numeric, 2) FROM immo.einheit e
       WHERE e.objekt_id = o.objekt_id AND e.nutzungsart = 'Wohnen');
-- Erwartet: keine Zeile.
