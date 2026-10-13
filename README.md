# Kennzahlen-Layer Hausverwaltung (PostgreSQL, Schema `immo`)

SQL-Views für das Hausverwaltungs-Reporting mit Ladeskript für CSV-Dateien. Stand: Testbestand, Stichtag 31.08.2026.
Views und Kontrollwerte: geprüft mit PostgreSQL 17 am vollständigen Testbestand. Ladeskript und Installation: zusätzlich mit Beispielzeilen unter PostgreSQL 16 ausgeführt. Es sind keine Erweiterungen nötig.

## Inhalt
| Datei / Ordner | Zweck |
|---|---|
| `basis_schema.sql` | Alle 18 Tabellen im Schema `immo` (nur Struktur) |
| `load/` | Ladeskript für die CSV-Dateien (Zwischenschicht `stg`, dann Übernahme nach `immo`) |
| `sql/` | Die Views und die Parameter, eine Datei je View, nummeriert in Laufreihenfolge |
| `install_alle.sql` | Alle Dateien aus `sql/` in einer Datei |
| `kontrollwerte.sql` | Prüfwerte auf dem Testbestand |
| `kontrollwerte_je_objekt.sql` | Soll-Werte je Objekt (nur Testbestand); erwartet: keine Zeile |
| `pflichtfelder.md` | Welche Tabellen und Felder jede Kennzahl braucht |

## Aufsetzen von Null
Voraussetzung: PostgreSQL-Client `psql` und ein Server. Die CSV-Dateien (Semikolon, UTF-8, Dezimalkomma, `ja`/`nein` für Wahrheitswerte, Kopfzeile) liegen im Ordner `daten/` neben `load/`. Alle Befehle aus dem Paketordner ausführen. Unter Windows (PowerShell) vorher `psql` bekannt machen und die Kodierung setzen, sonst werden Umlaute in den Skripten falsch gelesen:

```
$env:Path += ";C:\Program Files\PostgreSQL\17\bin"
$env:PGCLIENTENCODING = "UTF8"
createdb -h localhost -U postgres hausverwaltung
psql -h localhost -U postgres -d hausverwaltung -f basis_schema.sql
psql -h localhost -U postgres -d hausverwaltung -f load/laden.sql
psql -h localhost -U postgres -d hausverwaltung -f install_alle.sql
psql -h localhost -U postgres -d hausverwaltung -f kontrollwerte.sql
psql -h localhost -U postgres -d hausverwaltung -f kontrollwerte_je_objekt.sql
```

Verbindungsdaten (Server, Port, Benutzer, Datenbank) stehen nur in diesen Befehlen und im Power-BI-Parameter. In den SQL-Dateien stehen keine Verbindungsdaten.

## Einstellungen an einer Stelle
| Einstellung | Tabelle | Standard |
|---|---|---|
| Stichtag | `immo.parameter_stichtag` | 31.08.2026 |
| Karenztage | `immo.parameter_karenz` | 5 Tage, je Objekt überschreibbar |
| Soll-Mietzyklus | `immo.parameter_mietzyklus` | 24 Monate |

Stichtag ändern: `UPDATE immo.parameter_stichtag SET stichtag = DATE '2026-09-30';`
Alle Views lesen ihn über `immo.stichtag()`. Fluktuationsjahre und Vorjahr werden daraus abgeleitet. In den Marktmieten muss es eine Zeile für das Jahr des Stichtags geben.

## Eigene Daten laden
1. `load/01_stg_tabellen.sql` legt für jede Tabelle eine Zwischentabelle in `stg` an (alle Spalten als Text).
2. Eigene Quelldaten werden in diese Tabellen geladen. Die Spaltenzuordnung steht in `pflichtfelder.md`.
3. `load/03_nach_immo.sql` wandelt Dezimalkomma, `ja`/`nein` und leere Felder um und schreibt nach `immo`.

**Achtung:** `load/03_nach_immo.sql` leert zuerst die 18 Tabellen in `immo`. Parameter und Views bleiben unberührt.

## Datenqualitätsprüfungen
- `v_datenkonsistenz`: unvollständige Stornoketten, aktiver Vertrag bei offenem Leerstand, fehlende oder unplausible Fläche, Klärfälle
- `v_flaechenabweichung`: Stammdatenfläche gegen Summe der Einheiten
- `v_klaerfaelle`: Zahlungen ohne Zuordnung

## Definitionen
- Quoten werden als Summe Zähler ÷ Summe Nenner berechnet, nicht als Durchschnitt der Objektquoten.
- Forderungen: Karenztage werden von der Überfälligkeit abgezogen, Stornozeilen sind ausgeschlossen. Aging-Klassen: nicht überfällig, 01-30, 31-60, 61-90, über 90 Tage.
- Leerstand wirtschaftlich: entgangene Sollmiete ÷ theoretische Gesamtmiete, ohne sanierungsbedingten Leerstand (separat in `v_leerstand_sanierung`).
- Instandhaltung €/m²: Instandhaltung + Instandsetzung netto ÷ Stammdatenfläche. Richtwert 15 €/m², Modernisierung separat. Ausreißer: Aufträge über 1.500 € netto.
- NK-Gutschriften werden getrennt ausgewiesen und nicht mit Forderungen verrechnet.
- Die Views zeigen Einzelfälle nur mit Vertrags- oder Einheitsnummer, nicht mit Namen.

## Bekannte Einschränkungen
- Das Jahr 2023 ist in `v_instandhaltung_benchmark` als Rumpfjahr markiert (Datenbeginn).
- Die Spaltennamen `…_2025` in `v_auffaelligkeiten` sind historisch. Inhaltlich ist es das Vorjahr des Stichtags.
- Mietanpassung: gemessener Abstand im Schnitt 3,3 Jahre gegen 1,5 Jahre erwartet, Ursache ungeklärt.
- Keine Mandatsebene: Auswertung nur je Objekt.
