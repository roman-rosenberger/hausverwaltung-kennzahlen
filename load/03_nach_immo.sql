-- Übernahme von stg nach immo: Dezimalkomma, ja/nein und leere Felder werden umgewandelt.
-- ACHTUNG: leert zuerst die 18 Tabellen in immo (in einer Transaktion). Parameter und Views bleiben unberührt.

BEGIN;

DELETE FROM immo.vpi_index;
DELETE FROM immo.marktmiete;
DELETE FROM immo.betriebskosten;
DELETE FROM immo.instandhaltung;
DELETE FROM immo.zahlungszuordnung;
DELETE FROM immo.zahlungseingang;
DELETE FROM immo.sollstellung;
DELETE FROM immo.leerstand;
DELETE FROM immo.nk_abrechnung;
DELETE FROM immo.mahnung;
DELETE FROM immo.kaution;
DELETE FROM immo.vz_anpassung;
DELETE FROM immo.mietanpassung;
DELETE FROM immo.mietvertrag;
DELETE FROM immo.dienstleister;
DELETE FROM immo.mietpartei;
DELETE FROM immo.einheit;
DELETE FROM immo.objekt;

INSERT INTO immo.objekt (objekt_id, bezeichnung, strasse, plz, ort, ortsteil, baujahr, letzte_modernisierung, nutzungsart, grundstuecksflaeche_qm, wohnflaeche_gesamt_qm, anzahl_einheiten, lagequalitaet, heizungsart, heizung_baujahr)
SELECT objekt_id,
       bezeichnung,
       strasse,
       btrim(plz)::char(5),
       ort,
       ortsteil,
       replace(btrim(baujahr), ',', '.')::smallint,
       NULLIF(replace(btrim(letzte_modernisierung), ',', '.'), '')::smallint,
       nutzungsart,
       NULLIF(replace(btrim(grundstuecksflaeche_qm), ',', '.'), '')::numeric(10,2),
       NULLIF(replace(btrim(wohnflaeche_gesamt_qm), ',', '.'), '')::numeric(10,2),
       replace(btrim(anzahl_einheiten), ',', '.')::smallint,
       lagequalitaet,
       heizungsart,
       NULLIF(replace(btrim(heizung_baujahr), ',', '.'), '')::smallint
FROM stg.objekt;

INSERT INTO immo.einheit (einheit_id, objekt_id, bezeichnung, nutzungsart, flaeche_qm, zimmer, etage, balkon, ausstattungsklasse)
SELECT einheit_id,
       objekt_id,
       bezeichnung,
       nutzungsart,
       NULLIF(replace(btrim(flaeche_qm), ',', '.'), '')::numeric(8,2),
       NULLIF(replace(btrim(zimmer), ',', '.'), '')::numeric(3,1),
       NULLIF(replace(btrim(etage), ',', '.'), '')::smallint,
       CASE lower(btrim(balkon)) WHEN 'ja' THEN true WHEN 'nein' THEN false END,
       NULLIF(ausstattungsklasse, '')
FROM stg.einheit;

INSERT INTO immo.mietpartei (mietpartei_id, typ, anrede, name, vorname, telefon, email, personen_haushalt)
SELECT mietpartei_id,
       typ,
       NULLIF(anrede, ''),
       name,
       NULLIF(vorname, ''),
       NULLIF(telefon, ''),
       NULLIF(email, ''),
       NULLIF(replace(btrim(personen_haushalt), ',', '.'), '')::smallint
FROM stg.mietpartei;

INSERT INTO immo.dienstleister (dienstleister_id, name, gewerk, rahmenvertrag)
SELECT dienstleister_id,
       name,
       gewerk,
       CASE lower(btrim(rahmenvertrag)) WHEN 'ja' THEN true WHEN 'nein' THEN false END
FROM stg.dienstleister;

INSERT INTO immo.mietvertrag (vertrag_id, einheit_id, mietpartei_id, vertragsbeginn, vertragsende, befristet_bis, kuendigung_am, kuendigung_durch, auszugsgrund, kaltmiete, nk_vorauszahlung, hk_vorauszahlung, mietart, ust_option, vertragsstatus)
SELECT vertrag_id,
       einheit_id,
       mietpartei_id,
       btrim(vertragsbeginn)::date,
       NULLIF(btrim(vertragsende), '')::date,
       NULLIF(btrim(befristet_bis), '')::date,
       NULLIF(btrim(kuendigung_am), '')::date,
       NULLIF(kuendigung_durch, ''),
       NULLIF(auszugsgrund, ''),
       replace(btrim(kaltmiete), ',', '.')::numeric(10,2),
       replace(btrim(nk_vorauszahlung), ',', '.')::numeric(10,2),
       replace(btrim(hk_vorauszahlung), ',', '.')::numeric(10,2),
       mietart,
       CASE lower(btrim(ust_option)) WHEN 'ja' THEN true WHEN 'nein' THEN false END,
       vertragsstatus
