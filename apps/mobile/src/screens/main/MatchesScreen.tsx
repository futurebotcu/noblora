// ============================================================================
// MATCHES SCREEN
// Shows matches and their current status in the flow
// ============================================================================

import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image, RefreshControl } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { FlashList } from '@shopify/flash-list';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { Card } from '../../components/Card';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

interface MatchItem {
  id: string;
  name: string;
  photo: string;
  status: 'schedule' | 'call_pending' | 'call_complete' | 'chat' | 'meetup';
  lastActivity: string;
  unreadCount?: number;
}

// Mock data
const MOCK_MATCHES: MatchItem[] = [
  {
    id: '1',
    name: 'Sofia',
    photo: 'https://picsum.photos/100/100?random=1',
    status: 'schedule',
    lastActivity: 'Matched 2 hours ago',
  },
  {
    id: '2',
    name: 'Emma',
    photo: 'https://picsum.photos/100/100?random=2',
    status: 'chat',
    lastActivity: 'Sent a message',
    unreadCount: 2,
  },
  {
    id: '3',
    name: 'Ayşe',
    photo: 'https://picsum.photos/100/100?random=3',
    status: 'meetup',
    lastActivity: 'Meetup scheduled',
  },
];

export function MatchesScreen() {
  const navigation = useNavigation<NavigationProp>();
  const [matches, setMatches] = useState(MOCK_MATCHES);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    // Would fetch matches from API
    await new Promise(resolve => setTimeout(resolve, 1000));
    setIsRefreshing(false);
  }, []);

  const handleMatchPress = useCallback((match: MatchItem) => {
    switch (match.status) {
      case 'schedule':
        navigation.navigate('Scheduling', { matchId: match.id });
        break;
      case 'call_pending':
      case 'call_complete':
        navigation.navigate('VideoCall', { matchId: match.id });
        break;
      case 'chat':
        navigation.navigate('Chat', { matchId: match.id });
        break;
      case 'meetup':
        navigation.navigate('Meetup', { matchId: match.id });
        break;
    }
  }, [navigation]);

  const renderMatch = useCallback(({ item }: { item: MatchItem }) => (
    <MatchCard match={item} onPress={() => handleMatchPress(item)} />
  ), [handleMatchPress]);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Matches</Text>
        <Text style={styles.count}>{matches.length}</Text>
      </View>

      {matches.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyEmoji}>💫</Text>
          <Text style={styles.emptyTitle}>No matches yet</Text>
          <Text style={styles.emptyText}>
            Keep swiping to find your perfect match!
          </Text>
        </View>
      ) : (
        <FlashList
          data={matches}
          renderItem={renderMatch}
          keyExtractor={item => item.id}
          estimatedItemSize={100}
          contentContainerStyle={styles.list}
          refreshControl={
            <RefreshControl
              refreshing={isRefreshing}
              onRefresh={handleRefresh}
              tintColor={colors.primary}
            />
          }
        />
      )}
    </SafeAreaView>
  );
}

function MatchCard({ match, onPress }: { match: MatchItem; onPress: () => void }) {
  const getStatusBadge = () => {
    switch (match.status) {
      case 'schedule':
        return { text: 'Schedule Call', color: colors.warning };
      case 'call_pending':
        return { text: 'Call Scheduled', color: colors.info };
      case 'call_complete':
        return { text: 'Decide', color: colors.primary };
      case 'chat':
        return { text: 'Chat Open', color: colors.success };
      case 'meetup':
        return { text: 'Schedule Meetup', color: colors.secondary };
    }
  };

  const badge = getStatusBadge();

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.8}>
      <Card style={styles.matchCard}>
        <View style={styles.matchContent}>
          <Image source={{ uri: match.photo }} style={styles.matchPhoto} />

          <View style={styles.matchInfo}>
            <View style={styles.matchNameRow}>
              <Text style={styles.matchName}>{match.name}</Text>
              {match.unreadCount && match.unreadCount > 0 && (
                <View style={styles.unreadBadge}>
                  <Text style={styles.unreadText}>{match.unreadCount}</Text>
                </View>
              )}
            </View>
            <Text style={styles.matchActivity}>{match.lastActivity}</Text>
          </View>

          <View style={[styles.statusBadge, { backgroundColor: badge.color + '20' }]}>
            <Text style={[styles.statusText, { color: badge.color }]}>{badge.text}</Text>
          </View>
        </View>
      </Card>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
  },
  title: {
    fontSize: typography.fontSize.xxl,
    fontWeight: typography.fontWeight.bold,
    color: colors.textPrimary,
  },
  count: {
    fontSize: typography.fontSize.lg,
    color: colors.primary,
    fontWeight: typography.fontWeight.semibold,
  },
  list: {
    padding: spacing.lg,
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xl,
  },
  emptyEmoji: {
    fontSize: 64,
    marginBottom: spacing.xl,
  },
  emptyTitle: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  emptyText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
    textAlign: 'center',
  },
  matchCard: {
    marginBottom: spacing.md,
  },
  matchContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  matchPhoto: {
    width: 60,
    height: 60,
    borderRadius: 30,
    marginRight: spacing.md,
  },
  matchInfo: {
    flex: 1,
  },
  matchNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  matchName: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
    marginRight: spacing.sm,
  },
  unreadBadge: {
    backgroundColor: colors.primary,
    minWidth: 20,
    height: 20,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.xs,
  },
  unreadText: {
    fontSize: typography.fontSize.xs,
    color: colors.white,
    fontWeight: typography.fontWeight.bold,
  },
  matchActivity: {
    fontSize: typography.fontSize.sm,
    color: colors.textSecondary,
    marginTop: spacing.xxs,
  },
  statusBadge: {
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.sm,
  },
  statusText: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.semibold,
  },
});
