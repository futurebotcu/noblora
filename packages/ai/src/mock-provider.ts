// ============================================================================
// MOCK AI PROVIDER
// Used for development and testing when no real AI service is configured
// ============================================================================

import type { AIProvider, PhotoAnalysisResult, ContentModerationResult } from './types';

/**
 * Mock AI Provider that simulates AI responses for development
 */
export class MockAIProvider implements AIProvider {
  readonly name: string = 'mock';

  /**
   * Simulate photo analysis with randomized but reasonable results
   */
  async analyzePhoto(imageUrl: string): Promise<PhotoAnalysisResult> {
    // Simulate API latency
    await this.simulateLatency(200, 500);

    // Use URL hash to generate deterministic but varied results
    const hash = this.simpleHash(imageUrl);

    // Deterministic "random" values based on URL
    const faceDetected = hash % 10 < 8; // 80% have face
    const faceCount = faceDetected ? 1 + (hash % 3) : 0;
    const qualityScore = 50 + (hash % 50);
    const blurScore = hash % 30;
    const brightnessScore = 40 + (hash % 40);

    return {
      faceDetected,
      faceCount,
      faceVisible: faceDetected && faceCount === 1 && blurScore < 20,
      qualityScore,
      blurScore,
      brightnessScore,
      isAppropriate: true, // Mock always returns appropriate
      metadata: {
        glasses: hash % 5 === 0,
        sunglasses: hash % 10 === 0,
      },
      confidence: 0.85 + (hash % 15) / 100,
    };
  }

  /**
   * Simulate text content moderation
   */
  async moderateText(text: string): Promise<ContentModerationResult> {
    await this.simulateLatency(100, 200);

    // Basic keyword-based moderation for testing
    const lowerText = text.toLowerCase();

    const spamKeywords = ['buy now', 'click here', 'free money', 'winner'];
    const inappropriateKeywords = ['hate', 'kill', 'stupid'];

    const hasSpam = spamKeywords.some(k => lowerText.includes(k));
    const hasInappropriate = inappropriateKeywords.some(k => lowerText.includes(k));

    return {
      isAppropriate: !hasSpam && !hasInappropriate,
      flags: {
        spam: hasSpam,
        harassment: hasInappropriate,
        hatespeech: false,
        sexual: false,
        violence: false,
        other: false,
      },
      confidence: 0.9,
      reason: hasSpam ? 'Detected spam keywords' : hasInappropriate ? 'Detected inappropriate content' : undefined,
    };
  }

  /**
   * Mock provider is always available
   */
  async isAvailable(): Promise<boolean> {
    return true;
  }

  /**
   * Simulate API latency
   */
  private async simulateLatency(minMs: number, maxMs: number): Promise<void> {
    const delay = minMs + Math.random() * (maxMs - minMs);
    await new Promise(resolve => setTimeout(resolve, delay));
  }

  /**
   * Simple hash function for deterministic mock results
   */
  private simpleHash(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash;
    }
    return Math.abs(hash);
  }
}

/**
 * Create a mock provider instance
 */
export function createMockProvider(): AIProvider {
  return new MockAIProvider();
}
