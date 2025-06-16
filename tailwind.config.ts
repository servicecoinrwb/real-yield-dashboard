import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#f97316', // orange-500
        background: '#000000',
        foreground: '#ffffff',
      },
    },
  },
  plugins: [],
};

export default config;