FROM stg.mietvertrag;

INSERT INTO immo.mietanpassung (anpassung_id, vertrag_id, gueltig_ab, kaltmiete_alt, kaltmiete_neu, grund)
SELECT anpassung_id,
       vertrag_id,
       btrim(gueltig_ab)::date,
       replace(btrim(kaltmiete_alt), ',', '.')::numeric(10,2),
       replace(btrim(kaltmiete_neu), ',', '.')::numeric(10,2),
       grund
FROM stg.mietanpassung;

INSERT INTO immo.vz_anpassung (anpassung_id, vertrag_id, gueltig_ab, nk_alt, nk_neu, hk_alt, hk_neu, grund)
SELECT anpassung_id,
       vertrag_id,
       btrim(gueltig_ab)::date,
       replace(btrim(nk_alt), ',', '.')::numeric(10,2),
       replace(btrim(nk_neu), ',', '.')::numeric(10,2),
       replace(btrim(hk_alt), ',', '.')::numeric(10,2),
       replace(btrim(hk_neu), ',', '.')::numeric(10,2),
       grund
FROM stg.vz_anpassung;

INSERT INTO immo.kaution (vertrag_id, soll, erhalten, zahlungsart, anlageart, rueckzahlung_am, rueckzahlung_betrag)
SELECT vertrag_id,
       replace(btrim(soll), ',', '.')::numeric(10,2),
       replace(btrim(erhalten), ',', '.')::numeric(10,2),
       zahlungsart,
       anlageart,
       NULLIF(btrim(rueckzahlung_am), '')::date,
       NULLIF(replace(btrim(rueckzahlung_betrag), ',', '.'), '')::numeric(10,2)
FROM stg.kaution;

INSERT INTO immo.mahnung (mahnung_id, vertrag_id, mahnstufe, datum, offener_betrag, mahngebuehr)
SELECT mahnung_id,
       vertrag_id,
       replace(btrim(mahnstufe), ',', '.')::smallint,
       btrim(datum)::date,
       replace(btrim(offener_betrag), ',', '.')::numeric(10,2),
       replace(btrim(mahngebuehr), ',', '.')::numeric(6,2)
FROM stg.mahnung;

INSERT INTO immo.nk_abrechnung (vertrag_id, abrechnungsjahr, vorauszahlung, kosten, saldo, erstellt_am, versendet_am, zahlungsziel)
SELECT vertrag_id,
       replace(btrim(abrechnungsjahr), ',', '.')::smallint,
       replace(btrim(vorauszahlung), ',', '.')::numeric(10,2),
       replace(btrim(kosten), ',', '.')::numeric(10,2),
       replace(btrim(saldo), ',', '.')::numeric(10,2),
       btrim(erstellt_am)::date,
       btrim(versendet_am)::date,
       btrim(zahlungsziel)::date
FROM stg.nk_abrechnung;

INSERT INTO immo.leerstand (leerstand_id, einheit_id, von, bis, grund, sollmiete_potenziell, vermarktungsstart)
SELECT leerstand_id,
       einheit_id,
       btrim(von)::date,
       NULLIF(btrim(bis), '')::date,
       grund,
       replace(btrim(sollmiete_potenziell), ',', '.')::numeric(10,2),
       NULLIF(btrim(vermarktungsstart), '')::date
FROM stg.leerstand;

INSERT INTO immo.sollstellung (sollstellung_id, vertrag_id, periode, faelligkeit, "position", betrag, ust_satz, storno, storno_ref)
SELECT sollstellung_id,
       vertrag_id,
       btrim(periode)::char(7),
       btrim(faelligkeit)::date,
       "position",
       replace(btrim(betrag), ',', '.')::numeric(10,2),
       replace(btrim(ust_satz), ',', '.')::numeric(5,2),
       CASE lower(btrim(storno)) WHEN 'ja' THEN true WHEN 'nein' THEN false END,
       NULLIF(storno_ref, '')
FROM stg.sollstellung;

INSERT INTO immo.zahlungseingang (zahlung_id, buchungsdatum, wertstellung, betrag, zahlungsart, verwendungszweck, vertrag_id)
SELECT zahlung_id,
       btrim(buchungsdatum)::date,
       btrim(wertstellung)::date,
       replace(btrim(betrag), ',', '.')::numeric(10,2),
       zahlungsart,
       NULLIF(verwendungszweck, ''),
       NULLIF(vertrag_id, '')
FROM stg.zahlungseingang;

INSERT INTO immo.zahlungszuordnung (zahlung_id, sollstellung_id, betrag)
SELECT zahlung_id,
       sollstellung_id,
       replace(btrim(betrag), ',', '.')::numeric(10,2)
FROM stg.zahlungszuordnung;

