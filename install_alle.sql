-- Gesamtinstallation, Reihenfolge wie die Nummern in sql/

-- ===== sql/00_parameter.sql =====
-- Parameter: Stichtag, Karenztage, Mietanpassungs-Zyklus
-- Alle Views lesen den Stichtag über immo.stichtag(). Zum Wechseln des Stichtags
-- genügt: UPDATE immo.parameter_stichtag SET stichtag = DATE 'JJJJ-MM-TT';

CREATE TABLE IF NOT EXISTS immo.parameter_stichtag (
    id        INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    stichtag  DATE NOT NULL
);
INSERT INTO immo.parameter_stichtag (id, stichtag)
VALUES (1, DATE '2026-08-31')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION immo.stichtag() RETURNS date
LANGUAGE sql STABLE AS
$$ SELECT stichtag FROM immo.parameter_stichtag WHERE id = 1 $$;

CREATE TABLE IF NOT EXISTS immo.parameter_karenz (
    parameter_id  SERIAL PRIMARY KEY,
    objekt_id     TEXT REFERENCES immo.objekt(objekt_id),  -- NULL = globaler Standard
    karenztage    INTEGER NOT NULL CHECK (karenztage >= 0),
    gueltig_ab    DATE NOT NULL DEFAULT '2023-09-01',
    kommentar     TEXT
);
INSERT INTO immo.parameter_karenz (objekt_id, karenztage, kommentar)
SELECT NULL, 5, 'Globaler Standardwert'
WHERE NOT EXISTS (SELECT 1 FROM immo.parameter_karenz WHERE objekt_id IS NULL);

CREATE TABLE IF NOT EXISTS immo.parameter_mietzyklus (
    parameter_id        SERIAL PRIMARY KEY,
    soll_zyklus_monate  INTEGER NOT NULL,
    gueltig_ab          DATE NOT NULL DEFAULT '2023-09-01',
    kommentar           TEXT
);
INSERT INTO immo.parameter_mietzyklus (soll_zyklus_monate, kommentar)
SELECT 24, 'Soll-Anpassungszyklus in Monaten'
WHERE NOT EXISTS (SELECT 1 FROM immo.parameter_mietzyklus);

-- ===== sql/01_v_aktuelle_miete.sql =====
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

-- ===== sql/02_v_leerstand.sql =====
-- Leerstand je Objekt (Wohnen). Korrigierte Fassung: Flächen ohne SUM(DISTINCT), Zähler/Nenner je Einheit
CREATE OR REPLACE VIEW immo.v_leerstand AS
WITH leer AS (
    SELECT DISTINCT ON (l.einheit_id) l.einheit_id, l.sollmiete_potenziell
    FROM immo.leerstand l
    WHERE l.von <= immo.stichtag()
      AND (l.bis IS NULL OR l.bis >= immo.stichtag())
      AND l.grund <> 'sanierungsbedingt'
    ORDER BY l.einheit_id, l.von DESC
),
miete AS (
    SELECT einheit_id, MAX(aktuelle_kaltmiete) AS aktuelle_kaltmiete
    FROM immo.v_aktuelle_miete
    WHERE vertragsstatus = 'aktiv'
    GROUP BY einheit_id
)
SELECT
    o.objekt_id,
    o.bezeichnung,
    COUNT(*) AS einheiten_gesamt,
    COUNT(l.einheit_id) AS einheiten_leer,
    ROUND(COUNT(l.einheit_id) * 100.0 / NULLIF(COUNT(*), 0), 2) AS quote_einheiten_pct,
    ROUND(SUM(e.flaeche_qm)::numeric, 2) AS flaeche_gesamt_qm,
    ROUND(SUM(CASE WHEN l.einheit_id IS NOT NULL THEN e.flaeche_qm ELSE 0 END)::numeric, 2) AS flaeche_leer_qm,
    ROUND(
        SUM(CASE WHEN l.einheit_id IS NOT NULL THEN e.flaeche_qm ELSE 0 END) * 100.0
        / NULLIF(SUM(e.flaeche_qm), 0)::numeric, 2
    ) AS quote_flaeche_pct,
    ROUND(COALESCE(SUM(l.sollmiete_potenziell), 0)::numeric, 2) AS entgangene_miete,
    ROUND(
        (100.0 * SUM(l.sollmiete_potenziell)
         / NULLIF(SUM(COALESCE(l.sollmiete_potenziell, m.aktuelle_kaltmiete, 0)), 0))::numeric, 2
    ) AS quote_wirtschaftlich_pct
