/**
 * The type of a single item in `Object.entries<T>(value: T)`.
 *
 * Example:
 * ```
 * interface T {x: string; y: number}
 * type T2 = ObjectEntry<T>
 * ```
 * => type T2 = ["x", string] | ["y", number]
 */
export type ObjectEntry<T> = {
  // Without Exclude<keyof T, undefined>, this type produces `ExpectedEntries | undefined`
  // if T has any optional keys.
  [K in Exclude<keyof T, undefined>]: [K, T[K]];
}[Exclude<keyof T, undefined>];

/**
 * Like Object.entries, but returns a more specific type which can be less safe.
 *
 * Example:
 * ```
 * const o = {x: "ok", y: 10}
 * const unsafeEntries = Object.entries(o)
 * const safeEntries = objectEntries(o)
 * ```
 * => const unsafeEntries: [string, string | number][]
 * => const safeEntries: ObjectEntry<{
 *   x: string;
 *   y: number;
 * }>[]
 *
 * See `ObjectEntry` above.
 *
 * Note that Object.entries collapses all possible values into a single union
 * while objectEntries results in a union of 2-tuples.
 */
export const objectEntries = Object.entries as <const T>(
  o: T
) => Array<ObjectEntry<T>>;

export const fromEntries = Object.fromEntries as <
  const E extends readonly [PropertyKey, any]
>(
  entries: E[]
) => { [K in E[0]]: E[1] };
