# New Server Deployment

Run the interactive bootstrap script from the repo root:

```bash
bash scripts/new_server.sh
```

The script will:
1. Check pre-requisites (`.vault_key`, SSH key)
2. Prompt for the new server's IP and update `inventory.yml`
3. Test SSH connectivity
4. Install Python and Ansible Galaxy dependencies
5. Optionally run the playbook
