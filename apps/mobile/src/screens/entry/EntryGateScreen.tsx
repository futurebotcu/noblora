// ============================================================================
// ENTRY GATE SCREEN
// Shows referral requirement for entry approval
// ============================================================================

import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Share, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { useGatingStore, selectEntryProgress } from '../../store/gatingStore';
import { useProfileStore } from '../../store/profileStore';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { ProgressBar } from '../../components/ProgressBar';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'EntryGate'>;

export function EntryGateScreen() {
  const navigation = useNavigation<NavigationProp>();
  const { refresh } = useGatingStore();
  const progress = useGatingStore(selectEntryProgress);
  const profile = useProfileStore(state => state.profile);

  const [referralCode, setReferralCode] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const oppositeGender = profile?.gender_claim === 'male' ? 'female' : 'male';
  const genderLabel = oppositeGender === 'female' ? 'woman' : 'man';

  useEffect(() => {
    loadReferralCode();
  }, []);

  const loadReferralCode = async () => {
    const response = await api.getReferralStatus();
    if (response.success && response.data) {
      const codes = (response.data as { my_codes?: Array<{ code: string; is_active: boolean }> }).my_codes;
      const activeCode = codes?.find((c: { is_active: boolean }) => c.is_active);
      if (activeCode) {
        setReferralCode(activeCode.code);
      }
    }
  };

  const handleCreateCode = async () => {
    setIsLoading(true);
    try {
      const response = await api.createReferralCode(oppositeGender);
      if (response.success && response.data) {
        setReferralCode((response.data as { code: string }).code);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleShareCode = async () => {
    if (!referralCode) return;

    try {
      await Share.share({
        message: `Join me on Noblara! Use my invite code: ${referralCode}\n\nDownload: https://noblara.app`,
        title: 'Join Noblara',
      });
    } catch (error) {
      // User cancelled
    }
  };

  const progressPercent = (progress.referralsVerified / progress.referralsRequired) * 100;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.emoji}>🚪</Text>
          <Text style={styles.title}>Almost There!</Text>
          <Text style={styles.subtitle}>
            To maintain a balanced community, invite at least one verified {genderLabel} to unlock full access.
          </Text>
        </View>

        {/* Progress Card */}
        <Card style={styles.progressCard}>
          <Text style={styles.progressTitle}>Your Progress</Text>
          <ProgressBar progress={progressPercent} height={12} showLabel />
          <Text style={styles.progressText}>
            {progress.referralsVerified} of {progress.referralsRequired} verified {genderLabel}(s) invited
          </Text>
        </Card>

        {/* Referral Code */}
        <Card style={styles.codeCard}>
          <Text style={styles.codeTitle}>Your Invite Code</Text>
          {referralCode ? (
            <>
              <View style={styles.codeContainer}>
                <Text style={styles.code}>{referralCode}</Text>
              </View>
              <Button
                title="Share Code"
                onPress={handleShareCode}
                fullWidth
                style={styles.shareButton}
              />
            </>
          ) : (
            <Button
              title="Generate Invite Code"
              onPress={handleCreateCode}
              loading={isLoading}
              fullWidth
            />
          )}
          <Text style={styles.codeHint}>
            This code is for {genderLabel}s only
          </Text>
        </Card>

        {/* Have a code? */}
        <TouchableOpacity
          style={styles.haveCodeButton}
          onPress={() => navigation.navigate('ReferralCode')}
        >
          <Text style={styles.haveCodeText}>
            Have a referral code? <Text style={styles.haveCodeLink}>Enter it here</Text>
          </Text>
        </TouchableOpacity>

        {/* Info */}
        <Card variant="outlined" style={styles.infoCard}>
          <Text style={styles.infoTitle}>Why referrals?</Text>
          <Text style={styles.infoText}>
            Noblara maintains gender balance through symmetric referrals.
            This creates a fair environment for everyone and ensures
            quality connections.
          </Text>
        </Card>

        {/* Refresh */}
        <Button
          title="Refresh Status"
          onPress={refresh}
          variant="ghost"
          size="sm"
        />
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
  },
  header: {
    alignItems: 'center',
    marginBottom: spacing.xxl,
  },
  emoji: {
    fontSize: 64,
    marginBottom: spacing.lg,
  },
  title: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 24,
  },
  progressCard: {
    marginBottom: spacing.xl,
  },
  progressTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  progressText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginTop: spacing.sm,
  },
  codeCard: {
    marginBottom: spacing.xl,
    alignItems: 'center',
  },
  codeTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  codeContainer: {
    backgroundColor: colors.gray100,
    paddingVertical: spacing.lg,
    paddingHorizontal: spacing.xxl,
    borderRadius: 12,
    marginBottom: spacing.lg,
  },
  code: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.primary,
    letterSpacing: 4,
  },
  shareButton: {
    marginBottom: spacing.md,
  },
  codeHint: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
  },
  haveCodeButton: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  haveCodeText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
  },
  haveCodeLink: {
    color: colors.primary,
    fontWeight: typography.fontWeight.semibold,
  },
  infoCard: {
    backgroundColor: colors.gray50,
    marginBottom: spacing.xl,
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
