# WPHplan.md — Service Restoration Plan

**Objective:** Restore service for compromised WordPress sites quickly and cleanly, preserve valuable content, and assure strong security.  
**Assumptions:** No usable backups. Restoration may be in place or on new hosting.

---

## 1) Scope, priorities, constraints

- Multiple WordPress sites under one account with significant compromise.
- Prioritize by impact and feasibility; choose an initial set of priority sites.
- Constraints: limited staff, need for fast restoration, low tolerance for re‑infection.

---

## 2) Recovery and reinstall — domains and steps

### 2.1 Environment readiness
- Prepare a clean runtime per site (new account/host or clean subpath/subdomain).
- Set PHP version, HTTPS, empty docroot, least‑privilege DB and user.

### 2.2 Clean code install
- Install official WordPress core.
- Install trusted theme and minimal essential plugins from vendors/marketplaces.
- WP‑CLI example:
  ```bash
  wp core download --locale=en_US
  wp config create --dbname=DB --dbuser=USER --dbpass='PASS' --dbhost=localhost --skip-check
  wp core install --url=https://stg.example.com --title="Site" --admin_user=admin --admin_password='STRONG' --admin_email=you@example.com
  wp theme install twentytwentyfive --activate
  wp plugin install limit-login-attempts-reloaded --activate
  wp plugin update --all
  ```

### 2.3 Baseline hardening
- Disable dashboard code edits and dashboard updates (manage via CLI):
  ```php
  // wp-config.php
  define('DISALLOW_FILE_EDIT', true);
  define('DISALLOW_FILE_MODS', true);
  ```
- Rotate salts/keys:
  ```bash
  wp config shuffle-salts
  ```
- Enforce HTTPS and auto‑updates:
  ```bash
  wp option update home 'https://example.com'
  wp option update siteurl 'https://example.com'
  wp plugin auto-updates enable --all
  wp theme  auto-updates enable --all
  ```
- Ownership and permissions (adapt to host policy):
  ```bash
  find . -type d -exec chmod 775 {} \;
  find . -type f -exec chmod 664 {} \;
  ```
- Optional PHP toggles (via panel/php.ini):
  ```
  allow_url_fopen=Off
  expose_php=Off
  display_errors=Off
  ```

### 2.4 Content sanity checks
- Filename checks (known bad / ambiguous lists):
  ```bash
  ./tools/find_scan.sh --list ./tools/hacker /home2/wkarshat/public_html0
  ./tools/find_scan.sh --list ./tools/var    /home2/wkarshat/public_html0
  ```
- Content pattern scan (PHP by default):
  ```bash
  ./tools/scan_pat.sh --pat ./tools/pat.txt --php /home2/wkarshat/public_html0
  ```

### 2.5 Content export and salvage
**Goal:** move data only (posts/pages/authors/terms).

**Admin UI available**
```bash
# Source
wp export --dir=/tmp/exports --skip_comments --max_file_size=100MB
# Target
wp import /tmp/exports/*.xml --authors=create
```

**Admin blocked, WP‑CLI available**
```bash
wp user create tempadmin tempadmin@example.com --role=administrator --user_pass='STRONG'
wp export --dir=/tmp/exports --skip_comments --max_file_size=100MB
# import on target, then remove tempadmin on source
```

**DB‑only**
```bash
mysqldump -uUSER -pPASS DB   wp_posts wp_postmeta wp_terms wp_term_taxonomy wp_term_relationships > /tmp/posts.sql

# Target
wp db import /tmp/posts.sql
wp search-replace 'http://old.example.com' 'https://stg.example.com' --all-tables
wp rewrite flush --hard
```

**Last‑resort**
- RSS exports (limited).
- Wayback/static copy for key pages.

**Post‑import**
```bash
wp option get home && wp option get siteurl
wp term recount all
wp rewrite flush --hard
```

### 2.6 Media recovery
**scp**
```bash
scp -r user@old:/path/wp-content/uploads ./uploads-old
find ./uploads-old -type f ! -iregex '.*\.(jpg|jpeg|png|gif|webp|svg|pdf)$' -delete
rsync -a ./uploads-old/ ./wp-content/uploads/
```

**tar include**
```bash
(cd /old/wp-content/uploads && tar cf - $(find . -type f -iregex '.*\.(jpg|jpeg|png|gif|webp|svg|pdf)$')) | (cd /new/wp-content/uploads && tar xvf -)
```

**rclone**
```bash
rclone sync oldremote:uploads newremote:uploads --include="*.{jpg,jpeg,png,gif,webp,svg,pdf}"
```

**Sanity and thumbnails**
```bash
find ./wp-content/uploads -type f -name '*.php' -delete
wp media regenerate --yes
```

### 2.7 Minimal configuration and identity
- Recover existing values (if accessible on source):
  ```bash
  wp option get blogname
  wp option get blogdescription
  wp option get permalink_structure
  ```
