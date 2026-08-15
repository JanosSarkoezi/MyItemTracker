# My Item Tracker

**My Item Tracker** ist ein leichtgewichtiges World of Warcraft Addon (optimiert für WotLK Client 3.3.5a), das das Inventar, die Bank sowie die Gildenbank-/Personalbank-Inhalte all deiner Charaktere automatisch scannt und in einer durchsuchbaren Übersicht zusammenfasst.

---

## Hauptfunktionen

- **Automatischer Inventar-Scan:** Scanned automatisch Taschen und normale Bankfächer beim Einloggen oder Öffnen der Bank.
- **Gildenbank- & Personalbank-Unterstützung:** Erfasst Bank-Tabs beim Öffnen des Gildenbank-Fensters inklusive intelligenter Entzerrung/Verzögerung (Debounce), um Mehrfachscans zu vermeiden.
- **Durchsuchbares UI:** Integrierte Suchleiste, um Gegenstände blitzschnell nach Item-Name oder Charakter-Name zu filtern.
- **Performantes Frame-Pooling:** Nutzt effizientes Recycling von Benutzeroberflächen-Zeilen für ruckelfreies Scrollen selbst bei Tausenden von erfassten Gegenständen.
- **Interaktive Tooltips:** Beim Fahren über eine Tabellenzeile wird der originale Spiel-Tooltip des Items angezeigt.
- **Accountweiter Speicher:** Speichert Daten über `SavedVariables` (`MyItemTrackerDB`) für den gesamten Account.

---

## Installation

1. Lade den Quellcode herunter.
2. Navigiere in dein World of Warcraft Addon-Verzeichnis:
   `World of Warcraft\_retail_\Interface\AddOns\` *(bzw. dein Pfad zur WotLK 3.3.5a Installation)*.
3. Erstelle einen Ordner namens `MyItemTracker`.
4. Platziere die Quelldateien (`MyItemTracker.toc`, `Core.lua`, `UI.lua`) in diesem Ordner.

### Ordnerstruktur
```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── MyItemTracker/
            ├── MyItemTracker.toc
            ├── Core.lua
            └── UI.lua

```

---

## Benutzung & Befehle

### UI-Befehle

| Befehl | Alternative | Beschreibung |
| --- | --- | --- |
| `/mytracker` | `/items` | Öffnet oder schließt das Übersichtsfenster. |
| `/mytracker scan` | `/items scan` | Führt manuell einen erneuten Scan der Taschen des aktuellen Charakters aus. |

---

## Funktionsweise im Detail

1. **Scans & Events:**
* Beim **Einloggen** wird dein Charakter-Inventar (Taschen 0–4) gescannt.
* Beim **Öffnen der normalen Bank** werden die Fächer (-1) sowie die Banktaschen (5–12) miterfasst.
* Beim **Öffnen der Gildenbank** werden alle verfügbaren Tabs durchleuchtet und abgespeichert.


2. **Datenkonsistenz:**
Vor jedem neuen Scan werden veraltete Daten des jeweiligen Charakters automatisch bereinigt, um Dubletten zu vermeiden.
3. **Übersicht:**
Über das Suchfenster kannst du in Echtzeit nach Gegenständen suchen. Die Ergebnisse zeigen den Item-Namen, den zugehörigen Charakter (oder Bank-Tab) und die genaue Anzahl an.
