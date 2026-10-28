# Notelekh Custom Domain Connection Guide

This guide details how to connect your custom domain (`notelekh.com` or `app.notelekh.com`) before production launch.

---

## 1. Domain Configuration via Cloudflare / DNS Provider

### Root Domain (`notelekh.com`)
Add the following DNS records in your domain registrar or DNS dashboard (Cloudflare, Namecheap, Route 53, etc.):

| Type | Name | Target / IP | Proxy Status | TTL |
|------|------|-------------|--------------|-----|
| `A` | `@` | *Your server / hosting IP* (e.g., Vercel / Firebase IP) | Proxied / DNS only | Auto |
| `CNAME` | `www` | `notelekh.com` | Proxied | Auto |

### Subdomain Deployment (`app.notelekh.com`)
| Type | Name | Target | Proxy Status | TTL |
|------|------|--------|--------------|-----|
| `CNAME` | `app` | `cname.vercel-dns.com` (or your platform host) | Proxied | Auto |

---

## 2. Platform Specific Deployment Instructions

### Vercel
1. Run `vercel deploy --prod` from `apps/client`.
2. In the Vercel Project Settings > **Domains**, enter `notelekh.com`.
3. Vercel will automatically provision a free Let's Encrypt SSL certificate once DNS records are verified.

### Firebase Hosting
1. Run `firebase hosting:channel:deploy` or `firebase deploy --only hosting`.
2. Go to **Hosting** in Firebase Console > Click **Add custom domain**.
3. Enter `notelekh.com` and add the TXT verification records to your DNS provider.

### GitHub Pages
1. The included `apps/client/web/CNAME` file automatically points GitHub Pages to `notelekh.com`.
2. In your GitHub repository **Settings > Pages > Custom domain**, enforce HTTPS.

---

## 3. Pre-Launch Checklist Status
- [x] **Custom Domain Mapping**: `CNAME` file configured.
- [x] **Favicon Verified**: `apps/client/web/favicon.png` with `<link rel="icon" type="image/png" href="favicon.png"/>`.
- [x] **Privacy Policy**: Fully implemented and reachable at `/privacy` via in-app routing.
- [x] **Terms of Service**: Fully implemented and reachable at `/terms` via in-app routing.
- [x] **Zero AI-Slop Tagging**: No "Made with AI", "Verified by AI", or emoji slop in markup or UI.
- [x] **No Fake Metrics / Fake Reviews**: Real product guarantees and workflow specs only.
