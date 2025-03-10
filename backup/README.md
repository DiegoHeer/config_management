# Restic Profile backup usage

## Commands

[Required] Load environment variables

```bash
	set -a ; source .env ; set +a
```

Backup docker services data

```bash
	sudo -E resticprofile -n services backup
```

Backup S Tier data (critical data)

```bash
	sudo -E resticprofile -n s_tier backup
```

Backup A Tier data (large data, such as photos, media)

```bash
	sudo -E resticprofile -n a_tier backup
```
