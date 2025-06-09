# SSL Proxy Add-on

This add-on provides SSL-terminating reverse proxy functionality for HTTP services, allowing them to be used in Home Assistant ingress iframe mode without mixed content issues.

## Configuration

```yaml
services:
  - name: "unraid"
    target_host: "192.168.178.93"
    target_port: 80
    ssl_port: 8443
    domain: "unraid.local"
    remove_csp: true
    websocket_support: true
```

## Usage

1. Install and configure the add-on
2. Start the add-on
3. Use the SSL endpoint in your ingress configuration:

```yaml
ingress:
  unraid:
    title: Unraid
    icon: mdi:server
    work_mode: iframe
    ui_mode: normal
    require_admin: true
    url: https://unraid.local:8443/
```

## Options

- `name`: Unique identifier for the service
- `target_host`: IP address of the target service
- `target_port`: Port of the target service
- `ssl_port`: Port for the SSL proxy to listen on
- `domain`: Domain name for the SSL certificate
- `remove_csp`: Remove Content Security Policy headers (for iframe compatibility)
- `websocket_support`: Enable WebSocket proxying

## Installation Instructions

1. Add this repository to your Home Assistant instance:
   - Go to **Settings** → **Add-ons** → **Add-on Store**
   - Click the menu (⋮) → **Repositories**
   - Add the URL of this repository
   
2. Install the SSL Proxy add-on from the add-on store
   
3. Configure the add-on with your services:
   ```yaml
   services:
     - name: "unraid"
       target_host: "192.168.178.93"
       target_port: 80
       ssl_port: 8443
       domain: "unraid.local"
       remove_csp: true
       websocket_support: true
   ```

4. Start the add-on

5. Update your Home Assistant configuration to use the HTTPS endpoints

## Troubleshooting

If you encounter the "not a valid add-on repository" error when adding this repository, make sure:

1. The repository is public on GitHub
2. It contains a valid repository.yaml file in the root directory
3. The repository structure follows Home Assistant's add-on requirements
