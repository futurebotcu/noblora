const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');
const path = require('path');

// Find the monorepo root
const monorepoRoot = path.resolve(__dirname, '../..');

const config = {
  watchFolders: [monorepoRoot],
  resolver: {
    nodeModulesPaths: [
      path.resolve(__dirname, 'node_modules'),
      path.resolve(monorepoRoot, 'node_modules'),
    ],
    // Ensure we can resolve workspace packages
    extraNodeModules: {
      '@noblara/shared': path.resolve(monorepoRoot, 'packages/shared'),
      '@noblara/ai': path.resolve(monorepoRoot, 'packages/ai'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
