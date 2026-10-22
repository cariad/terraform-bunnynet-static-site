# Post-deployment checks

Run these after the first `tofu apply` of a website that uses this module, and before uploading the website itself. They check what `tofu test` can't: how bunny.net really behaves.

They take about half an hour, including an eight-minute wait. Run them in one zsh session on macOS, in order, because later checks rely on what earlier ones uploaded and cached.

If a result doesn't match what's expected, stop and paste the command and its output to Claude. Each section says what a failure would mean. Even if you stop for good, run section 6 to clean up before uploading the website.

## 0. Set up

Wait at least a minute after `tofu apply` finishes, because bunny.net applies edge rules asynchronously.

In the first four lines of the block, set `DOMAIN`, `PREFER_WWW` and `ZONE_NAME` to the module's `domain`, `prefer_www` and `zone_name`, and `DNS_ZONE` to its `dns_zone` if you set one. Then paste the whole block. It asks for two secrets without echoing them:

- **Account API key:** bunny.net dashboard > Account > API key.
- **Storage zone password:** Storage > the zone > Access (the API / HTTP section), not the read-only password.

The block also:

- Sets `STORAGE_HOST` to the storage endpoint for the storage zone's main region, DE.
- Uses `pin` to send every request for the preferred hostname to one edge server, so that a second request can hit what the first one cached.
- Creates tiny test files, whose contents say which version is being served.
- Defines `del` so it refuses anything outside the test folder and `404.html`.

```zsh
DOMAIN=cariad.engineering
DNS_ZONE=$DOMAIN
PREFER_WWW=false
ZONE_NAME=change-me

if [[ $PREFER_WWW == true ]]; then PREFERRED=www.$DOMAIN REDIRECTED=$DOMAIN; else PREFERRED=$DOMAIN REDIRECTED=www.$DOMAIN; fi

printf 'Account API key: '; read -rs BUNNYNET_API_KEY; echo
printf 'Storage zone password: '; read -rs STORAGE_PASSWORD; echo

STORAGE_HOST=storage.bunnycdn.com
DIR=postdeploy-$(date -u +%Y%m%d%H%M)
URL=https://$PREFERRED/$DIR

IP=$(dig +short A "$PREFERRED" | grep -E '^[0-9.]+$' | head -1)
[[ -n $IP ]] || IP=$(curl -4 -sS -o /dev/null -w '%{remote_ip}' "https://$PREFERRED/")
pin=(--resolve "$PREFERRED:443:$IP")

api()   { curl -sS -H "AccessKey: $BUNNYNET_API_KEY" "https://api.bunny.net/$1"; }
hdrs()  { curl -sS -o /dev/null -D - "${pin[@]}" "$@" | tr -d '\r' | grep -i -E '^(HTTP/|(cache-control|cdn-cache|cdn-cachedat|content-type|etag|location|server):)'; }
body()  { curl -sS "${pin[@]}" "$@"; }
first() { body "$1" | head -1 | cut -c1-40; }
twice() { printf '%-20s %s / %s | %s\n' "$1" "$(first "$URL/$1")" "$(first "$URL/$1")" "$(curl -sS -o /dev/null "${pin[@]}" -w '%header{cdn-cache} %header{cdn-cachedat}' "$URL/$1")"; }
put()   { : "${ZONE_NAME:?}" "${2:?}"; local ct=(); [[ -n $3 ]] && ct=(-H "Content-Type: $3"); curl -sS -o /dev/null -w "%{http_code} PUT $2\n" -H "AccessKey: $STORAGE_PASSWORD" "${ct[@]}" -T "$1" "https://$STORAGE_HOST/$ZONE_NAME/$2"; }
del()   { : "${ZONE_NAME:?}" "${DIR:?}" "${1:?}"; [[ $1 == $DIR/* || $1 == 404.html ]] || { print -u2 "del: refusing to delete $1"; return 1; }; curl -sS -o /dev/null -w "%{http_code} DELETE $1\n" -X DELETE -H "AccessKey: $STORAGE_PASSWORD" "https://$STORAGE_HOST/$ZONE_NAME/$1"; }
purge() { curl -sS -o /dev/null -w "%{http_code} purge $1\n" -X POST -G -H "AccessKey: $BUNNYNET_API_KEY" --data-urlencode "url=$1" --data-urlencode "async=false" https://api.bunny.net/purge; }

PZ=$(curl -sS -o /dev/null -D - "https://$PREFERRED/" | tr -d '\r' | awk -F': ' 'tolower($1)=="cdn-pullzone"{print $2}')

T=$(mktemp -d)
YEAR=(avif css gif jpeg jpg js mjs mp3 mp4 otf pdf png svg ttf wasm webm webp woff woff2)
SHORT=(html ico json txt webmanifest xml)
for e in "${YEAR[@]}" "${SHORT[@]}"; do printf 'v1 %s\n' "$e" > "$T/v1.$e"; printf 'v2 %s\n' "$e" > "$T/v2.$e"; done
printf 'v3 js\n' > "$T/v3.js"
printf '<!doctype html><title>Not found</title><p>POSTDEPLOY-404</p>\n' > "$T/404.html"
printf '<!doctype html><p>POSTDEPLOY-INDEX</p>\n' > "$T/index.html"

echo "Edge $IP, pull zone $PZ, test folder $URL/"
```

