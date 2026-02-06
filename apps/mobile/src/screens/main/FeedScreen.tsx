// ============================================================================
// FEED SCREEN
// 60fps swipe cards for discovering profiles
// ============================================================================

import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, Dimensions, Image } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  runOnJS,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated';
import { colors, spacing, typography, borderRadius, shadows } from '../../constants/theme';
import { Skeleton, SkeletonCard } from '../../components/SkeletonLoader';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const CARD_WIDTH = SCREEN_WIDTH - spacing.xl * 2;
const SWIPE_THRESHOLD = SCREEN_WIDTH * 0.3;
const ROTATION_ANGLE = 15;

interface ProfileCard {
  id: string;
  name: string;
  age: number;
  city: string;
  bio: string;
  photos: string[];
  instagramVerified: boolean;
  distance?: number;
}

// Mock data for development
const MOCK_PROFILES: ProfileCard[] = [
  {
    id: '1',
    name: 'Sofia',
    age: 26,
    city: 'Istanbul',
    bio: 'Coffee lover ☕ Travel enthusiast ✈️',
    photos: ['https://picsum.photos/400/600?random=1'],
    instagramVerified: true,
    distance: 5,
  },
  {
    id: '2',
    name: 'Emma',
    age: 24,
    city: 'Ankara',
    bio: 'Artist and dreamer 🎨',
    photos: ['https://picsum.photos/400/600?random=2'],
    instagramVerified: true,
    distance: 12,
  },
  {
    id: '3',
    name: 'Ayşe',
    age: 28,
    city: 'Izmir',
    bio: 'Yoga instructor | Nature lover 🌿',
    photos: ['https://picsum.photos/400/600?random=3'],
    instagramVerified: true,
    distance: 8,
  },
];

export function FeedScreen() {
  const [profiles, setProfiles] = useState(MOCK_PROFILES);
  const [isLoading, setIsLoading] = useState(false);

  const handleSwipe = useCallback((direction: 'left' | 'right', profileId: string) => {
    // Remove the swiped card
    setProfiles(prev => prev.filter(p => p.id !== profileId));

    if (direction === 'right') {
      // Handle like - would call API here
      console.log('Liked:', profileId);
    } else {
      // Handle pass
      console.log('Passed:', profileId);
    }

    // Load more profiles if running low
    if (profiles.length <= 2) {
      // Would fetch more from API
    }
  }, [profiles.length]);

  if (isLoading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.title}>Discover</Text>
        </View>
        <View style={styles.loadingContainer}>
          <SkeletonCard />
        </View>
      </SafeAreaView>
    );
  }

  if (profiles.length === 0) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.title}>Discover</Text>
        </View>
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyEmoji}>🔍</Text>
          <Text style={styles.emptyTitle}>No more profiles</Text>
          <Text style={styles.emptyText}>
            Check back later for new people to discover!
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Discover</Text>
        <Text style={styles.filterButton}>⚙️</Text>
      </View>

      <View style={styles.cardsContainer}>
        {/* Render cards in reverse order so top card renders last */}
        {profiles.slice(0, 3).reverse().map((profile, index) => {
          const isTopCard = index === profiles.slice(0, 3).length - 1;
          return (
            <SwipeCard
              key={profile.id}
              profile={profile}
              isTopCard={isTopCard}
              onSwipe={(direction) => handleSwipe(direction, profile.id)}
            />
          );
        })}
      </View>

      {/* Action Buttons */}
      <View style={styles.actions}>
        <ActionButton icon="✕" onPress={() => handleSwipe('left', profiles[0]?.id)} color={colors.error} />
        <ActionButton icon="♡" onPress={() => handleSwipe('right', profiles[0]?.id)} color={colors.primary} large />
      </View>
    </SafeAreaView>
  );
}

