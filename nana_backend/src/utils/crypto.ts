import { randomUUID } from 'node:crypto';

export function cryptoNative(): string {
  return randomUUID().replace(/-/g, '');
}
