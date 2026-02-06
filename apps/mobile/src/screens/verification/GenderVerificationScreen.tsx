// ============================================================================
// GENDER VERIFICATION SCREEN
// Submit ID/selfie proof for gender verification
// NOTE: We do NOT use AI to infer gender - admin review only
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { launchImageLibrary } from 'react-native-image-picker';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography } from '../../constants/theme';

export function GenderVerificationScreen() {
  const navigation = useNavigation();
  const [evidenceUrl, setEvidenceUrl] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState<'initial' | 'pending'>('initial');

  const handleSelectEvidence = async () => {
    try {
      const result = await launchImageLibrary({
        mediaType: 'photo',
        quality: 0.8,
      });

      if (result.assets?.[0]?.uri) {
        // In real app, upload to storage first and get URL
        setEvidenceUrl(result.assets[0].uri);
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to select image');
    }
  };

  const handleSubmit = async () => {
    if (!evidenceUrl) {
      Alert.alert('Error', 'Please upload verification evidence');
      return;
    }

    setIsLoading(true);
    try {
      const response = await api.submitGenderVerification(evidenceUrl);

      if (response.success) {
        setStatus('pending');
      } else {
        Alert.alert('Error', response.error?.message || 'Verification failed');
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to submit verification');
    } finally {
      setIsLoading(false);
    }
  };

  if (status === 'pending') {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.successContainer}>
          <Text style={styles.successIcon}>🔐</Text>
          <Text style={styles.successTitle}>Submitted for Review</Text>
          <Text style={styles.successText}>
            Your identity verification is being reviewed by our team.
            This usually takes 24-48 hours. We'll notify you once complete.
          </Text>
          <Button
            title="Continue"
            onPress={() => navigation.goBack()}
            fullWidth
            style={styles.continueButton}
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.content}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
            <Text style={styles.backText}>← Back</Text>
          </TouchableOpacity>

          <View style={styles.header}>
            <Text style={styles.title}>Identity Verification</Text>
            <Text style={styles.subtitle}>
              Verify your identity to help maintain a safe and authentic community.
              This information is handled securely and privately.
            </Text>
          </View>

          {/* Important Notice */}
          <Card variant="outlined" style={styles.noticeCard}>
            <Text style={styles.noticeTitle}>🛡️ Privacy & Safety</Text>
            <Text style={styles.noticeText}>
              • Your ID is reviewed by trained human moderators{'\n'}
              • We never use AI to infer or classify gender{'\n'}
              • Your documents are encrypted and can be deleted on request{'\n'}
              • Only your verification badge is visible to others
            </Text>
          </Card>

          {/* What to Submit */}
          <Text style={styles.sectionTitle}>What to Submit</Text>
          <Text style={styles.sectionText}>
            Please upload ONE of the following:
          </Text>

          <View style={styles.optionsList}>
            <Text style={styles.optionItem}>• Government-issued ID (name can be obscured)</Text>
            <Text style={styles.optionItem}>• Selfie holding a paper with today's date</Text>
            <Text style={styles.optionItem}>• Video selfie saying "Noblara verification"</Text>
          </View>

          {/* Upload Area */}
          <TouchableOpacity style={styles.uploadArea} onPress={handleSelectEvidence}>
            {evidenceUrl ? (
              <View style={styles.uploadedContainer}>
                <Text style={styles.uploadedIcon}>✓</Text>
                <Text style={styles.uploadedText}>Evidence uploaded</Text>
                <Text style={styles.uploadedHint}>Tap to change</Text>
              </View>
            ) : (
              <View style={styles.uploadPlaceholder}>
                <Text style={styles.uploadIcon}>📷</Text>
                <Text style={styles.uploadText}>Tap to upload verification</Text>
              </View>
            )}
          </TouchableOpacity>

          {/* Data Handling Notice */}
          <Card variant="outlined" style={styles.dataCard}>
            <Text style={styles.dataTitle}>How we handle your data</Text>
            <Text style={styles.dataText}>
              Your verification documents are stored securely with encryption.
              You can request deletion at any time through Settings → Privacy → Delete My Data.
            </Text>
          </Card>

          <View style={styles.footer}>
            <Button
              title="Submit for Review"
              onPress={handleSubmit}
              loading={isLoading}
              disabled={!evidenceUrl}
              fullWidth
              size="lg"
            />
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
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
  noticeCard: {
    backgroundColor: colors.infoLight,
    marginBottom: spacing.xl,
  },
  noticeTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.info,
    marginBottom: spacing.sm,
  },
  noticeText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 22,
  },
  sectionTitle: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  sectionText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    marginBottom: spacing.md,
  },
  optionsList: {
    marginBottom: spacing.xl,
  },
  optionItem: {
    fontSize: typography.fontSize.md,
    color: colors.textPrimary,
    lineHeight: 28,
  },
  uploadArea: {
    borderWidth: 2,
    borderColor: colors.border,
    borderStyle: 'dashed',
    borderRadius: 16,
    padding: spacing.xxl,
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  uploadPlaceholder: {
    alignItems: 'center',
  },
  uploadIcon: {
    fontSize: 48,
    marginBottom: spacing.md,
  },
  uploadText: {
    fontSize: typography.fontSize.md,
    color: colors.gray500,
  },
  uploadedContainer: {
    alignItems: 'center',
  },
  uploadedIcon: {
    fontSize: 48,
    color: colors.success,
    marginBottom: spacing.sm,
  },
  uploadedText: {
    fontSize: typography.fontSize.md,
    color: colors.success,
    fontWeight: typography.fontWeight.medium,
  },
  uploadedHint: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
    marginTop: spacing.xs,
  },
  dataCard: {
    backgroundColor: colors.gray50,
    marginBottom: spacing.xl,
  },
  dataTitle: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  dataText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
  footer: {
    marginTop: 'auto',
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
