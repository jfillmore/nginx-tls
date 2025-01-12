# nginx-tls

Generates nginx configs to proxy various dev hostnames to the appropriate
"assigned" port. Also generates a self-signed certificate with a custom root CA.

Creates the following in the nginx config path you provide:

- nginx.conf
- ssl-includes.conf
- sites-available/*.conf  # based on `sites/`
- sites-enabled/* -> ../sites-available/  # symlinks to each site, as wanted
- paladin-co.{key,crt}  # self-signed cert; signed with `acme-fake-ca.{crt,key}`

Use `--pki-only` to ignore the nginx stuff. The CA/host certificates will
automatically be renewed if expired.


## Quick start:

```sh
# Prep
cp openssl-crt.example.config openssl-crt.config
vim openssl-crt.config  # edit hostnames

# Run it!
./gen-conf.sh -v ~/path/to/nginx-dir
```


## Trusting the WebDev Root CA

Adding trust will allow your browser, command-line utils (e.g. curl) and other
programs to trust the self-signed certificates. No more pesky security warnings!

### Mac

1. Launch the "Keychain Access" app
2. Click on the "login" Keychain on the left nav
3. In the main menu, use "File" > "Import Items..." to select "acme-fake-ca.crt"
4. In the top-right corner, search for "paladin-co" to locate the certificate
5. Right-click the certificate and click "Get Info"
6. Expand the "Trust" drop-down and set "When using this certificate:" to "Always Trust"
7. Close the pop-up certificate details window and you'll be prompted for your password
