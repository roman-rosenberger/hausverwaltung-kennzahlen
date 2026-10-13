-- Datenqualitäts-Hinweise
CREATE OR REPLACE VIEW immo.v_datenkonsistenz AS
SELECT e.objekt_id::text AS objekt_id, 'Unvollständige Storno-Kette'::text AS kategorie,
       s.vertrag_id::text AS referenz, ('Periode ' || s.periode)::text AS beschreibung, s.betrag::numeric AS betrag
FROM immo.sollstellung s
JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
WHERE s.storno = true
  AND NOT EXISTS (SELECT 1 FROM immo.sollstellung s2
                  WHERE s2.storno_ref = s.storno_ref AND s2.storno = false AND s2.betrag > 0)
UNION ALL
SELECT e.objekt_id::text, 'Aktiver Vertrag bei offenem Leerstand',
       mv.vertrag_id::text, ('Leerstand ' || l.leerstand_id || ' seit ' || l.von)::text, NULL::numeric
FROM immo.einheit e
JOIN immo.mietvertrag mv ON mv.einheit_id = e.einheit_id AND mv.vertragsstatus = 'aktiv'
JOIN immo.leerstand l ON l.einheit_id = e.einheit_id AND l.bis IS NULL
UNION ALL
SELECT e.objekt_id::text, 'Fläche fehlt oder unplausibel',
       e.einheit_id::text, ('flaeche_qm = ' || COALESCE(e.flaeche_qm::text, 'NULL'))::text, NULL::numeric
FROM immo.einheit e
WHERE e.nutzungsart = 'Wohnen' AND (e.flaeche_qm IS NULL OR e.flaeche_qm < 15)
UNION ALL
SELECT e.objekt_id::text, 'Klärfall Zahlung',
       k.zahlung_id::text, k.klaerfall_typ::text, k.betrag::numeric
FROM immo.v_klaerfaelle k
LEFT JOIN immo.mietvertrag mv ON mv.vertrag_id = k.vertrag_id
LEFT JOIN immo.einheit e ON e.einheit_id = mv.einheit_id;
