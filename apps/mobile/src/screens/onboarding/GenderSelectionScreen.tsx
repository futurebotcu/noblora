// ============================================================================
// GENDER SELECTION SCREEN
// Declare gender with privacy notice
// NOTE: We do NOT use AI to infer gender
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'GenderSelection'>;
type Gender = 'female' | 'male' | 'other';

export function GenderSelectionScreen() {
  const navigation = useNavigation<NavigationProp>();
  const [selectedGender, setSelectedGender] = useState<Gender | null>(null);

  const handleContinue = () => {
    if (!selectedGender) return;
    navigation.navigate('ProfileBasics');
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.content}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
            <Text style={styles.backText}>← Back</Text>
          </TouchableOpacity>

          <View style={styles.header}>
            <Text style={styles.step}>Step 2 of 3</Text>
            <Text style={styles.title}>How do you identify?</Text>
            <Text style={styles.subtitle}>
              This helps us show you to the right people and maintains gender balance in our community
            </Text>
          </View>

          <View style={styles.options}>
            <GenderOption
              gender="female"
              emoji="👩"
              title="Woman"
              selected={selectedGender === 'female'}
              onSelect={() => setSelectedGender('female')}
            />

            <GenderOption
              gender="male"
              emoji="👨"
              title="Man"
              selected={selectedGender === 'male'}
              onSelect={() => setSelectedGender('male')}
            />

            <GenderOption
              gender="other"
              emoji="🌈"
              title="Non-binary"
              selected={selectedGender === 'other'}
              onSelect={() => setSelectedGender('other')}
            />
          </View>

          {/* Privacy Notice */}
          <Card variant="outlined" style={styles.privacyCard}>
            <Text style={styles.privacyTitle}>🔒 Privacy & Verification</Text>
            <Text style={styles.privacyText}>
              • Your gender declaration will be verified by our team (not AI){'\n'}
              • You'll need to submit ID verification{'\n'}
              • This information is kept private and secure{'\n'}
              • We never use AI to infer or classify gender
            </Text>
          </Card>

          <View style={styles.footer}>
            <Button
              title="Continue"
              onPress={handleContinue}
              disabled={!selectedGender}
              fullWidth
              size="lg"
            />
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function GenderOption({
  gender,
  emoji,
  title,
  selected,
  onSelect,
}: {
  gender: Gender;
  emoji: string;
  title: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <TouchableOpacity onPress={onSelect} activeOpacity={0.8}>
      <Card
        variant={selected ? 'elevated' : 'outlined'}
        style={[styles.option, selected && styles.optionSelected]}
        padding="lg"
      >
        <Text style={styles.optionEmoji}>{emoji}</Text>
        <Text style={[styles.optionTitle, selected && styles.optionTitleSelected]}>
          {title}
        </Text>
        {selected && (
          <View style={styles.checkmark}>
            <Text style={styles.checkmarkText}>✓</Text>
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
  backButton: {
    marginBottom: spacing.lg,
  },
  backText: {
    fontSize: typography.fontSize.md,
    color: colors.primary,
  },
  header: {
    marginBottom: spacing.xxl,
  },
  step: {
    fontSize: typography.fontSize.sm,
    color: colors.primary,
    fontWeight: typography.fontWeight.semibold,
    marginBottom: spacing.sm,
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
  options: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.xxl,
  },
  option: {
    flex: 1,
    marginHorizontal: spacing.xs,
    alignItems: 'center',
    position: 'relative',
  },
  optionSelected: {
    borderColor: colors.primary,
    borderWidth: 2,
  },
  optionEmoji: {
    fontSize: 36,
    marginBottom: spacing.sm,
  },
  optionTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
  },
  optionTitleSelected: {
    color: colors.primary,
  },
  checkmark: {
    position: 'absolute',
    top: -8,
    right: -8,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkmarkText: {
    color: colors.white,
    fontWeight: typography.fontWeight.bold,
    fontSize: 14,
  },
  privacyCard: {
    backgroundColor: colors.gray50,
    marginBottom: spacing.xxl,
  },
  privacyTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  privacyText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 22,
  },
  footer: {
    marginTop: 'auto',
    paddingTop: spacing.lg,
  },
});