- Apply to the new site:
  ```bash
  wp option update blogname "Site Title"
  wp option update blogdescription "Tagline"
  wp rewrite structure '/%postname%/'
  wp menu create "Main Menu"
  ```
- Users:
  ```bash
  wp user create editor editor@example.com --role=editor --user_pass='STRONG'
  ```

### 2.8 Iterative content and UX recovery
- Rebuild key pages (Home, About, Contact, landings); verify templates.
- Test forms end‑to‑end; confirm confirmation/thank‑you pages and emails.
- Fix internal links and embedded URLs:
  ```bash
  wp search-replace 'http://old.example.com' 'https://example.com' --all-tables
  ```
- Media checks:
  ```bash
  wp media list --format=csv | head
  ```
- Recreate menus, widgets/blocks as needed:
  ```bash
  wp menu location list
  wp menu item add-custom "Main Menu" "Home" https://example.com/
  ```

### 2.9 Validation and smoke tests
- HTTP checks:
  ```bash
  curl -I https://example.com/
  curl -I https://example.com/wp-login.php
  curl -sSL https://example.com/sitemap.xml | head
  ```
- Browser pass: Home, sample post, login, search, 404, forms.
- Logs: review PHP/webserver error logs.
- Optional public scan:
  ```bash
  wpscan --url https://example.com --stealthy
  ```

### 2.10 Cutover and DNS
- Lower TTL; update records; confirm SSL; post‑cutover smoke tests.

### 2.11 Monitoring and patch hygiene
- Uptime options: UptimeRobot, BetterUptime, StatusCake.
- Self‑hosted cron check:
  ```bash
  url="https://example.com"; code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  [ "$code" -eq 200 ] || mail -s "UPTIME ALERT $code $url" you@example.com <<< "Check $url"
  ```
- Updates:
  ```bash
  wp plugin update --all
  wp theme  update --all
  wp core   update
  ```

### 2.12 Source environment cleanup
- Archive then remove old docroot; keep evidence window if needed.
- Rotate credentials.

### Regenerate credentials and keys
- New salts/keys:
  ```bash
  wp config shuffle-salts
  ```
- Admin passwords (or force reset):
  ```bash
  wp user update admin --user_pass='NEW-STRONG-PASSWORD'
  ```
- Database user password and config:
  ```bash
  wp config set DB_PASSWORD 'NEW-DB-PASS' --raw
  ```
- TLS/SSL reissue (panel AutoSSL/Let’s Encrypt or manual OpenSSL):
  ```bash
  openssl req -newkey rsa:4096 -nodes -keyout domain.key -x509 -days 365 -out domain.crt -subj '/CN=example.com'
  ```
- Rotate API tokens, SSH keys, third‑party secrets.

---

## 3) Tracks

### Track A — Rapid clean rebuild
Sequence: 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 → 2.7 → 2.8 → 2.9 → 2.10 → 2.11 → 2.12

### Track B — Clean in‑place
Pre‑step: isolate the site.  
Sequence: (isolate) → 2.4 → 2.11 (replace core/theme/plugin code in place) → 2.3 → 2.7 → 2.8 → 2.9 → 2.10 → 2.11

### Track C — Migrate and modernize
Sequence: 2.1 (new provider/account with isolation) → 2.2 → 2.3 → per‑site loop of 2.5 → 2.4 → 2.6 → 2.7 → 2.8 → 2.9 → 2.10 → 2.11 → 2.12

---

## 4) Execution sequence
1. Choose an initial set of priority sites (impact + feasibility).  
2. For each site, pick a track.  
3. Execute: clean install and hardening → sanity checks → import data → media → identity → rebuild UX → validation → cutover → monitoring → cleanup.  
4. Record commands and outcomes per site; reuse checklists and scripts as you proceed.

---

## 5) Use cases
- Simple blog: few plugins, mostly posts → Track A with XML export.  
- Heavily customized site: complex theme/plugins → Track A; re‑implement custom bits cleanly.  
- Admin locked, DB‑only: use the DB path in 2.5; rebuild menus/widgets.  
- Many sites: Track C; standardized rebuilds, per‑site isolation, shared monitoring.

---

## 6) Trim redundancies
- Keep hardening steps in 2.3; later sections say “verify hardening.”  
- Keep validation in 2.9; avoid duplicating checks elsewhere.  
- Keep monitoring in 2.11.

---

## 7) Cross‑check and improvements
- 2.4 precedes 2.5 to gate imports into clean sites.  
- Prefer DISALLOW_FILE_MODS with CLI‑based updates for a smaller attack surface.  
- Use `wp search-replace` for URL normalization (handles serialization).  
- Scripts: `find_scan.sh`, `scan_pat.sh`, `make_fixed.sh`, `check_fixed.sh`, `run_audit.sh` remain useful; add `--dry-run` where you plan to move or delete files.
