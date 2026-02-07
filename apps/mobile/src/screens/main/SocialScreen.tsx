// ============================================================================
// SOCIAL SCREEN
// Daily micro-posts feed (max 150 chars, 1 per day)
// ============================================================================

import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, Alert, RefreshControl } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { FlashList } from '@shopify/flash-list';
import { Card } from '../../components/Card';
import { Button } from '../../components/Button';
import { colors, spacing, typography } from '../../constants/theme';

const MAX_POST_LENGTH = 150;

interface Post {
  id: string;
  userId: string;
  userName: string;
  userPhoto: string;
  body: string;
  createdAt: string;
}

// Mock data
const MOCK_POSTS: Post[] = [
  {
    id: '1',
    userId: 'u1',
    userName: 'Sofia',
    userPhoto: 'https://picsum.photos/50/50?random=1',
    body: 'Just had the best coffee at this hidden gem cafe ☕✨',
    createdAt: '2 hours ago',
  },
  {
    id: '2',
    userId: 'u2',
    userName: 'Emma',
    userPhoto: 'https://picsum.photos/50/50?random=2',
    body: 'Sunset views from my balcony 🌅 Grateful for moments like these',
    createdAt: '5 hours ago',
  },
  {
    id: '3',
    userId: 'u3',
    userName: 'Ayşe',
    userPhoto: 'https://picsum.photos/50/50?random=3',
    body: 'Morning yoga complete! Who else starts their day with stretching?',
    createdAt: '8 hours ago',
  },
];

export function SocialScreen() {
  const [posts, setPosts] = useState(MOCK_POSTS);
  const [newPost, setNewPost] = useState('');
  const [isPosting, setIsPosting] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [hasPostedToday, setHasPostedToday] = useState(false);

  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    // Would fetch posts from API
    await new Promise(resolve => setTimeout(resolve, 1000));
    setIsRefreshing(false);
  }, []);

  const handlePost = async () => {
    if (!newPost.trim() || newPost.length > MAX_POST_LENGTH) return;

    if (hasPostedToday) {
      Alert.alert('Limit Reached', 'You can only post once per day');
      return;
    }

    setIsPosting(true);
    try {
      // Would call API to create post
      const mockNewPost: Post = {
        id: Date.now().toString(),
        userId: 'me',
        userName: 'You',
        userPhoto: 'https://picsum.photos/50/50?random=me',
        body: newPost.trim(),
        createdAt: 'Just now',
      };

      setPosts([mockNewPost, ...posts]);
      setNewPost('');
      setHasPostedToday(true);
    } finally {
      setIsPosting(false);
    }
  };

  const handleReport = (_postId: string) => {
    Alert.alert(
      'Report Post',
      'Are you sure you want to report this post?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Report',
          style: 'destructive',
          onPress: () => {
            // Would call API to report
            Alert.alert('Reported', 'Thank you for reporting. We will review this post.');
          },
        },
      ]
    );
  };

  const renderPost = useCallback(({ item }: { item: Post }) => (
    <PostCard post={item} onReport={() => handleReport(item.id)} />
  ), []);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Social</Text>
      </View>

      {/* Compose Area */}
      <Card style={styles.composeCard}>
        <TextInput
          style={styles.composeInput}
          placeholder={hasPostedToday ? "You've posted today" : "What's on your mind?"}
          placeholderTextColor={colors.gray400}
          value={newPost}
          onChangeText={setNewPost}
          maxLength={MAX_POST_LENGTH}
          multiline
          editable={!hasPostedToday}
        />
        <View style={styles.composeFooter}>
          <Text style={[styles.charCount, newPost.length > MAX_POST_LENGTH - 20 && styles.charCountWarning]}>
            {newPost.length}/{MAX_POST_LENGTH}
          </Text>
          <Button
            title="Post"
            onPress={handlePost}
            size="sm"
            disabled={!newPost.trim() || hasPostedToday || isPosting}
            loading={isPosting}
          />
        </View>
      </Card>

      {/* Posts Feed */}
      <FlashList
        data={posts}
        renderItem={renderPost}
        keyExtractor={item => item.id}
        estimatedItemSize={120}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={colors.primary}
          />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>No posts yet. Be the first!</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

function PostCard({ post, onReport }: { post: Post; onReport: () => void }) {
  return (
    <Card style={styles.postCard}>
      <View style={styles.postHeader}>
        <View style={styles.postUser}>
          <View style={styles.userPhoto}>
            <Text style={styles.userPhotoText}>{post.userName[0]}</Text>
          </View>
          <View>
            <Text style={styles.userName}>{post.userName}</Text>
            <Text style={styles.postTime}>{post.createdAt}</Text>
          </View>
        </View>
        <TouchableOpacity onPress={onReport} style={styles.reportButton}>
          <Text style={styles.reportText}>•••</Text>
        </TouchableOpacity>
      </View>
      <Text style={styles.postBody}>{post.body}</Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
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
  composeCard: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.md,
  },
  composeInput: {
    fontSize: typography.fontSize.md,
    color: colors.textPrimary,
    minHeight: 60,
    textAlignVertical: 'top',
  },
  composeFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingTop: spacing.sm,
  },
  charCount: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
  },
  charCountWarning: {
    color: colors.warning,
  },
  list: {
    padding: spacing.lg,
  },
  emptyContainer: {
    padding: spacing.xxl,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: typography.fontSize.md,
    color: colors.textSecondary,
  },
  postCard: {
    marginBottom: spacing.md,
  },
  postHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.sm,
  },
  postUser: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  userPhoto: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.sm,
  },
  userPhotoText: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.bold,
    color: colors.white,
  },
  userName: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
  },
  postTime: {
    fontSize: typography.fontSize.sm,
    color: colors.textTertiary,
  },
  reportButton: {
    padding: spacing.sm,
  },
  reportText: {
    fontSize: typography.fontSize.lg,
    color: colors.gray400,
  },
  postBody: {
    fontSize: typography.fontSize.md,
    color: colors.textPrimary,
    lineHeight: 24,
  },
});
