import type { Metadata } from 'next';

import './globals.css';

export const metadata: Metadata = {
  title: 'tf-fs-nextjs-python',
  description:
    'Reference monorepo: Next.js frontend, FastAPI backend, Terraform on Cloud Run.',
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="font-sans">{children}</body>
    </html>
  );
}
