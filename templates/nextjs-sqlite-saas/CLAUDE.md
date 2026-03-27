# CLAUDE.md — Next.js 15 + SQLite SaaS

## Project Overview

This is a SaaS application built with **Next.js 15 App Router** and **SQLite** (via better-sqlite3 or Turso).

- **Database**: SQLite via `better-sqlite3` (local) or `@libsql/client` (Turso remote)
- **Auth**: NextAuth.js with credentials + OAuth providers
- **Styling**: Tailwind CSS
- **Deployment**: Vercel (frontend) + Railway/LiLz Wing (SQLite)

---

## Project Structure

```
app/                    # Next.js App Router pages
  (auth)/              # Auth routes (login, register, forgot-password)
  (dashboard)/         # Protected dashboard routes
  api/                 # API routes
    auth/              # NextAuth handlers
    v1/                # API v1 (REST)
components/
  ui/                  # Base UI components (Button, Input, Card, Modal)
  features/            # Feature-specific components
lib/
  db.ts                # Database client singleton
  schema.ts            # Drizzle ORM schema
  auth.ts              # Auth utilities
  validators/          # Zod schemas for API validation
```

**Rule**: All database queries go through `lib/db.ts`. Never import `better-sqlite3` directly in API routes.

---

## Database Rules

### Migrations

1. Create migration file in `drizzle/` using `drizzle-kit generate`
2. Run with `drizzle-kit migrate`
3. **Never** modify existing migration files
4. Test migrations on a local DB first

### Query Patterns

```typescript
// ✅ Good: parameterized, with error handling
const user = await db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

// ✅ Better: use Drizzle ORM for type-safe queries
const user = await db.select().from(users).where(eq(users.id, userId));

// ❌ Bad: string interpolation (SQL injection risk)
// const user = await db.prepare(`SELECT * FROM users WHERE id = '${id}'`);
```

### Transactions

Use transactions for multi-step writes:

```typescript
await db.transaction(async (tx) => {
  await tx.insert(users).values({ email, hashedPassword });
  await tx.insert(sessions).values({ userId: result.lastInsertRowid });
});
```

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Tables | snake_case, plural | `user_sessions` |
| Columns | snake_case | `created_at` |
| Variables | camelCase | `userId` |
| Functions | camelCase, verb-first | `getUserByEmail` |
| Components | PascalCase | `UserProfile` |
| API routes | kebab-case | `/api/v1/user-profile` |
| Files | kebab-case | `user-profile.ts` |

---

## API Design

### Request/Response Format

All API routes use JSON. Error responses:

```json
{ "error": "Error message", "code": "ERROR_CODE" }
```

Success responses:

```json
{ "data": { ... } }
```

### Validation

All API inputs **must** be validated with Zod before processing:

```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export async function POST(req: Request) {
  const body = await req.json();
  const parsed = CreateUserSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ error: 'Invalid input', code: 'VALIDATION_ERROR' }, { status: 400 });
  }
  // proceed with parsed.data
}
```

---

## Anti-Patterns to Avoid

### ❌ Don't do this in API routes

- Return raw SQLite errors to the client
- Use `console.log` for errors (use structured logging)
- Make database queries without error handling
- Trust user input without Zod validation
- Store passwords without hashing (always use bcrypt/argon2)

### ❌ Don't do this in components

- Use `use client` unless necessary (server components first)
- Prop-drill more than 2 levels (use context or state management)
- Fetch data in components (use Server Components or route handlers)

---

## Development Commands

```bash
npm run dev          # Start dev server (localhost:3000)
npm run build        # Production build
npm run db:migrate   # Run Drizzle migrations
npm run db:studio    # Open Drizzle Studio (DB browser)
npm run db:seed      # Run seed script
npm run lint         # ESLint
npm run typecheck    # TypeScript check
```

---

## Environment Variables

Required in `.env.local`:

```
DATABASE_URL=file:./data/app.db
NEXTAUTH_SECRET=<generate with: openssl rand -base64 32>
NEXTAUTH_URL=http://localhost:3000
```

Optional:
```
TURSO_DATABASE_URL=libsql://your-db.turso.io
TURSO_AUTH_TOKEN=your-token
```

---

## Common Tasks

### Adding a new API route

1. Create `app/api/v1/<resource>/route.ts`
2. Add Zod input schema in `lib/validators/`
3. Implement GET/POST/etc handlers
4. Export from `app/api/v1/route.ts` with `mergeRouters`

### Adding a new database table

1. Add schema in `lib/schema.ts` using Drizzle
2. Run `drizzle-kit generate`
3. Run `drizzle-kit migrate`
4. Add query functions in `lib/queries/`

### Adding a new page

1. Use App Router: `app/(dashboard)/<page>/page.tsx`
2. Mark as `'use client'` only if it needs browser APIs
3. Use `lib/db.ts` for server-side data fetching
