// ============================================================================
// GATING STORE
// Manages user verification and entry gate status
// ============================================================================

import { create } from 'zustand';
import { api } from '../services/api';
import type { GatingStatus } from '@noblara/shared';

interface GatingState {
  status: GatingStatus | null;
  isLoading: boolean;
  error: string | null;
  lastFetched: number | null;

  // Actions
  fetchStatus: () => Promise<void>;
  refresh: () => Promise<void>;
}

const CACHE_DURATION = 60000; // 1 minute

export const useGatingStore = create<GatingState>((set, get) => ({
  status: null,
  isLoading: false,
  error: null,
  lastFetched: null,

  fetchStatus: async () => {
    const { lastFetched, isLoading } = get();

    // Skip if already loading
    if (isLoading) return;

    // Use cache if fresh
    if (lastFetched && Date.now() - lastFetched < CACHE_DURATION) {
      return;
    }

    set({ isLoading: true, error: null });

    try {
      const response = await api.getGatingStatus();

      if (response.success && response.data) {
        set({
          status: response.data,
          isLoading: false,
          lastFetched: Date.now(),
        });
      } else {
        set({
          error: response.error?.message || 'Failed to fetch status',
          isLoading: false,
        });
      }
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
    }
  },

  refresh: async () => {
    set({ lastFetched: null });
    await get().fetchStatus();
  },
}));

// Selectors for common checks
export const selectIsVerified = (state: GatingState) => state.status?.isVerified ?? false;
export const selectIsEntryApproved = (state: GatingState) => state.status?.isEntryApproved ?? false;
export const selectCanLike = (state: GatingState) => state.status?.canLike ?? false;
export const selectCanChat = (state: GatingState) => state.status?.canChat ?? false;
export const selectVerificationProgress = (state: GatingState) => ({
  photosApproved: state.status?.verification.photosApproved ?? 0,
  photosRequired: state.status?.verification.photosRequired ?? 3,
  instagramVerified: state.status?.verification.instagramVerified ?? false,
  genderVerified: state.status?.verification.genderVerified ?? false,
});
export const selectEntryProgress = (state: GatingState) => ({
  referralsVerified: state.status?.entry.referralsVerified ?? 0,
  referralsRequired: state.status?.entry.referralsRequired ?? 1,
});
