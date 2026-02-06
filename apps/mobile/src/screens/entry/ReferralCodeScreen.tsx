// ============================================================================
// REFERRAL CODE SCREEN
// Enter and redeem a referral code
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { api } from '../../services/api';
import { useGatingStore } from '../../store/gatingStore';
import { Button } from '../../components/Button';
import { Input } from '../../components/Input';
import { Card } from '../../components/Card';
import { colors, spacing, typography } from '../../constants/theme';

export function ReferralCodeScreen() {
  const navigation = useNavigation();
  const { refresh } = useGatingStore();

  const [code, setCode] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleRedeem = async () => {
    if (!code.trim()) return;

    setIsLoading(true);
    try {
      const response = await api.redeemReferralCode(code.trim().toUpperCase());

      if (response.success) {
        setSuccess(true);
        await refresh();
      } else {
        Alert.alert('Error', response.error?.message || 'Invalid referral code');
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to redeem code');
    } finally {
      setIsLoading(false);
    }
  };

  if (success) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.successContainer}>
          <Text style={styles.successIcon}>🎉</Text>
          <Text style={styles.successTitle}>Code Redeemed!</Text>
          <Text style={styles.successText}>
            You've successfully used a referral code. Note that you still need
            to invite one verified member of the opposite gender to unlock full access.
          </Text>
          <Button
            title="Continue"
            onPress={() => navigation.goBack()}
            fullWidth
            size="lg"
            style={styles.continueButton}
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>Enter Referral Code</Text>
          <Text style={styles.subtitle}>
            If someone invited you to Noblara, enter their referral code below.
          </Text>
        </View>

        <Input
          label="Referral Code"
          placeholder="e.g., ABC12345"
          value={code}
          onChangeText={(text) => setCode(text.toUpperCase())}
          autoCapitalize="characters"
          autoCorrect={false}
          maxLength={20}
        />

        <Button
          title="Redeem Code"
          onPress={handleRedeem}
          loading={isLoading}
          disabled={!code.trim()}
          fullWidth
          size="lg"
          style={styles.redeemButton}
        />

        <Card variant="outlined" style={styles.noteCard}>
          <Text style={styles.noteTitle}>Note</Text>
          <Text style={styles.noteText}>
            Using a referral code helps your referrer but doesn't
            automatically approve your entry. You'll still need to
            invite one verified member of the opposite gender.
          </Text>
        </Card>

        <Button
          title="Go Back"
          onPress={() => navigation.goBack()}
          variant="ghost"
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
  redeemButton: {
    marginTop: spacing.md,
    marginBottom: spacing.xxl,
  },
  noteCard: {
    backgroundColor: colors.gray50,
    marginBottom: spacing.xl,
  },
  noteTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  noteText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
  successContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xl,
  },
  successIcon: {
    fontSize: 64,
    marginBottom: spacing.xl,
  },
  successTitle: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.md,
    textAlign: 'center',
  },
  successText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: spacing.xxl,
  },
  continueButton: {
    marginTop: spacing.xl,
  },
});