- [ ] The last line prints an IP address, a pull zone ID and a test folder.
- [ ] If the IP address is empty, stop: every pinned request would fail with `curl: (49)`.
- [ ] If the pull zone ID is empty, copy it from the pull zone's URL in the dashboard and set `PZ=<id>`.
- [ ] Write down the test folder.

If you lose this shell, paste the block again, then run `DIR=<the test folder>` and `URL=https://$PREFERRED/$DIR`, and carry on where you stopped.

Notes:

- `curl` doesn't cache, so these checks see only the edge's caching. `cache-control` is what browsers would do.
- Always quote URLs. zsh treats an unquoted `?` as a wildcard.
- Never print whole API objects. The storage zone and pull zone objects hold secrets, so every API command below selects fields with `jq`.
- Never add `-v`, `--trace`, `set -x` or `setopt xtrace` to anything that sends `AccessKey`: `api`, `put`, `del`, `purge`, and the raw `curl` commands in 2.7 and 6. They print the request's headers, and so the secret. If one of those fails, paste just its status line.

## 1. Before uploading anything

### 1.1 DNS

```zsh
dig +short NS "$DNS_ZONE"
dig +noall +answer A "$DOMAIN" @kiki.bunny.net
dig +noall +answer AAAA "$DOMAIN" @kiki.bunny.net
dig +noall +answer CNAME "www.$DOMAIN" @kiki.bunny.net
for t in MX TXT CAA; do echo "== $t"; dig +noall +answer "$t" "$DOMAIN" @kiki.bunny.net; done
api dnszone | jq --arg z "$DNS_ZONE" '.Items[] | select(.Domain==$z) | .Records[] | select(.Type==2) | {Name, Value, Accelerated}'
```

