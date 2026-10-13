-- Basisschema (nur Struktur, keine Daten) für das Hausverwaltungs-Reporting
-- Schema immo, getestet mit PostgreSQL 17. Nur ausführen, wenn die Tabellen noch nicht vorhanden sind.
-- Danach: sql/00_parameter.sql bis sql/99_v_auffaelligkeiten.sql (oder install_alle.sql).

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- immo (SCHEMA)
--

CREATE SCHEMA IF NOT EXISTS immo;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- betriebskosten (TABLE)
--

CREATE TABLE immo.betriebskosten (
    objekt_id text NOT NULL,
    abrechnungsjahr smallint NOT NULL,
    kostenart text NOT NULL,
    betrag numeric(12,2) NOT NULL,
    umlageschluessel text NOT NULL,
    umlagefaehig boolean NOT NULL
);


--
-- dienstleister (TABLE)
--

CREATE TABLE immo.dienstleister (
    dienstleister_id text NOT NULL,
    name text NOT NULL,
    gewerk text NOT NULL,
    rahmenvertrag boolean NOT NULL
);


--
-- einheit (TABLE)
--

CREATE TABLE immo.einheit (
    einheit_id text NOT NULL,
    objekt_id text NOT NULL,
    bezeichnung text NOT NULL,
    nutzungsart text NOT NULL,
    flaeche_qm numeric(8,2),
    zimmer numeric(3,1),
    etage smallint,
    balkon boolean,
    ausstattungsklasse text
);


--
-- COLUMN einheit.flaeche_qm (COMMENT)
--

COMMENT ON COLUMN immo.einheit.flaeche_qm IS 'Wohn-/Nutzfläche; Pflegequalität wie im Quellsystem';


--
-- instandhaltung (TABLE)
--

CREATE TABLE immo.instandhaltung (
    auftrag_id text NOT NULL,
    objekt_id text NOT NULL,
    einheit_id text,
    dienstleister_id text NOT NULL,
    gewerk text NOT NULL,
    schadensmeldung_am text,
    beauftragung_am text,
    ausfuehrung_am text,
    rechnungsdatum text,
    rechnungsnummer text NOT NULL,
    netto numeric(10,2) NOT NULL,
    ust numeric(10,2) NOT NULL,
    brutto numeric(10,2) NOT NULL,
    kostenart text NOT NULL,
    umlagefaehig boolean NOT NULL,
    angebot_eingeholt boolean NOT NULL,
    freigabe_durch text NOT NULL
);


--
-- COLUMN instandhaltung.schadensmeldung_am (COMMENT)
--

COMMENT ON COLUMN immo.instandhaltung.schadensmeldung_am IS 'Rohtext aus dem Handwerkermodul des Fremdsystems – Format vor Auswertung prüfen';


--
-- kaution (TABLE)
--

CREATE TABLE immo.kaution (
    vertrag_id text NOT NULL,
    soll numeric(10,2) NOT NULL,
    erhalten numeric(10,2) NOT NULL,
    zahlungsart text NOT NULL,
    anlageart text NOT NULL,
    rueckzahlung_am date,
    rueckzahlung_betrag numeric(10,2)
);


--
-- leerstand (TABLE)
--

CREATE TABLE immo.leerstand (
    leerstand_id text NOT NULL,
    einheit_id text NOT NULL,
    von date NOT NULL,
    bis date,
    grund text NOT NULL,
    sollmiete_potenziell numeric(10,2) NOT NULL,
    vermarktungsstart date
);


--
-- mahnung (TABLE)
--

CREATE TABLE immo.mahnung (
    mahnung_id text NOT NULL,
    vertrag_id text NOT NULL,
    mahnstufe smallint NOT NULL,
    datum date NOT NULL,
    offener_betrag numeric(10,2) NOT NULL,
    mahngebuehr numeric(6,2) NOT NULL,
    CONSTRAINT mahnung_mahnstufe_check CHECK (((mahnstufe >= 1) AND (mahnstufe <= 3)))
);


--
-- marktmiete (TABLE)
--

CREATE TABLE immo.marktmiete (
    plz character(5) NOT NULL,
    lagequalitaet text NOT NULL,
    jahr smallint NOT NULL,
    nutzungsart text NOT NULL,
    median_eur_qm numeric(6,2) NOT NULL,
    spanne_unten numeric(6,2) NOT NULL,
    spanne_oben numeric(6,2) NOT NULL
);


--
-- TABLE marktmiete (COMMENT)
--

COMMENT ON TABLE immo.marktmiete IS 'Externe Referenz (Mietspiegel-Ersatz); Join über plz + lagequalitaet + jahr';


--
-- mietanpassung (TABLE)
--

