# CLAUDE.md — Next.js 15 + SQLite SaaS Project

## Stack

- **Framework**: Next.js 15 (App Router)
- **Database**: SQLite via `better-sqlite3` or `@libsql/client` (Turso)
- **Styling**: Tailwind CSS (default) or CSS Modules (explicitly opt-in)
- **Auth**: NextAuth.js v5 or custom JWT (state in `src/lib/auth.ts`)
- **Deployment**: Vercel (serverless) or self-hosted

## Project Structure

```
src/
├── app/                    # Next.js App Router pages
│   ├── (auth)/            # Auth group route (login, register)
│   ├── (dashboard)/       # Protected routes (require auth)
│   ├── api/               # API Route Handlers
│   └── layout.tsx         # Root layout
├── components/
│   ├── ui/               # Reusable UI primitives (Button, Input, Card, etc.)
│   └── features/          # Feature-specific components
├── lib/
│   ├── db.ts             # Database connection singleton
│   ├── auth.ts           # Auth utilities and session helpers
│   └── utils.ts          # Shared utilities (formatDate, cn(), etc.)
├── types/                 # Shared TypeScript types
└── migrations/           # SQLite migration files (numbered)
    └── 001_initial.sql
```

**Rule**: All database queries go through `src/lib/db.ts`. Never query SQLite directly from API routes.

## Database Conventions

### Migrations (required for schema changes)

1. Create a numbered SQL file in `src/migrations/`
2. Naming: `XXX_description.sql` (e.g., `002_add_users_email_index.sql`)
3. Run migrations via `npm run db:migrate`
4. Never modify existing migration files after they've been applied

### Query patterns

```typescript
// ✅ Correct: use the db singleton
import { db } from '@/lib/db';
const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

// ❌ Wrong: creating new connections per request
import Database from 'better-sqlite3';
const db = new Database('./data.db'); // Don't do this
```

### SQL style

- Always use parameterized queries (no string interpolation)
- Foreign keys have `_id` suffix (e.g., `user_id`, `post_id`)
- Timestamps: ISO 8601 strings, not Unix integers
- Indexes on: foreign keys, `WHERE` columns, `ORDER BY` columns

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Files | kebab-case | `user-profile.tsx`, `auth-middleware.ts` |
| Components | PascalCase | `UserProfile.tsx`, `DashboardLayout.tsx` |
| Functions | camelCase | `getUserById()`, `formatCurrency()` |
| Database tables | snake_case | `users`, `post_comments` |
| Environment vars | UPPER_SNAKE | `DATABASE_URL`, `NEXTAUTH_SECRET` |
| React components | PascalCase + named export | `export function UserCard(...)` |

## Component Patterns

### Client vs Server Components

- **Default**: Server Components (can use `async/await`)
- **Add `"use client"`** only when you need: `useState`, `useEffect`, event handlers, browser APIs
- Keep client boundaries small — wrap specific parts, not entire pages

```typescript
// ✅ Good: small client boundary
export function PostList({ posts }: { posts: Post[] }) {
  return <ul>{posts.map(p => <PostItem key={p.id} post={p} />)}</ul>;
}

// "use client" only where needed
"use client";
import { useState } from 'react';
```

### API Route Handlers

```typescript
// ✅ Correct: explicit methods, typed responses, error handling
export async function POST(req: Request) {
  try {
    const body = await req.json();
    const user = await createUser(body);
    return Response.json({ data: user }, { status: 201 });
  } catch (err) {
    if (err instanceof DuplicateEmailError) {
      return Response.json({ error: 'Email already in use' }, { status: 409 });
    }
    return Response.json({ error: 'Internal error' }, { status: 500 });
  }
}
```

## What We Don't Do (and Why)

| Anti-pattern | Why | Alternative |
|---|---|---|
| `any` type | Hides bugs at compile time | Define proper interfaces |
| Inline styles | Inconsistent, hard to maintain | Tailwind classes or CSS Modules |
| `console.log` in API routes | Polutes server logs | Use a logger (`console.error` for errors) |
| Global CSS imports | Bundle bloat | Import CSS where needed |
| Client-side data fetching for server data | Unnecessary waterfall | Server Components or React Query |
| Storing secrets in code | Security risk | Environment variables |
| `npm start` instead of `npm run build` | Skips type checking | Always `npm run build` first |

## Dev Commands

```bash
npm run dev      # Start development server
npm run build    # Type-check + build for production
npm run db:migrate  # Run pending migrations
npm run db:seed   # Seed database (dev only)
npm run lint      # ESLint
npm run typecheck # TypeScript check without building
```

## Anti-Patterns to Avoid

1. **No `useEffect` for initial data load** — use Server Components or `loader` functions
2. **No client-side auth checks** — always verify session on the server
3. **No raw SQL in API routes** — abstract into `lib/db.ts` functions
4. **No prop drilling >3 levels** — use Context or `lib/db.ts` for shared data
5. **No `new Database()` inside request handlers** — use the singleton from `lib/db.ts`
