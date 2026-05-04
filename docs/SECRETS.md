# Secrets Management

Secrets are managed with [agenix](https://github.com/ryantm/agenix):

- **Encrypted secrets**: `secrets/*.age` (gitignored, Syncthing-synced)
- **Encryption rules**: `secrets/secrets.nix` (tracked — maps public keys to secret files)
- **Identity**: host SSH key at `/etc/ssh/ssh_host_ed25519_key`
- **Configuration**: `parts/security/agenix.nix`

## Setup

```bash
# 1. Ensure the host has an SSH ed25519 key (NixOS generates one by default)
cat /etc/ssh/ssh_host_ed25519_key.pub

# 2. Add the public key to secrets/secrets.nix
#    (already tracked in git — edit and commit)

# 3. Encrypt a new secret
agenix -e secrets/<name>.age

# 4. Reference in a module
myModules.security.agenix.secrets.<name> = {};
# Access at: config.age.secrets.<name>.path
```

## Recovery

Secrets are encrypted to each host's SSH public key. If the host SSH key is lost:

1. Generate a new host key (`ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key`)
2. Update `secrets/secrets.nix` with the new public key
3. Re-encrypt all secrets: `agenix --rekey`

The `.age` files are **not tracked in git** (belt-and-suspenders against host-key compromise exposing historical secrets). They are synced to each host via Syncthing.

For Secure Boot setup and recovery after BIOS updates, see [secure-boot.md](secure-boot.md). For installation from a live USB, see [installation.md](installation.md).
