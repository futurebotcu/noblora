// ============================================================================
// SCHEDULING SCREEN
// Schedule video call - women propose first
// ============================================================================

import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { useProfileStore } from '../../store/profileStore';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Scheduling'>;
type RouteType = RouteProp<RootStackParamList, 'Scheduling'>;

interface TimeSlot {
  start: string;
  end: string;
  label: string;
}

const generateTimeSlots = (): TimeSlot[] => {
  const slots: TimeSlot[] = [];
  const now = new Date();

  for (let i = 0; i < 24; i++) {
    const start = new Date(now.getTime() + (i + 1) * 60 * 60 * 1000);
    const end = new Date(start.getTime() + 30 * 60 * 1000);

    const hour = start.getHours();
    if (hour >= 9 && hour <= 22) {
      slots.push({
        start: start.toISOString(),
        end: end.toISOString(),
        label: `${start.toLocaleDateString('en-US', { weekday: 'short' })} ${start.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`,
      });
    }
  }

  return slots.slice(0, 12);
};

export function SchedulingScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { matchId } = route.params;
  const profile = useProfileStore(state => state.profile);

  const [timeSlots] = useState(generateTimeSlots());
  const [selectedSlots, setSelectedSlots] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [deadlineRemaining, setDeadlineRemaining] = useState('12:00:00');
  const [canPropose, setCanPropose] = useState(false);

  const isFemale = profile?.gender_claim === 'female';

  useEffect(() => {
    // Check if user can propose (women first)
    setCanPropose(isFemale);

    // Update countdown
    const interval = setInterval(() => {
      // Would calculate from actual match created_at
      const hours = Math.floor(Math.random() * 12);
      const mins = Math.floor(Math.random() * 60);
      setDeadlineRemaining(`${hours}:${mins.toString().padStart(2, '0')}:00`);
    }, 1000);

    return () => clearInterval(interval);
  }, [isFemale]);

  const toggleSlot = (slotStart: string) => {
    if (selectedSlots.includes(slotStart)) {
      setSelectedSlots(selectedSlots.filter(s => s !== slotStart));
    } else if (selectedSlots.length < 5) {
      setSelectedSlots([...selectedSlots, slotStart]);
    }
  };

  const handlePropose = async () => {
    if (selectedSlots.length === 0) return;

    setIsLoading(true);
    try {
      const slots = selectedSlots.map(start => {
        const slot = timeSlots.find(s => s.start === start)!;
        return { start: slot.start, end: slot.end };
      });

      await api.proposeCall(matchId, slots);
      navigation.goBack();
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.closeButton}>✕</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Schedule Call</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Countdown */}
        <Card style={styles.countdownCard}>
          <Text style={styles.countdownLabel}>Schedule window closes in</Text>
          <Text style={styles.countdownTime}>{deadlineRemaining}</Text>
        </Card>

        {/* Info */}
        <Card variant="outlined" style={styles.infoCard}>
          <Text style={styles.infoTitle}>📹 Video Call Rules</Text>
          <Text style={styles.infoText}>
            • Call duration: 3-5 minutes{'\n'}
            • Both must complete the call{'\n'}
            • Chat unlocks only if both tap "Continue"
          </Text>
        </Card>

        {/* Women First Notice */}
        {!isFemale && (
          <Card variant="outlined" style={styles.waitingCard}>
            <Text style={styles.waitingTitle}>⏳ Waiting for Proposal</Text>
            <Text style={styles.waitingText}>
              The woman makes the first scheduling proposal.
              You'll be notified when she proposes times.
            </Text>
          </Card>
        )}

        {/* Time Slot Selection */}
        {canPropose && (
          <>
            <Text style={styles.sectionTitle}>Select up to 5 time slots</Text>
            <View style={styles.slotsGrid}>
              {timeSlots.map((slot) => (
                <TouchableOpacity
                  key={slot.start}
                  style={[
                    styles.slot,
                    selectedSlots.includes(slot.start) && styles.slotSelected,
                  ]}
                  onPress={() => toggleSlot(slot.start)}
                >
                  <Text style={[
                    styles.slotText,
                    selectedSlots.includes(slot.start) && styles.slotTextSelected,
                  ]}>
                    {slot.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Button
              title={`Propose ${selectedSlots.length} Time${selectedSlots.length !== 1 ? 's' : ''}`}
              onPress={handlePropose}
              loading={isLoading}
              disabled={selectedSlots.length === 0}
              fullWidth
              size="lg"
            />
          </>
        )}
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
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  closeButton: {
    fontSize: 24,
    color: colors.textSecondary,
  },
  title: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
  },
  content: {
    padding: spacing.xl,
  },
  countdownCard: {
    alignItems: 'center',
    marginBottom: spacing.xl,
    backgroundColor: colors.warningLight,
  },
  countdownLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.warning,
    marginBottom: spacing.xs,
  },
  countdownTime: {
    fontSize: typography.fontSize.xxxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.warning,
  },
  infoCard: {
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
    lineHeight: 22,
  },
  waitingCard: {
    backgroundColor: colors.infoLight,
    marginBottom: spacing.xl,
  },
  waitingTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.info,
    marginBottom: spacing.sm,
  },
  waitingText: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
  sectionTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.md,
  },
  slotsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -spacing.xs,
    marginBottom: spacing.xl,
  },
  slot: {
    width: '48%',
    margin: '1%',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.white,
    alignItems: 'center',
  },
  slotSelected: {
    borderColor: colors.primary,
    backgroundColor: colors.primaryLight + '20',
  },
  slotText: {
    fontSize: typography.fontSize.sm,
    color: colors.textPrimary,
  },
  slotTextSelected: {
    color: colors.primary,
    fontWeight: typography.fontWeight.semibold,
  },
});