CREATE TABLE immo.mietanpassung (
    anpassung_id text NOT NULL,
    vertrag_id text NOT NULL,
    gueltig_ab date NOT NULL,
    kaltmiete_alt numeric(10,2) NOT NULL,
    kaltmiete_neu numeric(10,2) NOT NULL,
    grund text NOT NULL
);


--
-- mietpartei (TABLE)
--

CREATE TABLE immo.mietpartei (
    mietpartei_id text NOT NULL,
    typ text NOT NULL,
    anrede text,
    name text NOT NULL,
    vorname text,
    telefon text,
    email text,
    personen_haushalt smallint
);


--
-- TABLE mietpartei (COMMENT)
--

COMMENT ON TABLE immo.mietpartei IS 'Mieter; Namensfelder in Quellsystem-Qualität';


--
-- mietvertrag (TABLE)
--

CREATE TABLE immo.mietvertrag (
    vertrag_id text NOT NULL,
    einheit_id text NOT NULL,
    mietpartei_id text NOT NULL,
    vertragsbeginn date NOT NULL,
    vertragsende date,
    befristet_bis date,
    kuendigung_am date,
    kuendigung_durch text,
    auszugsgrund text,
    kaltmiete numeric(10,2) NOT NULL,
    nk_vorauszahlung numeric(10,2) NOT NULL,
    hk_vorauszahlung numeric(10,2) NOT NULL,
    mietart text NOT NULL,
    ust_option boolean NOT NULL,
    vertragsstatus text NOT NULL,
    CONSTRAINT mietvertrag_check CHECK (((vertragsende IS NULL) OR (vertragsende >= vertragsbeginn)))
);


--
-- COLUMN mietvertrag.kaltmiete (COMMENT)
--

COMMENT ON COLUMN immo.mietvertrag.kaltmiete IS 'Kaltmiete bei Vertragsbeginn. Die aktuelle Miete ergibt sich aus mietanpassung.';


--
-- nk_abrechnung (TABLE)
--

CREATE TABLE immo.nk_abrechnung (
    vertrag_id text NOT NULL,
    abrechnungsjahr smallint NOT NULL,
    vorauszahlung numeric(10,2) NOT NULL,
    kosten numeric(10,2) NOT NULL,
    saldo numeric(10,2) NOT NULL,
    erstellt_am date NOT NULL,
    versendet_am date NOT NULL,
    zahlungsziel date NOT NULL
);


--
-- TABLE nk_abrechnung (COMMENT)
--

COMMENT ON TABLE immo.nk_abrechnung IS 'Abrechnungsjahr 2023 enthält auch Vorauszahlungen vor der Systemumstellung 09/2023 (Summenübernahme)';


--
-- objekt (TABLE)
--

CREATE TABLE immo.objekt (
    objekt_id text NOT NULL,
    bezeichnung text NOT NULL,
    strasse text NOT NULL,
    plz character(5) NOT NULL,
    ort text NOT NULL,
    ortsteil text NOT NULL,
    baujahr smallint NOT NULL,
    letzte_modernisierung smallint,
    nutzungsart text NOT NULL,
    grundstuecksflaeche_qm numeric(10,2),
    wohnflaeche_gesamt_qm numeric(10,2),
    anzahl_einheiten smallint NOT NULL,
    lagequalitaet text NOT NULL,
    heizungsart text NOT NULL,
    heizung_baujahr smallint
);


--
-- TABLE objekt (COMMENT)
--

COMMENT ON TABLE immo.objekt IS 'Wirtschaftseinheiten (Gebäude) des Bestands';


--
-- COLUMN objekt.wohnflaeche_gesamt_qm (COMMENT)
--

COMMENT ON COLUMN immo.objekt.wohnflaeche_gesamt_qm IS 'Gesamtfläche laut Objektstammblatt; kann von der Summe der Einheiten abweichen';


--
-- sollstellung (TABLE)
--

CREATE TABLE immo.sollstellung (
    sollstellung_id text NOT NULL,
    vertrag_id text NOT NULL,
    periode character(7) NOT NULL,
    faelligkeit date NOT NULL,
    "position" text NOT NULL,
    betrag numeric(10,2) NOT NULL,
    ust_satz numeric(5,2) NOT NULL,
    storno boolean NOT NULL,
    storno_ref text
);


--
-- TABLE sollstellung (COMMENT)
--

COMMENT ON TABLE immo.sollstellung IS 'Forderungszeilen. Stornoketten: Original + Stornozeile (storno=true, negativer Betrag, storno_ref) + Neubuchung.';


--
-- vz_anpassung (TABLE)
--

CREATE TABLE immo.vz_anpassung (
    anpassung_id text NOT NULL,
    vertrag_id text NOT NULL,
    gueltig_ab date NOT NULL,
    nk_alt numeric(10,2) NOT NULL,
    nk_neu numeric(10,2) NOT NULL,
    hk_alt numeric(10,2) NOT NULL,
    hk_neu numeric(10,2) NOT NULL,
    grund text NOT NULL
);


