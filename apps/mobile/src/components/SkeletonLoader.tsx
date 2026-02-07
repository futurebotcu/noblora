// ============================================================================
// SKELETON LOADER COMPONENT
// Animated placeholder for loading states
// ============================================================================

import React, { useEffect } from 'react';
import { View, StyleSheet, ViewStyle, DimensionValue } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { colors, borderRadius } from '../constants/theme';

interface SkeletonProps {
  width?: number | string;
  height?: number;
  borderRadius?: number;
  style?: ViewStyle;
}

export function Skeleton({
  width = '100%',
  height = 20,
  borderRadius: radius = borderRadius.md,
  style,
}: SkeletonProps) {
  const shimmerProgress = useSharedValue(0);

  useEffect(() => {
    shimmerProgress.value = withRepeat(
      withTiming(1, { duration: 1500 }),
      -1, // infinite
      false
    );
  }, [shimmerProgress]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: interpolate(shimmerProgress.value, [0, 0.5, 1], [0.3, 0.6, 0.3]),
  }));

  return (
    <Animated.View
      style={[
        styles.skeleton,
        { width: width as DimensionValue, height, borderRadius: radius },
        animatedStyle,
        style,
      ]}
    />
  );
}

// Pre-built skeleton layouts
export function SkeletonCard() {
  return (
    <View style={styles.card}>
      <Skeleton height={200} borderRadius={borderRadius.lg} />
      <View style={styles.cardContent}>
        <Skeleton width="60%" height={24} style={styles.cardTitle} />
        <Skeleton width="40%" height={16} />
      </View>
    </View>
  );
}

export function SkeletonListItem() {
  return (
    <View style={styles.listItem}>
      <Skeleton width={50} height={50} borderRadius={25} />
      <View style={styles.listItemContent}>
        <Skeleton width="70%" height={18} style={styles.listItemTitle} />
        <Skeleton width="50%" height={14} />
      </View>
    </View>
  );
}

export function SkeletonProfile() {
  return (
    <View style={styles.profile}>
      <Skeleton width={100} height={100} borderRadius={50} />
      <Skeleton width={150} height={24} style={styles.profileName} />
      <Skeleton width={100} height={16} />
    </View>
  );
}

const styles = StyleSheet.create({
  skeleton: {
    backgroundColor: colors.gray200,
  },
  card: {
    backgroundColor: colors.white,
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
  },
  cardContent: {
    padding: 16,
  },
  cardTitle: {
    marginBottom: 8,
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
  },
  listItemContent: {
    flex: 1,
    marginLeft: 12,
  },
  listItemTitle: {
    marginBottom: 4,
  },
  profile: {
    alignItems: 'center',
    padding: 20,
  },
  profileName: {
    marginTop: 16,
    marginBottom: 8,
  },
});
