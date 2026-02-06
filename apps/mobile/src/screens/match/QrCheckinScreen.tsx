// ============================================================================
// QR CHECK-IN SCREEN
// Generate and scan QR codes for meetup verification
// ============================================================================

import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { Card } from '../../components/Card';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'QrCheckin'>;
type RouteType = RouteProp<RootStackParamList, 'QrCheckin'>;

export function QrCheckinScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { meetupId } = route.params;

  const [mode, setMode] = useState<'generate' | 'scan'>('generate');
  const [qrData, setQrData] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [checkedIn, setCheckedIn] = useState(false);

  useEffect(() => {
    generateQr();
  }, []);

  const generateQr = async () => {
    setIsLoading(true);
    try {
      const response = await api.generateQrToken(meetupId);
      if (response.success && response.data) {
        setQrData((response.data as { qr_data: string }).qr_data);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleScan = async () => {
    // Would integrate camera scanner here
    // For now, simulate a successful scan
    setIsLoading(true);
    try {
      // Simulated scan result
      const mockScannedData = JSON.stringify({
        meetup_id: meetupId,
        token: 'mock-token',
        user_id: 'other-user',
      });

      const response = await api.scanQrCode(meetupId, mockScannedData);

      if (response.success) {
        const data = response.data as { both_checked_in: boolean };
        if (data.both_checked_in) {
          Alert.alert(
            '🎉 Meetup Confirmed!',
            'Both of you have checked in. Enjoy your meetup!',
            [{ text: 'OK', onPress: () => navigation.popToTop() }]
          );
        } else {
          setCheckedIn(true);
          Alert.alert(
            '✓ Check-in Complete',
            'Waiting for your match to check in too.',
            [{ text: 'OK' }]
          );
        }
      }
    } finally {
      setIsLoading(false);
    }
  };

  if (checkedIn) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>←</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>QR Check-in</Text>
          <View style={{ width: 24 }} />
        </View>

        <View style={styles.waitingContent}>
          <Text style={styles.waitingEmoji}>⏳</Text>
          <Text style={styles.waitingTitle}>Waiting for Sofia</Text>
          <Text style={styles.waitingText}>
            You've checked in! Waiting for Sofia to scan your QR code too.
          </Text>

          {/* Show your QR for them to scan */}
          <Card style={styles.qrCard}>
            <View style={styles.qrPlaceholder}>
              <Text style={styles.qrText}>📱</Text>
              <Text style={styles.qrLabel}>Your QR Code</Text>
            </View>
          </Card>
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
        <Text style={styles.headerTitle}>QR Check-in</Text>
        <View style={{ width: 24 }} />
      </View>

      <View style={styles.content}>
        {/* Mode Toggle */}
        <View style={styles.modeToggle}>
          <TouchableOpacity
            style={[styles.modeButton, mode === 'generate' && styles.modeButtonActive]}
            onPress={() => setMode('generate')}
          >
            <Text style={[styles.modeText, mode === 'generate' && styles.modeTextActive]}>
              Show My QR
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.modeButton, mode === 'scan' && styles.modeButtonActive]}
            onPress={() => setMode('scan')}
          >
            <Text style={[styles.modeText, mode === 'scan' && styles.modeTextActive]}>
              Scan QR
            </Text>
          </TouchableOpacity>
        </View>

        {mode === 'generate' ? (
          <>
            {/* QR Code Display */}
            <Card style={styles.qrCard}>
              {qrData ? (
                <View style={styles.qrPlaceholder}>
                  <Text style={styles.qrText}>📱</Text>
                  <Text style={styles.qrLabel}>QR Code Generated</Text>
                  <Text style={styles.qrHint}>Show this to your match</Text>
                </View>
              ) : (
                <View style={styles.qrPlaceholder}>
                  <Text style={styles.qrLabel}>Generating...</Text>
                </View>
              )}
            </Card>

            <Text style={styles.instruction}>
              Let your match scan this QR code to confirm you've met
            </Text>

            <Button
              title="Regenerate QR"
              onPress={generateQr}
              loading={isLoading}
              variant="outline"
            />
          </>
        ) : (
          <>
            {/* Scanner */}
            <Card style={styles.scannerCard}>
              <View style={styles.scannerPlaceholder}>
                <Text style={styles.scannerIcon}>📷</Text>
                <Text style={styles.scannerText}>Camera Scanner</Text>
                <Text style={styles.scannerHint}>Point at your match's QR code</Text>
              </View>
            </Card>

            <Text style={styles.instruction}>
              Scan your match's QR code to confirm you've met
            </Text>

            {/* Simulate scan for demo */}
            <Button
              title="Simulate Scan"
              onPress={handleScan}
              loading={isLoading}
            />
          </>
        )}

        {/* Info */}
        <Card variant="outlined" style={styles.infoCard}>
          <Text style={styles.infoTitle}>Why QR check-in?</Text>
          <Text style={styles.infoText}>
            Mutual QR check-in confirms that you actually met in person.
            This builds trust in our community and helps maintain quality connections.
          </Text>
        </Card>
      </View>
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
    flex: 1,
    padding: spacing.xl,
    alignItems: 'center',
  },
  modeToggle: {
    flexDirection: 'row',
    backgroundColor: colors.gray100,
    borderRadius: borderRadius.lg,
    padding: spacing.xs,
    marginBottom: spacing.xl,
  },
  modeButton: {
    flex: 1,
    paddingVertical: spacing.md,
    alignItems: 'center',
    borderRadius: borderRadius.md,
  },
  modeButtonActive: {
    backgroundColor: colors.white,
  },
  modeText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
  },
  modeTextActive: {
    color: colors.primary,
    fontWeight: typography.fontWeight.semibold,
  },
  qrCard: {
    width: '100%',
    aspectRatio: 1,
    marginBottom: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
  },
  qrPlaceholder: {
    alignItems: 'center',
  },
  qrText: {
    fontSize: 80,
    marginBottom: spacing.md,
  },
  qrLabel: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
  },
  qrHint: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginTop: spacing.xs,
  },
  scannerCard: {
    width: '100%',
    aspectRatio: 1,
    marginBottom: spacing.xl,
    backgroundColor: colors.gray800,
  },
  scannerPlaceholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scannerIcon: {
    fontSize: 64,
    marginBottom: spacing.md,
  },
  scannerText: {
    fontSize: typography.fontSize.lg,
    color: colors.white,
    fontWeight: typography.fontWeight.semibold,
  },
  scannerHint: {
    fontSize: typography.fontSize.sm,
    color: colors.gray400,
    marginTop: spacing.xs,
  },
  instruction: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
    marginBottom: spacing.xl,
  },
  infoCard: {
    marginTop: 'auto',
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
    lineHeight: 20,
  },
  waitingContent: {
    flex: 1,
    padding: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
  },
  waitingEmoji: {
    fontSize: 64,
    marginBottom: spacing.xl,
  },
  waitingTitle: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  waitingText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
    marginBottom: spacing.xxl,
  },
});
