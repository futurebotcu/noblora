// ============================================================================
// AI PROVIDER FACTORY
// Creates the appropriate AI provider based on configuration
// ============================================================================

import type { AIProvider, AIProviderConfig } from './types';
import { MockAIProvider } from './mock-provider';

// Singleton instance
let providerInstance: AIProvider | null = null;

/**
 * Get the configured AI provider
 * Returns mock provider if no configuration or if explicitly set to mock
 */
export function getAIProvider(config?: AIProviderConfig): AIProvider {
  if (providerInstance) {
    return providerInstance;
  }

  // Default to mock if no config
  if (!config || config.provider === 'mock') {
    providerInstance = new MockAIProvider();
    return providerInstance;
  }

  // Placeholder for real providers - implement when needed
  switch (config.provider) {
    case 'openai':
      // TODO: Implement OpenAI provider
      // providerInstance = new OpenAIProvider(config);
      console.warn('OpenAI provider not implemented, falling back to mock');
      providerInstance = new MockAIProvider();
      break;

    case 'anthropic':
      // TODO: Implement Anthropic provider
      // providerInstance = new AnthropicProvider(config);
      console.warn('Anthropic provider not implemented, falling back to mock');
      providerInstance = new MockAIProvider();
      break;

    case 'custom':
      // TODO: Implement custom provider loader
      console.warn('Custom provider not implemented, falling back to mock');
      providerInstance = new MockAIProvider();
      break;

    default:
      providerInstance = new MockAIProvider();
  }

  return providerInstance;
}

/**
 * Reset the provider instance (useful for testing)
 */
export function resetAIProvider(): void {
  providerInstance = null;
}

/**
 * Create AI provider config from environment variables
 */
export function getAIConfigFromEnv(): AIProviderConfig {
  const provider = (process.env.AI_PROVIDER || 'mock') as AIProviderConfig['provider'];

  switch (provider) {
    case 'openai':
      return {
        provider: 'openai',
        apiKey: process.env.OPENAI_API_KEY,
      };

    case 'anthropic':
      return {
        provider: 'anthropic',
        apiKey: process.env.ANTHROPIC_API_KEY,
      };

    default:
      return { provider: 'mock' };
  }
}

// ============================================================================
// PROVIDER INTERFACE STUBS FOR FUTURE IMPLEMENTATION
// ============================================================================

/**
 * OpenAI Provider stub - implement when ready
 */
export class OpenAIProvider extends MockAIProvider {
  override readonly name = 'openai';

  constructor(_config: AIProviderConfig) {
    super();
    // TODO: Initialize OpenAI client
  }

  // Override methods with real OpenAI API calls when implementing
}

/**
 * Anthropic Provider stub - implement when ready
 */
export class AnthropicProvider extends MockAIProvider {
  override readonly name = 'anthropic';

  constructor(_config: AIProviderConfig) {
    super();
    // TODO: Initialize Anthropic client
  }

  // Override methods with real Anthropic API calls when implementing
}
