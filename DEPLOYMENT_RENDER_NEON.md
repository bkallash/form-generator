# Deploying Laravel Form Generator to Render with Neon PostgreSQL

This guide explains how to deploy this project to [Render](https://render.com) connected to your [Neon](https://neon.tech) serverless PostgreSQL database.

---

## 1. Get Your Neon Database Connection String

1. Log in to your [Neon Console](https://console.neon.tech).
2. Select your project and branch (typically `main`).
3. In the **Dashboard** or **Connection Details** section, locate your connection string.
4. **Important**: Uncheck **"Pooled connection"** (or use the **Direct** connection without `-pooler`). 
   - Neon's pooled connection uses PgBouncer, which aborts multi-statement DDL migration transaction blocks.
   - Example **Direct** connection string (notice **no** `-pooler`):
     ```text
     postgresql://neondb_owner:npg_AbCdEf123456@ep-cool-snowflake-12345678.us-east-2.aws.neon.tech/neondb?sslmode=require
     ```
5. Copy this **Direct** connection string. You will use it for `DATABASE_URL` both locally and on Render.

---

## 2. Deploy to Render

### Option A: Using the Render Blueprint (`render.yaml`) — Recommended

1. Push your latest code (including `Dockerfile`, `docker/`, and `render.yaml`) to your **GitHub** or **GitLab** repository:
   ```bash
   git add .
   git commit -m "Configure Render and Neon deployment"
   git push origin main
   ```
2. Go to your [Render Dashboard](https://dashboard.render.com).
3. Click **New +** and select **Blueprint**.
4. Connect your repository and select the branch (`main`).
5. Render will automatically detect `render.yaml` and configure the Web Service with Docker.
6. When prompted for environment variables, fill in:
   - `DATABASE_URL`: Paste your Neon connection string.
   - `APP_URL`: Enter your temporary or custom URL (e.g., `https://form-generator.onrender.com`).
   - `GEMINI_API_KEY`: Your Gemini API key (if using AI features).
   - `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`: Your Google OAuth credentials (if using Google login).
7. Click **Apply**.

---

### Option B: Manual Web Service Setup on Render

If you prefer setting up the Web Service manually via the UI:

1. In Render Dashboard, click **New +** -> **Web Service**.
2. Connect your Git repository.
3. Configure the service settings:
   - **Name**: `form-generator` (or your choice)
   - **Language / Runtime**: `Docker`
   - **Dockerfile Path**: `./Dockerfile`
   - **Instance Type**: `Free` or `Starter`
   - **Health Check Path**: `/up`
4. Expand **Advanced** -> **Environment Variables** and add:

| Key | Value | Description |
| :--- | :--- | :--- |
| `APP_NAME` | `Form Generator` | Application name |
| `APP_ENV` | `production` | Production environment |
| `APP_DEBUG` | `false` | Disable debug display for security |
| `APP_KEY` | `base64:...` | Generate via `php artisan key:generate --show` locally |
| `APP_URL` | `https://your-service.onrender.com` | Your Render public URL |
| `DB_CONNECTION` | `pgsql` | PostgreSQL driver |
| `DATABASE_URL` | `postgresql://user:pass@ep-xyz.neon.tech/neondb?sslmode=require` | Your Neon connection string |
| `DB_SSLMODE` | `require` | Required for Neon serverless Postgres |
| `AUTORUN_MIGRATIONS` | `true` | Runs `php artisan migrate --force` on boot |
| `LOG_CHANNEL` | `stderr` | Sends logs to Render log console |
| `SESSION_DRIVER` | `database` | Stores user sessions in Postgres |
| `CACHE_STORE` | `database` | Stores application cache in Postgres |
| `QUEUE_CONNECTION` | `database` | Processes queued jobs via Postgres |
| `GEMINI_API_KEY` | `AIzaSy...` | *(Optional)* Google Gemini AI API key |
| `GEMINI_MODEL` | `gemini-2.5-flash` | *(Optional)* Gemini model name |
| `GOOGLE_CLIENT_ID` | `...` | *(Optional)* Google OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | `...` | *(Optional)* Google OAuth Client Secret |
| `GOOGLE_REDIRECT_URI` | `https://your-service.onrender.com/auth/google/callback` | *(Optional)* Google callback URL |

5. Click **Create Web Service**.

---

## 3. Post-Deployment Verification

### Automatic Database Migrations
On container boot, `docker/entrypoint.sh` runs:
```bash
php artisan migrate --force
```
All database tables (users, forms, submissions, drafts, cache, sessions, jobs) will be created automatically in your Neon database.

### Verifying Logs
1. Go to your Render Web Service dashboard and open the **Logs** tab.
2. You will see the container boot sequence:
   - Nginx listening on port assigned by Render.
   - Cache optimizations (`config:cache`, `route:cache`, `view:cache`).
   - Migration status on Neon PostgreSQL.
   - Supervisord starting Nginx and PHP-FPM.

### Health Check
Render will monitor the built-in Laravel health check at `https://your-service.onrender.com/up`. When it returns HTTP 200, Render marks the service **Live**.

---

## 4. Google OAuth Configuration (If Used)

If you use Google OAuth login:
1. Go to [Google Cloud Console -> Credentials](https://console.cloud.google.com/apis/credentials).
2. Edit your OAuth 2.0 Client ID.
3. Under **Authorized redirect URIs**, add your production URL:
   ```text
   https://<your-render-subdomain>.onrender.com/auth/google/callback
   ```
4. Save the changes.

---

## 5. Helpful Commands & Shell Access

You can open the **Shell** tab in your Render dashboard to run Artisan commands directly:

- Re-run migrations:
  ```bash
  php artisan migrate --status
  ```
- Clear or warm caches:
  ```bash
  php artisan optimize:clear
  php artisan optimize
  ```
- Create a test user or inspect via Tinker:
  ```bash
  php artisan tinker
  ```

---

## 6. Running Queue Jobs & Background Tasks

### Integrated Queue Worker (Default & Cost-Free)
Your container is already configured via `docker/supervisord.conf` with an integrated queue worker:
```ini
[program:laravel-worker]
command=php /var/www/html/artisan queue:work --sleep=3 --tries=3 --max-time=3600 --timeout=90
```
This worker:
- Starts automatically alongside Nginx and PHP-FPM when the container boots.
- Processes background jobs (emails, AI processing, notifications) from your Neon PostgreSQL `jobs` table.
- Automatically logs all job processing output directly to your Render **Logs** dashboard.
- Requires **no extra paid services or configuration**.
