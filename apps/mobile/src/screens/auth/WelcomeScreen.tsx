// ============================================================================
// WELCOME SCREEN
// Initial landing screen with sign in/up options
// ============================================================================

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { Button } from '../../components/Button';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Welcome'>;

export function WelcomeScreen() {
  const navigation = useNavigation<NavigationProp>();

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        {/* Logo and branding */}
        <View style={styles.header}>
          <Text style={styles.logo}>Noblara</Text>
          <Text style={styles.tagline}>Premium connections for meaningful relationships</Text>
        </View>

        {/* Features */}
        <View style={styles.features}>
          <FeatureItem
            emoji="✓"
            title="Verified profiles"
            description="Photos, Instagram, and identity verified"
          />
          <FeatureItem
            emoji="📹"
            title="Video-first"
            description="Connect through video calls before chat"
          />
          <FeatureItem
            emoji="🤝"
            title="Real meetups"
            description="QR check-in confirms genuine meetings"
          />
        </View>

        {/* Actions */}
        <View style={styles.actions}>
          <Button
            title="Create Account"
            onPress={() => navigation.navigate('SignUp')}
            fullWidth
            size="lg"
          />
          <Button
            title="Sign In"
            onPress={() => navigation.navigate('SignIn')}
            variant="outline"
            fullWidth
            size="lg"
            style={styles.signInButton}
          />
        </View>

        {/* Terms */}
        <Text style={styles.terms}>
          By continuing, you agree to our Terms of Service and Privacy Policy
        </Text>
      </View>
    </SafeAreaView>
  );
}

function FeatureItem({
  emoji,
  title,
  description,
}: {
  emoji: string;
  title: string;
  description: string;
}) {
  return (
    <View style={styles.featureItem}>
      <Text style={styles.featureEmoji}>{emoji}</Text>
      <View style={styles.featureText}>
        <Text style={styles.featureTitle}>{title}</Text>
        <Text style={styles.featureDescription}>{description}</Text>
      </View>
    </View>
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
    justifyContent: 'space-between',
  },
  header: {
    alignItems: 'center',
    marginTop: spacing.xxxxl,
  },
  logo: {
    fontSize: 48,
    fontWeight: typography.fontWeight.bold,
    color: colors.primary,
    marginBottom: spacing.md,
  },
  tagline: {
    fontSize: typography.fontSize.lg,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 26,
  },
  features: {
    marginVertical: spacing.xxxl,
  },
  featureItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: spacing.xl,
  },
  featureEmoji: {
    fontSize: 24,
    marginRight: spacing.lg,
    marginTop: 2,
  },
  featureText: {
    flex: 1,
  },
  featureTitle: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  featureDescription: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    lineHeight: 22,
  },
  actions: {
    marginBottom: spacing.xl,
  },
  signInButton: {
    marginTop: spacing.md,
  },
  terms: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
    textAlign: 'center',
    lineHeight: 20,
  },
});
