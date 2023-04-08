import { useEffect, useState } from "react";

function createIsDarkQuery() {
  return window.matchMedia("(prefers-color-scheme: dark)");
}

export function useColorScheme() {
  const [scheme, setScheme] = useState<"light" | "dark">(() =>
    createIsDarkQuery().matches ? "dark" : "light"
  );

  useEffect(() => {
    const isDarkQuery = createIsDarkQuery();
    const listener = (e: MediaQueryListEvent) => {
      setScheme(e.matches ? "dark" : "light");
    };
    isDarkQuery.addEventListener("change", listener);
    return () => isDarkQuery.removeEventListener("change", listener);
  });

  return scheme;
}
