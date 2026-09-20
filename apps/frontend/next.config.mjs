/** @type {import('next').NextConfig} */
const nextConfig = {
  // Emits .next/standalone with a minimal server and only the node_modules
  // actually imported. This is what keeps the runtime container small and is
  // required by the Dockerfile's final stage.
  output: 'standalone',

  // Fail the production build on type or lint errors rather than shipping
  // them. (Next's defaults already do this; stated explicitly so nobody
  // "fixes" a red build by flipping these on.)
  typescript: { ignoreBuildErrors: false },
  eslint: { ignoreDuringBuilds: false },

  reactStrictMode: true,

  // Do not advertise the framework version to the world.
  poweredByHeader: false,
};

export default nextConfig;
