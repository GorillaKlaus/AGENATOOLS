# Inventar

iPhone-Web-App zum Verwalten von **Logins**, **ausgegebener Hardware** und **SIM-Karten**.

- Alles läuft lokal auf dem Gerät, kein Server, keine Cloud.
- Daten sind mit einem Master-Passwort verschlüsselt (AES-256-GCM, Schlüssel per PBKDF2-SHA256, 600.000 Iterationen).
- Automatische Sperre nach Inaktivität bzw. wenn die App im Hintergrund war.
- Passwort-Generator, Kopieren per Tipp, Suche, Status-Filter, Personenübersicht („wer hat was?“).
- SIM-Karten lassen sich einem Gerät zuordnen.
- Verschlüsseltes Backup exportieren/importieren (z. B. in die Dateien-App / iCloud Drive).

## Auf dem iPhone installieren

Die App muss über **HTTPS** ausgeliefert werden (sonst ist die Verschlüsselung im Browser nicht verfügbar), z. B. per GitHub Pages:

1. Im Repo unter *Settings → Pages* als Quelle den Branch wählen, Ordner `/ (root)`.
2. Auf dem iPhone in **Safari** `https://<user>.github.io/<repo>/inventar/` öffnen.
3. *Teilen → Zum Home-Bildschirm*.

Als Home-Bildschirm-App funktioniert sie offline und iOS löscht die gespeicherten Daten nicht automatisch.
Trotzdem regelmäßig ein Backup exportieren – das Master-Passwort ist nicht wiederherstellbar.
