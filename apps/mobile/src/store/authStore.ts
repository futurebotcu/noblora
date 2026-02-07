// ============================================================================
// AUTH STORE
// Manages authentication state with Zustand
// ============================================================================

import { create } from 'zustand';
import { supabase } from '../services/supabase';
import { setUser as setSentryUser } from '../services/sentry';
import type { User, Session } from '@supabase/supabase-js';

interface AuthState {
  user: User | null;
  session: Session | null;
  isInitialized: boolean;
  isLoading: boolean;
  error: string | null;

  // Actions
  initialize: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<boolean>;
  signUp: (email: string, password: string) => Promise<boolean>;
  signOut: () => Promise<void>;
  clearError: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  session: null,
  isInitialized: false,
  isLoading: false,
  error: null,

  initialize: async () => {
    try {
      // Get current session
      const { data: { session } } = await supabase.auth.getSession();

      if (session?.user) {
        setSentryUser({ id: session.user.id, email: session.user.email });
      }

      set({
        user: session?.user ?? null,
        session,
        isInitialized: true,
      });

      // Listen for auth changes
      supabase.auth.onAuthStateChange((_event, session) => {
        set({
          user: session?.user ?? null,
          session,
        });

        if (session?.user) {
          setSentryUser({ id: session.user.id, email: session.user.email });
        } else {
          setSentryUser(null);
        }
      });
    } catch (error) {
      console.error('Auth initialization error:', error);
      set({ isInitialized: true, error: 'Failed to initialize auth' });
    }
  },

  signIn: async (email: string, password: string) => {
    set({ isLoading: true, error: null });

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        set({ error: error.message, isLoading: false });
        return false;
      }

      set({
        user: data.user,
        session: data.session,
        isLoading: false,
      });

      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },

  signUp: async (email: string, password: string) => {
    set({ isLoading: true, error: null });

    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
      });

      if (error) {
        set({ error: error.message, isLoading: false });
        return false;
      }

      set({
        user: data.user,
        session: data.session,
        isLoading: false,
      });

      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },

  signOut: async () => {
    set({ isLoading: true });

    try {
      await supabase.auth.signOut();
      set({
        user: null,
        session: null,
        isLoading: false,
      });
      setSentryUser(null);
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
    }
  },

  clearError: () => set({ error: null }),
}));
