// ============================================================================
// PROFILE SCREEN
// User profile and settings
// ============================================================================

import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Image, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuthStore } from '../../store/authStore';
import { useProfileStore } from '../../store/profileStore';
import { Card } from '../../components/Card';
import { Button } from '../../components/Button';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

export function ProfileScreen() {
  const { signOut } = useAuthStore();
  const { profile, photos } = useProfileStore();

  const handleSignOut = () => {
    Alert.alert(
      'Sign Out',
      'Are you sure you want to sign out?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Sign Out', style: 'destructive', onPress: signOut },
      ]
    );
  };

  const handleDeleteAccount = () => {
    Alert.alert(
      'Delete Account',
      'This will permanently delete your account and all data. This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => {
            // Would call API to request deletion
            Alert.alert('Request Submitted', 'Your account deletion request has been submitted.');
          },
        },
      ]
    );
  };

  const currentYear = new Date().getFullYear();
  const age = profile?.birth_year ? currentYear - profile.birth_year : null;

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.header}>
          <Text style={styles.title}>Profile</Text>
        </View>

        {/* Profile Card */}
        <Card style={styles.profileCard}>
          <View style={styles.photoContainer}>
            {photos[0] ? (
              <Image source={{ uri: photos[0].url }} style={styles.profilePhoto} />
            ) : (
              <View style={styles.photoPlaceholder}>
                <Text style={styles.photoPlaceholderText}>📷</Text>
              </View>
            )}
          </View>

          <Text style={styles.profileName}>
            {profile?.bio?.split(' ')[0] || 'User'}{age ? `, ${age}` : ''}
          </Text>
          <Text style={styles.profileLocation}>
            📍 {profile?.city || 'Location not set'}
          </Text>

          <View style={styles.modeBadge}>
            <Text style={styles.modeText}>
              {profile?.mode === 'dating' ? '💜 Dating Mode' : '🤝 BFF Mode'}
            </Text>
          </View>
        </Card>

        {/* Settings Sections */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Settings</Text>

          <SettingsItem
            icon="👤"
            title="Edit Profile"
            onPress={() => {/* Navigate to edit profile */}}
          />
          <SettingsItem
            icon="📷"
            title="Manage Photos"
            onPress={() => {/* Navigate to photo management */}}
          />
          <SettingsItem
            icon="🔄"
            title="Switch Mode"
            subtitle={profile?.mode === 'dating' ? 'Currently: Dating' : 'Currently: BFF'}
            onPress={() => {/* Toggle mode */}}
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Discovery</Text>

          <SettingsItem
            icon="📍"
            title="Distance"
            subtitle="Up to 50 km"
            onPress={() => {/* Open distance picker */}}
          />
          <SettingsItem
            icon="🎂"
            title="Age Range"
            subtitle="18 - 45"
            onPress={() => {/* Open age range picker */}}
          />
          <SettingsItem
            icon="👻"
            title="Incognito Mode"
            subtitle="Premium"
            onPress={() => {/* Show premium upsell */}}
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Privacy & Security</Text>

          <SettingsItem
            icon="🔐"
            title="Privacy Settings"
            onPress={() => {/* Navigate to privacy */}}
          />
          <SettingsItem
            icon="🚫"
            title="Blocked Users"
            onPress={() => {/* Navigate to blocked */}}
          />
          <SettingsItem
            icon="📋"
            title="Terms & Privacy Policy"
            onPress={() => {/* Open terms */}}
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Account</Text>

          <SettingsItem
            icon="⭐"
            title="Upgrade to Premium"
            onPress={() => {/* Show premium */}}
          />
          <SettingsItem
            icon="📧"
            title="Contact Support"
            onPress={() => {/* Open support */}}
          />
        </View>

        <View style={styles.dangerZone}>
          <Button
            title="Sign Out"
            onPress={handleSignOut}
            variant="outline"
            fullWidth
          />
          <TouchableOpacity onPress={handleDeleteAccount} style={styles.deleteButton}>
            <Text style={styles.deleteText}>Delete Account</Text>
          </TouchableOpacity>
        </View>

        <Text style={styles.version}>Noblara v0.1.0</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function SettingsItem({
  icon,
  title,
  subtitle,
  onPress,
}: {
  icon: string;
  title: string;
  subtitle?: string;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity style={styles.settingsItem} onPress={onPress}>
      <Text style={styles.settingsIcon}>{icon}</Text>
      <View style={styles.settingsContent}>
        <Text style={styles.settingsTitle}>{title}</Text>
        {subtitle && <Text style={styles.settingsSubtitle}>{subtitle}</Text>}
      </View>
      <Text style={styles.settingsArrow}>›</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    paddingBottom: spacing.xxxxl,
  },
  header: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
  },
  title: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
  },
  profileCard: {
    marginHorizontal: spacing.lg,
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  photoContainer: {
    marginBottom: spacing.md,
  },
  profilePhoto: {
    width: 100,
    height: 100,
    borderRadius: 50,
  },
  photoPlaceholder: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: colors.gray200,
    alignItems: 'center',
    justifyContent: 'center',
  },
  photoPlaceholderText: {
    fontSize: 40,
  },
  profileName: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  profileLocation: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    marginBottom: spacing.md,
  },
  modeBadge: {
    backgroundColor: colors.primaryLight + '30',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.full,
  },
  modeText: {
    fontSize: typography.fontSize.sm,
    color: colors.primary,
    fontWeight: typography.fontWeight.medium,
  },
  section: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.xl,
  },
  sectionTitle: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textTertiary,
    textTransform: 'uppercase',
    marginBottom: spacing.sm,
    paddingHorizontal: spacing.sm,
  },
  settingsItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.white,
    padding: spacing.lg,
    borderRadius: borderRadius.lg,
    marginBottom: spacing.xs,
  },
  settingsIcon: {
    fontSize: 20,
    marginRight: spacing.md,
  },
  settingsContent: {
    flex: 1,
  },
  settingsTitle: {
    fontSize: typography.fontSize.md,
    color: colors.textPrimary,
  },
  settingsSubtitle: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
    marginTop: spacing.xxs,
  },
  settingsArrow: {
    fontSize: 24,
    color: colors.gray400,
  },
  dangerZone: {
    marginHorizontal: spacing.lg,
    marginTop: spacing.xl,
  },
  deleteButton: {
    alignItems: 'center',
    padding: spacing.lg,
    marginTop: spacing.md,
  },
  deleteText: {
    fontSize: typography.fontSize.md,
    color: colors.error,
  },
  version: {
    textAlign: 'center',
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
    marginTop: spacing.xl,
  },
});