function SwipeCard({
  profile,
  isTopCard,
  onSwipe,
}: {
  profile: ProfileCard;
  isTopCard: boolean;
  onSwipe: (direction: 'left' | 'right') => void;
}) {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);

  const gesture = Gesture.Pan()
    .enabled(isTopCard)
    .onUpdate((event) => {
      translateX.value = event.translationX;
      translateY.value = event.translationY;
    })
    .onEnd((event) => {
      if (Math.abs(event.translationX) > SWIPE_THRESHOLD) {
        const direction = event.translationX > 0 ? 'right' : 'left';
        const targetX = direction === 'right' ? SCREEN_WIDTH * 1.5 : -SCREEN_WIDTH * 1.5;

        translateX.value = withTiming(targetX, { duration: 300 }, () => {
          runOnJS(onSwipe)(direction);
        });
      } else {
        // Spring back to center
        translateX.value = withSpring(0, { damping: 15, stiffness: 150 });
        translateY.value = withSpring(0, { damping: 15, stiffness: 150 });
      }
    });

  const cardStyle = useAnimatedStyle(() => {
    const rotation = interpolate(
      translateX.value,
      [-SCREEN_WIDTH, 0, SCREEN_WIDTH],
      [-ROTATION_ANGLE, 0, ROTATION_ANGLE],
      Extrapolation.CLAMP
    );

    return {
      transform: [
        { translateX: translateX.value },
        { translateY: translateY.value },
        { rotate: `${rotation}deg` },
      ],
    };
  });

  const likeOpacity = useAnimatedStyle(() => ({
    opacity: interpolate(translateX.value, [0, SWIPE_THRESHOLD], [0, 1], Extrapolation.CLAMP),
  }));

  const nopeOpacity = useAnimatedStyle(() => ({
    opacity: interpolate(translateX.value, [-SWIPE_THRESHOLD, 0], [1, 0], Extrapolation.CLAMP),
  }));

  return (
    <GestureDetector gesture={gesture}>
      <Animated.View style={[styles.card, cardStyle]}>
        <Image
          source={{ uri: profile.photos[0] }}
          style={styles.cardImage}
          resizeMode="cover"
        />

        {/* Like/Nope overlays */}
        <Animated.View style={[styles.likeOverlay, likeOpacity]}>
          <Text style={styles.likeText}>LIKE</Text>
        </Animated.View>
        <Animated.View style={[styles.nopeOverlay, nopeOpacity]}>
          <Text style={styles.nopeText}>NOPE</Text>
        </Animated.View>

        {/* Profile info overlay */}
        <View style={styles.cardOverlay}>
          <View style={styles.cardInfo}>
            <View style={styles.nameRow}>
              <Text style={styles.cardName}>{profile.name}, {profile.age}</Text>
              {profile.instagramVerified && (
                <View style={styles.verifiedBadge}>
                  <Text style={styles.verifiedText}>✓ IG</Text>
                </View>
              )}
            </View>
            <Text style={styles.cardCity}>
              📍 {profile.city} {profile.distance && `• ${profile.distance} km`}
            </Text>
            <Text style={styles.cardBio} numberOfLines={2}>{profile.bio}</Text>
          </View>
        </View>
      </Animated.View>
    </GestureDetector>
  );
}

function ActionButton({
  icon,
  onPress,
  color,
  large = false,
}: {
  icon: string;
  onPress: () => void;
  color: string;
  large?: boolean;
}) {
  return (
    <Animated.View
      style={[
        styles.actionButton,
        { borderColor: color },
        large && styles.actionButtonLarge,
      ]}
    >
      <Text
        style={[styles.actionIcon, { color }, large && styles.actionIconLarge]}
        onPress={onPress}
      >
        {icon}
      </Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
  },
  title: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
  },
  filterButton: {
    fontSize: 24,
  },
  loadingContainer: {
    flex: 1,
    padding: spacing.xl,
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xl,
  },
  emptyEmoji: {
    fontSize: 64,
    marginBottom: spacing.xl,
  },
  emptyTitle: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  emptyText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
  },
  cardsContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  card: {
    position: 'absolute',
    width: CARD_WIDTH,
    height: SCREEN_HEIGHT * 0.6,
    borderRadius: borderRadius.xl,
    overflow: 'hidden',
    ...shadows.xl,
  },
  cardImage: {
    width: '100%',
    height: '100%',
  },
  cardOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'flex-end',
    background: 'linear-gradient(transparent, rgba(0,0,0,0.6))',
  },
  cardInfo: {
    padding: spacing.xl,
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  cardName: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.white,
    marginRight: spacing.sm,
  },
  verifiedBadge: {
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xxs,
    borderRadius: borderRadius.sm,
  },
  verifiedText: {
    fontSize: typography.fontSize.xs,
    color: colors.white,
    fontWeight: typography.fontWeight.semibold,
  },
  cardCity: {
    fontSize: typography.fontSize.md,
    color: colors.white,
    marginBottom: spacing.sm,
    opacity: 0.9,
  },
  cardBio: {
    fontSize: typography.fontSize.md,
    color: colors.white,
    opacity: 0.8,
  },
  likeOverlay: {
    position: 'absolute',
    top: spacing.xxl,
    left: spacing.xl,
    borderWidth: 4,
    borderColor: colors.success,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    transform: [{ rotate: '-20deg' }],
  },
  likeText: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.success,
  },
  nopeOverlay: {
    position: 'absolute',
    top: spacing.xxl,
    right: spacing.xl,
    borderWidth: 4,
    borderColor: colors.error,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    transform: [{ rotate: '20deg' }],
  },
  nopeText: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.error,
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: spacing.xl,
    gap: spacing.xl,
  },
  actionButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.white,
    ...shadows.md,
  },
  actionButtonLarge: {
    width: 72,
    height: 72,
    borderRadius: 36,
  },
  actionIcon: {
    fontSize: 24,
  },
  actionIconLarge: {
    fontSize: 32,
  },
});