- [ ] The nameservers are `kiki.bunny.net.` and `coco.bunny.net.`.
- [ ] `$DOMAIN` answers with `A` (and perhaps `AAAA`) addresses, with no `CNAME` line. If `$DOMAIN` is a subdomain inside another zone, a `CNAME` to `$ZONE_NAME.b-cdn.net.` is right instead.
- [ ] `www.$DOMAIN` is a `CNAME` to `$ZONE_NAME.b-cdn.net.`.
- [ ] Every `MX`, `TXT` and `CAA` record you kept at the zone's own domain is still answered. Any `CAA` record allows `letsencrypt.org`.
- [ ] Two of the `CNAME` records, named `""` and `www` (or your subdomain's label and `www.<label>`), have the value `$ZONE_NAME.b-cdn.net` and `"Accelerated": false`. Any others are your own.

If the `MX` or `TXT` records have gone, the README's record-clearing step is wrong, and mail may be broken.

### 1.2 Certificates

```zsh
for h in "$DOMAIN" "www.$DOMAIN"; do
  echo "== $h"
  echo | /usr/bin/openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null | /usr/bin/openssl x509 -noout -issuer -startdate -enddate -text | grep -E 'issuer=|notBefore=|notAfter=|DNS:'
  curl -sS -o /dev/null -w 'curl: HTTP %{http_code}\n' "https://$h/"
done
```

- [ ] Both issuers are Let's Encrypt.
- [ ] Each certificate's `DNS:` list covers its hostname, by name or by `*.$DOMAIN`.
- [ ] `notAfter` is in the future. Write down `notBefore` for the renewal check in section 8.
- [ ] `curl` prints `HTTP 404` for `$PREFERRED`, because nothing's uploaded yet, and `HTTP 301` for `$REDIRECTED`. Neither shows a certificate error.

### 1.3 TLS versions and ciphers

```zsh
for v in 1.0 1.1 1.2; do printf 'TLS %s: ' $v; curl -sS -o /dev/null -w '%{http_code}\n' --tlsv$v --tls-max $v "https://$PREFERRED/" 2>&1 | head -1; done
curl -sS -v -o /dev/null "https://$PREFERRED/" 2>&1 | grep 'SSL connection using'
for c in kRSA 'ECDHE:!AESGCM:!CHACHA20'; do echo "== $c"; echo | /usr/bin/openssl s_client -connect "$PREFERRED:443" -servername "$PREFERRED" -tls1_2 -cipher "$c" 2>&1 | grep -E 'Cipher is|alert|error' | head -2; done
```

- [ ] TLS 1.0 and 1.1 fail with a `curl: (35)` error. The exact message doesn't matter.
- [ ] TLS 1.2 prints an HTTP status.
- [ ] A default connection uses `TLSv1.3`.
- [ ] Both `openssl` attempts fail, with `Cipher is (NONE)`, an alert or an error. The first tries RSA key exchange, the second CBC ciphers.

A successful TLS 1.0, 1.1, RSA or CBC connection means the pull zone isn't at the "Modern only" TLS level.

### 1.4 Redirects

```zsh
for u in "http://$REDIRECTED/a/b?x=1" "https://$REDIRECTED/a/b?x=1" "https://$REDIRECTED/" "http://$PREFERRED/a/b?x=1" "http://$ZONE_NAME.b-cdn.net/a/b?x=1" "https://$ZONE_NAME.b-cdn.net/a/b?x=1"; do
  echo "== $u"
  curl -sS -o /dev/null -w '%{http_code} -> %{redirect_url}\n' "$u"
  curl -sS -o /dev/null -L --max-redirs 5 -w '   %{num_redirects} redirect(s), ends at %{http_code} %{url_effective}\n' "$u"
done
for s in http https; do curl -sS -o /dev/null -w "$s ACME: %{http_code} -> [%{redirect_url}]\n" "$s://$REDIRECTED/.well-known/acme-challenge/postdeploy-check"; done
```

- [ ] Both `$REDIRECTED` URLs give `301 -> https://$PREFERRED/a/b?x=1`, in one redirect.
- [ ] `https://$REDIRECTED/` gives `301 -> https://$PREFERRED/`, with no double slash.
- [ ] `http://$PREFERRED` redirects to `https://$PREFERRED/a/b?x=1` in one redirect. Write down its status code, which bunny.net doesn't document.
- [ ] Both `b-cdn.net` URLs give `301 -> https://$PREFERRED/a/b?x=1`, in one redirect.
- [ ] Both ACME lines show `404 -> []`, so Let's Encrypt's challenges aren't redirected.

### 1.5 Settings as bunny.net stored them

```zsh
api "pullzone/$PZ" | jq '{CacheControlMaxAgeOverride, CacheControlPublicMaxAgeOverride, CacheErrorResponses, IgnoreQueryStrings, EnableSmartCache, UseStaleWhileOffline, UseStaleWhileUpdating, TlsSecurityLevel, Hostnames: [.Hostnames[] | {Value, ForceSSL, HasCertificate}]}'
api "pullzone/$PZ" | jq '[.EdgeRules[] | {Description, Enabled, ActionType, TriggerMatchingType, Status: [.Triggers[] | select(.Type==8) | .PatternMatches[]], UrlPatterns: ([.Triggers[] | select(.Type==0) | .PatternMatches[]] | length)}]'
api storagezone | jq --arg n "$ZONE_NAME" '.[] | select(.Name==$n) | {Region, ZoneTier, ReplicationRegions: (.ReplicationRegions | sort), Custom404FilePath, Rewrite404To200}'
```

- [ ] The pull zone has `300`, `0`, `false`, `true`, `false`, `true`, `true` and `2`, in that order.
- [ ] `$PREFERRED` has `ForceSSL` true and `$REDIRECTED` false, and both have `HasCertificate` true.
- [ ] There are eleven edge rules, all enabled:
  - one browser rule (`ActionType` 16) with 19 URL patterns;
  - four edge rules (`ActionType` 3), each with `TriggerMatchingType` 1 and `Status` `["200"]`, whose URL patterns add up to 19;
  - two redirects (`ActionType` 1);
  - four content-type rules (`ActionType` 5), for `.mjs`, `.otf`, `.ttf` and `.webmanifest`, each with `TriggerMatchingType` 1, `Status` `["404"]` and 1 URL pattern.
- [ ] The storage zone has `"DE"`, `ZoneTier` 1, the 14 replication regions `BR`, `CZ`, `ES`, `HK`, `JH`, `JP`, `LA`, `MI`, `NY`, `SE`, `SG`, `SYD`, `UK` and `WA`, `"/404.html"` and `false`.

Fewer than 19 patterns means bunny.net dropped some, and those extensions only get five minutes.

### 1.6 Missing files aren't cached (round 1)

Each of these four extensions is in a different year-long edge rule. Don't request these URLs anywhere else.

```zsh
for e in css js png woff2 html; do
  echo "== $e"
  for i in 1 2 3; do hdrs "$URL/missing-a.$e" | grep -i -E '^(HTTP/|(cache-control|cdn-cache):)' | tr '\n' ' '; echo; sleep 10; done
done
first "$URL/missing-a.html"
```

- [ ] Every response is a `404`, with `cdn-cache: MISS` every time and never `HIT`.
- [ ] The year-long extensions show `cache-control: no-cache`. Anything except `max-age=31536000` passes.
- [ ] `.html` shows `cache-control: public, max-age=0`.
- [ ] The last line is the start of bunny.net's own 404 page.

A `HIT` on a 404 means the `200` gate doesn't work, so a visitor who asks for a file before it's uploaded could pin that 404 at their edge location for a year. The README's "Upload order" section would then be wrong. A year-long `max-age` on a 404 means browsers would keep the 404 for a year.

## 2. Upload the test files

```zsh
for e in "${YEAR[@]}" "${SHORT[@]}"; do put "$T/v1.$e" "$DIR/probe.$e"; done
for f in UPPER.CSS Mixed.Css name.css.bak deep/er/nested.css delete-me.css; do put "$T/v1.css" "$DIR/$f"; done
for e in css js png woff2; do put "$T/v1.$e" "$DIR/missing-a.$e"; done
put "$T/v1.js" "$DIR/sw.js"
put "$T/v1.mp4" "$DIR/range.mp4"
put "$T/index.html" "$DIR/dir/index.html"
put "$T/v1.html" "$DIR/fresh.html"
```

- [ ] Every line starts with `201`.

### 2.1 The files missing in 1.6 aren't stuck

```zsh
for e in css js png woff2; do printf '%-6s %s\n' $e "$(first "$URL/missing-a.$e")"; done
```

- [ ] Each prints `v1 <extension>`, not a 404 page.

If one shows a 404 page, run the line again after 30 seconds. If it then shows `v1`, the file hadn't replicated yet, which the README's "Upload order" section doesn't allow for. Tell Claude either way.

### 2.2 Content types and caching

This requests every test file twice.

```zsh
for e in "${YEAR[@]}" "${SHORT[@]}"; do
  a=$(curl -sS -o /dev/null "${pin[@]}" -w '%{http_code} %header{cdn-cache}' "$URL/probe.$e")
  b=$(curl -sS -o /dev/null "${pin[@]}" -w '%header{cdn-cache} | %header{content-type} | %header{cache-control}' "$URL/probe.$e")
  printf '%-12s %s %s\n' $e "$a" "$b"
done
for e in mjs otf ttf webmanifest; do printf '%-12s %s\n' $e "$(curl -sS -o /dev/null -D - "${pin[@]}" "$URL/probe.$e" | grep -ci '^content-type:')"; done
```

- [ ] Every line of the first loop shows `200 MISS HIT`.
- [ ] Every year-long extension shows `public, max-age=31536000`.
- [ ] `html`, `ico`, `json`, `txt`, `webmanifest` and `xml` show `public, max-age=0`.
- [ ] The last loop prints `1` four times: each file whose type the module sets has exactly one `Content-Type`.
- [ ] Each content type matches this table. A `; charset=...` suffix is fine, except on `.wasm`.

| Extension     | Content type                                                               | Browsers refuse a wrong one? |
| ------------- | -------------------------------------------------------------------------- | ---------------------------- |
| `css`         | `text/css`                                                                 | Yes                          |
| `js`, `mjs`   | any JavaScript type, such as `text/javascript` or `application/javascript` | Yes, for modules             |
| `wasm`        | exactly `application/wasm`                                                 | Yes, for streaming           |
| `svg`         | `image/svg+xml`                                                            | Yes                          |
| `webmanifest` | `application/manifest+json`                                                | Mostly not                   |
| `avif`        | `image/avif`                                                               | Rarely                       |
| `gif`         | `image/gif`                                                                | Rarely                       |
| `jpeg`, `jpg` | `image/jpeg`                                                               | Rarely                       |
| `png`         | `image/png`                                                                | Rarely                       |
| `webp`        | `image/webp`                                                               | Rarely                       |
| `otf`         | `font/otf`                                                                 | Rarely                       |
| `ttf`         | `font/ttf`                                                                 | Rarely                       |
| `woff`        | `font/woff`                                                                | Rarely                       |
| `woff2`       | `font/woff2`                                                               | Rarely                       |
| `mp3`         | `audio/mpeg`                                                               | Rarely                       |
| `mp4`         | `video/mp4`                                                                | Rarely                       |
| `webm`        | `video/webm`                                                               | Rarely                       |
| `pdf`         | `application/pdf`                                                          | Rarely                       |
| `html`        | `text/html`                                                                | Yes                          |
| `ico`         | `image/x-icon` or `image/vnd.microsoft.icon`                               | Rarely                       |
| `json`        | `application/json`                                                         | Sometimes                    |
| `txt`         | `text/plain`                                                               | No                           |
| `xml`         | `application/xml` or `text/xml`                                            | Sometimes                    |

A wrong type for one of the "Yes" rows needs fixing in the module before launch, by adding the extension and its type to `local.content_types` in `content_type.tf`. A `max-age=0` on a year-long extension means its pattern doesn't match.

`mjs`, `otf` and `ttf` are the only extensions that both a content-type rule and the year-long rules match. If only they get the wrong type or lose the year, those rules get in each other's way. Tell Claude.

### 2.3 Look-alike names aren't year-long

```zsh
for f in UPPER.CSS Mixed.Css name.css.bak deep/er/nested.css; do printf '%-20s %s\n' $f "$(curl -sS -o /dev/null "${pin[@]}" -w '%{http_code} %header{cache-control}' "$URL/$f")"; done
```

- [ ] `UPPER.CSS`, `Mixed.Css` and `name.css.bak` show `200 public, max-age=0`.
- [ ] `deep/er/nested.css` shows `200 public, max-age=31536000`.

A year-long `max-age` on an uppercase name means bunny.net matches case-insensitively, and the README is wrong to say uppercase extensions get five minutes.

### 2.4 Query strings share the cached copy

`probe.html` is requested twice first, because its five-minute copy from 2.2 may have expired.

```zsh
for u in "$URL/probe.css" "$URL/probe.css?v=2" "$URL/probe.html" "$URL/probe.html" "$URL/probe.html?utm_source=postdeploy"; do printf '%-34s %s\n' "${u#$URL/}" "$(curl -sS -o /dev/null "${pin[@]}" -w '%header{cdn-cache} %header{cdn-cachedat} | %header{cache-control}' "$u")"; done
```

- [ ] Each URL with a query string shows `HIT` and the same `cdn-cachedat` as the line above it.
- [ ] The `.css` lines show `max-age=31536000`, and the `.html` lines show `max-age=0`.

### 2.5 Revalidation keeps the year

`probe.mjs` is checked too, because a content-type rule matches it as well as the year-long rules.

```zsh
for f in probe.css probe.mjs; do
  ET=$(curl -sS -o /dev/null "${pin[@]}" -w '%header{etag}' "$URL/$f"); echo "== $f $ET"
  hdrs -H "If-None-Match: $ET" "$URL/$f"
done
```

- [ ] Each gives a `304` with `cache-control: public, max-age=31536000`.
- [ ] If `probe.mjs`'s `304` has a `content-type`, it's `text/javascript`.

A `304` with `max-age=0` means browsers would check the file on every page view after their first revalidation. It isn't broken, but the year is lost.

### 2.6 Range requests and directory URLs

The first request for `range.mp4` asks for only its first two bytes, which is how browsers usually start fetching audio and video.

```zsh
curl -sS -o /dev/null "${pin[@]}" -r 0-1 -w '%{http_code} %header{cdn-cache}\n' "$URL/range.mp4"
first "$URL/range.mp4"
hdrs "$URL/dir/"; first "$URL/dir/"
hdrs "$URL/dir"
```

- [ ] `range.mp4` gives `206 MISS`, then the whole `v1 mp4`.
- [ ] `dir/` gives `200`, `text/html` and `POSTDEPLOY-INDEX`.
- [ ] Write down what `dir` (no trailing slash) does: a `200`, a redirect or a `404`. The blog's links must match it.

### 2.7 Uploads can't set their own caching or types

The first check confirms that Bunny Storage ignores an uploaded `Cache-Control`. The second shows which upload header sets a file's type, which matters to the uploader.

```zsh
curl -sS -o /dev/null -w '%{http_code}\n' -H "AccessKey: $STORAGE_PASSWORD" -H 'Cache-Control: max-age=4242' -T "$T/v1.html" "https://$STORAGE_HOST/$ZONE_NAME/$DIR/cc.html"
hdrs "$URL/cc.html" | grep -i cache-control

put "$T/v1.txt" "$DIR/type-header.txt" text/x-postdeploy
curl -sS -o /dev/null -w '%{http_code}\n' -H "AccessKey: $STORAGE_PASSWORD" -H 'Override-Content-Type: text/x-postdeploy' -T "$T/v1.txt" "https://$STORAGE_HOST/$ZONE_NAME/$DIR/type-override.txt"
for f in type-header.txt type-override.txt probe.txt; do printf '%-18s %s\n' $f "$(curl -sS -o /dev/null "${pin[@]}" -w '%header{content-type}' "$URL/$f")"; done
```

- [ ] `cc.html` shows `public, max-age=0`, not `4242`.
- [ ] Write down which of `type-header.txt` and `type-override.txt` shows `text/x-postdeploy`, if either does.

### 2.8 Cache the files that section 3 changes

Run this straight before section 3. Nothing has requested `fresh.html` yet, so this caches a new five-minute copy, which can't expire during section 3's one-minute wait. Don't request it anywhere else.

```zsh
for f in fresh.html delete-me.css sw.js; do twice $f; done
```

- [ ] Each line ends with `HIT`.

## 3. Change the files, then wait

```zsh
for e in "${YEAR[@]}" "${SHORT[@]}"; do put "$T/v2.$e" "$DIR/probe.$e"; done
put "$T/v2.css" "$DIR/UPPER.CSS"
put "$T/v2.html" "$DIR/fresh.html"
put "$T/v2.js" "$DIR/sw.js"
del "$DIR/delete-me.css"
sleep 60
for f in probe.css fresh.html sw.js delete-me.css; do twice $f; done
```

- [ ] Every `PUT` prints `201`, and the `DELETE` prints `200`.
- [ ] All four files show `v1` twice and `HIT`, with the `cdn-cachedat` from 2.2 or 2.8.

If any of them serves `v2`, or `delete-me.css` is already a 404, bunny.net purges the edge when a stored file changes. Then the README's advice to purge is unnecessary, and the next checks will look different. Tell Claude.

Now wait seven more minutes:

```zsh
sleep 420
for e in "${SHORT[@]}"; do twice probe.$e; done
twice UPPER.CSS; twice fresh.html
for e in "${YEAR[@]}"; do twice probe.$e; done
twice sw.js; twice delete-me.css
curl -sS -o /dev/null "${pin[@]}" -w 'range.mp4: %header{cdn-cache} %header{cdn-cachedat}\n' "$URL/range.mp4"
```

- [ ] Every five-minute file, including `UPPER.CSS` and `fresh.html`, shows `v2` by its second request. One `v1` first is fine, because bunny.net serves a stale copy while it fetches the new one.
- [ ] Every year-long file, `sw.js` and `delete-me.css` show `v1` twice and `HIT`, with a `cdn-cachedat` from before section 3.
- [ ] Write down whether `range.mp4` is a `HIT` from 2.6 (the year applied) or a refetch (five minutes). Either passes.

A year-long file that shows `v1` and then `v2`, or a 404 for `delete-me.css`, means the edge kept that file for only five minutes and served one stale copy. If every year-long extension does this, the `200` gate is stopping the year from applying. If only `mjs`, `otf` and `ttf` do, the content-type rules are getting in the way of the year-long ones, as in 2.2. If only others do, check their patterns in 1.5. `v2` on both requests means the edge's copy was replaced after the upload, rather than expiring. Tell Claude either way.

## 4. Purges

### 4.1 Purging one URL with the API

```zsh
purge "$URL/probe.css"; first "$URL/probe.css"
purge "$URL/delete-me.css"; hdrs "$URL/delete-me.css" | head -1
```

- [ ] Each purge prints `200`.
- [ ] `probe.css` shows `v2`.
- [ ] `delete-me.css` is now a `404`.

### 4.2 Purging one URL in the dashboard

The README tells you to purge single files in the bunny.net dashboard. The dashboard takes URLs only on the pull zone's `b-cdn.net` hostname, not on your own domain.

In the dashboard, purge the URL that `echo "https://$ZONE_NAME.b-cdn.net/$DIR/probe.js"` prints, then run:

```zsh
first "$URL/probe.js"; first "$URL/probe.png"
```

- [ ] `probe.js` shows `v2`, and `probe.png` still shows `v1`.

If `probe.js` still shows `v1`, purging the `b-cdn.net` URL didn't clear your own domain's copy. If `probe.png` also shows `v2`, the dashboard purged the whole pull zone, not the URL. Either way, the README's purge steps are wrong. Tell Claude.

### 4.3 The service worker procedure

This follows the README's service-worker steps, but purges with the API. 4.2 checks that the dashboard can do the same. `sw.js` was changed in section 3, and it's still serving `v1`.

```zsh
purge "$URL/sw.js"; hdrs "$URL/sw.js" | grep -i -E '^(cache-control|cdn-cache):'; first "$URL/sw.js"
```

- [ ] `cdn-cache: MISS` and `max-age=31536000`, then `v2 js`.

The README says to purge as soon as everything has finished uploading. This checks that a purge straight after an upload doesn't pick up the old copy from a region that hasn't caught up:

```zsh
put "$T/v3.js" "$DIR/sw.js"; purge "$URL/sw.js"; first "$URL/sw.js"; first "$URL/sw.js"
```

- [ ] `201`, `200`, then `v3 js` twice.

`v2 js` means the edge fetched the old script from a region that hadn't caught up, and will now keep it for a year. The README would then need a wait, such as a minute, between uploading the service worker and purging it. Run `purge "$URL/sw.js"` again, and tell Claude.

## 5. The custom 404 page

```zsh
put "$T/404.html" 404.html
sleep 30
for u in "$URL/missing-b.html" "$URL/missing-b.css" "$URL/missing-b.webmanifest" "$URL/missing-b/"; do
  echo "== $u"
  curl -sS "${pin[@]}" -D - "$u" | tr -d '\r' | grep -i -E '^(HTTP/|(cache-control|content-type|cdn-cache):)|POSTDEPLOY-404'
done
hdrs "https://$PREFERRED/404.html" | head -1
```

- [ ] Each missing URL gives a `404`, `text/html` and a body containing `POSTDEPLOY-404`.
- [ ] `missing-b.css` doesn't show `max-age=31536000`.
- [ ] `missing-b.webmanifest` shows `text/html`, not `application/manifest+json`.
- [ ] `/404.html` itself gives `200`.

A `200` for a missing URL means search engines would index soft 404s. `application/manifest+json` on the missing manifest means the `StatusCode` triggers don't see the response's status, so the `200` gate may never match either.

### 5.1 Missing files still aren't cached (round 2)

The custom 404 page might change what the `200` gate sees, so repeat 1.6 with new names:

```zsh
for e in css js png woff2; do
  echo "== $e"
  for i in 1 2 3; do hdrs "$URL/missing-c.$e" | grep -i -E '^(HTTP/|cdn-cache:)' | tr '\n' ' '; echo; sleep 10; done
done
for e in css js png woff2; do put "$T/v1.$e" "$DIR/missing-c.$e"; done
for e in css js png woff2; do printf '%-6s %s\n' $e "$(first "$URL/missing-c.$e")"; done
```

- [ ] Every response is a `404` and a `MISS`.
- [ ] After the upload, each prints `v1 <extension>`. If one shows the 404 page, try it again after 30 seconds, as in 2.1.

## 6. Clean up

The trailing slash in `"$DIR/"` deletes only the test folder. The blog uploads its own `404.html`.

```zsh
del "$DIR/"
del 404.html
sleep 30
curl -sS -o /dev/null -w '%{http_code} purge everything\n' -X POST -H "AccessKey: $BUNNYNET_API_KEY" -H 'Content-Type: application/json' -d '{}' "https://api.bunny.net/pullzone/$PZ/purgeCache"
sleep 30
hdrs "$URL/probe.css" | head -1
rm -r "$T"; unset BUNNYNET_API_KEY STORAGE_PASSWORD
```

- [ ] Both `DELETE`s print `200`, and the purge prints `204`. Instead of the API purge, you can use **Purge Cache** in the pull zone's dashboard, with no tag.
- [ ] `probe.css` is now a `404`. The purge can print `204` before it has reached the edge, so if it's still a `200`, run `hdrs "$URL/probe.css" | head -1` again after a minute.

If `probe.css` is still a `200` a few minutes later, the edge may have fetched it again from a storage region that hadn't caught up with the `DELETE`, and will now keep it for a year. Purge the pull zone again in the dashboard, and tell Claude.

Never send a DELETE for the storage zone's root by hand. bunny.net refuses one unless it carries `allowRootDelete`, and with that, every file in the storage zone is deleted.

## 7. After the blog's first upload

This needs no secrets, so a new shell is fine. Set `DOMAIN` and `PREFER_WWW` as in section 0.

```zsh
DOMAIN=cariad.engineering
PREFER_WWW=false
if [[ $PREFER_WWW == true ]]; then PREFERRED=www.$DOMAIN; else PREFERRED=$DOMAIN; fi
curl -sS -o /dev/null -D - "https://$PREFERRED/" | tr -d '\r' | grep -i -E '^(HTTP/|(cache-control|content-type):)'
curl -sS -w '\nHTTP %{http_code}\n' "https://$PREFERRED/this-page-does-not-exist/" | grep -i -E '<title>|^HTTP '
```

- [ ] The home page gives `200`, `text/html` and `public, max-age=0`.
- [ ] A missing page gives `HTTP 404`, with your own 404 page's `<title>`.

## 8. About 70 days later

In a new shell, set `DOMAIN` as in section 0, then run 1.2's block again. It needs no secrets.

- [ ] Both certificates show a later `notBefore` than the one you wrote down, so bunny.net has renewed them.

If a certificate hasn't renewed, renew it in the dashboard under the pull zone's hostnames, and tell Claude before it expires.

## Not covered

These can't be checked from one machine with `curl`:

- **Other regions:** the checks reach only your nearest edge and the storage regions it uses. So they can't show whether a visitor elsewhere could get a 404 for a file uploaded seconds earlier, which the README's "Upload order" section rests on. The `200` gate checks in 1.6 and 5.1 make sure that such a 404 wouldn't last.
- **Serving while the storage zone is offline:** this needs an outage.
- **The full year:** section 3 shows only that the edge keeps year-long files for more than eight minutes.
- **Browsers:** their caching, and how they update service workers.
