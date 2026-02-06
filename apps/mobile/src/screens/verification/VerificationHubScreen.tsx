// ============================================================================
// VERIFICATION HUB SCREEN
// Central screen showing verification progress and requirements
// ============================================================================

import React, { useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { useGatingStore, selectVerificationProgress } from '../../store/gatingStore';
import { Card } from '../../components/Card';
import { ProgressBar } from '../../components/ProgressBar';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'VerificationHub'>;

export function VerificationHubScreen() {
  const navigation = useNavigation<NavigationProp>();
  const { fetchStatus } = useGatingStore();
  const progress = useGatingStore(selectVerificationProgress);

  useEffect(() => {
    fetchStatus();
  }, [fetchStatus]);

  const totalSteps = 3;
  const completedSteps =
    (progress.photosApproved >= progress.photosRequired ? 1 : 0) +
    (progress.instagramVerified ? 1 : 0) +
    (progress.genderVerified ? 1 : 0);

  const overallProgress = (completedSteps / totalSteps) * 100;

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.content}>
          <View style={styles.header}>
            <Text style={styles.title}>Verify Your Profile</Text>
            <Text style={styles.subtitle}>
              Complete all verification steps to unlock likes and messaging
            </Text>
          </View>

          {/* Overall Progress */}
          <Card style={styles.progressCard}>
            <Text style={styles.progressLabel}>Overall Progress</Text>
            <ProgressBar progress={overallProgress} showLabel height={12} />
            <Text style={styles.progressText}>
              {completedSteps} of {totalSteps} steps completed
            </Text>
          </Card>

          {/* Verification Steps */}
          <View style={styles.steps}>
            <VerificationStep
              number={1}
              title="Photos"
              description={`Upload ${progress.photosRequired} photos with your face clearly visible`}
              status={progress.photosApproved >= progress.photosRequired ? 'complete' : 'incomplete'}
              progress={`${progress.photosApproved}/${progress.photosRequired}`}
              onPress={() => navigation.navigate('PhotoVerification')}
            />

            <VerificationStep
              number={2}
              title="Instagram"
              description="Verify your Instagram account to prove authenticity"
              status={progress.instagramVerified ? 'complete' : 'incomplete'}
              onPress={() => navigation.navigate('InstagramVerification')}
            />

            <VerificationStep
              number={3}
              title="Identity"
              description="Verify your identity for a safe community"
              status={progress.genderVerified ? 'complete' : 'incomplete'}
              onPress={() => navigation.navigate('GenderVerification')}
            />
          </View>

          {/* Info Card */}
          <Card variant="outlined" style={styles.infoCard}>
            <Text style={styles.infoTitle}>Why verification?</Text>
            <Text style={styles.infoText}>
              Noblara maintains a high-quality community by verifying all members.
              This ensures authentic profiles and creates a safer environment for everyone.
            </Text>
          </Card>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function VerificationStep({
  number,
  title,
  description,
  status,
  progress,
  onPress,
}: {
  number: number;
  title: string;
  description: string;
  status: 'complete' | 'incomplete' | 'pending';
  progress?: string;
  onPress: () => void;
}) {
  const isComplete = status === 'complete';
  const isPending = status === 'pending';

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.8}>
      <Card style={[styles.step, isComplete && styles.stepComplete]}>
        <View style={styles.stepHeader}>
          <View style={[styles.stepNumber, isComplete && styles.stepNumberComplete]}>
            {isComplete ? (
              <Text style={styles.stepNumberTextComplete}>✓</Text>
            ) : (
              <Text style={styles.stepNumberText}>{number}</Text>
            )}
          </View>
          <View style={styles.stepContent}>
            <View style={styles.stepTitleRow}>
              <Text style={styles.stepTitle}>{title}</Text>
              {progress && <Text style={styles.stepProgress}>{progress}</Text>}
            </View>
            <Text style={styles.stepDescription}>{description}</Text>
          </View>
          <Text style={styles.stepArrow}>→</Text>
        </View>
        {isPending && (
          <View style={styles.pendingBadge}>
            <Text style={styles.pendingText}>Pending Review</Text>
          </View>
        )}
      </Card>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    flexGrow: 1,
  },
  content: {
    flex: 1,
    padding: spacing.xl,
  },
  header: {
    marginBottom: spacing.xxl,
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
    marginBottom: spacing.xxl,
  },
  progressLabel: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.medium,
    color: colors.textSecondary,
    marginBottom: spacing.sm,
  },
  progressText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginTop: spacing.sm,
  },
  steps: {
    marginBottom: spacing.xxl,
  },
  step: {
    marginBottom: spacing.md,
  },
  stepComplete: {
    borderLeftWidth: 3,
    borderLeftColor: colors.success,
  },
  stepHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  stepNumber: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.gray200,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
  },
  stepNumberComplete: {
    backgroundColor: colors.success,
  },
  stepNumberText: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textSecondary,
  },
  stepNumberTextComplete: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.bold,
    color: colors.white,
  },
  stepContent: {
    flex: 1,
  },
  stepTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  stepTitle: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  stepProgress: {
    fontSize: typography.fontSize.sm,
    color: colors.primary,
    fontWeight: typography.fontWeight.medium,
  },
  stepDescription: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
  stepArrow: {
    fontSize: typography.fontSize.xl,
    color: colors.gray400,
    marginLeft: spacing.md,
  },
  pendingBadge: {
    backgroundColor: colors.warningLight,
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
    borderRadius: 4,
    alignSelf: 'flex-start',
    marginTop: spacing.sm,
    marginLeft: 44,
  },
  pendingText: {
    fontSize: typography.fontSize.xs,
    color: colors.warning,
    fontWeight: typography.fontWeight.medium,
  },
  infoCard: {
    backgroundColor: colors.gray50,
  },
  infoTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  infoText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
});
