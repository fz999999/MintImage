---
name: Fluent Pro AI Workstation
colors:
  surface: '#101416'
  surface-dim: '#101416'
  surface-bright: '#363a3c'
  surface-container-lowest: '#0b0f11'
  surface-container-low: '#181c1e'
  surface-container: '#1c2022'
  surface-container-high: '#272b2c'
  surface-container-highest: '#313537'
  on-surface: '#e0e3e5'
  on-surface-variant: '#bec8cd'
  inverse-surface: '#e0e3e5'
  inverse-on-surface: '#2d3133'
  outline: '#899297'
  outline-variant: '#3f484c'
  surface-tint: '#81d1f0'
  primary: '#81d1f0'
  on-primary: '#003544'
  primary-container: '#0e7490'
  on-primary-container: '#d3f1ff'
  inverse-primary: '#006781'
  secondary: '#93ccff'
  on-secondary: '#003351'
  secondary-container: '#3198dc'
  on-secondary-container: '#002c47'
  tertiary: '#ffb86f'
  on-tertiary: '#4a2800'
  tertiary-container: '#965e1c'
  on-tertiary-container: '#ffe8d6'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#b9eaff'
  primary-fixed-dim: '#81d1f0'
  on-primary-fixed: '#001f29'
  on-primary-fixed-variant: '#004d62'
  secondary-fixed: '#cce5ff'
  secondary-fixed-dim: '#93ccff'
  on-secondary-fixed: '#001d31'
  on-secondary-fixed-variant: '#004b73'
  tertiary-fixed: '#ffdcbd'
  tertiary-fixed-dim: '#ffb86f'
  on-tertiary-fixed: '#2c1600'
  on-tertiary-fixed-variant: '#693c00'
  background: '#101416'
  on-background: '#e0e3e5'
  surface-variant: '#313537'
  surface-light: '#F8FAFC'
  surface-dark: '#0F172A'
  accent-teal: '#06B6D4'
  border-subtle: rgba(255, 255, 255, 0.08)
typography:
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 16px
  margin: 24px
  space-xs: 4px
  space-sm: 8px
  space-md: 16px
  space-lg: 24px
  space-xl: 32px
---

## Brand & Style

This design system delivers a professional, clean, and sophisticated aesthetic tailored for a desktop image generation application. Combining the principles of Microsoft's Fluent Design system with modern pro-tool ergonomics, the UI evokes precision, focus, and creative empowerment. 

The visual style leverages crisp glassmorphism with subtle acrylic materials, sophisticated multi-layered surfaces, and refined cyan and teal accents against high-contrast light and dark canvases. It balances technical capability with approachable, tactile interactions.

## Colors

The color palette is anchored by deep workstation slates and vibrant cyan/teal chromatic accents that signal processing power and digital creation. 

- **Primary (`#0E7490`)**: Used for primary interactive elements, active states, and focal points.
- **Secondary (`#0284C7`)**: Provides vibrant contrast for secondary actions, progress indicators, and glowing highlights.
- **Neutrals**: Scaled dynamically between light (`#F8FAFC`) and dark (`#0F172A`) modes to reduce eye strain during extended generation sessions.
- **Surface & Borders**: Utilizes semi-transparent materials with subtle borders to achieve a frosted glass effect.

## Typography

The typography stack utilizes **Manrope** for its geometric precision, readability, and modern desktop feel, with fallback support for system fonts like Microsoft YaHei for localized clarity. 

Type scaling is tightly controlled to maintain information density across complex workspace panels, inspectors, and prompt generation parameters. Large display scales feature tighter letter-spacing for structural impact.

## Layout & Spacing

The layout model relies on a flexible, multi-pane desktop grid optimized for tool panels, infinite canvas viewports, and parameter inspectors. 

- **Grid & Margins**: A 12-column workspace model with 16px gutters and 24px outer window margins.
- **Rhythm**: Spacing follows an 8px baseline grid scale (`space-sm` to `space-xl`) to maintain consistent alignment across densely packed toolbars and parameter sliders.
- **Responsiveness**: Adapts fluidly from compact windowed states to maximized 4K ultra-wide desktop layouts without breaking the core panel hierarchy.

## Elevation & Depth

Depth is communicated through modern acrylic glassmorphism and subtle ambient shadows rather than harsh drop-shadows. 

- **Surface Tiers**: Floating tool palettes and modal dialogs use semi-transparent background blurs (backdrop-filter) layered over the canvas.
- **Shadows**: Soft, multi-layered ambient shadows with low opacity provide gentle separation from the background.
- **Borders**: Refined, low-contrast ghost borders (`1px solid`) define interactive boundaries and enhance the tactile glass effect in both light and dark modes.

## Shapes

The shape language embraces a soft, professional desktop geometry (`roundedness` level 1). 

- **Elements**: Buttons, input fields, and small containers use a 0.25rem radius for crispness.
- **Containers**: Major panels, modal cards, and image preview containers use `rounded-lg` (0.5rem) to `rounded-xl` (0.75rem) to soften the UI while retaining a rigorous engineering aesthetic.

## Components

All UI components must adhere to the Fluent Pro aesthetic, combining translucent surfaces, subtle cyan highlights, and clear micro-interactions.

- **Buttons**: Primary actions use solid cyan/teal fills (`#0E7490`) with crisp hover states and subtle inner glows. Secondary actions use ghost glass buttons with border outlines.
- **Input Fields**: Parameter inputs and prompt textareas feature translucent background fills, clear focus rings in `#0284C7`, and embedded helper icons.
- **Cards**: Image generation result cards use frosted glass containers, featuring hover-reveal action overlays and status badges.
- **Checkboxes & Radios**: Designed with clean geometric geometry, utilizing primary accent fills when checked.
- **Lists & Trees**: Layer lists and asset trees feature subtle row-hover highlights and compact padding for high-density navigation.
- **Additional Workstation Components**: Includes custom sliders for generation steps/CFG scale, collapsible accordion inspectors, and segmented control tabs for switching model checkpoints.