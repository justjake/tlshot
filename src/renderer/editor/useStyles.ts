import { CSSProperties, useMemo } from "react";

export function useStyles<T extends Record<string, CSSProperties>>(
  fn: () => T,
  deps: unknown[]
): T {
  return useMemo(fn, deps);
}
