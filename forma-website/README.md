# Forma Website

Marketing website for Forma (`https://formafiles.com`), built with Next.js App Router.

## Local development

```bash
npm install
npm run dev
```

Then open [http://localhost:3000](http://localhost:3000).

## Build and checks

```bash
npm run lint
npm run build
```

## Environment variables

Copy `.env.example` to `.env.local` and fill values:

- `NEXT_PUBLIC_MAC_APP_STORE_URL`: production App Store URL (required for download CTAs).
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_PLAUSIBLE_DOMAIN` (optional)
- `NEXT_PUBLIC_PLAUSIBLE_SRC` (optional)
- `NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION` (optional)
- `NEXT_PUBLIC_BING_SITE_VERIFICATION` (optional)

## Public SEO and AI-agent routes

- `/robots.txt`
- `/sitemap.xml`
- `/blog`
- `/blog/[slug]`
- `/llms.txt`
- `/for-agents`
- `/openapi.json`
- `/api/public/product`
- `/api/public/faq`
- `/api/public/faq/[id]`

