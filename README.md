# Free Remote Commander VPS 1.2

## Hinweis fuer Docker Engine 29 (VPS 1.2)

Das bisherige Installationsskript kombiniert ein internes Docker-Netzwerk mit Port-Publishing. Bei diesem VPS fuehrt dies zu einem fehlenden Host-Port und einem fehlgeschlagenen lokalen Healthcheck. Das ist **kein Fehler des Wardogs-Containers**.

Fuer eine bereits erfolgte Installation (Image gebaut, Container `frc-vps-folder-12` gestartet) gibt es den einzeln getesteten Reparatur-Helfer [fix.sh](./fix.sh) ([Quelltext](./repair-connectivity.sh)). Er **behaelt Backend, internes Netzwerk, Workspace und .env** und erstellt nur einen separaten, auf `127.0.0.1:17887` gebundenen Proxy-Container in einem eigenen Bridge-Netzwerk. Der Proxy bekommt keinen Host-Dateisystem- oder Docker-Socket-Zugriff.

```bash
cd /root/free-remote-commander-vps
curl -fL -o fix.sh https://raw.githubusercontent.com/redshoxx/free-remote-commander-vps/main/fix.sh
sha256sum fix.sh  # vor dem Ausfuehren mit veroeffentlichtem SHA-256-Wert vergleichen
bash fix.sh
bash scripts/verify.sh
```

SHA-256 fuer `fix.sh`: `237bdef354b263e18bd4d73e869acf926a3cf37176d1ca1722bf77d0a12d624e`.

**Wichtig:** Der Reparatur-Helfer ist lokal auf Syntax und Proxy-Funktionen getestet, aber noch nicht auf dem VPS Docker 29. Kein geheimer MCP-Link darf oeffentlich freigegeben werden.


Isolierter MCP-Server für **einen neu angelegten Arbeitsordner** auf Ubuntu 24.04 mit Docker Engine >= 28. `docker compose` ist **nicht** erforderlich. Kein Root-SSH, keine Shell-/Prozess-Tools, keine Host-Verzeichnisse außerhalb des Workspace.

**Status:** Lokal mit 15 automatisierten Tests geprüft. Noch **nicht** auf dem produktiven VPS installiert oder dort verifiziert. Die Veröffentlichung dieses Repositorys installiert nichts.

## Prüfen und installieren (Netcup-VNC-Konsole)

Der Download stammt aus dem hier veröffentlichten Repository. Die Prüfsumme schützt gegen unbemerkte Veränderungen während des Downloads.

```bash
cd /root
curl -fL --proto '=https' --tlsv1.2 -o Free-Remote-Commander-VPS-Ubuntu-1.2.tar.gz \
  https://raw.githubusercontent.com/redshoxx/free-remote-commander-vps/main/Free-Remote-Commander-VPS-Ubuntu-1.2.tar.gz
echo 'e1061a31d96c17dd96676e696499801dd64275e2cd55441b8d28a4cadb75969b  Free-Remote-Commander-VPS-Ubuntu-1.2.tar.gz' | sha256sum -c -
tar -xzf Free-Remote-Commander-VPS-Ubuntu-1.2.tar.gz
cd free-remote-commander-vps
```

**Vor dem Start:** `less README.md` sowie `less scripts/install.sh` lesen. Nur ausführen, wenn du Docker-Zugang auf dem VPS autorisiert hast und die Sicherheitsvoraussetzungen stimmen.

```bash
bash scripts/install.sh
bash scripts/verify.sh
```

Der Installer erstellt ausschließlich den eigenen Container `frc-vps-folder-12`, das interne Netzwerk `frc-vps-internal-12` und einen **neuen** leeren Workspace. Er stoppt weder den bestehenden `nolimits-wardogs-v2`-Container noch aktualisiert er Docker oder verändert Nginx/PostgreSQL/Firewall.

Der MCP-Port wird auf `127.0.0.1:17887` gebunden. **Keine öffentliche Freigabe vor erfolgreicher Prüfung und gesonderter Authentifizierungsplanung!** Die zufällig generierte .env-Datei und der vollständige MCP-Pfad müssen geheim bleiben.

**Rückbau:** `bash scripts/uninstall.sh` im entpackten Projekt. Entfernt nur den eigenen Container/das eigene Netzwerk; eigene Dateien bleiben bestehen.

## Archivdatei

- [Paket herunterladen](https://raw.githubusercontent.com/redshoxx/free-remote-commander-vps/main/Free-Remote-Commander-VPS-Ubuntu-1.2.tar.gz)
- SHA-256: `e1061a31d96c17dd96676e696499801dd64275e2cd55441b8d28a4cadb75969b`

Die ausführlichen Anleitungen und Quellcode-Dateien befinden sich im Paket. Keine Zugangsdaten/Secrets sind enthalten.

### Korrektur der Laufzeitpruefung nach Docker-29-Proxy-Reparatur

Die aktualisierte Projektwurzel-Version von `verify-fixed.sh` behebt zusaetzlich die irrtuemliche Meldung `Missing .env: install first`. Das urspruengliche `scripts/verify.sh` kann bei Schritt 7 abbrechen, obwohl der Port funktioniert: `ss` sieht Docker-NAT nicht in allen Konfigurationen. Nutze im bereits installierten Verzeichnis stattdessen das **nur lesende** [verify-fixed.sh](./verify-fixed.sh), das die tatsaechliche Docker-Portbindung sowie Proxy-Isolation, Backend-Mounts und Netzwerke prueft:

```bash
curl -fL -o verify-fixed.sh https://raw.githubusercontent.com/redshoxx/free-remote-commander-vps/main/verify-fixed.sh
curl -fL -o verify-fixed.sha256 https://raw.githubusercontent.com/redshoxx/free-remote-commander-vps/main/verify-fixed.sha256
sha256sum -c verify-fixed.sha256
bash verify-fixed.sh
```

Erwartete SHA-256: `d65d20b53dfa72c278ea32eaf89ea3905e7995b40fd30943c7b51fdd5229cd4b`. Das Skript aendert keine Container, Netzwerke oder Firewall-Einstellungen. Der lokale Test bestand bei gueltigem Docker-Mock und schlug bei absichtlich unsicherer Bindung wie erwartet fehl. **Der echte VPS-Test steht bis zur Ausfuehrung noch aus.**
