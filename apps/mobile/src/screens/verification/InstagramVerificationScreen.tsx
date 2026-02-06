// ============================================================================
// INSTAGRAM VERIFICATION SCREEN
// Connect and verify Instagram account
// NOTE: IG username is NEVER shown to other users
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { launchImageLibrary } from 'react-native-image-picker';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Input } from '../../components/Input';
import { Card } from '../../components/Card';
import { colors, spacing, typography } from '../../constants/theme';

export function InstagramVerificationScreen() {
  const navigation = useNavigation();
  const [username, setUsername] = useState('');
  const [proofUrl, setProofUrl] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState<'initial' | 'pending' | 'verified'>('initial');

  const handleOAuthConnect = async () => {
    // OAuth flow placeholder - would open Instagram OAuth
    Alert.alert(
      'Instagram OAuth',
      'OAuth integration coming soon. Please use manual verification for now.',
      [{ text: 'OK' }]
    );
  };

  const handleSelectProof = async () => {
    try {
      const result = await launchImageLibrary({
        mediaType: 'photo',
        quality: 0.8,
      });

      if (result.assets?.[0]?.uri) {
        // In real app, upload to storage first and get URL
        setProofUrl(result.assets[0].uri);
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to select image');
    }
  };

  const handleManualVerify = async () => {
    if (!username || !proofUrl) {
      Alert.alert('Error', 'Please enter your username and upload proof');
      return;
    }

    setIsLoading(true);
    try {
      const response = await api.connectInstagram({
        ig_username: username,
        proof_image_url: proofUrl,
      });

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
        <View style={styles.content}>
          <View style={styles.successContainer}>
            <Text style={styles.successIcon}>📸</Text>
            <Text style={styles.successTitle}>Verification Submitted</Text>
            <Text style={styles.successText}>
              Your Instagram verification is pending review. We'll notify you once it's approved.
            </Text>
            <Button
              title="Continue"
              onPress={() => navigation.goBack()}
              fullWidth
              style={styles.continueButton}
            />
          </View>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>

        <View style={styles.header}>
          <Text style={styles.title}>Verify Instagram</Text>
          <Text style={styles.subtitle}>
            Connect your Instagram to verify your authenticity. Your username is kept private and never shown to others.
          </Text>
        </View>

        {/* Privacy Notice */}
        <Card variant="outlined" style={styles.privacyCard}>
          <Text style={styles.privacyTitle}>🔒 Privacy First</Text>
          <Text style={styles.privacyText}>
            Other users will only see an "Instagram Verified" badge.
            Your username and profile are never shared.
          </Text>
        </Card>

        {/* OAuth Option */}
        <Button
          title="Connect with Instagram"
          onPress={handleOAuthConnect}
          variant="outline"
          fullWidth
          size="lg"
          style={styles.oauthButton}
        />

        <View style={styles.divider}>
          <View style={styles.dividerLine} />
          <Text style={styles.dividerText}>or verify manually</Text>
          <View style={styles.dividerLine} />
        </View>

        {/* Manual Verification */}
        <Input
          label="Instagram Username"
          placeholder="your_username"
          value={username}
          onChangeText={setUsername}
          autoCapitalize="none"
          autoCorrect={false}
        />

        <Text style={styles.proofLabel}>Upload Proof Screenshot</Text>
        <Text style={styles.proofHint}>
          Take a screenshot of your Instagram profile showing your username and a recent photo with your face
        </Text>

        <TouchableOpacity style={styles.proofUpload} onPress={handleSelectProof}>
          {proofUrl ? (
            <Text style={styles.proofSelected}>✓ Proof selected</Text>
          ) : (
            <Text style={styles.proofPlaceholder}>Tap to select screenshot</Text>
          )}
        </TouchableOpacity>

        <View style={styles.footer}>
          <Button
            title="Submit for Review"
            onPress={handleManualVerify}
            loading={isLoading}
            disabled={!username || !proofUrl}
            fullWidth
            size="lg"
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
  privacyCard: {
    backgroundColor: colors.successLight,
    marginBottom: spacing.xl,
  },
  privacyTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.success,
    marginBottom: spacing.xs,
  },
  privacyText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
  oauthButton: {
    marginBottom: spacing.xl,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: colors.border,
  },
  dividerText: {
    marginHorizontal: spacing.md,
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
  },
  proofLabel: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.medium,
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  proofHint: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
    marginBottom: spacing.md,
    lineHeight: 20,
  },
  proofUpload: {
    borderWidth: 2,
    borderColor: colors.border,
    borderStyle: 'dashed',
    borderRadius: 12,
    padding: spacing.xl,
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  proofPlaceholder: {
    fontSize: typography.fontSize.md,
    color: colors.gray400,
  },
  proofSelected: {
    fontSize: typography.fontSize.md,
    color: colors.success,
    fontWeight: typography.fontWeight.medium,
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
