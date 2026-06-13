# gogcli (Google CLI) Authentication Setup for OpenClaw

This guide covers the one-time setup of `gogcli` authentication for an OpenClaw instance so your agent can interact with Google services (Gmail, Calendar, Drive, Docs, Sheets, Contacts, etc.).

## What you need to provide

A single **OAuth Desktop client secret JSON file** downloaded from the [Google Cloud Console](https://console.cloud.google.com). This is the only manual step — everything after that is automated by `scripts/openclaw-life-gog-auth`.

> **Note:** The OAuth client secret identifies your "app" to Google. You create **one** client secret per Google Cloud project and can reuse it across multiple OpenClaw instances and Google accounts. You do **not** need a new client secret for every instance.

---

## Step 1 — Create a Google Cloud project (once)

1. Open [https://console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate).
2. Give it a name (e.g. `openclaw-gog`). You can use the same project for all your agents.

## Step 2 — Enable the Google APIs you need

1. Go to [API Library](https://console.cloud.google.com/apis/library).
2. Enable each API your agents will use:
   - **Gmail API** — if you want to read/search email
   - **Google Calendar API** — calendar events and scheduling
   - **Google Drive API** — file access and management
   - **Google Docs API** — document editing
   - **Google Sheets API** — spreadsheet access
   - **People API** — contacts
   - *(Any others you plan to use)*

## Step 3 — Configure the OAuth consent screen

1. Go to [OAuth consent screen](https://console.cloud.google.com/auth/consent).
2. Select **External** as the user type.
3. Fill in the basic app info:
   - **App name:** whatever you want (e.g. `OpenClaw Gog`)
   - **User support email:** your email
   - **Developer contact information:** your email
4. **Scopes** — skip adding scopes here for now; `gog` will request them dynamically at auth time.
5. Finish the wizard.

> **Important:** Before you authorize — and especially if you will be re-authenticating frequently — publish the app to **"In production"** so your refresh tokens do not expire after 7 days.
> - Go to [Audience](https://console.cloud.google.com/auth/audience) in the same project.
> - Under **Publishing status**, click **Publish app** → **Confirm**.
> - This does **not** trigger Google verification; it simply stops the 7-day refresh-token death spiral for a personal-use app.

## Step 4 — Create a Desktop OAuth client

1. Go to [Credentials](https://console.cloud.google.com/auth/clients).
2. Click **Create credentials** → **OAuth client ID**.
3. Select **Application type: Desktop app**.
4. Give it a name (e.g. `openclaw-desktop`).
5. Click **Create**.
6. Click **Download JSON**.

The downloaded file will have a name like:

```
client_secret_2_960008870215-7co0rmvurhhddnilma235fsrj12pm2kr.apps.googleusercontent.com.json
```

## Step 5 — Place the file in the instance data directory

Move or copy the downloaded file into the **host-side** data directory for your OpenClaw instance:

```bash
# For an instance named "henry"
cp ~/Downloads/client_secret_2_*.json \
   ~/.openclaw-life/data/openclaw-henry/
```

This path is already bind-mounted into the container at `/home/node/.openclaw/`, so the container will see it automatically.

## Step 6 — Run the automation script

From your laptop, SSH into the host where OpenClaw runs, then:

```bash
cd ~/openclaw-life
./scripts/openclaw-life-gog-auth henry
```

Or, if you are already inside the instance directory:

```bash
cd ~/openclaw-life/openclaw-henry
../scripts/openclaw-life-gog-auth
```

The script will:

1. Verify the container is running.
2. Load the `client_secret_*.json` into `gog`'s credential store.
3. Prompt you for:
   - The Google account email to authorize
   - The comma-separated list of services to enable (defaults to `gmail,calendar,drive,docs,sheets,contacts`)
4. Launch `gog auth add --manual` interactively inside the container, which prints an OAuth URL.
5. **You** copy the URL to your laptop browser, sign in, click **Allow**, and copy the authorization code back into the terminal.
6. The script verifies the token with `gog auth doctor --check`.
7. It updates the instance `.env` file with `GOG_HOME`, `GOG_KEYRING_BACKEND`, `GOG_KEYRING_PASSWORD`, and `GOG_ACCOUNT`.

After completion, restart the container to pick up the new environment variables:

```bash
cd openclaw-henry
docker compose restart
```

## Correct gog command syntax

Inside the container, the gog binary is at `/usr/local/bin/gog`. After auth, typical commands look like:

```bash
# Using the default account set in GOG_ACCOUNT
docker compose exec openclaw gog gmail search 'newer_than:1d' --max 5 --json

# Specifying an account explicitly
docker compose exec openclaw gog --account you@gmail.com calendar events --today

# List authorized accounts
docker compose exec openclaw gog auth list --check

# Re-check token health
docker compose exec openclaw gog auth doctor --check
```

The key `gog auth` subcommands are:

| Command | Purpose |
|---|---|
| `gog auth credentials <path>` | Stores a downloaded `client_secret_*.json` into gog's config |
| `gog auth add <email> --services <list>` | Interactive OAuth authorization for a Google account |
| `gog auth list --check` | Lists authorized accounts and checks token validity |
| `gog auth doctor --check` | Deep health check on keyring, tokens, and scopes |

## File mapping recap

| Host (VM) | Container | Purpose |
|---|---|---|
| `~/.openclaw-life/data/openclaw-NAME/` | `/home/node/.openclaw/` | Persistent instance data |
| `~/.openclaw-life/data/openclaw-NAME/client_secret_*.json` | `/home/node/.openclaw/client_secret_*.json` | OAuth client credentials (source) |
| `~/.openclaw-life/data/openclaw-NAME/gogcli/` | `/home/node/.openclaw/gogcli/` | gog config, tokens, keyring |

## Troubleshooting

### "No client_secret file found"

Make sure you placed the downloaded JSON in `~/.openclaw-life/data/openclaw-NAME/` **on the VM host**, not inside the container. The bind mount brings it in automatically.

### "Container is not running"

Start the instance first:
```bash
cd openclaw-NAME
docker compose up -d
```

### "Auth verification failed"

- Check that the Google account email is correct.
- If the OAuth app is still in **Testing**, the token may have expired after 7 days. Publish the app to **In production** and re-run the script.
- Try running `gog auth doctor --check --no-input` manually inside the container for detailed diagnostics.

### Multiple client_secret files

If you have more than one `client_secret_*.json` in the data directory, the script lists them and asks which one to use. You can delete old ones to skip the prompt.
