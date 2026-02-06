// ============================================================================
// VIDEO CALL SCREEN
// In-app video call with 3-5 minute duration enforcement
// ============================================================================

import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { api } from '../../services/api';
import { Button } from '../../components/Button';
import { colors, spacing, typography } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'VideoCall'>;
type RouteType = RouteProp<RootStackParamList, 'VideoCall'>;

const MIN_DURATION = 180; // 3 minutes
const MAX_DURATION = 300; // 5 minutes

export function VideoCallScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { matchId } = route.params;

  const [callState, setCallState] = useState<'waiting' | 'connecting' | 'active' | 'ended'>('waiting');
  const [duration, setDuration] = useState(0);
  const [isMinMet, setIsMinMet] = useState(false);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, []);

  const startTimer = () => {
    timerRef.current = setInterval(() => {
      setDuration(prev => {
        const newDuration = prev + 1;

        if (newDuration >= MIN_DURATION && !isMinMet) {
          setIsMinMet(true);
        }

        if (newDuration >= MAX_DURATION) {
          // Force end at 5 minutes
          handleEndCall(true);
        }

        return newDuration;
      });
    }, 1000);
  };

  const handleStartCall = async () => {
    setCallState('connecting');

    try {
      await api.startCall(matchId, `${matchId}-${Date.now()}`);
      setCallState('active');
      startTimer();
    } catch (error) {
      Alert.alert('Error', 'Failed to start call');
      setCallState('waiting');
    }
  };

  const handleEndCall = async (forced = false) => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }

    setCallState('ended');

    try {
      await api.endCall(matchId);

      if (duration >= MIN_DURATION || forced) {
        navigation.replace('PostCallDecision', { matchId });
      } else {
        Alert.alert(
          'Call Too Short',
          `The call must be at least 3 minutes to unlock chat. This call was ${Math.floor(duration / 60)}:${(duration % 60).toString().padStart(2, '0')}.`,
          [{ text: 'OK', onPress: () => navigation.goBack() }]
        );
      }
    } catch (error) {
      navigation.goBack();
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const remainingForMin = Math.max(0, MIN_DURATION - duration);
  const remainingTotal = Math.max(0, MAX_DURATION - duration);

  return (
    <SafeAreaView style={styles.container}>
      {/* Video placeholder - would integrate WebRTC here */}
      <View style={styles.videoContainer}>
        {/* Remote video */}
        <View style={styles.remoteVideo}>
          <Text style={styles.videoPlaceholder}>
            {callState === 'active' ? '👤' : '📹'}
          </Text>
          <Text style={styles.matchName}>Sofia</Text>
        </View>

        {/* Local video preview */}
        <View style={styles.localVideo}>
          <Text style={styles.localPlaceholder}>You</Text>
        </View>
      </View>

      {/* Call info */}
      <View style={styles.infoBar}>
        {callState === 'active' && (
          <>
            <View style={styles.durationContainer}>
              <Text style={styles.durationLabel}>Duration</Text>
              <Text style={[styles.duration, isMinMet && styles.durationGreen]}>
                {formatTime(duration)}
              </Text>
            </View>

            {!isMinMet && (
              <View style={styles.minRemainingContainer}>
                <Text style={styles.minRemainingLabel}>Min. remaining</Text>
                <Text style={styles.minRemaining}>{formatTime(remainingForMin)}</Text>
              </View>
            )}

            <View style={styles.maxRemainingContainer}>
              <Text style={styles.maxRemainingLabel}>Call ends in</Text>
              <Text style={styles.maxRemaining}>{formatTime(remainingTotal)}</Text>
            </View>
          </>
        )}
      </View>

      {/* Progress bar */}
      {callState === 'active' && (
        <View style={styles.progressContainer}>
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                {
                  width: `${(duration / MAX_DURATION) * 100}%`,
                  backgroundColor: duration >= MIN_DURATION ? colors.success : colors.warning,
                },
              ]}
            />
            {/* Min marker */}
            <View style={[styles.progressMarker, { left: `${(MIN_DURATION / MAX_DURATION) * 100}%` }]} />
          </View>
          <View style={styles.progressLabels}>
            <Text style={styles.progressLabel}>0:00</Text>
            <Text style={styles.progressLabel}>3:00 min</Text>
            <Text style={styles.progressLabel}>5:00 max</Text>
          </View>
        </View>
      )}

      {/* Controls */}
      <View style={styles.controls}>
        {callState === 'waiting' && (
          <Button
            title="Start Call"
            onPress={handleStartCall}
            size="lg"
            fullWidth
          />
        )}

        {callState === 'connecting' && (
          <Text style={styles.connectingText}>Connecting...</Text>
        )}

        {callState === 'active' && (
          <View style={styles.activeControls}>
            <TouchableOpacity style={styles.controlButton}>
              <Text style={styles.controlIcon}>🔇</Text>
              <Text style={styles.controlLabel}>Mute</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.controlButton, styles.endCallButton]}
              onPress={() => handleEndCall()}
            >
              <Text style={styles.endCallIcon}>📞</Text>
              <Text style={styles.endCallLabel}>End</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.controlButton}>
              <Text style={styles.controlIcon}>📷</Text>
              <Text style={styles.controlLabel}>Camera</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      {/* Minimum requirement notice */}
      {callState === 'active' && !isMinMet && (
        <View style={styles.minNotice}>
          <Text style={styles.minNoticeText}>
            Stay on call for at least 3 minutes to unlock chat
          </Text>
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.black,
  },
  videoContainer: {
    flex: 1,
    position: 'relative',
  },
  remoteVideo: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.gray800,
  },
  videoPlaceholder: {
    fontSize: 80,
    marginBottom: spacing.md,
  },
  matchName: {
    fontSize: typography.fontSize.xl,
    color: colors.white,
    fontWeight: typography.fontWeight.semibold,
  },
  localVideo: {
    position: 'absolute',
    top: spacing.xl,
    right: spacing.xl,
    width: 100,
    height: 140,
    backgroundColor: colors.gray700,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  localPlaceholder: {
    fontSize: typography.fontSize.sm,
    color: colors.white,
  },
  infoBar: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: spacing.lg,
    backgroundColor: colors.gray900,
  },
  durationContainer: {
    alignItems: 'center',
  },
  durationLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.gray400,
    marginBottom: spacing.xxs,
  },
  duration: {
    fontSize: typography.fontSize.xxl,
    color: colors.white,
    fontWeight: typography.fontWeight.bold,
  },
  durationGreen: {
    color: colors.success,
  },
  minRemainingContainer: {
    alignItems: 'center',
  },
  minRemainingLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.warning,
    marginBottom: spacing.xxs,
  },
  minRemaining: {
    fontSize: typography.fontSize.lg,
    color: colors.warning,
    fontWeight: typography.fontWeight.semibold,
  },
  maxRemainingContainer: {
    alignItems: 'center',
  },
  maxRemainingLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.gray400,
    marginBottom: spacing.xxs,
  },
  maxRemaining: {
    fontSize: typography.fontSize.lg,
    color: colors.gray300,
    fontWeight: typography.fontWeight.semibold,
  },
  progressContainer: {
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.md,
    backgroundColor: colors.gray900,
  },
  progressTrack: {
    height: 6,
    backgroundColor: colors.gray700,
    borderRadius: 3,
    position: 'relative',
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  progressMarker: {
    position: 'absolute',
    top: -3,
    width: 2,
    height: 12,
    backgroundColor: colors.white,
  },
  progressLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.xs,
  },
  progressLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.gray500,
  },
  controls: {
    padding: spacing.xl,
    backgroundColor: colors.gray900,
  },
  connectingText: {
    fontSize: typography.fontSize.lg,
    color: colors.white,
    textAlign: 'center',
  },
  activeControls: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  controlButton: {
    alignItems: 'center',
    padding: spacing.md,
  },
  controlIcon: {
    fontSize: 28,
    marginBottom: spacing.xs,
  },
  controlLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.white,
  },
  endCallButton: {
    backgroundColor: colors.error,
    borderRadius: 40,
    width: 80,
    height: 80,
    justifyContent: 'center',
  },
  endCallIcon: {
    fontSize: 32,
    transform: [{ rotate: '135deg' }],
  },
  endCallLabel: {
    color: colors.white,
    fontWeight: typography.fontWeight.semibold,
  },
  minNotice: {
    backgroundColor: colors.warning,
    padding: spacing.md,
  },
  minNoticeText: {
    fontSize: typography.fontSize.sm,
    color: colors.white,
    textAlign: 'center',
    fontWeight: typography.fontWeight.medium,
  },
});
