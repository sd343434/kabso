---
name: kabso-conventions
description: Development conventions and patterns for kabso. TypeScript project with mixed commits.
---

# Kabso Conventions

> Generated from [sd343434/kabso](https://github.com/sd343434/kabso) on 2026-11-06

## Overview

This skill teaches Claude the development patterns and conventions used in kabso.

## Tech Stack

- **Primary Language**: TypeScript
- **Architecture**: feature-based module organization
- **Test Location**: mixed
- **Test Framework**: vitest

## When to Use This Skill

Activate this skill when:
- Making changes to this repository
- Adding new features following established patterns
- Writing tests that match project conventions
- Creating commits with proper message format

## Commit Conventions

Follow these commit message conventions based on 190 analyzed commits.

### Commit Style: Mixed Style

### Prefixes Used

- `docs`
- `feat`
- `fix`
- `test`

### Message Guidelines

- Average message length: ~71 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
docs: KL-049 isolated verification status; KL-052 verdict; KL-053 proposed; PP-28 conditions
```

*Commit message example*

```text
feat(mobile): KL-034 live room redesign (D44)
```

*Commit message example*

```text
test(db): KL-013b fix the two e2e assertions that failed in CI run 73
```

*Commit message example*

```text
fix(db): KL-013b per-database runtime group, membership-aware boot guard, atomic bootstrap
```

*Commit message example*

```text
chore: ignore golden failure diffs; board KL-033 done, KL-038 started
```

*Commit message example*

```text
docs(design): reference patterns OREF-02..06 (text only, no images); D46; KL-051 prototype
```

*Commit message example*

```text
docs(board): KL-049 committed (e2e pending verification path); KL-050 held for owner review
```

*Commit message example*

```text
Merge KL-035b: live room review captures from the real app (A5)
```

## Architecture

### Project Structure: Monorepo

This project uses **feature-based** module organization.

### Configuration Files

- `.github/workflows/ci.yml`
- `apps/api/package.json`
- `apps/api/tsconfig.json`
- `apps/api/vitest.config.ts`
- `docker-compose.yml`
- `package.json`
- `tools/redocly/package.json`

### Guidelines

- Group related code by feature/domain
- Each feature folder should be self-contained
- Shared utilities go in a common/shared folder

## Code Style

### Language: TypeScript

### Naming Conventions

| Element | Convention |
|---------|------------|
| Files | camelCase |
| Functions | camelCase |
| Classes | PascalCase |
| Constants | SCREAMING_SNAKE_CASE |

### Import Style: Relative Imports

### Export Style: Named Exports


*Preferred import style*

```typescript
// Use relative imports
import { Button } from '../components/Button'
import { useAuth } from './hooks/useAuth'
```

*Preferred export style*

```typescript
// Use named exports
export function calculateTotal() { ... }
export const TAX_RATE = 0.1
export interface Order { ... }
```

## Testing

### Test Framework: vitest

### File Pattern: `*.spec.ts`

### Test Types

- **Unit tests**: Test individual functions and components in isolation
- **Integration tests**: Test interactions between multiple components/services
- **E2e tests**: Test complete user flows through the application


*Test file structure*

```typescript
import { describe, it, expect } from 'vitest'

describe('MyFunction', () => {
  it('should return expected result', () => {
    const result = myFunction(input)
    expect(result).toBe(expected)
  })
})
```

## Error Handling

### Error Handling Style: Try-Catch Blocks


*Standard error handling pattern*

```typescript
try {
  const result = await riskyOperation()
  return result
} catch (error) {
  console.error('Operation failed:', error)
  throw new Error('User-friendly message')
}
```

## Common Workflows

These workflows were detected from analyzing commit patterns.

### Database Migration

Database schema changes with migration files

**Frequency**: ~2 times per month

**Steps**:
1. Create migration file
2. Update schema definitions
3. Generate/update types

**Files typically involved**:
- `migrations/*`
- `**/schema.*`

**Example commit sequence**:
```
feat(api,db): contract v1.3 live discovery, host lifecycle, public profile, follow (KL-037)
Merge KL-037: live discovery, host lifecycle, public profile and follow API (contract v1.3) (A3)
docs(board): KL-037 integrated; review decisions D42
```

### Feature Development

Standard feature implementation workflow

**Frequency**: ~4 times per month

**Steps**:
1. Add feature implementation
2. Add tests for feature
3. Update documentation

**Files typically involved**:
- `apps/mobile/lib/features/debug/*`
- `apps/api/src/*`
- `apps/api/src/common/audit/*`
- `**/*.test.*`
- `**/api/**`

**Example commit sequence**:
```
feat(mobile): KL-038 wire the Live discovery hub to the v1.3 API
Merge KL-038: Live hub wired to contract v1.3 endpoints (A2)
docs(board): KL-038 integrated; D41
```


## Best Practices

Based on analysis of the codebase, follow these practices:

### Do

- Keep feature code co-located in feature folders
- Write tests using vitest
- Follow *.spec.ts naming pattern
- Use camelCase for file names
- Prefer named exports

### Don't

- Don't skip tests for new features
- Don't deviate from established patterns without discussion

---

*This skill was auto-generated by [ECC Tools](https://ecc.tools). Review and customize as needed for your team.*
