# Public web network and deployment

The canonical URL is https://tradinggame.oberhumerdesign.at/. The deployed Firebase Hosting site remains `tradinggame-live` in project `tradinggame-austria-prod`. Do not deploy both sites accidentally.

Build: `flutter build web --release --no-wasm-dry-run`

Deploy after review: `firebase deploy --only hosting:tradinggame-live --project tradinggame-austria-prod`

The root page runs the standard full-screen Flutter bootstrap with no visible HTML wrapper. Public introduction, instructions and network links are available separately at `/anleitung.html`; imprint and privacy remain independent HTML pages. `web/` assets are copied into the web build by Flutter. The existing Dart auth-domain selection is unchanged. Authorize the custom domain in Firebase Authentication and the Google OAuth client as required before testing Google sign-in.

## Advertising preparation

Publisher metadata and ads.txt identify `ca-pub-3801562351743751`. They do not load ads. There is deliberately no AdSense loader or ad placement. Before enabling ads, configure the Google-certified CMP for the domain, verify consent behavior, update the privacy notice to match the actual processing, and complete publisher/site review. Technical preparation is not approval. In particular, the canvas gameplay alone is not the site's crawlable content; review the public content for usefulness and policy compliance before requesting review.

## Verification before release

- Verify the canonical, sitemap and robots on the custom domain.
- Confirm the game occupies the full viewport without a header, footer or page scroll; check the separate information pages directly.
- Check guest mode, existing account restoration and Google sign-in on the custom domain.
- Confirm ads.txt is served as plain text, without an SPA fallback.
- Keep the existing web.app address as an operational fallback; canonical tags identify the preferred custom URL.

## Web CI

Pushes to `main` and `dev` run analysis and tests, then build with Flutter 3.41.5 and deploy only the mapped `tradinggame-live` Hosting target using the existing `FIREBASE_SERVICE_ACCOUNT` secret. Pull requests build and test without deployment. Live web jobs share concurrency to avoid overlapping deployments; pull-request builds use separate groups. The existing Android and desktop release jobs and Play publishing behavior are unchanged.
