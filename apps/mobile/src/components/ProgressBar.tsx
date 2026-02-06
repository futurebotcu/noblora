// ============================================================================
// PROGRESS BAR COMPONENT
// Animated progress indicator
// ============================================================================

import React, { useEffect } from 'react';
import { View, StyleSheet, Text, ViewStyle } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { colors, spacing, borderRadius, typography } from '../constants/theme';

interface ProgressBarProps {
  progress: number; // 0-100
  color?: string;
  backgroundColor?: string;
  height?: number;
  showLabel?: boolean;
  labelPosition?: 'top' | 'right' | 'inside';
  style?: ViewStyle;
}

export function ProgressBar({
  progress,
  color = colors.primary,
  backgroundColor = colors.gray200,
  height = 8,
  showLabel = false,
  labelPosition = 'right',
  style,
}: ProgressBarProps) {
  const animatedProgress = useSharedValue(0);

  useEffect(() => {
    animatedProgress.value = withTiming(Math.min(100, Math.max(0, progress)), {
      duration: 500,
      easing: Easing.bezier(0.25, 0.1, 0.25, 1),
    });
  }, [progress, animatedProgress]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${animatedProgress.value}%`,
  }));

  const label = `${Math.round(progress)}%`;

  return (
    <View style={[styles.container, style]}>
      {showLabel && labelPosition === 'top' && (
        <Text style={styles.labelTop}>{label}</Text>
      )}

      <View style={styles.row}>
        <View
          style={[
            styles.track,
            { backgroundColor, height, borderRadius: height / 2 },
          ]}
        >
          <Animated.View
            style={[
              styles.fill,
              { backgroundColor: color, height, borderRadius: height / 2 },
              animatedStyle,
            ]}
          >
            {showLabel && labelPosition === 'inside' && height >= 16 && (
              <Text style={styles.labelInside}>{label}</Text>
            )}
          </Animated.View>
        </View>

        {showLabel && labelPosition === 'right' && (
          <Text style={styles.labelRight}>{label}</Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  track: {
    flex: 1,
    overflow: 'hidden',
  },
  fill: {
    justifyContent: 'center',
    alignItems: 'flex-end',
    paddingRight: spacing.sm,
  },
  labelTop: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
    textAlign: 'right',
  },
  labelRight: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginLeft: spacing.sm,
    minWidth: 40,
  },
  labelInside: {
    fontSize: typography.fontSize.xs,
    color: colors.white,
    fontWeight: typography.fontWeight.semibold,
  },
});
