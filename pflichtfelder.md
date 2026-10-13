# Pflichtfelder je Kennzahl

Welche Tabellen und Felder jede Kennzahl mindestens braucht und was sie fachlich bedeuten. So lässt sich eine fremde Datenstruktur auf dieses Schema abbilden.
Stand: Testbestand, Stichtag 31.08.2026. Die Spaltentypen stehen in `basis_schema.sql`.

| Kennzahl (View) | Tabellen und Felder | Fachliche Bedeutung |
|---|---|---|
| Aktuelle Miete (`v_aktuelle_miete`) | `mietvertrag`: vertrag_id, einheit_id, kaltmiete, nk_vorauszahlung, hk_vorauszahlung, mietart, ust_option, vertragsstatus. `einheit`: einheit_id, objekt_id, nutzungsart, flaeche_qm. `mietanpassung`: vertrag_id, gueltig_ab, kaltmiete_neu. `vz_anpassung`: vertrag_id, gueltig_ab, nk_neu, hk_neu | Miete zum Stichtag. Gilt die letzte Anpassung mit Datum bis zum Stichtag, sonst die Kaltmiete bei Vertragsbeginn. NK und HK entsprechend. |
| Leerstand (`v_leerstand`, `v_leerstand_wirtschaftlich`) | `einheit`: einheit_id, objekt_id, nutzungsart (Wohnen), flaeche_qm. `leerstand`: einheit_id, von, bis, grund, sollmiete_potenziell. Dazu die aktuelle Miete | Eine Einheit ist leer, wenn am Stichtag von ≤ Stichtag und bis leer oder ≥ Stichtag. Sanierungsbedingter Leerstand zählt hier nicht. Wirtschaftliche Quote: entgangene Sollmiete ÷ theoretische Gesamtmiete. |
| Sanierungsleerstand (`v_leerstand_sanierung`) | `leerstand`: einheit_id, von, bis, grund, sollmiete_potenziell. `einheit`: objekt_id | Laufender Leerstand mit `grund = sanierungsbedingt`, getrennt ausgewiesen. |
| Leerstandsdauer (`v_leerstandsdauer`) | `mietvertrag`: vertrag_id, einheit_id, vertragsbeginn, vertragsende. `einheit`: objekt_id, nutzungsart (Wohnen) | Tage zwischen dem Ende eines Vertrags und dem Beginn des nächsten Vertrags derselben Einheit. |
| Fluktuation (`v_fluktuation`) | `mietvertrag`: vertrag_id, einheit_id, vertragsende, vertragsstatus (beendet, gekündigt). `einheit`: objekt_id, nutzungsart (Wohnen) | Beendete Verträge je Jahr des Vertragsendes ÷ Wohneinheiten des Objekts. |
| Forderungen und Aging (`v_forderungen_aging`, `_position`, `_gewerbe`, `_saldo`) | `sollstellung`: sollstellung_id, vertrag_id, periode, faelligkeit, position, betrag, storno. `zahlungszuordnung`: sollstellung_id, betrag. `mietvertrag`: vertrag_id, einheit_id. `einheit`: objekt_id, nutzungsart | Offen = Sollbetrag minus zugeordnete Zahlungen. Stornozeilen und negative Beträge sind ausgeschlossen. Überfällig seit: Stichtag − Fälligkeit − Karenztage. |
| Klärfälle (`v_klaerfaelle`) | `zahlungseingang`: zahlung_id, buchungsdatum, betrag, zahlungsart, vertrag_id. `zahlungszuordnung`: zahlung_id | Zahlungen mit positivem Betrag, die keiner Sollstellung zugeordnet sind. |
| NK-Gutschriften (`v_nk_gutschriften`) | `sollstellung`: vertrag_id, position (NK-Nachforderung), betrag (negativ), storno | Gutschriften aus der Nebenkostenabrechnung. Sie werden nicht mit Forderungen verrechnet. |
| Mietanpassung (`v_mietanpassung_aktualitaet`, `_intervall`) | `mietanpassung`: vertrag_id, gueltig_ab. `mietvertrag`: vertrag_id, einheit_id, vertragsbeginn, vertragsstatus. `einheit`: nutzungsart (Wohnen) | Monate seit der letzten Anpassung (ohne Anpassung seit Vertragsbeginn) gegen den Soll-Zyklus. Intervall = Abstand zweier Anpassungen. |
| Marktvergleich (`v_marktvergleich`) | Aktuelle Miete (siehe oben). `objekt`: plz, lagequalitaet. `marktmiete`: plz, lagequalitaet, jahr, nutzungsart, median_eur_qm, spanne_unten, spanne_oben | Ist-Miete je m² gegen den Marktmedian derselben PLZ, Lage und Nutzung im Jahr des Stichtags. Nur aktive Verträge, Fläche über 15 m². |
| Gewerbe (`v_gewerbe`) | `mietvertrag`: vertrag_id, einheit_id, mietart, ust_option, vertragsstatus, vertragsbeginn, vertragsende, befristet_bis, kaltmiete. `einheit`: flaeche_qm, nutzungsart (Gewerbe). `mietanpassung`: vertrag_id, gueltig_ab, kaltmiete_neu. `vpi_index`: monat, indexwert | Nettomiete (USt herausgerechnet bei ust_option), €/m², Indexpotenzial: VPI zum Stichtag gegen VPI im Monat der letzten Anpassung. |
| Stellplätze (`v_stellplaetze`) | `mietvertrag`, `einheit` (nutzungsart Stellplatz oder Garage), `mietanpassung`, `leerstand` | Aktive Stellplatz- und Garagenverträge mit aktueller Miete und Leerstandskennzeichen. |
| Instandhaltung (`v_instandhaltung`, `_benchmark`, `_rollierend`, `_ausreisser`) | `instandhaltung`: auftrag_id, objekt_id, kostenart, rechnungsdatum, netto, brutto. `objekt`: bezeichnung, wohnflaeche_gesamt_qm | Netto je m² Stammdatenfläche. Benchmark: Instandhaltung + Instandsetzung, Modernisierung separat. Ausreißer: Aufträge über 1.500 € netto. |
| Flächenabweichung (`v_flaechenabweichung`) | `objekt`: wohnflaeche_gesamt_qm. `einheit`: flaeche_qm, nutzungsart (Wohnen) | Stammdatenfläche gegen Summe der Einheitenflächen. |
| Datenkonsistenz (`v_datenkonsistenz`) | `sollstellung`: storno, storno_ref. `leerstand`: bis. `mietvertrag`: vertragsstatus. `einheit`: flaeche_qm. Klärfälle | Datenqualitätshinweise: unvollständige Stornoketten, aktiver Vertrag bei offenem Leerstand, fehlende oder unplausible Fläche, Klärfälle. |
| Auffälligkeiten (`v_auffaelligkeiten`) | Fasst die obigen Views je Objekt zusammen | Eine Zeile je Objekt mit den wichtigsten Kennzahlen des Vorjahres bzw. Stichtags. |

