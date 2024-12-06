morbo api.pl

# to specify custom URLs for UDPipe and NameTag, run, e.g.:
# morbo -- api.pl --url-udpipe https://lindat.mff.cuni.cz/services/udpipe/api --url-nametag https://lindat.mff.cuni.cz/services/nametag/api

exit


<<COMMENT

REST API implementováno v Perlu pomocí knihovny Mojolicious::Lite, spouští se pomocí příkazu morbo api.pl.

Aby REST API služba fungovala nezávisle na terminálu a i po restartu počítače: použití process manager a service pro správu běhu.

Konfigurační soubor pro Systemd: (`/etc/systemd/system/my-api.service`):

   ```
   [Unit]
   Description=My API Service

   [Service]
   ExecStart=/usr/bin/morbo /cesta/k/tvemu/api.pl
   WorkingDirectory=/cesta/k/tvemu
   Restart=always
   User=tvoje-uzivatelske-jmeno

   [Install]
   WantedBy=multi-user.target
   ```

   Nastavit cestu k `api.pl`, pracovní adresář, uživatelské jméno a další parametry podle potřeby.

Aktivace a spuštění služby:

Po vytvoření konfigurace:

   ```
   sudo systemctl daemon-reload
   sudo systemctl enable my-api
   sudo systemctl start my-api
   ```

Služba se začne automaticky spouštět při startu systému a bude se také automaticky restartovat v případě selhání.

Správa služby:

   ```
   sudo systemctl status my-api
   sudo systemctl stop my-api
   sudo systemctl restart my-api
   ```

REST API je takto spuštěna jako systémová služba, která bude fungovat nezávisle na terminálu a bude se také automaticky restartovat po restartu počítače.

===========
Pozn.
Vstupní body služby REST API (např. info, process) je potřeba nastavit také v konfiguraci serveru Apache:
/etc/apache2/sites-available/000-default.conf, např.:

        # Proxy pro /api/process a /api/info
        ProxyPass "/api/process" "http://localhost:3000/api/process"
        ProxyPassReverse "/api/process" "http://localhost:3000/api/process"
        ProxyPass "/api/info" "http://localhost:3000/api/info"
        ProxyPassReverse "/api/info" "http://localhost:3000/api/info"

a pak provést
  sudo service apache2 restart

COMMENT
