# CLAUDE.md — Next.js 15 App Router + SQLite SaaS Template

## Stack & Versions

| Concern | Choice | Why |
|---------|--------|-----|
| Framework | Next.js 15 (App Router) | Server Components are the default; RSC reduces JS bundle |
| Language | TypeScript 5.x (strict mode) | Catch errors at write-time, not runtime |
| Database | SQLite via `better-sqlite3` | Single-file, zero-config, synchronous API that fits Node.js patterns |
| ORM | Drizzle ORM | Type-safe, SQL-like, no runtime overhead — unlike Prisma it emits real SQL |
| Auth | Next-Auth v5 (Beta) | App Router native, typed to the hilt |
| Styling | CSS Modules + CSS custom properties | No runtime CSS-in-JS cost; co-locates with components |
| Validation | Zod | The only schema validator worth using; used by Next.js, tRPC, and more |
| Deployment | Vercel (or any Node.js host) | `npm run start` is your binary — no special runtime needed |

**Pin these in `package.json` — don't use `latest` tags for core deps.**

```json
{
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "better-sqlite3": "^11.0.0",
    "drizzle-orm": "^0.38.0",
    "next-auth": "^5.0.0-beta.25",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "drizzle-kit": "^0.30.0",
    "@types/better-sqlite3": "^7.6.0",
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0"
  }
}
```

---

## Project Structure

```
/
├── app/                        # Next.js App Router — everything is a Server Component unless marked 'use client'
│   ├── (auth)/                 # Route group: no URL prefix, groups auth pages together
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   ├── (dashboard)/            # Authenticated layout via middleware
│   │   ├── layout.tsx          # Server Component — fetch user, pass session down
│   │   ├── page.tsx            # Dashboard home
│   │   └── settings/page.tsx
│   ├── api/                    # Route Handlers (no 'use server' needed — these ARE server)
│   │   ├── auth/[...nextauth]/route.ts
│   │   └── v1/                 # Version prefix all public APIs
│   │       └── users/route.ts
│   ├── layout.tsx              # Root layout — metadata, fonts, providers
│   └── globals.css
├── components/
│   ├── ui/                     # Headless, framework-agnostic primitives (Button, Input, Dialog…)
│   │   ├── Button.tsx
│   │   └── Button.module.css
│   ├── forms/                  # Form components — always 'use client'
│   │   └── LoginForm.tsx
│   └── server/                 # Server Components that touch the DB or session
│       └── UserBadge.tsx
├── db/
│   ├── index.ts                 # Singleton DB connection (see §Connection)
│   ├── schema.ts               # Drizzle schema — one file, no subdirs
│   └── migrations/
│       └── 0000_init.sql       # Drizzle generates these; commit them like code
├── lib/
│   ├── auth.ts                 # Next-Auth config
│   ├── db.ts                   # Alias to db/index.ts — prefer importing from `~/db`
│   ├── zod.ts                  # Shared Zod schemas (re-used across API + client)
│   └── utils.ts                # Pure utility functions — no side effects, no imports from db/
├── middleware.ts               # Auth route protection, CORS headers, rate limiting
├── drizzle.config.ts
└── next.config.ts
```

### Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Files (React) | `PascalCase` | `UserProfile.tsx` |
| Files (logic) | `camelCase` | `sendEmail.ts` |
| Route segments | `kebab-case` | `user-profile/page.tsx` |
| CSS Modules | `Name.module.css` | `UserProfile.module.css` |
| DB tables | `snake_case` | `user_sessions` |
| DB columns | `snake_case` | `created_at` |
| Environment vars | `UPPER_SNAKE_CASE` | `DATABASE_URL` |
| React components | `PascalCase` | `<UserCard />` |
| Drizzle schema | `camelCase` (file), `snake_case` (tables) | `export const userSessions =...` |

**Why `snake_case` for DB?** SQLite is case-insensitive for identifiers, but many tools (Drizzle Kit, Turso, PlanetScale) expect `snake_case`. Consistency beats aesthetics here.

---

## Database & Migrations

### Connection — Singleton Pattern

**Never use a global variable for the DB in development with Next.js.** The App Router can spin up multiple Node.js processes. Use the module-level singleton instead:

```typescript
// db/index.ts
import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import * as schema from './schema';

const sqlite = new Database(process.env.DATABASE_URL ?? 'sqlite.db');
sqlite.pragma('journal_mode = WAL');
sqlite.pragma('foreign_keys = ON');

export const db = drizzle(sqlite, { schema });

// For use in Route Handlers and Server Components ONLY
export { schema };
```

**Why WAL mode?** WAL (Write-Ahead Logging) allows concurrent reads while writing — critical for Vercel's concurrent request model. Without it, you get `SQLITE_BUSY` errors under load.

**Why `foreign_keys = ON`?** SQLite disables foreign keys by default. Without this pragma, a dangling `user_id` won't throw — it silently succeeds.

