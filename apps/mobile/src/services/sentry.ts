// ============================================================================
// SENTRY PLACEHOLDER
// Error tracking and monitoring
// ============================================================================

// This is a placeholder implementation
// Replace with actual Sentry SDK when ready

interface SentryOptions {
  dsn?: string;
  environment?: string;
  release?: string;
}

export function initSentry(_options?: SentryOptions): void {
  // Placeholder - initialize Sentry SDK here
  // import * as Sentry from '@sentry/react-native';
  // Sentry.init({ dsn: options.dsn, ... });

  if (__DEV__) {
    console.log('[Sentry] Initialized (placeholder)');
  }
}

export function captureException(error: Error, context?: Record<string, unknown>): void {
  if (__DEV__) {
    console.error('[Sentry] Exception:', error, context);
  }

  // Placeholder - capture exception here
  // Sentry.captureException(error, { extra: context });
}

export function captureMessage(message: string, level: 'info' | 'warning' | 'error' = 'info'): void {
  if (__DEV__) {
    console.log(`[Sentry] ${level.toUpperCase()}:`, message);
  }

  // Placeholder - capture message here
  // Sentry.captureMessage(message, level);
}

export function setUser(user: { id: string; email?: string } | null): void {
  if (__DEV__) {
    console.log('[Sentry] Set user:', user?.id);
  }

  // Placeholder - set user context here
  // Sentry.setUser(user);
}

export function addBreadcrumb(breadcrumb: {
  category: string;
  message: string;
  level?: 'info' | 'warning' | 'error';
}): void {
  if (__DEV__) {
    console.log('[Sentry] Breadcrumb:', breadcrumb.category, breadcrumb.message);
  }

  // Placeholder - add breadcrumb here
  // Sentry.addBreadcrumb(breadcrumb);
}

export function startTransaction(name: string, _op: string) {
  // Placeholder - start performance transaction
  // return Sentry.startTransaction({ name, op });

  return {
    finish: () => {
      if (__DEV__) {
        console.log(`[Sentry] Transaction finished: ${name}`);
      }
    },
    startChild: (childOp: { op: string; description: string }) => ({
      finish: () => {
        if (__DEV__) {
          console.log(`[Sentry] Child finished: ${childOp.description}`);
        }
      },
    }),
  };
}
