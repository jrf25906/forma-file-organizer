import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    // Custom screens for better viewport coverage
    screens: {
      'sm': '640px',
      'md': '768px',
      'tablet': '900px',  // Explicit tablet breakpoint for iPad landscape
      'lg': '1024px',
      'xl': '1280px',
      '2xl': '1536px',
      '3xl': '1920px',    // Large desktop
      'ultrawide': '2560px', // Ultra-wide displays (21:9)
    },
    extend: {
      colors: {
        // Forma Brand Colors
        forma: {
          obsidian: "#1A1A1A",
          bone: "#FAFAF8",
          "steel-blue": "#5B7C99",
          sage: "#7A9D7E",
          "muted-blue": "#6B8CA8",
          "warm-orange": "#C97E66",
          "soft-green": "#8BA688",
        },
      },
      // Semantic opacity scale (reduce 11 values to 6)
      opacity: {
        'text-secondary': '0.70',
        'text-tertiary': '0.50',
        'text-disabled': '0.35',
        'border-subtle': '0.05',
        'border-light': '0.10',
        'border-medium': '0.20',
      },
      // Semantic spacing for sections
      spacing: {
        'section-sm': '3rem',     // 48px - py-12
        'section-md': '5rem',     // 80px - py-20
        'section-lg': '8rem',     // 128px - py-32
      },
      // Consolidated border radius
      borderRadius: {
        'card': '0.5rem',         // 8px
        'modal': '1rem',          // 16px
        'badge': '0.375rem',      // 6px
      },
      fontFamily: {
        display: ["var(--font-display)", "Georgia", "serif"],
        body: ["var(--font-body)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "monospace"],
      },
      backgroundImage: {
        "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
        "gradient-conic": "conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))",
        "glass-gradient": "linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.05) 100%)",
      },
      animation: {
        "float": "float 6s ease-in-out infinite",
        "float-slow": "float 8s ease-in-out infinite",
        "float-slower": "float 10s ease-in-out infinite",
        "pulse-slow": "pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        "gradient-shift": "gradient-shift 15s ease infinite",
        "fade-in": "fade-in 0.6s ease-out forwards",
        "fade-in-up": "fade-in-up 0.8s ease-out forwards",
        "slide-up": "slide-up 0.6s ease-out forwards",
        "slide-down": "slide-down 0.6s ease-out forwards",
        "scale-in": "scale-in 0.5s ease-out forwards",
        "blur-in": "blur-in 0.8s ease-out forwards",
        "blink": "blink 1s step-end infinite",
        "forma-settle": "forma-settle 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards",
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-20px)" },
        },
        "gradient-shift": {
          "0%, 100%": { backgroundPosition: "0% 50%" },
          "50%": { backgroundPosition: "100% 50%" },
        },
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        "slide-up": {
          "0%": { opacity: "0", transform: "translateY(30px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "slide-down": {
          "0%": { opacity: "0", transform: "translateY(-30px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "scale-in": {
          "0%": { opacity: "0", transform: "scale(0.95)" },
          "100%": { opacity: "1", transform: "scale(1)" },
        },
        "blur-in": {
          "0%": { opacity: "0", filter: "blur(10px)" },
          "100%": { opacity: "1", filter: "blur(0)" },
        },
        "fade-in-up": {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "blink": {
          "0%, 100%": { opacity: "1" },
          "50%": { opacity: "0" },
        },
        "forma-settle": {
          "0%": {
            opacity: "0",
            transform: "translateY(12px) scale(0.98)",
          },
          "100%": {
            opacity: "1",
            transform: "translateY(0) scale(1)",
          },
        },
      },
      backdropBlur: {
        xs: "2px",
      },
      boxShadow: {
        "glass": "0 8px 32px rgba(0, 0, 0, 0.12)",
        "glass-lg": "0 16px 48px rgba(0, 0, 0, 0.15)",
        "glass-xl": "0 24px 64px rgba(0, 0, 0, 0.2)",
        "inner-light": "inset 0 1px 0 rgba(255, 255, 255, 0.1)",
        "glow-blue": "0 0 40px rgba(91, 124, 153, 0.3)",
        "glow-sage": "0 0 40px rgba(122, 157, 126, 0.3)",
      },
    },
  },
  plugins: [],
};

export default config;
