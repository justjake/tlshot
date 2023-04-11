import { CSSProperties, useMemo } from "react";

export function useStyles<T extends Record<string, CSSProperties>>(
  fn: () => T,
  deps: unknown[]
): T {
  // eslint-disable-next-line react-hooks/exhaustive-deps
  return useMemo(fn, deps);
}