FROM immo.einheit e
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
LEFT JOIN leer l ON l.einheit_id = e.einheit_id
LEFT JOIN miete m ON m.einheit_id = e.einheit_id
WHERE e.nutzungsart = 'Wohnen'
GROUP BY o.objekt_id, o.bezeichnung
ORDER BY o.objekt_id;

-- ===== sql/03_v_leerstand_sanierung.sql =====
-- Sanierungsbedingter Leerstand, getrennt ausgewiesen
CREATE OR REPLACE VIEW immo.v_leerstand_sanierung AS
SELECT
    e.objekt_id,
    o.bezeichnung,
    COUNT(l.leerstand_id) AS einheiten_sanierung,
    ROUND(SUM(l.sollmiete_potenziell)::numeric, 2) AS entgangene_miete_monat,
    MIN(l.von) AS aeltester_sanierungsbeginn,
    MAX(immo.stichtag() - l.von) AS laengste_sanierungsphase_tage
FROM immo.leerstand l
JOIN immo.einheit e ON e.einheit_id = l.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE l.grund = 'sanierungsbedingt'
AND l.von <= immo.stichtag()
AND l.bis IS NULL
GROUP BY e.objekt_id, o.bezeichnung
ORDER BY einheiten_sanierung DESC;

-- ===== sql/04_v_leerstand_wirtschaftlich.sql =====
-- Wirtschaftlicher Leerstand: Summe Zähler / Summe Nenner
CREATE OR REPLACE VIEW immo.v_leerstand_wirtschaftlich AS
WITH leer AS (
    SELECT DISTINCT ON (l.einheit_id) l.einheit_id, l.sollmiete_potenziell
    FROM immo.leerstand l
    WHERE l.von <= immo.stichtag()
      AND (l.bis IS NULL OR l.bis >= immo.stichtag())
      AND l.grund <> 'sanierungsbedingt'
    ORDER BY l.einheit_id, l.von DESC
),
miete AS (
    SELECT einheit_id, MAX(aktuelle_kaltmiete) AS aktuelle_kaltmiete
    FROM immo.v_aktuelle_miete
    WHERE vertragsstatus = 'aktiv'
    GROUP BY einheit_id
)
SELECT
    e.objekt_id,
    o.bezeichnung,
    COUNT(*) AS einheiten_gesamt,
    COUNT(l.einheit_id) AS einheiten_leer,
    ROUND(SUM(l.sollmiete_potenziell)::numeric, 2) AS entgangene_miete,
    ROUND((100.0 * SUM(l.sollmiete_potenziell)
           / NULLIF(SUM(COALESCE(l.sollmiete_potenziell, m.aktuelle_kaltmiete, 0)), 0))::numeric, 2) AS quote_wirtschaftlich_pct
FROM immo.einheit e
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
LEFT JOIN leer l ON l.einheit_id = e.einheit_id
LEFT JOIN miete m ON m.einheit_id = e.einheit_id
WHERE e.nutzungsart = 'Wohnen'
GROUP BY e.objekt_id, o.bezeichnung;

-- ===== sql/05_v_fluktuation.sql =====
-- Fluktuation je Objekt und Jahr (Stichtagsjahr und die drei Vorjahre)
CREATE OR REPLACE VIEW immo.v_fluktuation AS
SELECT
    o.objekt_id,
    o.bezeichnung,
    j.jahr,
    COUNT(DISTINCT e.einheit_id) AS einheiten_gesamt,
    COUNT(mv.vertrag_id) AS auszuege,
    ROUND(
        COUNT(mv.vertrag_id) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.einheit_id), 0), 2
    ) AS fluktuationsrate_pct
FROM immo.objekt o
CROSS JOIN generate_series(EXTRACT(YEAR FROM immo.stichtag())::int - 3,
                           EXTRACT(YEAR FROM immo.stichtag())::int) AS j(jahr)
