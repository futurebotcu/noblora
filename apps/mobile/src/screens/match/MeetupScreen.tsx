// ============================================================================
// MEETUP SCREEN
// Schedule meetup within 5 days and QR check-in
// ============================================================================

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { Input } from '../../components/Input';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Meetup'>;
type RouteType = RouteProp<RootStackParamList, 'Meetup'>;

export function MeetupScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { matchId, meetupId } = route.params;

  const [location, setLocation] = useState('');
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [hasMeetup, setHasMeetup] = useState(!!meetupId);

  const generateDates = () => {
    const dates: Date[] = [];
    const now = new Date();
    for (let i = 1; i <= 5; i++) {
      const date = new Date(now.getTime() + i * 24 * 60 * 60 * 1000);
      dates.push(date);
    }
    return dates;
  };

  const dates = generateDates();

  const handleSchedule = async () => {
    if (!selectedDate || !location.trim()) return;

    setIsLoading(true);
    try {
      // Would call API to create meetup
      Alert.alert(
        'Meetup Scheduled!',
        `You've scheduled a meetup on ${selectedDate.toLocaleDateString()}.`,
        [{ text: 'OK', onPress: () => setHasMeetup(true) }]
      );
    } finally {
      setIsLoading(false);
    }
  };

  if (hasMeetup) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>←</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Meetup</Text>
          <View style={{ width: 24 }} />
        </View>

        <View style={styles.meetupDetails}>
          <Card style={styles.meetupCard}>
            <Text style={styles.meetupEmoji}>📍</Text>
            <Text style={styles.meetupTitle}>Meetup Scheduled</Text>
            <Text style={styles.meetupDate}>
              {selectedDate?.toLocaleDateString('en-US', {
                weekday: 'long',
                month: 'long',
                day: 'numeric',
              }) || 'Saturday, January 15'}
            </Text>
            <Text style={styles.meetupLocation}>{location || 'Coffee Shop Downtown'}</Text>
          </Card>

          <Card variant="outlined" style={styles.qrInfoCard}>
            <Text style={styles.qrInfoTitle}>📱 QR Check-in</Text>
            <Text style={styles.qrInfoText}>
              When you meet, scan each other's QR codes to confirm the meetup happened.
              This helps maintain trust in the community.
            </Text>
          </Card>

          <Button
            title="Generate My QR Code"
            onPress={() => navigation.navigate('QrCheckin', { meetupId: meetupId || 'mock-id' })}
            fullWidth
            size="lg"
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.backButton}>←</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Schedule Meetup</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Deadline */}
        <Card style={styles.deadlineCard}>
          <Text style={styles.deadlineLabel}>Schedule within</Text>
          <Text style={styles.deadlineValue}>5 days</Text>
        </Card>

        {/* Date Selection */}
        <Text style={styles.sectionTitle}>Select a day</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.datesScroll}>
          {dates.map((date, index) => (
            <TouchableOpacity
              key={index}
              style={[
                styles.dateOption,
                selectedDate?.getTime() === date.getTime() && styles.dateOptionSelected,
              ]}
              onPress={() => setSelectedDate(date)}
            >
              <Text style={[
                styles.dateDay,
                selectedDate?.getTime() === date.getTime() && styles.dateDaySelected,
              ]}>
                {date.toLocaleDateString('en-US', { weekday: 'short' })}
              </Text>
              <Text style={[
                styles.dateNumber,
                selectedDate?.getTime() === date.getTime() && styles.dateNumberSelected,
              ]}>
                {date.getDate()}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        {/* Location */}
        <Input
          label="Meeting place"
          placeholder="e.g., Starbucks on Main Street"
          value={location}
          onChangeText={setLocation}
          hint="Just a general location - no need for exact address"
        />

        {/* Info */}
        <Card variant="outlined" style={styles.infoCard}>
          <Text style={styles.infoTitle}>About meetups</Text>
          <Text style={styles.infoText}>
            • Choose a public place for safety{'\n'}
            • Both need to QR check-in to confirm{'\n'}
            • You can chat to finalize details
          </Text>
        </Card>

        <Button
          title="Schedule Meetup"
          onPress={handleSchedule}
          loading={isLoading}
          disabled={!selectedDate || !location.trim()}
          fullWidth
          size="lg"
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  backButton: {
    fontSize: 28,
    color: colors.primary,
  },
  headerTitle: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
  },
  content: {
    padding: spacing.xl,
  },
  deadlineCard: {
    alignItems: 'center',
    marginBottom: spacing.xl,
    backgroundColor: colors.primaryLight + '20',
  },
  deadlineLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  deadlineValue: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.primary,
  },
  sectionTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  datesScroll: {
    marginBottom: spacing.xl,
  },
  dateOption: {
    width: 70,
    height: 80,
    borderRadius: borderRadius.lg,
    backgroundColor: colors.gray100,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  dateOptionSelected: {
    borderColor: colors.primary,
    backgroundColor: colors.primaryLight + '20',
  },
  dateDay: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
  },
  dateDaySelected: {
    color: colors.primary,
  },
  dateNumber: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
  },
  dateNumberSelected: {
    color: colors.primary,
  },
  infoCard: {
    marginBottom: spacing.xl,
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
    lineHeight: 22,
  },
  meetupDetails: {
    flex: 1,
    padding: spacing.xl,
  },
  meetupCard: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  meetupEmoji: {
    fontSize: 48,
    marginBottom: spacing.md,
  },
  meetupTitle: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  meetupDate: {
    fontSize: typography.fontSize.lg,
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  meetupLocation: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
  },
  qrInfoCard: {
    marginBottom: spacing.xl,
  },
  qrInfoTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  qrInfoText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
});
