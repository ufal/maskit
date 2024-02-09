morbo api.pl

exit

<<COMMENT

Svoji službu REST API implementovanou v perlu pomocí knihovny Mojolicious::Lite spouštím na serveru pomocí příkazu morbo api.pl. Potřeboval bych, aby ta služba fungovala nezávisle na terminálu a pokud možno i po restartu počítače. Jak se toto řeší?


Abyste zajistil, že vaše REST API služba implementovaná v Perl s knihovnou Mojolicious::Lite bude fungovat nezávisle na terminálu a i po restartu počítače, můžete využít několik přístupů. Jedním z možných řešení je použití procesního správce (process manager) a služby (service) pro správu běhu vaší aplikace.

Zde je návod, jak postupovat:

1. **Přesunout kód API do samostatného souboru:**
   Nejprve přesuňte kód vašeho REST API implementovaného pomocí Mojolicious::Lite do samostatného souboru, například `api.pl`. Ujistěte se, že váš kód obsahuje všechny potřebné moduly a nastavení.

2. **Instalovat službu pro správu procesů:**
   Na systému, kde chcete spouštět svoji službu, by měl být k dispozici nějaký procesní správce. Pro unixové systémy je jednou z běžných možností [Systemd](https://www.freedesktop.org/wiki/Software/systemd/), který umožňuje definovat a spravovat systémové služby.

3. **Vytvoření konfiguračního souboru pro službu:**
   Vytvořte konfigurační soubor pro vaši službu. Pro Systemd může vypadat nějak takto (`/etc/systemd/system/my-api.service`):

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

   Upravte cestu k `api.pl`, pracovní adresář, uživatelské jméno a další parametry podle vašeho nastavení.

4. **Aktivace a spuštění služby:**
   Po vytvoření konfigurace spusťte následující příkazy:

   ```
   sudo systemctl daemon-reload
   sudo systemctl enable my-api
   sudo systemctl start my-api
   ```

   Tímto se služba začne automaticky spouštět při startu systému a bude se také automaticky restartovat v případě selhání.

5. **Správa služby:**
   Službu lze spravovat pomocí příkazů `systemctl`, např.:

   ```
   sudo systemctl status my-api
   sudo systemctl stop my-api
   sudo systemctl restart my-api
   ```

Tímto způsobem byste měl mít svoji REST API službu spuštěnou jako systémovou službu, která bude fungovat nezávisle na terminálu a bude se také automaticky restartovat po restartu počítače.

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
  sudo service apache restart

COMMENT