JOIN immo.einheit e ON e.objekt_id = o.objekt_id
LEFT JOIN immo.mietvertrag mv 
    ON mv.einheit_id = e.einheit_id
    AND mv.vertragsende IS NOT NULL
    AND mv.vertragsstatus IN ('beendet', 'gekündigt')
    AND EXTRACT(YEAR FROM mv.vertragsende) = j.jahr
WHERE e.nutzungsart = 'Wohnen'
GROUP BY o.objekt_id, o.bezeichnung, j.jahr
ORDER BY j.jahr, fluktuationsrate_pct DESC;

-- ===== sql/06_v_leerstandsdauer.sql =====
-- Leerstandsdauer zwischen zwei Mietern
CREATE OR REPLACE VIEW immo.v_leerstandsdauer AS
SELECT
    e.objekt_id,
    o.bezeichnung,
    e.einheit_id,
    mv1.vertrag_id AS vertrag_alt,
    mv1.vertragsende AS auszug,
    mv2.vertrag_id AS vertrag_neu,
    mv2.vertragsbeginn AS einzug,
    mv2.vertragsbeginn - mv1.vertragsende AS tage_leer
FROM immo.mietvertrag mv1
JOIN immo.einheit e ON e.einheit_id = mv1.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
JOIN immo.mietvertrag mv2 
    ON mv2.einheit_id = mv1.einheit_id
    AND mv2.vertragsbeginn > mv1.vertragsende
    AND mv2.vertragsbeginn = (
        SELECT MIN(mv3.vertragsbeginn)
        FROM immo.mietvertrag mv3
        WHERE mv3.einheit_id = mv1.einheit_id
        AND mv3.vertragsbeginn > mv1.vertragsende
    )
WHERE mv1.vertragsende IS NOT NULL
AND e.nutzungsart = 'Wohnen';

-- ===== sql/07_v_instandhaltung.sql =====
-- Instandhaltungskosten je Objekt, Jahr und Kostenart
CREATE OR REPLACE VIEW immo.v_instandhaltung AS
SELECT
    ih.objekt_id,
    o.bezeichnung,
    EXTRACT(YEAR FROM
        CASE
            WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$'
                THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
            WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$'
                THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
            ELSE NULL
        END
    ) AS jahr,
    ih.kostenart,
    COUNT(*) AS anzahl_auftraege,
    ROUND(SUM(ih.netto)::numeric, 2) AS kosten_netto,
    o.wohnflaeche_gesamt_qm,
    ROUND(
        SUM(ih.netto) / NULLIF(o.wohnflaeche_gesamt_qm, 0)::numeric, 2
    ) AS euro_pro_qm
FROM immo.instandhaltung ih
JOIN immo.objekt o ON o.objekt_id = ih.objekt_id
WHERE ih.rechnungsdatum IS NOT NULL
GROUP BY ih.objekt_id, o.bezeichnung, o.wohnflaeche_gesamt_qm,
    EXTRACT(YEAR FROM
        CASE
            WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$'
                THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
            WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$'
                THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
            ELSE NULL
        END
    ), ih.kostenart
ORDER BY ih.objekt_id, jahr, ih.kostenart;

-- ===== sql/08_v_instandhaltung_benchmark.sql =====
-- Instandhaltung + Instandsetzung €/m² gegen VDIV-Richtwert, Modernisierung separat
CREATE OR REPLACE VIEW immo.v_instandhaltung_benchmark AS
SELECT
    objekt_id,
    bezeichnung,
    jahr::int AS jahr,
    (jahr::int = 2023) AS rumpfjahr,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart IN ('Instandhaltung','Instandsetzung'))::numeric, 2) AS kosten_benchmark,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart = 'Instandhaltung')::numeric, 2) AS kosten_instandhaltung,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart = 'Instandsetzung')::numeric, 2) AS kosten_instandsetzung,
    ROUND(SUM(kosten_netto) FILTER (WHERE kostenart = 'Modernisierung')::numeric, 2) AS kosten_modernisierung,
    MAX(wohnflaeche_gesamt_qm) AS wohnflaeche_gesamt_qm,
    ROUND((SUM(kosten_netto) FILTER (WHERE kostenart IN ('Instandhaltung','Instandsetzung'))
           / NULLIF(MAX(wohnflaeche_gesamt_qm),0))::numeric, 2) AS euro_pro_qm_benchmark,
    (SUM(kosten_netto) FILTER (WHERE kostenart IN ('Instandhaltung','Instandsetzung'))
           / NULLIF(MAX(wohnflaeche_gesamt_qm),0)) > 15 AS ueber_richtwert
