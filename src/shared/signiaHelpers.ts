import { react } from "signia";

/**
 * Wait until the given signal function returns a non-undefined value.
 */
export function waitUntil<T>(
  debugName: string,
  fn: () => T | undefined
): T | Promise<T> {
  const firstValue = fn();
  if (firstValue !== undefined) {
    return firstValue;
  }
  return new Promise((resolve) => {
    const stop = react(`waitUntil:${debugName}`, () => {
      const value = fn();
      if (value === undefined) {
        return;
      }
      stop();
      resolve(value);
    });
  });
}
