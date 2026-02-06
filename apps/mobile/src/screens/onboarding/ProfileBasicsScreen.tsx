// ============================================================================
// PROFILE BASICS SCREEN
// Enter basic profile information
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, KeyboardAvoidingView, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { useProfileStore } from '../../store/profileStore';
import { Button } from '../../components/Button';
import { Input } from '../../components/Input';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'ProfileBasics'>;

export function ProfileBasicsScreen() {
  const navigation = useNavigation<NavigationProp>();
  const { createProfile, isLoading, error } = useProfileStore();

  const [birthYear, setBirthYear] = useState('');
  const [city, setCity] = useState('');
  const [bio, setBio] = useState('');

  const currentYear = new Date().getFullYear();
  const minYear = currentYear - 100;
  const maxYear = currentYear - 18;

  const validateBirthYear = () => {
    const year = parseInt(birthYear, 10);
    return year >= minYear && year <= maxYear;
  };

  const handleContinue = async () => {
    if (!validateBirthYear()) return;

    // TODO: Get mode and gender from previous screens via navigation params or store
    const success = await createProfile({
      mode: 'dating', // TODO: Get from store
      gender_claim: 'female', // TODO: Get from store
      birth_year: parseInt(birthYear, 10),
      city: city || undefined,
      bio: bio || undefined,
    });

    if (success) {
      // Navigation will be handled by RootNavigator
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        style={styles.keyboardView}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView contentContainerStyle={styles.scrollContent}>
          <View style={styles.content}>
            <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
              <Text style={styles.backText}>← Back</Text>
            </TouchableOpacity>

            <View style={styles.header}>
              <Text style={styles.step}>Step 3 of 3</Text>
              <Text style={styles.title}>About you</Text>
              <Text style={styles.subtitle}>Help others get to know you better</Text>
            </View>

            <View style={styles.form}>
              <Input
                label="Birth Year"
                placeholder={`e.g., ${currentYear - 25}`}
                value={birthYear}
                onChangeText={setBirthYear}
                keyboardType="number-pad"
                maxLength={4}
                error={birthYear && !validateBirthYear() ? 'You must be 18 or older' : undefined}
                hint="We only show your age, not birth year"
              />

              <Input
                label="City"
                placeholder="Where are you based?"
                value={city}
                onChangeText={setCity}
                autoCapitalize="words"
              />

              <Input
                label="Bio"
                placeholder="Tell others about yourself..."
                value={bio}
                onChangeText={setBio}
                multiline
                numberOfLines={4}
                maxLength={500}
                hint={`${bio.length}/500 characters`}
                style={styles.bioInput}
              />

              {error && <Text style={styles.error}>{error}</Text>}
            </View>

            <View style={styles.footer}>
              <Button
                title="Create Profile"
                onPress={handleContinue}
                loading={isLoading}
                disabled={!birthYear || !validateBirthYear()}
                fullWidth
                size="lg"
              />
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  keyboardView: {
    flex: 1,
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
  },
  form: {
    flex: 1,
  },
  bioInput: {
    height: 120,
    textAlignVertical: 'top',
  },
  error: {
    color: colors.error,
    fontSize: typography.fontSize.sm,
    marginBottom: spacing.md,
    textAlign: 'center',
  },
  footer: {
    paddingTop: spacing.lg,
  },
});