Zahlen- und Datumsformate im Schema: Beträge als Dezimalzahl, Daten als `JJJJ-MM-TT`, `periode` und `monat` als `JJJJ-MM`. Nur `instandhaltung.rechnungsdatum` ist Text und darf `TT.MM.JJJJ` oder `JJJJ-MM-TT` enthalten.

## Dieselbe Liste je Tabelle

| Tabelle | Benötigte Spalten | Hinweise zu den Werten |
|---|---|---|
| `objekt` | objekt_id, bezeichnung, plz, lagequalitaet, wohnflaeche_gesamt_qm | `plz` und `lagequalitaet` müssen zu `marktmiete` passen. Die Fläche ist die Stammdatenfläche (Wohnen). |
| `einheit` | einheit_id, objekt_id, nutzungsart, flaeche_qm | `nutzungsart`: Wohnen, Gewerbe, Stellplatz, Garage. Fläche über 15 m² für den Marktvergleich. |
| `mietvertrag` | vertrag_id, einheit_id, vertragsbeginn, vertragsende, befristet_bis, kaltmiete, nk_vorauszahlung, hk_vorauszahlung, mietart, ust_option, vertragsstatus | `vertragsstatus`: aktiv, beendet, gekündigt. `kaltmiete` ist der Wert bei Vertragsbeginn. |
| `mietanpassung` | vertrag_id, gueltig_ab, kaltmiete_neu | Historie. Die aktuelle Miete ist die letzte Anpassung bis zum Stichtag. |
| `vz_anpassung` | vertrag_id, gueltig_ab, nk_neu, hk_neu | Historie der NK-/HK-Vorauszahlungen. |
| `leerstand` | leerstand_id, einheit_id, von, bis, grund, sollmiete_potenziell | `grund = sanierungsbedingt` wird separat ausgewiesen. `bis` leer = laufender Leerstand. |
| `sollstellung` | sollstellung_id, vertrag_id, periode, faelligkeit, position, betrag, storno, storno_ref | `periode` im Format JJJJ-MM. Stornozeilen: storno = true, negativer Betrag. NK-Gutschriften: Position `NK-Nachforderung` mit negativem Betrag. |
| `zahlungseingang` | zahlung_id, buchungsdatum, betrag, zahlungsart, vertrag_id | `vertrag_id` darf leer sein (Klärfall). |
| `zahlungszuordnung` | zahlung_id, sollstellung_id, betrag | Verknüpft Zahlungen mit Sollstellungen (n:m). |
| `instandhaltung` | auftrag_id, objekt_id, kostenart, rechnungsdatum, netto, brutto | `kostenart`: Instandhaltung, Instandsetzung, Modernisierung. `rechnungsdatum` als Text im Format TT.MM.JJJJ oder JJJJ-MM-TT. |
| `marktmiete` | plz, lagequalitaet, jahr, nutzungsart, median_eur_qm, spanne_unten, spanne_oben | Es muss eine Zeile für das Jahr des Stichtags geben, sonst fehlt der Marktvergleich. |
| `vpi_index` | monat, indexwert | `monat` im Format JJJJ-MM. Der Monat des Stichtags muss vorhanden sein. |

## Tabellen, die die Views nicht lesen

`betriebskosten`, `dienstleister`, `kaution`, `mahnung`, `nk_abrechnung`, `mietpartei`.

Sie sind im Schema vorhanden, weil Fremdschlüssel darauf verweisen oder die Quelle sie liefert. Die Kennzahlen hängen nicht von ihnen ab.

## Personenbezogene Felder

Die Views lesen keine Namen, Telefonnummern, E-Mail-Adressen oder Verwendungszwecke.
- `mietpartei` (Name, Vorname, Telefon, E-Mail) wird nur über den Fremdschlüssel `mietvertrag.mietpartei_id` gebraucht. Dort genügt eine ID, die Namensfelder können anonymisiert werden.
- `zahlungseingang.verwendungszweck` wird nicht gelesen und kann leer bleiben.

## Prüfung nach dem Laden

Nach der Installation `kontrollwerte.sql` ausführen. Die ersten beiden Zeilen (Objekte, Einheiten) und die Anzahl der Wohneinheiten sind mit den eigenen Stammdaten zu vergleichen. Die übrigen Sollwerte gelten nur für den Testbestand.
