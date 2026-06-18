# Overlay — full-stack web app (Next.js App Router)

**Type:** web-app · **Full doc:** `arch-design/coming-next.md` *(create in target repo)* · **Boundary:** `docs/ARCHITECTURE.md` or `README.md#layers`

## Fused abstraction

Edge/runtime shell (routing, middleware, env) + feature modules (RSC pages, server actions, API routes) + data plane (DB, cache, auth) → one deployable product with clear server/client boundary.

## Mission (§0 template)

Ship [product outcome] on a stack that survives framework churn — typed boundaries, observable deploys, agent-safe verification before merge.

## Thrive north star (§0b, 3–5y)

| Role | Wins because |
|------|----------------|
| App shell | Routing, auth gate, layout contracts stable across pages |
| Feature modules | Colocated UI + server logic; delete a feature = delete a folder |
| Data / auth layer | Provider-swappable (Clerk, DB host) without page rewrites |
| Verification | Preview deploy + E2E + typecheck as merge gate |

## Scorecard skeleton

| Area | Grade | Evidence |
|------|-------|----------|
| Type safety | ? | `tsc --noEmit`, strict tsconfig |
| Auth boundary | ? | middleware, session checks on server actions |
| Data access | ? | single module per domain, no raw SQL in components |
| CI / preview | ? | Vercel preview, required checks |
| Agent workflow | ? | `pnpm verify` or documented test script |
| Docs / roadmap | ? | `coming-next.md` exists and current |

## Typical SN backlog (customize)

1. **SN-1** Dogfood gate — run full verify locally, no feature code
2. **SN-2** Extract shared `lib/` contracts (auth, db, errors)
3. **SN-3** Server action / API validation layer (zod or equivalent)
4. **SN-4** E2E smoke on critical path (login, checkout, etc.)
5. **SN-5** Performance budget (LCP, bundle) on top 3 routes
6. **SN-6** MCP or CLI surface for agent deploy/verify (optional thrive bet)
7. **SN-7** Doc triage — one arch doc + coming-next, archive stale ADRs

## Guardrails (§6)

| Refuse | Build toward thrive |
|--------|---------------------|
| `use client` by default on pages | RSC first; client islands |
| Secrets in repo or client bundles | env vars + server-only imports |
| Auth checks only in UI | middleware + server action guards |
| One-off scripts without `package.json` script | `pnpm verify` discoverable |

## Key paths (mindmap seed)

`app/` · `app/api/` · `middleware.ts` · `lib/` · `components/` · `prisma/` or `drizzle/` · `.github/workflows/` · `playwright.config.*`

## Verify commands (customize)

```bash
pnpm type-check   # or npm run type-check
pnpm lint
pnpm test
pnpm build
# optional: pnpm test:e2e
```

**Expand full doc for:** product-specific SN file tables, gantt, monitoring metrics.
