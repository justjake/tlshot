import { createTLShotStore } from "@/shared/store";

// We need to polyfill this because TLStore uses it internally as an effect scheduler
globalThis.requestAnimationFrame = (cb) => setTimeout(cb, 0);

export const MainProcessStore = createTLShotStore({
  process: "main",
});