INSERT INTO immo.instandhaltung (auftrag_id, objekt_id, einheit_id, dienstleister_id, gewerk, schadensmeldung_am, beauftragung_am, ausfuehrung_am, rechnungsdatum, rechnungsnummer, netto, ust, brutto, kostenart, umlagefaehig, angebot_eingeholt, freigabe_durch)
SELECT auftrag_id,
       objekt_id,
       NULLIF(einheit_id, ''),
       dienstleister_id,
       gewerk,
       NULLIF(schadensmeldung_am, ''),
       NULLIF(beauftragung_am, ''),
       NULLIF(ausfuehrung_am, ''),
       NULLIF(rechnungsdatum, ''),
       rechnungsnummer,
       replace(btrim(netto), ',', '.')::numeric(10,2),
       replace(btrim(ust), ',', '.')::numeric(10,2),
       replace(btrim(brutto), ',', '.')::numeric(10,2),
       kostenart,
       CASE lower(btrim(umlagefaehig)) WHEN 'ja' THEN true WHEN 'nein' THEN false END,
       CASE lower(btrim(angebot_eingeholt)) WHEN 'ja' THEN true WHEN 'nein' THEN false END,
       freigabe_durch
FROM stg.instandhaltung;

INSERT INTO immo.betriebskosten (objekt_id, abrechnungsjahr, kostenart, betrag, umlageschluessel, umlagefaehig)
SELECT objekt_id,
       replace(btrim(abrechnungsjahr), ',', '.')::smallint,
       kostenart,
       replace(btrim(betrag), ',', '.')::numeric(12,2),
       umlageschluessel,
       CASE lower(btrim(umlagefaehig)) WHEN 'ja' THEN true WHEN 'nein' THEN false END
FROM stg.betriebskosten;

INSERT INTO immo.marktmiete (plz, lagequalitaet, jahr, nutzungsart, median_eur_qm, spanne_unten, spanne_oben)
SELECT btrim(plz)::char(5),
       lagequalitaet,
       replace(btrim(jahr), ',', '.')::smallint,
       nutzungsart,
       replace(btrim(median_eur_qm), ',', '.')::numeric(6,2),
       replace(btrim(spanne_unten), ',', '.')::numeric(6,2),
       replace(btrim(spanne_oben), ',', '.')::numeric(6,2)
FROM stg.marktmiete;

INSERT INTO immo.vpi_index (monat, indexwert)
SELECT btrim(monat)::char(7),
       replace(btrim(indexwert), ',', '.')::numeric(6,1)
FROM stg.vpi_index;

COMMIT;

-- Kontrolle: Zeilen je Tabelle

SELECT 'objekt' AS tabelle, COUNT(*) AS zeilen FROM immo.objekt UNION ALL SELECT 'einheit' AS tabelle, COUNT(*) AS zeilen FROM immo.einheit UNION ALL SELECT 'mietpartei' AS tabelle, COUNT(*) AS zeilen FROM immo.mietpartei UNION ALL SELECT 'dienstleister' AS tabelle, COUNT(*) AS zeilen FROM immo.dienstleister UNION ALL SELECT 'mietvertrag' AS tabelle, COUNT(*) AS zeilen FROM immo.mietvertrag UNION ALL SELECT 'mietanpassung' AS tabelle, COUNT(*) AS zeilen FROM immo.mietanpassung UNION ALL SELECT 'vz_anpassung' AS tabelle, COUNT(*) AS zeilen FROM immo.vz_anpassung UNION ALL SELECT 'kaution' AS tabelle, COUNT(*) AS zeilen FROM immo.kaution UNION ALL SELECT 'mahnung' AS tabelle, COUNT(*) AS zeilen FROM immo.mahnung UNION ALL SELECT 'nk_abrechnung' AS tabelle, COUNT(*) AS zeilen FROM immo.nk_abrechnung UNION ALL SELECT 'leerstand' AS tabelle, COUNT(*) AS zeilen FROM immo.leerstand UNION ALL SELECT 'sollstellung' AS tabelle, COUNT(*) AS zeilen FROM immo.sollstellung UNION ALL SELECT 'zahlungseingang' AS tabelle, COUNT(*) AS zeilen FROM immo.zahlungseingang UNION ALL SELECT 'zahlungszuordnung' AS tabelle, COUNT(*) AS zeilen FROM immo.zahlungszuordnung UNION ALL SELECT 'instandhaltung' AS tabelle, COUNT(*) AS zeilen FROM immo.instandhaltung UNION ALL SELECT 'betriebskosten' AS tabelle, COUNT(*) AS zeilen FROM immo.betriebskosten UNION ALL SELECT 'marktmiete' AS tabelle, COUNT(*) AS zeilen FROM immo.marktmiete UNION ALL SELECT 'vpi_index' AS tabelle, COUNT(*) AS zeilen FROM immo.vpi_index ORDER BY 1;
