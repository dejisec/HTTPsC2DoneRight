# HTTPsC2DoneRight.sh

## Overview

`HTTPsC2DoneRight.sh` is a Bash script designed to set up TLS certificates for a specified domain using Certbot and Let's Encrypt.

## Requirements

* Root privileges
* A valid domain name with an A record already pointing to the server where the script is executed.

## Usage

Run the script with root privileges, providing the domain name and a password for the keystore as arguments:

```bash
sudo ./HTTPsC2DoneRight.sh --domain <domain> --password <password> [--verbose|--debug]
```

### Example

```bash
sudo ./HTTPsC2DoneRight.sh my.domain.com mySecurePassword
```

## Features

* Generates TLS certificates for the specified domain.
* Creates a Java keystore from the obtained certificates.

## Credit

<https://raw.githubusercontent.com/ad0nis/CobaltStrike-ToolKit/patch-1/HTTPsC2DoneRight.sh>
<https://github.com/FortyNorthSecurity/RandomScripts/blob/main/Cobalt%20Scripts/httpsc2doneright.sh>