--
-- TABLE vz_anpassung (COMMENT)
--

COMMENT ON TABLE immo.vz_anpassung IS 'Anpassungen der NK-/HK-Vorauszahlungen, i. d. R. nach einer Nebenkostenabrechnung. Die aktuelle Vorauszahlung ergibt sich aus mietvertrag (Anfangswerte) + dieser Historie.';


--
-- zahlungseingang (TABLE)
--

CREATE TABLE immo.zahlungseingang (
    zahlung_id text NOT NULL,
    buchungsdatum date NOT NULL,
    wertstellung date NOT NULL,
    betrag numeric(10,2) NOT NULL,
    zahlungsart text NOT NULL,
    verwendungszweck text,
    vertrag_id text
);


--
-- COLUMN zahlungseingang.vertrag_id (COMMENT)
--

COMMENT ON COLUMN immo.zahlungseingang.vertrag_id IS 'Vorläufige Zuordnung aus der Buchhaltung – Qualität wie im Quellsystem, kein Fremdschlüssel';


--
-- zahlungszuordnung (TABLE)
--

CREATE TABLE immo.zahlungszuordnung (
    zahlung_id text NOT NULL,
    sollstellung_id text NOT NULL,
    betrag numeric(10,2) NOT NULL
);


--
-- TABLE zahlungszuordnung (COMMENT)
--

COMMENT ON TABLE immo.zahlungszuordnung IS 'n:m – Teilzahlungen (mehrere Zahlungen je Soll) und Sammelzahlungen (eine Zahlung auf mehrere Solls)';


--
-- vpi_index (TABLE)
--

CREATE TABLE immo.vpi_index (
    monat character(7) NOT NULL,
    indexwert numeric(6,1) NOT NULL
);


--
-- betriebskosten betriebskosten_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.betriebskosten
    ADD CONSTRAINT betriebskosten_pkey PRIMARY KEY (objekt_id, abrechnungsjahr, kostenart);


--
-- dienstleister dienstleister_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.dienstleister
    ADD CONSTRAINT dienstleister_pkey PRIMARY KEY (dienstleister_id);


--
-- einheit einheit_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.einheit
    ADD CONSTRAINT einheit_pkey PRIMARY KEY (einheit_id);


--
-- instandhaltung instandhaltung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.instandhaltung
    ADD CONSTRAINT instandhaltung_pkey PRIMARY KEY (auftrag_id);


--
-- kaution kaution_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.kaution
    ADD CONSTRAINT kaution_pkey PRIMARY KEY (vertrag_id);


--
-- leerstand leerstand_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.leerstand
    ADD CONSTRAINT leerstand_pkey PRIMARY KEY (leerstand_id);


--
-- mahnung mahnung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.mahnung
    ADD CONSTRAINT mahnung_pkey PRIMARY KEY (mahnung_id);


--
-- marktmiete marktmiete_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.marktmiete
    ADD CONSTRAINT marktmiete_pkey PRIMARY KEY (plz, lagequalitaet, jahr, nutzungsart);


--
-- mietanpassung mietanpassung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.mietanpassung
    ADD CONSTRAINT mietanpassung_pkey PRIMARY KEY (anpassung_id);


--
-- mietpartei mietpartei_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.mietpartei
    ADD CONSTRAINT mietpartei_pkey PRIMARY KEY (mietpartei_id);


--
-- mietvertrag mietvertrag_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.mietvertrag
    ADD CONSTRAINT mietvertrag_pkey PRIMARY KEY (vertrag_id);


--
-- nk_abrechnung nk_abrechnung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.nk_abrechnung
    ADD CONSTRAINT nk_abrechnung_pkey PRIMARY KEY (vertrag_id, abrechnungsjahr);


--
-- objekt objekt_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.objekt
    ADD CONSTRAINT objekt_pkey PRIMARY KEY (objekt_id);


--
-- sollstellung sollstellung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.sollstellung
    ADD CONSTRAINT sollstellung_pkey PRIMARY KEY (sollstellung_id);


--
-- vpi_index vpi_index_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.vpi_index
    ADD CONSTRAINT vpi_index_pkey PRIMARY KEY (monat);


--
-- vz_anpassung vz_anpassung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.vz_anpassung
    ADD CONSTRAINT vz_anpassung_pkey PRIMARY KEY (anpassung_id);


--
-- zahlungseingang zahlungseingang_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.zahlungseingang
    ADD CONSTRAINT zahlungseingang_pkey PRIMARY KEY (zahlung_id);


--
-- zahlungszuordnung zahlungszuordnung_pkey (CONSTRAINT)
--

