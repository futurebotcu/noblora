// ============================================================================
// SUPABASE CLIENT
// ============================================================================

import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Config from 'react-native-config';

// Get config from environment
const supabaseUrl = Config.SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseAnonKey = Config.SUPABASE_ANON_KEY || 'placeholder-key';

// Custom storage adapter for React Native
const AsyncStorageAdapter = {
  getItem: async (key: string) => {
    return AsyncStorage.getItem(key);
  },
  setItem: async (key: string, value: string) => {
    return AsyncStorage.setItem(key, value);
  },
  removeItem: async (key: string) => {
    return AsyncStorage.removeItem(key);
  },
};

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorageAdapter,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Helper to check if we're in mock mode
export const isMockMode = () => {
  return supabaseUrl.includes('placeholder') || !Config.SUPABASE_URL;
};

// Type-safe database query helpers
export type Tables = {
  profiles: {
    Row: {
      user_id: string;
      mode: 'dating' | 'bff';
      gender_claim: 'female' | 'male' | 'other';
      birth_year: number;
      city: string | null;
      bio: string | null;
      latitude: number | null;
      longitude: number | null;
      created_at: string;
      updated_at: string;
    };
    Insert: Omit<Tables['profiles']['Row'], 'created_at' | 'updated_at'>;
    Update: Partial<Tables['profiles']['Insert']>;
  };
  photos: {
    Row: {
      id: string;
      user_id: string;
      url: string;
      order_index: number;
      face_visible: boolean;
      quality_score: number;
      approved: boolean;
      created_at: string;
    };
  };
  // Add more table types as needed
};
