// ============================================================================
// PHOTO VERIFICATION SCREEN
// Upload and manage profile photos
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { launchImageLibrary } from 'react-native-image-picker';
import { useProfileStore } from '../../store/profileStore';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

const MAX_PHOTOS = 6;
const MIN_PHOTOS = 3;

export function PhotoVerificationScreen() {
  const navigation = useNavigation();
  const { photos, uploadPhoto, deletePhoto, isLoading } = useProfileStore();
  const [verifyingIndex, setVerifyingIndex] = useState<number | null>(null);

  const handleSelectPhoto = async (index: number) => {
    try {
      const result = await launchImageLibrary({
        mediaType: 'photo',
        quality: 0.8,
        maxWidth: 1200,
        maxHeight: 1200,
      });

      if (result.assets?.[0]?.uri) {
        const success = await uploadPhoto(result.assets[0].uri, index);
        if (success) {
          // Auto-verify after upload
          setVerifyingIndex(index);
          const photo = photos.find(p => p.order_index === index);
          if (photo) {
            await api.verifyPhoto(photo.id);
          }
          setVerifyingIndex(null);
        }
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to upload photo');
    }
  };

  const handleDeletePhoto = async (photoId: string) => {
    Alert.alert(
      'Delete Photo',
      'Are you sure you want to delete this photo?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => deletePhoto(photoId),
        },
      ]
    );
  };

  const approvedCount = photos.filter(p => p.approved && p.face_visible).length;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>

        <View style={styles.header}>
          <Text style={styles.title}>Add Photos</Text>
          <Text style={styles.subtitle}>
            Upload at least {MIN_PHOTOS} photos with your face clearly visible.
            Photos are verified by AI for quality and visibility.
          </Text>
        </View>

        {/* Progress */}
        <Card variant="outlined" style={styles.progressCard}>
          <Text style={styles.progressText}>
            {approvedCount} of {MIN_PHOTOS} verified photos
          </Text>
          {approvedCount >= MIN_PHOTOS && (
            <Text style={styles.successText}>✓ Photo requirement met!</Text>
          )}
        </Card>

        {/* Photo Grid */}
        <View style={styles.grid}>
          {Array.from({ length: MAX_PHOTOS }).map((_, index) => {
            const photo = photos.find(p => p.order_index === index);
            const isVerifying = verifyingIndex === index;

            return (
              <PhotoSlot
                key={index}
                photo={photo}
                isPrimary={index === 0}
                isLoading={isLoading || isVerifying}
                onSelect={() => handleSelectPhoto(index)}
                onDelete={photo ? () => handleDeletePhoto(photo.id) : undefined}
              />
            );
          })}
        </View>

        {/* Tips */}
        <Card variant="outlined" style={styles.tipsCard}>
          <Text style={styles.tipsTitle}>Photo Tips</Text>
          <Text style={styles.tipText}>• Face clearly visible and well-lit</Text>
          <Text style={styles.tipText}>• No sunglasses or face coverings</Text>
          <Text style={styles.tipText}>• Recent photos only</Text>
          <Text style={styles.tipText}>• No group photos as primary</Text>
        </Card>

        <Button
          title="Continue"
          onPress={() => navigation.goBack()}
          disabled={approvedCount < MIN_PHOTOS}
          fullWidth
          size="lg"
        />
      </View>
    </SafeAreaView>
  );
}

function PhotoSlot({
  photo,
  isPrimary,
  isLoading,
  onSelect,
  onDelete,
}: {
  photo?: { url: string; approved: boolean; face_visible: boolean };
  isPrimary: boolean;
  isLoading: boolean;
  onSelect: () => void;
  onDelete?: () => void;
}) {
  const isApproved = photo?.approved && photo?.face_visible;

  return (
    <TouchableOpacity
      style={[styles.slot, isPrimary && styles.slotPrimary]}
      onPress={onSelect}
      disabled={isLoading}
    >
      {photo ? (
        <>
          <Image source={{ uri: photo.url }} style={styles.photo} />
          {isApproved && (
            <View style={styles.approvedBadge}>
              <Text style={styles.approvedText}>✓</Text>
            </View>
          )}
          {!isApproved && !isLoading && (
            <View style={styles.pendingBadge}>
              <Text style={styles.pendingText}>Pending</Text>
            </View>
          )}
          {onDelete && (
            <TouchableOpacity style={styles.deleteButton} onPress={onDelete}>
              <Text style={styles.deleteText}>×</Text>
            </TouchableOpacity>
          )}
        </>
      ) : (
        <View style={styles.placeholder}>
          <Text style={styles.placeholderIcon}>+</Text>
          {isPrimary && <Text style={styles.primaryLabel}>Primary</Text>}
        </View>
      )}
      {isLoading && (
        <View style={styles.loadingOverlay}>
          <Text style={styles.loadingText}>...</Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  content: {
    flex: 1,
    padding: spacing.xl,
  },
  backButton: {
    marginBottom: spacing.lg,
  },
  backText: {
    fontSize: typography.fontSize.md,
    color: colors.primary,
  },
  header: {
    marginBottom: spacing.xl,
  },
  title: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  subtitle: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    lineHeight: 22,
  },
  progressCard: {
    marginBottom: spacing.xl,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  progressText: {
    fontSize: typography.fontSize.md,
    color: colors.textPrimary,
  },
  successText: {
    fontSize: typography.fontSize.sm,
    color: colors.success,
    fontWeight: typography.fontWeight.medium,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -spacing.xs,
    marginBottom: spacing.xl,
  },
  slot: {
    width: '33.33%',
    aspectRatio: 0.8,
    padding: spacing.xs,
  },
  slotPrimary: {
    width: '66.66%',
  },
  photo: {
    width: '100%',
    height: '100%',
    borderRadius: borderRadius.md,
  },
  placeholder: {
    width: '100%',
    height: '100%',
    backgroundColor: colors.gray100,
    borderRadius: borderRadius.md,
    borderWidth: 2,
    borderColor: colors.gray300,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  placeholderIcon: {
    fontSize: 32,
    color: colors.gray400,
  },
  primaryLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.gray500,
    marginTop: spacing.xs,
  },
  approvedBadge: {
    position: 'absolute',
    top: spacing.sm,
    right: spacing.sm,
    backgroundColor: colors.success,
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  approvedText: {
    color: colors.white,
    fontWeight: typography.fontWeight.bold,
  },
  pendingBadge: {
    position: 'absolute',
    bottom: spacing.sm,
    left: spacing.sm,
    backgroundColor: colors.warningLight,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xxs,
    borderRadius: 4,
  },
  pendingText: {
    fontSize: typography.fontSize.xs,
    color: colors.warning,
  },
  deleteButton: {
    position: 'absolute',
    top: spacing.sm,
    left: spacing.sm,
    backgroundColor: colors.error,
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  deleteText: {
    color: colors.white,
    fontSize: 18,
    fontWeight: typography.fontWeight.bold,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(255,255,255,0.8)',
    borderRadius: borderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    fontSize: 24,
  },
  tipsCard: {
    marginBottom: spacing.xl,
    backgroundColor: colors.gray50,
  },
  tipsTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  tipText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 22,
  },
});