FROM immo.v_instandhaltung
GROUP BY objekt_id, bezeichnung, jahr::int;

-- ===== sql/09_v_instandhaltung_rollierend.sql =====
-- Rollierende 12-Monats-Summe je Objekt
CREATE OR REPLACE VIEW immo.v_instandhaltung_rollierend AS
WITH monatswerte AS (
    SELECT
        ih.objekt_id,
        DATE_TRUNC('month', 
            CASE
                WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$' THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
                WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
                ELSE NULL
            END
        )::date AS monat,
        SUM(ih.netto) AS kosten_netto_monat
    FROM immo.instandhaltung ih
    WHERE ih.kostenart IN ('Instandhaltung', 'Instandsetzung')
    AND ih.rechnungsdatum IS NOT NULL
    GROUP BY ih.objekt_id, 
        DATE_TRUNC('month', 
            CASE
                WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$' THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
                WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
                ELSE NULL
            END
        )
),
alle_monate AS (
    SELECT DISTINCT objekt_id, monat FROM monatswerte
)
SELECT
    m.objekt_id,
    o.bezeichnung,
    m.monat,
    ROUND(
        SUM(mw.kosten_netto_monat) FILTER (
            WHERE mw.monat BETWEEN m.monat - INTERVAL '11 months' AND m.monat
        )::numeric, 2
    ) AS kosten_rollierend_12m,
    o.wohnflaeche_gesamt_qm,
    ROUND(
        (SUM(mw.kosten_netto_monat) FILTER (
            WHERE mw.monat BETWEEN m.monat - INTERVAL '11 months' AND m.monat
        ) / NULLIF(o.wohnflaeche_gesamt_qm, 0))::numeric, 2
    ) AS euro_pro_qm_rollierend_12m
FROM alle_monate m
JOIN immo.objekt o ON o.objekt_id = m.objekt_id
LEFT JOIN monatswerte mw ON mw.objekt_id = m.objekt_id
GROUP BY m.objekt_id, o.bezeichnung, m.monat, o.wohnflaeche_gesamt_qm
ORDER BY m.objekt_id, m.monat;

-- ===== sql/10_v_instandhaltung_ausreisser.sql =====
-- Einzelaufträge über 1.500 € netto
CREATE OR REPLACE VIEW immo.v_instandhaltung_ausreisser AS
SELECT
    ih.auftrag_id,
    ih.objekt_id,
    o.bezeichnung,
    ih.kostenart,
    ih.netto,
    ih.brutto,
    CASE
        WHEN ih.rechnungsdatum ~ '^\d{2}\.\d{2}\.\d{4}$' THEN TO_DATE(ih.rechnungsdatum, 'DD.MM.YYYY')
        WHEN ih.rechnungsdatum ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(ih.rechnungsdatum, 'YYYY-MM-DD')
        ELSE NULL
    END AS rechnungsdatum,
    CASE WHEN ih.netto > 1500 THEN true ELSE false END AS ausreisser
FROM immo.instandhaltung ih
JOIN immo.objekt o ON o.objekt_id = ih.objekt_id
WHERE ih.kostenart IN ('Instandhaltung', 'Instandsetzung')
ORDER BY ih.netto DESC;

-- ===== sql/11_v_marktvergleich.sql =====
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