ALTER TABLE ONLY immo.zahlungszuordnung
    ADD CONSTRAINT zahlungszuordnung_pkey PRIMARY KEY (zahlung_id, sollstellung_id);


--
-- ix_soll_vertrag_periode (INDEX)
--

CREATE INDEX ix_soll_vertrag_periode ON immo.sollstellung USING btree (vertrag_id, periode);


--
-- betriebskosten betriebskosten_objekt_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.betriebskosten
    ADD CONSTRAINT betriebskosten_objekt_id_fkey FOREIGN KEY (objekt_id) REFERENCES immo.objekt(objekt_id);


--
-- einheit einheit_objekt_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.einheit
    ADD CONSTRAINT einheit_objekt_id_fkey FOREIGN KEY (objekt_id) REFERENCES immo.objekt(objekt_id);


--
-- instandhaltung instandhaltung_dienstleister_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.instandhaltung
    ADD CONSTRAINT instandhaltung_dienstleister_id_fkey FOREIGN KEY (dienstleister_id) REFERENCES immo.dienstleister(dienstleister_id);


--
-- instandhaltung instandhaltung_einheit_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.instandhaltung
    ADD CONSTRAINT instandhaltung_einheit_id_fkey FOREIGN KEY (einheit_id) REFERENCES immo.einheit(einheit_id);


--
-- instandhaltung instandhaltung_objekt_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.instandhaltung
    ADD CONSTRAINT instandhaltung_objekt_id_fkey FOREIGN KEY (objekt_id) REFERENCES immo.objekt(objekt_id);


--
-- kaution kaution_vertrag_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.kaution
    ADD CONSTRAINT kaution_vertrag_id_fkey FOREIGN KEY (vertrag_id) REFERENCES immo.mietvertrag(vertrag_id);


--
-- leerstand leerstand_einheit_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.leerstand
    ADD CONSTRAINT leerstand_einheit_id_fkey FOREIGN KEY (einheit_id) REFERENCES immo.einheit(einheit_id);


--
-- mahnung mahnung_vertrag_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.mahnung
    ADD CONSTRAINT mahnung_vertrag_id_fkey FOREIGN KEY (vertrag_id) REFERENCES immo.mietvertrag(vertrag_id);


--
-- mietanpassung mietanpassung_vertrag_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.mietanpassung
    ADD CONSTRAINT mietanpassung_vertrag_id_fkey FOREIGN KEY (vertrag_id) REFERENCES immo.mietvertrag(vertrag_id);


--
-- mietvertrag mietvertrag_einheit_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.mietvertrag
    ADD CONSTRAINT mietvertrag_einheit_id_fkey FOREIGN KEY (einheit_id) REFERENCES immo.einheit(einheit_id);


--
-- mietvertrag mietvertrag_mietpartei_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.mietvertrag
    ADD CONSTRAINT mietvertrag_mietpartei_id_fkey FOREIGN KEY (mietpartei_id) REFERENCES immo.mietpartei(mietpartei_id);


--
-- nk_abrechnung nk_abrechnung_vertrag_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.nk_abrechnung
    ADD CONSTRAINT nk_abrechnung_vertrag_id_fkey FOREIGN KEY (vertrag_id) REFERENCES immo.mietvertrag(vertrag_id);


--
-- sollstellung sollstellung_storno_ref_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.sollstellung
    ADD CONSTRAINT sollstellung_storno_ref_fkey FOREIGN KEY (storno_ref) REFERENCES immo.sollstellung(sollstellung_id) DEFERRABLE INITIALLY DEFERRED;


--
-- sollstellung sollstellung_vertrag_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.sollstellung
    ADD CONSTRAINT sollstellung_vertrag_id_fkey FOREIGN KEY (vertrag_id) REFERENCES immo.mietvertrag(vertrag_id);


--
-- vz_anpassung vz_anpassung_vertrag_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.vz_anpassung
    ADD CONSTRAINT vz_anpassung_vertrag_id_fkey FOREIGN KEY (vertrag_id) REFERENCES immo.mietvertrag(vertrag_id);


--
-- zahlungszuordnung zahlungszuordnung_sollstellung_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.zahlungszuordnung
    ADD CONSTRAINT zahlungszuordnung_sollstellung_id_fkey FOREIGN KEY (sollstellung_id) REFERENCES immo.sollstellung(sollstellung_id);


--
-- zahlungszuordnung zahlungszuordnung_zahlung_id_fkey (FK CONSTRAINT)
--

ALTER TABLE ONLY immo.zahlungszuordnung
    ADD CONSTRAINT zahlungszuordnung_zahlung_id_fkey FOREIGN KEY (zahlung_id) REFERENCES immo.zahlungseingang(zahlung_id);


--
-- PostgreSQL database dump complete
--


