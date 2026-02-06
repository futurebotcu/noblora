// ============================================================================
// ROOT NAVIGATOR
// Main navigation structure with auth and verification gates
// ============================================================================

import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useAuthStore } from '../store/authStore';
import { useGatingStore, selectIsVerified, selectIsEntryApproved } from '../store/gatingStore';
import { useProfileStore } from '../store/profileStore';

// Auth Screens
import { WelcomeScreen } from '../screens/auth/WelcomeScreen';
import { SignInScreen } from '../screens/auth/SignInScreen';
import { SignUpScreen } from '../screens/auth/SignUpScreen';

// Onboarding Screens
import { ModeSelectionScreen } from '../screens/onboarding/ModeSelectionScreen';
import { ProfileBasicsScreen } from '../screens/onboarding/ProfileBasicsScreen';
import { GenderSelectionScreen } from '../screens/onboarding/GenderSelectionScreen';

// Verification Screens
import { VerificationHubScreen } from '../screens/verification/VerificationHubScreen';
import { PhotoVerificationScreen } from '../screens/verification/PhotoVerificationScreen';
import { InstagramVerificationScreen } from '../screens/verification/InstagramVerificationScreen';
import { GenderVerificationScreen } from '../screens/verification/GenderVerificationScreen';

// Entry Gate Screens
import { EntryGateScreen } from '../screens/entry/EntryGateScreen';
import { ReferralCodeScreen } from '../screens/entry/ReferralCodeScreen';

// Main App Screens
import { MainTabNavigator } from './MainTabNavigator';

// Match Flow Screens
import { MatchScreen } from '../screens/match/MatchScreen';
import { SchedulingScreen } from '../screens/match/SchedulingScreen';
import { VideoCallScreen } from '../screens/match/VideoCallScreen';
import { PostCallDecisionScreen } from '../screens/match/PostCallDecisionScreen';
import { ChatScreen } from '../screens/match/ChatScreen';
import { MeetupScreen } from '../screens/match/MeetupScreen';
import { QrCheckinScreen } from '../screens/match/QrCheckinScreen';

export type RootStackParamList = {
  // Auth
  Welcome: undefined;
  SignIn: undefined;
  SignUp: undefined;

  // Onboarding
  ModeSelection: undefined;
  ProfileBasics: undefined;
  GenderSelection: undefined;

  // Verification
  VerificationHub: undefined;
  PhotoVerification: undefined;
  InstagramVerification: undefined;
  GenderVerification: undefined;

  // Entry Gate
  EntryGate: undefined;
  ReferralCode: undefined;

  // Main App
  MainTabs: undefined;

  // Match Flow
  Match: { matchId: string };
  Scheduling: { matchId: string };
  VideoCall: { matchId: string };
  PostCallDecision: { matchId: string };
  Chat: { matchId: string };
  Meetup: { matchId: string; meetupId?: string };
  QrCheckin: { meetupId: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  const user = useAuthStore(state => state.user);
  const profile = useProfileStore(state => state.profile);
  const isVerified = useGatingStore(selectIsVerified);
  const isEntryApproved = useGatingStore(selectIsEntryApproved);

  // Determine which flow to show
  const isAuthenticated = !!user;
  const hasProfile = !!profile;

  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        animation: 'slide_from_right',
      }}
    >
      {!isAuthenticated ? (
        // Auth Flow
        <>
          <Stack.Screen name="Welcome" component={WelcomeScreen} />
          <Stack.Screen name="SignIn" component={SignInScreen} />
          <Stack.Screen name="SignUp" component={SignUpScreen} />
        </>
      ) : !hasProfile ? (
        // Onboarding Flow
        <>
          <Stack.Screen name="ModeSelection" component={ModeSelectionScreen} />
          <Stack.Screen name="GenderSelection" component={GenderSelectionScreen} />
          <Stack.Screen name="ProfileBasics" component={ProfileBasicsScreen} />
        </>
      ) : !isVerified ? (
        // Verification Flow
        <>
          <Stack.Screen name="VerificationHub" component={VerificationHubScreen} />
          <Stack.Screen name="PhotoVerification" component={PhotoVerificationScreen} />
          <Stack.Screen name="InstagramVerification" component={InstagramVerificationScreen} />
          <Stack.Screen name="GenderVerification" component={GenderVerificationScreen} />
        </>
      ) : !isEntryApproved ? (
        // Entry Gate Flow
        <>
          <Stack.Screen name="EntryGate" component={EntryGateScreen} />
          <Stack.Screen name="ReferralCode" component={ReferralCodeScreen} />
        </>
      ) : (
        // Main App Flow
        <>
          <Stack.Screen name="MainTabs" component={MainTabNavigator} />

          {/* Match Flow - Modal Stack */}
          <Stack.Group screenOptions={{ presentation: 'modal' }}>
            <Stack.Screen name="Match" component={MatchScreen} />
            <Stack.Screen name="Scheduling" component={SchedulingScreen} />
            <Stack.Screen name="VideoCall" component={VideoCallScreen} />
            <Stack.Screen name="PostCallDecision" component={PostCallDecisionScreen} />
            <Stack.Screen name="Chat" component={ChatScreen} />
            <Stack.Screen name="Meetup" component={MeetupScreen} />
            <Stack.Screen name="QrCheckin" component={QrCheckinScreen} />
          </Stack.Group>
        </>
      )}
    </Stack.Navigator>
  );
}
