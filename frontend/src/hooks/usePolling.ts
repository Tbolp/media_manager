import { useEffect, useRef } from 'react';

export function usePolling(
  callback: () => Promise<boolean>,
  intervalMs: number,
  enabled: boolean = true,
) {
  const savedCallback = useRef(callback);
  savedCallback.current = callback;

  useEffect(() => {
    if (!enabled) return;

    let timeoutId: ReturnType<typeof setTimeout>;
    let cancelled = false;

    const poll = async () => {
      if (cancelled) return;
      try {
        const shouldContinue = await savedCallback.current();
        if (shouldContinue && !cancelled) {
          timeoutId = setTimeout(poll, intervalMs);
        }
      } catch {
        // 出错后仍继续轮询
        if (!cancelled) {
          timeoutId = setTimeout(poll, intervalMs);
        }
      }
    };

    poll();
    return () => {
      cancelled = true;
      clearTimeout(timeoutId);
    };
  }, [intervalMs, enabled]);
}
