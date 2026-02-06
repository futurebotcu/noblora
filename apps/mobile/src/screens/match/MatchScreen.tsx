// ============================================================================
// MATCH SCREEN
// Shows new match celebration
// ============================================================================

import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { Button } from '../../components/Button';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Match'>;
type RouteType = RouteProp<RootStackParamList, 'Match'>;

export function MatchScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { matchId } = route.params;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.emoji}>💜</Text>
        <Text style={styles.title}>It's a Match!</Text>
        <Text style={styles.subtitle}>
          You and Sofia liked each other
        </Text>

        {/* Photos */}
        <View style={styles.photosContainer}>
          <Image
            source={{ uri: 'https://picsum.photos/120/120?random=me' }}
            style={styles.photo}
          />
          <View style={styles.heartContainer}>
            <Text style={styles.heart}>♥</Text>
          </View>
          <Image
            source={{ uri: 'https://picsum.photos/120/120?random=match' }}
            style={styles.photo}
          />
        </View>

        {/* Schedule Window Info */}
        <View style={styles.infoCard}>
          <Text style={styles.infoTitle}>What's next?</Text>
          <Text style={styles.infoText}>
            You have 12 hours to schedule a video call.{'\n'}
            The woman makes the first proposal.
          </Text>
        </View>

        <View style={styles.actions}>
          <Button
            title="Schedule Call"
            onPress={() => navigation.replace('Scheduling', { matchId })}
            fullWidth
            size="lg"
          />
          <Button
            title="Keep Swiping"
            onPress={() => navigation.goBack()}
            variant="outline"
            fullWidth
            size="lg"
            style={styles.keepSwipingButton}
          />
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.primary,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xl,
  },
  emoji: {
    fontSize: 64,
    marginBottom: spacing.lg,
  },
  title: {
    fontSize: typography.fontSize.display,
    fontWeight: typography.fontWeight.bold,
    color: colors.white,
    marginBottom: spacing.sm,
  },
  subtitle: {
    fontSize: typography.fontSize.lg,
    color: colors.white,
    opacity: 0.9,
    marginBottom: spacing.xxl,
  },
  photosContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xxl,
  },
  photo: {
    width: 120,
    height: 120,
    borderRadius: 60,
    borderWidth: 4,
    borderColor: colors.white,
  },
  heartContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: colors.secondary,
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: -spacing.lg,
    zIndex: 1,
  },
  heart: {
    fontSize: 24,
    color: colors.white,
  },
  infoCard: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    padding: spacing.xl,
    borderRadius: 16,
    marginBottom: spacing.xxl,
    width: '100%',
  },
  infoTitle: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.white,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  infoText: {
    fontSize: typography.fontSize.md,
    color: colors.white,
    opacity: 0.9,
    textAlign: 'center',
    lineHeight: 24,
  },
  actions: {
    width: '100%',
  },
  keepSwipingButton: {
    marginTop: spacing.md,
    borderColor: colors.white,
  },
});