### Schema Rules

1. **Always use `NOT NULL` unless the column genuinely has no default.** Null is a footgun in SQLite — it doesn't behave like PostgreSQL.
2. **Use `INTEGER PRIMARY KEY` for auto-incrementing IDs**, not `TEXT`. It's faster, uses less space, and works with foreign keys.
3. **Add `created_at` and `updated_at` to every table.** Use Drizzle's `$defaultDefaults`:

```typescript
// db/schema.ts
import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const users = sqliteTable('users', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  passwordHash: text('password_hash').notNull(),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer('updated_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
});
```

4. **Index every foreign key and every column you filter `WHERE` on.**
5. **Don't use Drizzle relations for simple lookups.** Write the join SQL — it's readable and faster than relation-based queries for read-heavy SaaS pages.

### Migrations

```bash
# Generate a migration from schema changes
npx drizzle-kit generate

# Apply migrations (run on startup — see below)
npx drizzle-kit migrate

# Push schema (dev only — never in production)
npx drizzle-kit push
```

**Apply migrations on app startup**, not at build time. In your `package.json`:

```json
{
  "scripts": {
    "dev": "drizzle-kit migrate && next dev",
    "start": "drizzle-kit migrate && next start",
    "build": "next build"
  }
}
```

**Why migrate at runtime?** On platforms like Vercel, the build process runs in a different environment than the runtime. Migration runs once per cold start, not per deployment.

---

## API Layer (Route Handlers)

### Rules

1. **Always validate with Zod before touching the DB.** Request bodies are untrusted by default.

```typescript
// app/api/v1/users/route.ts
import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db, schema } from '~/db';
import { eq } from 'drizzle-orm';

const CreateUserSchema = z.object({
  email: z.email(),  // use a reusable schema from ~/lib/zod.ts
  name: z.string().min(1).max(100),
});

export async function POST(req: Request) {
  const body = await req.json();
  const parsed = CreateUserSchema.safeParse(body);
  
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid input', details: parsed.error.flatten() }, { status: 400 });
  }

  const [user] = await db.insert(schema.users).values(parsed.data).returning();
  return NextResponse.json(user, { status: 201 });
}
```

