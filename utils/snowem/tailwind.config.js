/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/client/**/*.{html,tsx,ts}'],
  theme: {
    extend: {
      colors: {
        snow: {
          nav: '#1b2a3e',
          'nav-hover': '#243a52',
          accent: '#62d84e',
          surface: '#f4f4f4',
          border: '#e0e0e0',
        },
      },
    },
  },
  plugins: [],
};