-- ===== sql/12_v_forderungen_aging.sql =====
-- Offene Posten nach Karenz mit Aging-Klassen, ohne Storno
CREATE OR REPLACE VIEW immo.v_forderungen_aging AS
WITH karenz_effektiv AS (
    SELECT o.objekt_id,
        COALESCE(
            (SELECT p.karenztage FROM immo.parameter_karenz p
             WHERE p.objekt_id = o.objekt_id ORDER BY p.gueltig_ab DESC LIMIT 1),
            (SELECT p.karenztage FROM immo.parameter_karenz p
             WHERE p.objekt_id IS NULL ORDER BY p.gueltig_ab DESC LIMIT 1),
            5
        ) AS karenztage
    FROM immo.objekt o
)
SELECT
    s.vertrag_id,
    mv.einheit_id,
    e.objekt_id,
    o.bezeichnung AS objekt_bezeichnung,
    s.sollstellung_id,
    s.periode,
    s.faelligkeit,
    s."position",
    s.betrag AS soll,
    COALESCE(zz_sum.gezahlt, 0::numeric) AS gezahlt,
    s.betrag - COALESCE(zz_sum.gezahlt, 0::numeric) AS offen,
    ke.karenztage,
    (immo.stichtag() - s.faelligkeit - ke.karenztage) AS tage_ueberfaellig,
    CASE
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 0 THEN 'nicht überfällig'
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 30 THEN '01-30 Tage'
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 60 THEN '31-60 Tage'
        WHEN (immo.stichtag() - s.faelligkeit - ke.karenztage) <= 90 THEN '61-90 Tage'
        ELSE 'über 90 Tage'
    END AS aging_bucket,
    e.nutzungsart
FROM immo.sollstellung s
JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
JOIN immo.einheit e       ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o        ON o.objekt_id = e.objekt_id
JOIN karenz_effektiv ke   ON ke.objekt_id = o.objekt_id
LEFT JOIN (
    SELECT sollstellung_id, SUM(betrag) AS gezahlt
    FROM immo.zahlungszuordnung GROUP BY sollstellung_id
) zz_sum ON zz_sum.sollstellung_id = s.sollstellung_id
WHERE s.storno = false
AND s.betrag > 0
AND (s.betrag - COALESCE(zz_sum.gezahlt, 0::numeric)) > 0::numeric;

-- ===== sql/13_v_forderungen_position.sql =====
-- Offene Forderungen nach Position
CREATE OR REPLACE VIEW immo.v_forderungen_position AS
SELECT fa.objekt_id,
       fa.objekt_bezeichnung AS bezeichnung,
       fa.nutzungsart,
       fa."position",
       COUNT(*) AS anzahl_offene_posten,
       ROUND(SUM(fa.offen)::numeric, 2) AS offener_betrag
FROM immo.v_forderungen_aging fa
GROUP BY fa.objekt_id, fa.objekt_bezeichnung, fa.nutzungsart, fa."position";

-- ===== sql/14_v_forderungen_gewerbe.sql =====
-- Offene Forderungen Gewerbe je Aging-Klasse
CREATE OR REPLACE VIEW immo.v_forderungen_gewerbe AS
SELECT
    fa.objekt_id,
    fa.objekt_bezeichnung,
    fa.aging_bucket,
    ROUND(SUM(fa.offen)::numeric, 2) AS offener_betrag
FROM immo.v_forderungen_aging fa
JOIN immo.einheit e ON e.einheit_id = fa.einheit_id
WHERE e.nutzungsart = 'Gewerbe'
GROUP BY fa.objekt_id, fa.objekt_bezeichnung, fa.aging_bucket
ORDER BY fa.objekt_id, fa.aging_bucket;

-- ===== sql/15_v_forderungen_saldo.sql =====
-- Forderungen brutto, NK-Gutschriften und Saldo je Objekt
CREATE OR REPLACE VIEW immo.v_forderungen_saldo AS
WITH pos AS (
    SELECT objekt_id, SUM(offen) AS forderungen
    FROM immo.v_forderungen_aging
    GROUP BY objekt_id
),
gut AS (
    SELECT e.objekt_id,
           SUM(s.betrag - COALESCE(zz.gezahlt, 0)) AS gutschriften,
           COUNT(*) AS anzahl_gutschriften
    FROM immo.sollstellung s
    JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
    JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
    LEFT JOIN (SELECT sollstellung_id, SUM(betrag) AS gezahlt
               FROM immo.zahlungszuordnung GROUP BY sollstellung_id) zz
           ON zz.sollstellung_id = s.sollstellung_id
    WHERE s.storno = false AND s.betrag < 0 AND s."position" = 'NK-Nachforderung'
    GROUP BY e.objekt_id
)
SELECT
    o.objekt_id,
    o.bezeichnung,
    ROUND(COALESCE(p.forderungen, 0)::numeric, 2) AS forderungen_brutto,
    ROUND(COALESCE(g.gutschriften, 0)::numeric, 2) AS nk_gutschriften,
    ROUND((COALESCE(p.forderungen, 0) + COALESCE(g.gutschriften, 0))::numeric, 2) AS saldo_netto,
    COALESCE(g.anzahl_gutschriften, 0) AS anzahl_gutschriften
