/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@noblara/shared'],
  experimental: {
    serverComponentsExternalPackages: ['@supabase/supabase-js'],
  },
};

export default nextConfig;
