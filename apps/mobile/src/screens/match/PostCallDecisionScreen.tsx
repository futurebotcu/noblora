// ============================================================================
// POST CALL DECISION SCREEN
// Both users must tap Continue to unlock chat
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'PostCallDecision'>;
type RouteType = RouteProp<RootStackParamList, 'PostCallDecision'>;

export function PostCallDecisionScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { matchId } = route.params;

  const [isLoading, setIsLoading] = useState(false);
  const [hasDecided, setHasDecided] = useState(false);
  const [decision, setDecision] = useState<boolean | null>(null);

  const handleDecision = async (continueMatch: boolean) => {
    setIsLoading(true);

    try {
      const response = await api.submitCallDecision(matchId, continueMatch);

      if (response.success) {
        setHasDecided(true);
        setDecision(continueMatch);

        const data = response.data as {
          both_decided: boolean;
          chat_unlocked: boolean;
          match_closed: boolean;
        };

        if (data.both_decided) {
          if (data.chat_unlocked) {
            Alert.alert(
              '🎉 Chat Unlocked!',
              'You can now chat with Sofia.',
              [{ text: 'Start Chatting', onPress: () => navigation.replace('Chat', { matchId }) }]
            );
          } else if (data.match_closed) {
            Alert.alert(
              'Match Closed',
              'This match has ended.',
              [{ text: 'OK', onPress: () => navigation.popToTop() }]
            );
          }
        }
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to submit decision');
    } finally {
      setIsLoading(false);
    }
  };

  if (hasDecided && decision) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.waitingContent}>
          <Text style={styles.waitingEmoji}>⏳</Text>
          <Text style={styles.waitingTitle}>Waiting for Sofia</Text>
          <Text style={styles.waitingText}>
            You chose to continue! Waiting for Sofia to make her decision...
          </Text>
          <Button
            title="Go to Matches"
            onPress={() => navigation.popToTop()}
            variant="outline"
            style={styles.matchesButton}
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.emoji}>🤔</Text>
        <Text style={styles.title}>How was the call?</Text>
        <Text style={styles.subtitle}>
          Would you like to continue chatting with Sofia?
        </Text>

        <Card variant="outlined" style={styles.infoCard}>
          <Text style={styles.infoText}>
            If you both choose to continue, chat will be unlocked.
            If either declines, the match will be closed permanently.
          </Text>
        </Card>

        <View style={styles.ratingSection}>
          <Text style={styles.ratingLabel}>Rate the call (optional)</Text>
          <View style={styles.stars}>
            {[1, 2, 3, 4, 5].map(star => (
              <Text key={star} style={styles.star}>⭐</Text>
            ))}
          </View>
        </View>

        <View style={styles.actions}>
          <Button
            title="Continue"
            onPress={() => handleDecision(true)}
            loading={isLoading}
            fullWidth
            size="lg"
          />
          <Button
            title="End Match"
            onPress={() => {
              Alert.alert(
                'End Match',
                'Are you sure? This cannot be undone.',
                [
                  { text: 'Cancel', style: 'cancel' },
                  { text: 'End Match', style: 'destructive', onPress: () => handleDecision(false) },
                ]
              );
            }}
            variant="outline"
            fullWidth
            size="lg"
            style={styles.endButton}
          />
        </View>
      </View>
    </SafeAreaView>
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
    alignItems: 'center',
    justifyContent: 'center',
  },
  emoji: {
    fontSize: 64,
    marginBottom: spacing.xl,
  },
  title: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: typography.fontSize.lg,
    color: colors.textSecondary,
    marginBottom: spacing.xxl,
    textAlign: 'center',
  },
  infoCard: {
    marginBottom: spacing.xxl,
    width: '100%',
  },
  infoText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  ratingSection: {
    alignItems: 'center',
    marginBottom: spacing.xxl,
  },
  ratingLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginBottom: spacing.sm,
  },
  stars: {
    flexDirection: 'row',
  },
  star: {
    fontSize: 32,
    marginHorizontal: spacing.xs,
  },
  actions: {
    width: '100%',
  },
  endButton: {
    marginTop: spacing.md,
    borderColor: colors.error,
  },
  waitingContent: {
    flex: 1,
    padding: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
  },
  waitingEmoji: {
    fontSize: 64,
    marginBottom: spacing.xl,
  },
  waitingTitle: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  waitingText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: spacing.xxl,
  },
  matchesButton: {
    marginTop: spacing.xl,
  },
});