FROM immo.objekt o
LEFT JOIN pos p ON p.objekt_id = o.objekt_id
LEFT JOIN gut g ON g.objekt_id = o.objekt_id;

-- ===== sql/16_v_klaerfaelle.sql =====
-- Nicht zugeordnete Zahlungseingänge. Ohne Verwendungszweck (kann in Echtdaten Namen enthalten)
CREATE OR REPLACE VIEW immo.v_klaerfaelle AS
SELECT
    z.zahlung_id,
    z.buchungsdatum,
    z.betrag,
    z.zahlungsart,
    z.vertrag_id,
    CASE 
        WHEN z.vertrag_id IS NULL THEN 'Ohne Vertragszuordnung'
        ELSE 'Mit Vertrag, aber ohne Sollstellungszuordnung'
    END AS klaerfall_typ
FROM immo.zahlungseingang z
WHERE NOT EXISTS (
    SELECT 1 
    FROM immo.zahlungszuordnung zz 
    WHERE zz.zahlung_id = z.zahlung_id
)
AND z.betrag > 0;

-- ===== sql/17_v_nk_gutschriften.sql =====
-- NK-Gutschriften je Objekt (negative Nachforderungen)
CREATE OR REPLACE VIEW immo.v_nk_gutschriften AS
SELECT
    e.objekt_id,
    o.bezeichnung,
    COUNT(*) AS anzahl_gutschriften,
    ROUND(SUM(s.betrag)::numeric, 2) AS betrag_gutschriften
FROM immo.sollstellung s
JOIN immo.mietvertrag mv ON mv.vertrag_id = s.vertrag_id
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE s.storno = false
  AND s.betrag < 0
  AND s."position" = 'NK-Nachforderung'
GROUP BY e.objekt_id, o.bezeichnung;

-- ===== sql/18_v_mietanpassung_aktualitaet.sql =====
-- Monate seit letzter Mietanpassung gegen Soll-Zyklus
CREATE OR REPLACE VIEW immo.v_mietanpassung_aktualitaet AS
WITH letzte_anpassung AS (
    SELECT DISTINCT ON (ma.vertrag_id)
        ma.vertrag_id,
        ma.gueltig_ab AS letzte_anpassung_am
    FROM immo.mietanpassung ma
    ORDER BY ma.vertrag_id, ma.gueltig_ab DESC
),
basis AS (
    SELECT
        mv.vertrag_id,
        e.objekt_id,
        mv.vertragsbeginn,
        COALESCE(la.letzte_anpassung_am, mv.vertragsbeginn) AS bezugsdatum,
        (immo.stichtag() - COALESCE(la.letzte_anpassung_am, mv.vertragsbeginn)) / 30.44 AS monate_seit_anpassung
    FROM immo.mietvertrag mv
    JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
    LEFT JOIN letzte_anpassung la ON la.vertrag_id = mv.vertrag_id
    WHERE mv.vertragsstatus = 'aktiv'
      AND e.nutzungsart = 'Wohnen'
)
SELECT
    b.objekt_id,
    COUNT(*) AS anzahl_vertraege,
    ROUND(AVG(b.monate_seit_anpassung)::numeric, 1) AS oe_monate_seit_anpassung,
    pm.soll_zyklus_monate,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE b.monate_seit_anpassung > pm.soll_zyklus_monate) / COUNT(*), 1
    ) AS anteil_ueberfaellig_pct
FROM basis b
CROSS JOIN (
    SELECT soll_zyklus_monate FROM immo.parameter_mietzyklus
    ORDER BY gueltig_ab DESC LIMIT 1
) pm
GROUP BY b.objekt_id, pm.soll_zyklus_monate
ORDER BY oe_monate_seit_anpassung DESC;

