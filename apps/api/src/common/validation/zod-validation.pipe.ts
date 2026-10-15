import type { PipeTransform } from '@nestjs/common';
import type { z } from 'zod';
import { AppException } from '../errors/app-exception.js';
import type { ErrorDetail } from '../errors/error-codes.js';

type Issue = z.core.$ZodIssue;

function joinPath(path: readonly PropertyKey[]): string {
  return path.map((segment) => String(segment)).join('.');
}

/** Converts a zod issue into stable `{ field, issue }` details (snake_case issue names). */
export function issueToDetails(issue: Issue): ErrorDetail[] {
  const field = joinPath(issue.path);
  switch (issue.code) {
    case 'unrecognized_keys':
      return issue.keys.map((key) => ({
        field: field ? `${field}.${key}` : key,
        issue: 'unknown_field',
      }));
    case 'invalid_type':
      return [{ field, issue: issue.input === undefined ? 'required' : 'invalid_type' }];
    case 'too_small':
      return [
        {
          field,
          issue: issue.origin === 'string' ? 'too_short' : issue.origin === 'array' ? 'too_few' : 'too_small',
        },
      ];
    case 'too_big':
      return [
        {
          field,
          issue: issue.origin === 'string' ? 'too_long' : issue.origin === 'array' ? 'too_many' : 'too_big',
        },
      ];
    case 'invalid_format':
      return [{ field, issue: issue.format === 'email' ? 'invalid_email' : 'invalid_format' }];
    case 'invalid_value':
      return [{ field, issue: 'invalid_value' }];
    case 'custom':
      return [{ field, issue: typeof issue.params?.issue === 'string' ? issue.params.issue : 'invalid' }];
    default:
      return [{ field, issue: 'invalid' }];
  }
}

export function zodErrorToDetails(error: z.ZodError): ErrorDetail[] {
  return error.issues.flatMap(issueToDetails);
}

/**
 * Validates and parses a request part (body/query/param) with a zod schema. Schemas are strict
 * (`z.strictObject`), so unknown fields produce `unknown_field` details.
 */
export class ZodValidationPipe<S extends z.ZodType> implements PipeTransform<unknown, z.output<S>> {
  constructor(private readonly schema: S) {}

  transform(value: unknown): z.output<S> {
    // reportInput lets us tell "required" (undefined) apart from "invalid_type"; inputs are
    // never copied into the response.
    const result = this.schema.safeParse(value, { reportInput: true });
    if (!result.success) {
      throw AppException.validation(zodErrorToDetails(result.error));
    }
    return result.data;
  }
}
