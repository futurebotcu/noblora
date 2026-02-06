// ============================================================================
// AI PROVIDER TYPES
// ============================================================================

/**
 * Result of photo analysis for face detection and quality
 */
export interface PhotoAnalysisResult {
  faceDetected: boolean;
  faceCount: number;
  faceVisible: boolean; // Face clearly visible and recognizable
  qualityScore: number; // 0-100
  blurScore: number; // 0-100, higher = more blurry
  brightnessScore: number; // 0-100
  isAppropriate: boolean; // No explicit/inappropriate content
  metadata?: {
    estimatedAge?: number; // We do NOT use this for gender inference
    glasses?: boolean;
    sunglasses?: boolean;
  };
  confidence: number; // 0-1, confidence in the analysis
  error?: string;
}

/**
 * Result of content moderation
 */
export interface ContentModerationResult {
  isAppropriate: boolean;
  flags: {
    spam: boolean;
    harassment: boolean;
    hatespeech: boolean;
    sexual: boolean;
    violence: boolean;
    other: boolean;
  };
  confidence: number;
  reason?: string;
}

/**
 * AI Provider interface - implement this for different AI backends
 */
export interface AIProvider {
  /**
   * Provider name for logging
   */
  readonly name: string;

  /**
   * Analyze a photo for face detection and quality
   * @param imageUrl URL or base64 of the image
   */
  analyzePhoto(imageUrl: string): Promise<PhotoAnalysisResult>;

  /**
   * Moderate text content
   * @param text The text to moderate
   */
  moderateText(text: string): Promise<ContentModerationResult>;

  /**
   * Check if the provider is available
   */
  isAvailable(): Promise<boolean>;
}

/**
 * Configuration for AI providers
 */
export interface AIProviderConfig {
  provider: 'mock' | 'openai' | 'anthropic' | 'custom';
  apiKey?: string;
  endpoint?: string;
  options?: Record<string, unknown>;
}