2. **Return structured errors** — never `throw` from a Route Handler. Return a `NextResponse` with a machine-readable status code.
3. **Use `status` codes correctly:**
   - `200` — success, with body
   - `201` — resource created
   - `400` — bad input (validation failed)
   - `401` — not authenticated
   - `403` — authenticated but not authorized
   - `404` — resource not found
   - `409` — conflict (e.g., duplicate email)
   - `500` — server error (log it server-side, don't leak details)

4. **Never return `any` from an API.** Type the response or use a Zod schema to validate.

---

## Component Patterns

### Server vs. Client Components

| Use Case | Component Type | Why |
|----------|---------------|-----|
| Fetching DB data | Server Component | Zero client JS, direct DB access |
| Showing session/user | Server Component | No client-side auth round-trip |
| Form with user input | Client Component (`'use client'`) | Needs browser APIs (form state, validation) |
| Interactive UI (dropdown, modal) | Client Component | Needs event listeners, state |
| Shared UI primitive | Either (prefer Server if no interactivity) | Reduces bundle |

**The rule:** Start as a Server Component. Add `'use client'` only when you need browser APIs or React state.

### Props — Strict Typing

**Never use `any` for props.** If you find yourself reaching for `any`, the type likely needs to be extracted or the component needs splitting.

```typescript
// ❌ Bad
function UserCard(props: any) { ... }

// ✅ Good — explicit interface
interface UserCardProps {
  user: {
    id: number;
    email: string;
    name: string;
  };
  onSelect?: (id: number) => void;
}

function UserCard({ user, onSelect }: UserCardProps) { ... }
```

**Prop drilling > 3 levels is a code smell.** If you're passing props through 4+ levels, use React Context or a state management solution.

```typescript
// ❌ Bad — 4 levels of passing `userId`
<Page userId={id} />
  <Layout userId={id} />
    <Section userId={id} />
      <Card userId={id} />

// ✅ Good — fetch where needed (Server Components don't pay a round-trip cost)
<Page />
  <Layout>
    <Section>
      <Card />  {/* fetches its own data from DB */}
```

### Forms

Every form component is a Client Component. Use controlled inputs with Zod validation:

```typescript
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { CreateUserSchema } from '~/lib/zod';

export function RegisterForm() {
  const form = useForm<z.infer<typeof CreateUserSchema>>({
    resolver: zodResolver(CreateUserSchema),
    defaultValues: { email: '', name: '' },
  });

  async function onSubmit(values: z.infer<typeof CreateUserSchema>) {
    const res = await fetch('/api/v1/users', {
      method: 'POST',
      body: JSON.stringify(values),
    });
    if (!res.ok) { /* handle error */ }
  }

  return <form onSubmit={form.handleSubmit(onSubmit)}>...</form>;
}
```

---

## What We DON'T Do (and Why)

### ❌ `any` — Forbidden

TypeScript without `any` is a linter, not a type checker. If you can't type something, use `unknown` and narrow it. If the codebase has `// eslint-disable @typescript-eslint/no-explicit-any` — that's a red flag, not a feature.

### ❌ Raw SQL strings in API routes — Use Drizzle

String concatenation for SQL is SQL injection waiting to happen. Drizzle's query builder is safe, typed, and readable. If you need raw SQL for performance, use `db.run(sql`...)` with parameterized queries — never string interpolation.

### ❌ Prop drilling beyond 3 levels

Props should travel at most 3 component layers. Beyond that, something is wrong with your component boundaries. Fetch data at the component that needs it — Server Components make this free.

### ❌ Putting API calls in `useEffect` for initial data

`useEffect` for data fetching causes waterfalls, flash-of-unauthenticated-content, and makes your app slower. If the component is a Server Component, fetch in the component body. If it's a Client Component that needs initial data, pass it as a prop from a Server Component parent.

### ❌ CSS-in-JS (styled-components, emotion, etc.)

Runtime CSS-in-JS adds JavaScript to the client bundle that computes styles at runtime. CSS Modules are compile-time — zero runtime cost, tree-shakeable, co-located with components. For design tokens, use CSS custom properties.

### ❌ Global state libraries for server-derived data

Don't use Redux or Zustand to store data that came from the DB. Server state (DB data, session) belongs in Server Components. Client state is for browser-only concerns (UI state, form state). Mixing them creates sync bugs.

### ❌ Returning raw DB errors to the client

`err.message` from the DB can leak schema details, column names, and internal paths. Always return a generic `{ error: 'Something went wrong' }` to the client and log the real error server-side.

### ❌ Using `new Date()` for DB timestamps — Use integer Unix ms

SQLite has no native `TIMESTAMP` type. Use `INTEGER` storing Unix milliseconds. Drizzle's `mode: 'timestamp'` handles conversion, but be deliberate about it — mixing ISO strings and timestamps in the same column is a maintenance nightmare.

### ❌ `console.log` in Route Handlers — Use a logger

`console.log` goes to stdout, which on Vercel disappears. Use a structured logger (like `console.error` with a JSON object, or a library like `pino`). At minimum, log errors to `stderr`:

```typescript
catch (err) {
  console.error('POST /api/v1/users failed', { error: err, body: parsed.data });
  return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
}
```

### ❌ Mutating `process.env` at runtime

Environment variables are frozen after the module system initializes. All env vars that Next.js needs must be declared in `.env.local` and accessed via `process.env` — never `process.env.SOME_VAR = 'something'`.

### ❌ Non-version-controlled migrations

Drizzle migrations are SQL files. They go in `db/migrations/` and are committed to Git. A migration that exists only on your machine is a deployment disaster waiting to happen.

---

## Dev Commands

```bash
# Install deps
npm install

# Start dev server (runs migrations first)
npm run dev

# Build for production
npm run build

# Start production server (runs migrations first)
npm run start

# Generate a DB migration from schema changes
npx drizzle-kit generate

# Apply pending migrations
npx drizzle-kit migrate

# Push schema to DB (dev only — destroys data)
npx drizzle-kit push

# Type check
npx tsc --noEmit

# Lint
npx next lint

# Open Prisma-like GUI for SQLite (optional)
npx drizzle-kit studio
```

---

## File Organization Principles

1. **Colocate files that change together.** A component and its CSS Module live together. A schema and its migrations live together.
2. **Prefer flat over deep.** `components/forms/LoginForm.tsx` is better than `components/forms/auth/login/LoginForm.tsx`. Nesting beyond 2 levels is usually unnecessary.
3. **One schema file.** Put all your Drizzle table definitions in `db/schema.ts`. As the project grows, split into sub-files only when you have 20+ tables — and even then, keep them under `db/schema/`.
4. **No `utils/` catch-all.** If a utility function belongs to a domain, put it near that domain. Generic utilities go in `lib/utils.ts`.

---

## Security Checklist (Review Before Launch)

- [ ] All public API routes validate input with Zod
- [ ] All API routes check session/auth before processing
- [ ] `DATABASE_URL` is set in `.env.local`, not committed
- [ ] `SECRET` env var for Next-Auth is ≥ 32 characters
- [ ] No `any` types in the codebase (run `npx tsc --noEmit`)
- [ ] CORS is explicitly configured, not wide-open
- [ ] Rate limiting is applied to auth-sensitive routes
- [ ] Error messages to the client are generic
- [ ] SQL queries use parameterized statements (Drizzle handles this)
