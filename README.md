# Free Remote Commander VPS 1.2

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
