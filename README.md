# SmartCart

SmartCart turns a food request into a healthy menu, aggregates the ingredients,
compares current store prices and promotions, and calculates whether one or
multiple stores are worth the extra travel by car, bike, e-bike or on foot.

This repository is a developer handoff: it contains a buildable application,
an interactive mobile-first product demo, the existing collaborative-list
backend, a normalised data model, a deterministic shopping optimiser and
implementation notes for the missing retailer integrations.

## Start here

1. Read [`DEVELOPER_HANDOFF.md`](DEVELOPER_HANDOFF.md).
2. Copy `.env.example` to `.env.local` and fill in the required values.
3. Install and initialise:

```bash
npm install
npm run db:generate
npm run db:migrate -- --name initial
npm run dev
```

4. Open `http://localhost:3000/demo` first. This route works without accounts,
   a database or API keys and demonstrates the intended user experience with
   clearly labelled deterministic demo prices.

## Quality gates

```bash
npm run type-check
npm run lint
npm test
npm run build
```

The handoff was validated with all four commands. `npm audit --omit=dev`
reported zero known production vulnerabilities at handoff time.

## Important product rule

AI may propose menus and normalise ingredients. It must never invent prices,
promotions, availability, distances or savings. Those values must come from a
retailer API/product feed, SmartCart's normalised database, and a routing
provider. Every displayed price carries a source, freshness timestamp and
confidence status.

## Main routes

| Route | Purpose | Status |
|---|---|---|
| `/demo` | Mobile-first reference experience with map and optimiser | Working with demo data |
| `/signin` | Google sign-in and demo entry | Working after OAuth setup |
| `/` | Existing real-time shared shopping-list dashboard | Working after services are configured |
| `/api/ai/menu-plan` | Structured menu and ingredient generation | Working after Anthropic setup |
| `/api/stores/nearby` | Nearby grocery locations from OpenStreetMap/Overpass | Working after sign-in |
| `/api/prices/compare` | Reads normalised current prices | Working with demo or database provider |
| `/api/plans/optimize` | Deterministic store and travel-cost optimiser | Working after sign-in |
| `/api/routes/route` | Driving/cycling/walking geometry | Working with openrouteservice; labelled fallback without key |

## Documentation

- [`DEVELOPER_HANDOFF.md`](DEVELOPER_HANDOFF.md) — technical handoff and setup
- [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md) — intended product and decision logic
- [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md) — honest ready/demo/missing matrix
- [`docs/PRICE_DATA_INTEGRATION.md`](docs/PRICE_DATA_INTEGRATION.md) — retailer API/feed architecture
- [`docs/MAPS_AND_ROUTING.md`](docs/MAPS_AND_ROUTING.md) — map and route architecture
## weg test