-- ===== sql/19_v_mietanpassung_intervall.sql =====
-- Gemessener Abstand zwischen Mietanpassungen
CREATE OR REPLACE VIEW immo.v_mietanpassung_intervall AS
WITH anpassungen_sortiert AS (
    SELECT
        ma.vertrag_id,
        ma.gueltig_ab,
        LAG(ma.gueltig_ab) OVER (PARTITION BY ma.vertrag_id ORDER BY ma.gueltig_ab) AS vorherige_anpassung
    FROM immo.mietanpassung ma
),
intervalle AS (
    SELECT
        a.vertrag_id,
        e.objekt_id,
        (a.gueltig_ab - a.vorherige_anpassung) / 30.44 AS monate_zwischen_anpassungen
    FROM anpassungen_sortiert a
    JOIN immo.mietvertrag mv ON mv.vertrag_id = a.vertrag_id
    JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
    WHERE a.vorherige_anpassung IS NOT NULL
      AND e.nutzungsart = 'Wohnen'
)
SELECT
    objekt_id,
    COUNT(*) AS anzahl_intervalle,
    ROUND(AVG(monate_zwischen_anpassungen)::numeric, 1) AS oe_monate_zwischen_anpassungen,
    ROUND((AVG(monate_zwischen_anpassungen) / 12)::numeric, 2) AS oe_jahre_zwischen_anpassungen
FROM intervalle
GROUP BY objekt_id
ORDER BY oe_monate_zwischen_anpassungen;

-- ===== sql/20_v_gewerbe.sql =====
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

-- ===== sql/21_v_stellplaetze.sql =====
-- Stellplätze und Garagen
CREATE OR REPLACE VIEW immo.v_stellplaetze AS
SELECT
    mv.vertrag_id,
    mv.einheit_id,
    e.objekt_id,
    o.bezeichnung,
    e.nutzungsart,
    e.flaeche_qm,
    mv.vertragsstatus,
    mv.vertragsbeginn,
    mv.vertragsende,
    COALESCE(
        (SELECT ma.kaltmiete_neu
         FROM immo.mietanpassung ma
         WHERE ma.vertrag_id = mv.vertrag_id
         AND ma.gueltig_ab <= immo.stichtag()
         ORDER BY ma.gueltig_ab DESC
         LIMIT 1),
        mv.kaltmiete
    ) AS aktuelle_miete,
    -- Leerstand
    CASE
        WHEN EXISTS (
            SELECT 1 FROM immo.leerstand l
            WHERE l.einheit_id = e.einheit_id
            AND l.von <= immo.stichtag()
            AND (l.bis IS NULL OR l.bis >= immo.stichtag())
        ) THEN true
        ELSE false
    END AS leer
FROM immo.mietvertrag mv
JOIN immo.einheit e ON e.einheit_id = mv.einheit_id
JOIN immo.objekt o ON o.objekt_id = e.objekt_id
WHERE e.nutzungsart IN ('Stellplatz', 'Garage')
AND mv.vertragsstatus = 'aktiv'
ORDER BY e.nutzungsart, e.objekt_id;

-- ===== sql/22_v_flaechenabweichung.sql =====
-- Stammdatenfläche gegen Summe der Einheitenflächen
CREATE OR REPLACE VIEW immo.v_flaechenabweichung AS
SELECT
    o.objekt_id,
    o.bezeichnung,
    o.wohnflaeche_gesamt_qm AS flaeche_stammdaten,
    ROUND(SUM(e.flaeche_qm)::numeric, 2) AS flaeche_summe_einheiten,
    ROUND((o.wohnflaeche_gesamt_qm - SUM(e.flaeche_qm))::numeric, 2) AS abweichung_qm,
    ROUND(
        ((o.wohnflaeche_gesamt_qm - SUM(e.flaeche_qm)) * 100.0 / NULLIF(o.wohnflaeche_gesamt_qm, 0))::numeric, 2
    ) AS abweichung_pct
FROM immo.objekt o
JOIN immo.einheit e ON e.objekt_id = o.objekt_id
WHERE e.nutzungsart = 'Wohnen'
GROUP BY o.objekt_id, o.bezeichnung, o.wohnflaeche_gesamt_qm
ORDER BY abweichung_pct DESC;

-- ===== sql/23_v_datenkonsistenz.sql =====
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

-- ===== sql/99_v_auffaelligkeiten.sql =====
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
