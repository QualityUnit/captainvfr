/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class', // important so that dark: utilities work on the .dark class

  content: [
    './layouts/**/*.html',
    '../../layouts/**/*.html',
    '../**/layouts/**/*.html',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      colors: {
       primary: {
          50:  '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          DEFAULT: '#2563eb', // (600) as default if you use `bg-primary, text-primary, etc.`
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
          950: '#172554',
        },
        // Brand colors for surface, text, icons, borders, and buttons
        brand: {
          surface: '#eff6ff',
          'dark-surface': '#1e3a8a',
          'surface-secondary': '#dbeafe',
          'dark-surface-secondary': '#1e40af',
          underlight: '#bfdbfe',
          'dark-underlight': '#1d4ed8',
          text: '#2563eb',
          'dark-text': '#60a5fa',
          icon: '#3b82f6',
          'dark-icon': '#93c5fd',
          border: '#93c5fd',
          'dark-border': '#1d4ed8',
        },
        // Button colors
        button: {
          primary: '#2563eb',
          'primary-hover': '#1d4ed8',
          'primary-outline': '#2563eb',
          'primary-dark': '#60a5fa',
          'primary-dark-hover': '#93c5fd',
          secondary: '#ffffff',
          'secondary-border': '#d1d5db',
          'secondary-text': '#374151',
          'secondary-border-hover': '#9ca3af',
          'secondary-dark': '#ffffff',
          'secondary-dark-text': '#ffffff',
          'secondary-dark-border': '#4b5563',
          'secondary-dark-border-hover': '#6b7280',
          text: '#2563eb',
          'text-hover': '#1d4ed8',
          'text-dark': '#60a5fa',
          'text-dark-hover': '#93c5fd',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
  ],
  // Ensure Tailwind doesn't conflict with the lazy loading and responsive image features
  safelist: ['lazy-load', 'lazy-load-bg', 'lazy-load-video', 'picture', 'source', 'webp', 'srcset'],
};
