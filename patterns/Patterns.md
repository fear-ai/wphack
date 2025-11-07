# Patterns (Deep Guide)

Updated: 2025-11-04T00:00:00Z

This guide explains what each pattern family detects, why it matters, attacker variations, and tuning for signal vs. noise.
Patterns assume **one regex per line** in `patall.txt` (**no inline comments**). Use `patshort.txt` for quick triage; use `patall.txt` for deeper sweeps.

## 1) Loader / Execution Primitives
- `\beval\s*\(` — generic eval; consider noisy; pair with other hits.
- `@?eval\s*\(\s*['"]\?>` — payload-injected PHP tail evaluated.
- `\beval\s*\(\s*\$[A-Za-z_]\w*` — variable-driven eval; high-signal.
- `eval\s*\(\s*base64_decode\s*\(` — classic loader chain; very high-signal.
- `assert\s*\(\s*\$[A-Za-z_]\w*` — assert-as-eval; legacy but abused.
- `(?:system|exec|passthru|shell_exec)\s*\(\s*\$[A-Za-z_]\w*` — OS command exec via variable.
- `(?:include|require|include_once|require_once)\s*\(\s*\$[A-Za-z_]\w*` — variable includes; arbitrary file load.

## 2) Obfuscation / Encoding Chains
- `base64_decode\s*\(`, `gzinflate\s*\(`, `gzuncompress\s*\(`, `str_rot13\s*\(` — decoding ladder.
- `\$\w+\s*=\s*base64_decode\s*\(` — staged decode into variable.
- `\$\w+\s*=\s*['"][A-Za-z0-9+/=]{200,}['"]` — long base64 literal (likely payload).
- `chr\(\d+\)\s*\.\s*chr\(\d+\)` — string assembly (often for keywords like eval).

## 3) Remote Code Fetch (and SSL-off)
- `(?:file_get_contents|fopen|curl_init)\s*\(\s*['"]https?://raw\.githubusercontent\.com/` — fetch from GitHub raw.
- `githubusercontent\.com` — broader net for GH content delivery.
- `stream_context_create\s*\(` — often used to tweak UA/headers for fetch.
- `curl_setopt\s*\(.*(?:SSL_VERIFYPEER|SSL_VERIFYHOST)\s*,\s*0` — TLS verification disabled; strong with remote fetch.

## 4) Header payloads & Superglobal Injection
Very high-signal when present (code sourced from request data):
- `@?eval\s*\(\s*\$_(?:GET|POST|REQUEST|COOKIE)`
- `@?assert\s*\(\s*\$_(?:GET|POST|REQUEST|COOKIE)`
- `@include\s*\(\s*\$_(?:GET|POST|REQUEST|COOKIE)`
- `file_put_contents\s*\([^,]+,\s*\$_(?:GET|POST|REQUEST|COOKIE)`

Uploads (supporting indicators):
- `\$_FILES\[\s*['"][^'"]+['"]\s*\]`, `move_uploaded_file\s*\(`

## 5) Stealth / Config Weakening & Redirects
- `error_reporting\s*\(\s*0\s*\)`, `ini_set\s*\(\s*['"]display_errors['"]\s*,\s*['"]?0['"]?\s*\)` — hide errors.
- `allow_url_include\s*=\s*On`, `allow_url_fopen\s*=\s*On` — enable risky behaviors.
- `header\s*\(\s*['"]Location:\s*https?://` — suspicious redirects (SEO/phish).

## 6) SEO Bot Filter (“Crawler-Gate” family)
- `preg_match\(.+HTTP_USER_AGENT.+(Heritrix|SeznamBot|ahrefsBot|Bytespider|semrushBot|Bing|Google|Yandex|PetalBot)` — crawler denylist.
- `\$_SERVER\[\s*['"]REQUEST_SCHEME['"]\s*\]\s*=` — scheme rewrite.
- `\$requsturl\s*=` — remote gateway var.
- `file_get_contents\s*\(\s*\$requsturl` — remote fetch call.
- `writeToFile\s*\(\s*['"]robots\.txt['"]` — robots manipulation.
- `header\s*\(\s*['"]HTTP/1\.0 403 Forbidden['"]` — cloaking bots.

## 7) Verification Checklist
1. `wp core verify-checksums`
2. Find out-of-place core names (e.g., `about.php` only under `wp-admin/`)
3. `./tools/scan_pat.sh --pat patshort.txt --php TARGET`
4. `./tools/scan_pat.sh --pat patall.txt --php TARGET`
5. `./tools/check_fixed.sh --file fixed-<domain>.csv --target TARGET`

