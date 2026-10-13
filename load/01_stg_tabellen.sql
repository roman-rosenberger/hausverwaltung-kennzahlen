-- Zwischenschicht stg: alle Spalten als Text, genau so wie in den CSV-Dateien.
-- Eigene Quelldaten werden hier eingeordnet (Spaltenzuordnung), bevor sie nach immo übernommen werden.
CREATE SCHEMA IF NOT EXISTS stg;

DROP TABLE IF EXISTS stg.objekt;
CREATE TABLE stg.objekt (
    objekt_id text,
    bezeichnung text,
    strasse text,
    plz text,
    ort text,
    ortsteil text,
    baujahr text,
    letzte_modernisierung text,
    nutzungsart text,
    grundstuecksflaeche_qm text,
    wohnflaeche_gesamt_qm text,
    anzahl_einheiten text,
    lagequalitaet text,
    heizungsart text,
    heizung_baujahr text
);

DROP TABLE IF EXISTS stg.einheit;
CREATE TABLE stg.einheit (
    einheit_id text,
    objekt_id text,
    bezeichnung text,
    nutzungsart text,
    flaeche_qm text,
    zimmer text,
    etage text,
    balkon text,
    ausstattungsklasse text
);

DROP TABLE IF EXISTS stg.mietpartei;
CREATE TABLE stg.mietpartei (
    mietpartei_id text,
    typ text,
    anrede text,
    name text,
    vorname text,
    telefon text,
    email text,
    personen_haushalt text
);

DROP TABLE IF EXISTS stg.dienstleister;
CREATE TABLE stg.dienstleister (
    dienstleister_id text,
    name text,
    gewerk text,
    rahmenvertrag text
);

DROP TABLE IF EXISTS stg.mietvertrag;
CREATE TABLE stg.mietvertrag (
    vertrag_id text,
    einheit_id text,
    mietpartei_id text,
    vertragsbeginn text,
    vertragsende text,
    befristet_bis text,
    kuendigung_am text,
    kuendigung_durch text,
    auszugsgrund text,
    kaltmiete text,
    nk_vorauszahlung text,
    hk_vorauszahlung text,
    mietart text,
    ust_option text,
    vertragsstatus text
);

DROP TABLE IF EXISTS stg.mietanpassung;
CREATE TABLE stg.mietanpassung (
    anpassung_id text,
    vertrag_id text,
    gueltig_ab text,
    kaltmiete_alt text,
    kaltmiete_neu text,
    grund text
);

DROP TABLE IF EXISTS stg.vz_anpassung;
CREATE TABLE stg.vz_anpassung (
    anpassung_id text,
    vertrag_id text,
    gueltig_ab text,
    nk_alt text,
    nk_neu text,
    hk_alt text,
    hk_neu text,
    grund text
);

DROP TABLE IF EXISTS stg.kaution;
CREATE TABLE stg.kaution (
    vertrag_id text,
    soll text,
    erhalten text,
    zahlungsart text,
    anlageart text,
    rueckzahlung_am text,
    rueckzahlung_betrag text
);

DROP TABLE IF EXISTS stg.mahnung;
CREATE TABLE stg.mahnung (
    mahnung_id text,
    vertrag_id text,
    mahnstufe text,
    datum text,
    offener_betrag text,
    mahngebuehr text
);

DROP TABLE IF EXISTS stg.nk_abrechnung;
CREATE TABLE stg.nk_abrechnung (
    vertrag_id text,
    abrechnungsjahr text,
    vorauszahlung text,
    kosten text,
    saldo text,
    erstellt_am text,
    versendet_am text,
    zahlungsziel text
);

DROP TABLE IF EXISTS stg.leerstand;
CREATE TABLE stg.leerstand (
    leerstand_id text,
    einheit_id text,
    von text,
    bis text,
    grund text,
    sollmiete_potenziell text,
    vermarktungsstart text
);

DROP TABLE IF EXISTS stg.sollstellung;
CREATE TABLE stg.sollstellung (
    sollstellung_id text,
    vertrag_id text,
    periode text,
    faelligkeit text,
    "position" text,
    betrag text,
    ust_satz text,
    storno text,
    storno_ref text
);

DROP TABLE IF EXISTS stg.zahlungseingang;
CREATE TABLE stg.zahlungseingang (
    zahlung_id text,
    buchungsdatum text,
    wertstellung text,
    betrag text,
    zahlungsart text,
    verwendungszweck text,
    vertrag_id text
);

DROP TABLE IF EXISTS stg.zahlungszuordnung;
CREATE TABLE stg.zahlungszuordnung (
    zahlung_id text,
    sollstellung_id text,
    betrag text
);

DROP TABLE IF EXISTS stg.instandhaltung;
CREATE TABLE stg.instandhaltung (
    auftrag_id text,
    objekt_id text,
    einheit_id text,
    dienstleister_id text,
    gewerk text,
    schadensmeldung_am text,
    beauftragung_am text,
    ausfuehrung_am text,
    rechnungsdatum text,
    rechnungsnummer text,
    netto text,
    ust text,
    brutto text,
    kostenart text,
    umlagefaehig text,
    angebot_eingeholt text,
    freigabe_durch text
);

DROP TABLE IF EXISTS stg.betriebskosten;
CREATE TABLE stg.betriebskosten (
    objekt_id text,
    abrechnungsjahr text,
    kostenart text,
    betrag text,
    umlageschluessel text,
    umlagefaehig text
);

DROP TABLE IF EXISTS stg.marktmiete;
CREATE TABLE stg.marktmiete (
    plz text,
    lagequalitaet text,
    jahr text,
    nutzungsart text,
    median_eur_qm text,
    spanne_unten text,
    spanne_oben text
);

DROP TABLE IF EXISTS stg.vpi_index;
CREATE TABLE stg.vpi_index (
    monat text,
    indexwert text
);
