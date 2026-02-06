// ============================================================================
// PROFILE STORE
// Manages user profile state
// ============================================================================

import { create } from 'zustand';
import { supabase } from '../services/supabase';
import type { Profile, Photo, Mode, Gender } from '@noblara/shared';

interface ProfileState {
  profile: Profile | null;
  photos: Photo[];
  isLoading: boolean;
  error: string | null;

  // Actions
  fetchProfile: () => Promise<void>;
  createProfile: (data: {
    mode: Mode;
    gender_claim: Gender;
    birth_year: number;
    city?: string;
    bio?: string;
  }) => Promise<boolean>;
  updateProfile: (data: Partial<Profile>) => Promise<boolean>;
  uploadPhoto: (uri: string, orderIndex: number) => Promise<boolean>;
  deletePhoto: (photoId: string) => Promise<boolean>;
  reorderPhotos: (photoIds: string[]) => Promise<boolean>;
}

export const useProfileStore = create<ProfileState>((set, get) => ({
  profile: null,
  photos: [],
  isLoading: false,
  error: null,

  fetchProfile: async () => {
    set({ isLoading: true, error: null });

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        set({ isLoading: false, error: 'Not authenticated' });
        return;
      }

      // Fetch profile
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', user.id)
        .single();

      if (profileError && profileError.code !== 'PGRST116') {
        throw profileError;
      }

      // Fetch photos
      const { data: photos, error: photosError } = await supabase
        .from('photos')
        .select('*')
        .eq('user_id', user.id)
        .order('order_index');

      if (photosError) {
        throw photosError;
      }

      set({
        profile: profile || null,
        photos: photos || [],
        isLoading: false,
      });
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
    }
  },

  createProfile: async (data) => {
    set({ isLoading: true, error: null });

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        set({ isLoading: false, error: 'Not authenticated' });
        return false;
      }

      const { data: profile, error } = await supabase
        .from('profiles')
        .insert({
          user_id: user.id,
          ...data,
        })
        .select()
        .single();

      if (error) throw error;

      set({ profile, isLoading: false });
      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },

  updateProfile: async (data) => {
    set({ isLoading: true, error: null });

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        set({ isLoading: false, error: 'Not authenticated' });
        return false;
      }

      const { data: profile, error } = await supabase
        .from('profiles')
        .update(data)
        .eq('user_id', user.id)
        .select()
        .single();

      if (error) throw error;

      set({ profile, isLoading: false });
      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },

  uploadPhoto: async (uri, orderIndex) => {
    set({ isLoading: true, error: null });

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        set({ isLoading: false, error: 'Not authenticated' });
        return false;
      }

      // Upload to storage
      const fileName = `${user.id}/${Date.now()}.jpg`;
      const response = await fetch(uri);
      const blob = await response.blob();

      const { error: uploadError } = await supabase.storage
        .from('photos')
        .upload(fileName, blob, {
          contentType: 'image/jpeg',
        });

      if (uploadError) throw uploadError;

      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('photos')
        .getPublicUrl(fileName);

      // Create photo record
      const { data: photo, error: insertError } = await supabase
        .from('photos')
        .upsert({
          user_id: user.id,
          url: publicUrl,
          order_index: orderIndex,
        })
        .select()
        .single();

      if (insertError) throw insertError;

      // Update local state
      const photos = get().photos.filter(p => p.order_index !== orderIndex);
      photos.push(photo);
      photos.sort((a, b) => a.order_index - b.order_index);

      set({ photos, isLoading: false });
      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },

  deletePhoto: async (photoId) => {
    set({ isLoading: true, error: null });

    try {
      const { error } = await supabase
        .from('photos')
        .delete()
        .eq('id', photoId);

      if (error) throw error;

      const photos = get().photos.filter(p => p.id !== photoId);
      set({ photos, isLoading: false });
      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },

  reorderPhotos: async (photoIds) => {
    set({ isLoading: true, error: null });

    try {
      // Update order indexes
      const updates = photoIds.map((id, index) => ({
        id,
        order_index: index,
      }));

      for (const update of updates) {
        const { error } = await supabase
          .from('photos')
          .update({ order_index: update.order_index })
          .eq('id', update.id);

        if (error) throw error;
      }

      // Reorder local state
      const photos = get().photos;
      const reordered = photoIds.map(id => photos.find(p => p.id === id)!).filter(Boolean);
      reordered.forEach((photo, index) => {
        photo.order_index = index;
      });

      set({ photos: reordered, isLoading: false });
      return true;
    } catch (error) {
      set({
        error: (error as Error).message,
        isLoading: false,
      });
      return false;
    }
  },
}));
