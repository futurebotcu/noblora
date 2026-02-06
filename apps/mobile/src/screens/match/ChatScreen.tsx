// ============================================================================
// CHAT SCREEN
// Messaging after chat unlock
// ============================================================================

import React, { useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import { FlashList } from '@shopify/flash-list';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../../navigation/RootNavigator';
import { colors, spacing, typography, borderRadius } from '../../constants/theme';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Chat'>;
type RouteType = RouteProp<RootStackParamList, 'Chat'>;

interface Message {
  id: string;
  body: string;
  fromMe: boolean;
  createdAt: string;
}

// Mock messages
const MOCK_MESSAGES: Message[] = [
  { id: '1', body: 'Hey! It was great talking to you!', fromMe: false, createdAt: '10:30 AM' },
  { id: '2', body: 'I really enjoyed our call too!', fromMe: true, createdAt: '10:31 AM' },
  { id: '3', body: 'So, about that coffee place you mentioned...', fromMe: false, createdAt: '10:32 AM' },
];

export function ChatScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RouteType>();
  const { matchId } = route.params;

  const [messages, setMessages] = useState(MOCK_MESSAGES);
  const [inputText, setInputText] = useState('');
  const listRef = useRef<FlashList<Message>>(null);

  const handleSend = useCallback(() => {
    if (!inputText.trim()) return;

    const newMessage: Message = {
      id: Date.now().toString(),
      body: inputText.trim(),
      fromMe: true,
      createdAt: new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }),
    };

    setMessages([...messages, newMessage]);
    setInputText('');

    // Would call API to send message
  }, [inputText, messages]);

  const renderMessage = useCallback(({ item }: { item: Message }) => (
    <View style={[styles.messageContainer, item.fromMe && styles.myMessageContainer]}>
      <View style={[styles.messageBubble, item.fromMe && styles.myMessageBubble]}>
        <Text style={[styles.messageText, item.fromMe && styles.myMessageText]}>
          {item.body}
        </Text>
        <Text style={[styles.messageTime, item.fromMe && styles.myMessageTime]}>
          {item.createdAt}
        </Text>
      </View>
    </View>
  ), []);

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.backButton}>←</Text>
        </TouchableOpacity>
        <View style={styles.headerInfo}>
          <Text style={styles.headerName}>Sofia</Text>
          <Text style={styles.headerStatus}>Online</Text>
        </View>
        <TouchableOpacity onPress={() => navigation.navigate('Meetup', { matchId })}>
          <Text style={styles.meetupButton}>📅</Text>
        </TouchableOpacity>
      </View>

      {/* Meetup Reminder */}
      <View style={styles.meetupReminder}>
        <Text style={styles.reminderText}>
          📍 Schedule a meetup within 5 days
        </Text>
        <TouchableOpacity onPress={() => navigation.navigate('Meetup', { matchId })}>
          <Text style={styles.reminderLink}>Schedule Now</Text>
        </TouchableOpacity>
      </View>

      {/* Messages */}
      <KeyboardAvoidingView
        style={styles.messagesContainer}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={100}
      >
        <FlashList
          ref={listRef}
          data={messages}
          renderItem={renderMessage}
          keyExtractor={item => item.id}
          estimatedItemSize={80}
          contentContainerStyle={styles.messagesList}
          inverted={false}
        />
      </KeyboardAvoidingView>

      {/* Input */}
      <View style={styles.inputContainer}>
        <TextInput
          style={styles.input}
          placeholder="Type a message..."
          placeholderTextColor={colors.gray400}
          value={inputText}
          onChangeText={setInputText}
          multiline
          maxLength={2000}
        />
        <TouchableOpacity
          style={[styles.sendButton, !inputText.trim() && styles.sendButtonDisabled]}
          onPress={handleSend}
          disabled={!inputText.trim()}
        >
          <Text style={styles.sendButtonText}>→</Text>
        </TouchableOpacity>
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
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  backButton: {
    fontSize: 28,
    color: colors.primary,
    marginRight: spacing.md,
  },
  headerInfo: {
    flex: 1,
  },
  headerName: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.textPrimary,
  },
  headerStatus: {
    fontSize: typography.fontSize.sm,
    color: colors.success,
  },
  meetupButton: {
    fontSize: 24,
  },
  meetupReminder: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: colors.warningLight,
    padding: spacing.md,
  },
  reminderText: {
    fontSize: typography.fontSize.sm,
    color: colors.warning,
  },
  reminderLink: {
    fontSize: typography.fontSize.sm,
    color: colors.primary,
    fontWeight: typography.fontWeight.semibold,
  },
  messagesContainer: {
    flex: 1,
  },
  messagesList: {
    padding: spacing.lg,
  },
  messageContainer: {
    marginBottom: spacing.md,
    alignItems: 'flex-start',
  },
  myMessageContainer: {
    alignItems: 'flex-end',
  },
  messageBubble: {
    maxWidth: '80%',
    backgroundColor: colors.gray100,
    borderRadius: borderRadius.lg,
    borderBottomLeftRadius: borderRadius.xs,
    padding: spacing.md,
  },
  myMessageBubble: {
    backgroundColor: colors.primary,
    borderBottomLeftRadius: borderRadius.lg,
    borderBottomRightRadius: borderRadius.xs,
  },
  messageText: {
    fontSize: typography.fontSize.md,
    color: colors.textPrimary,
    lineHeight: 22,
  },
  myMessageText: {
    color: colors.white,
  },
  messageTime: {
    fontSize: typography.fontSize.xs,
    color: colors.textTertiary,
    marginTop: spacing.xs,
  },
  myMessageTime: {
    color: 'rgba(255,255,255,0.7)',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    backgroundColor: colors.white,
  },
  input: {
    flex: 1,
    backgroundColor: colors.gray100,
    borderRadius: borderRadius.lg,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    fontSize: typography.fontSize.md,
    maxHeight: 100,
    color: colors.textPrimary,
  },
  sendButton: {
    marginLeft: spacing.sm,
    backgroundColor: colors.primary,
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendButtonDisabled: {
    backgroundColor: colors.gray300,
  },
  sendButtonText: {
    fontSize: 24,
    color: colors.white,
  },
});
