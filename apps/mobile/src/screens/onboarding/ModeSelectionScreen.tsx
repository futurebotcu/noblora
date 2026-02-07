// ============================================================================
// MODE SELECTION SCREEN
// Choose between Dating and BFF modes
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'ModeSelection'>;
type Mode = 'dating' | 'bff';

export function ModeSelectionScreen() {
  const navigation = useNavigation<NavigationProp>();
  const [selectedMode, setSelectedMode] = useState<Mode | null>(null);

  const handleContinue = () => {
    if (!selectedMode) return;
    // Store selected mode and continue
    navigation.navigate('GenderSelection');
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.step}>Step 1 of 3</Text>
          <Text style={styles.title}>What are you looking for?</Text>
          <Text style={styles.subtitle}>You can change this later in settings</Text>
        </View>

        <View style={styles.options}>
          <ModeOption
            emoji="💜"
            title="Dating"
            description="Find romantic connections and meaningful relationships"
            selected={selectedMode === 'dating'}
            onSelect={() => setSelectedMode('dating')}
          />

          <ModeOption
            emoji="🤝"
            title="BFF"
            description="Make new friends and expand your social circle"
            selected={selectedMode === 'bff'}
            onSelect={() => setSelectedMode('bff')}
          />
        </View>

        <View style={styles.footer}>
          <Button
            title="Continue"
            onPress={handleContinue}
            disabled={!selectedMode}
            fullWidth
            size="lg"
          />
        </View>
      </View>
    </SafeAreaView>
  );
}

function ModeOption({
  emoji,
  title,
  description,
  selected,
  onSelect,
}: {
  emoji: string;
  title: string;
  description: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <TouchableOpacity onPress={onSelect} activeOpacity={0.8}>
      <Card
        variant={selected ? 'elevated' : 'outlined'}
        style={[styles.option, selected && styles.optionSelected]}
      >
        <Text style={styles.optionEmoji}>{emoji}</Text>
        <Text style={[styles.optionTitle, selected && styles.optionTitleSelected]}>
          {title}
        </Text>
        <Text style={styles.optionDescription}>{description}</Text>
        {selected && <View style={styles.checkmark}><Text>✓</Text></View>}
      </Card>
    </TouchableOpacity>
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
    marginBottom: spacing.xxxl,
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
  },
  options: {
    flex: 1,
  },
  option: {
    marginBottom: spacing.lg,
    alignItems: 'center',
    padding: spacing.xl,
    position: 'relative',
  },
  optionSelected: {
    borderColor: colors.primary,
    borderWidth: 2,
  },
  optionEmoji: {
    fontSize: 48,
    marginBottom: spacing.md,
  },
  optionTitle: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  optionTitleSelected: {
    color: colors.primary,
  },
  optionDescription: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  checkmark: {
    position: 'absolute',
    top: spacing.md,
    right: spacing.md,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  footer: {
    paddingTop: spacing.lg,
  },
});
