# Dashboard UI Patterns & Styling Guide

## Overview

This guide documents the design system, component patterns, and styling conventions used in the TGF Parkrun Dashboard. The dashboard is built as a **mobile-first, zero-JavaScript** application using Astro's server-side rendering and Islands architecture.

## Design System

### Color Palette

**Neutrals (Primary):**

- `#ffffff` — White (backgrounds, cards)
- `#f5f5f5` — Light gray (alternate backgrounds, subtle dividers)
- `#e0e0e0` — Medium gray (borders, disabled states)
- `#666666` — Dark gray (secondary text)
- `#333333` — Near-black (primary text, headings)

**Brand & Accent Colors:**

- `#0066cc` — Blue (links, primary actions, highlights)
- `#00aa44` — Green (success, positive change, "new")
- `#ff6600` — Orange (warnings, "change")
- `#cc0000` — Red (errors, critical info)

**Data Visualization:**

- Chart colors should use a consistent palette for consistency across pages (ApexCharts defaults are acceptable)
- Avoid red/green-only distinctions for accessibility; use blue/orange or include patterns/icons

### Typography

**Font Stack:**

```css
font-family:
  -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue',
  Arial, sans-serif;
```

**Scale:**

- **H1 (Page Title):** 28px, font-weight 700, line-height 1.2
- **H2 (Section):** 20px, font-weight 700, line-height 1.3
- **H3 (Subsection):** 16px, font-weight 600, line-height 1.4
- **Body:** 16px, font-weight 400, line-height 1.5
- **Small/Caption:** 14px, font-weight 400, line-height 1.5
- **Tiny:** 12px, font-weight 400, line-height 1.4

**Usage:**

- Headings use bold weight (600–700) for visual hierarchy
- Body text uses regular (400) for readability
- All text uses `line-height >= 1.5` for accessibility (WCAG 1.5× requirement)

### Spacing Scale

Consistent 8px base unit:

```
xs:  4px   (gaps, small margins)
sm:  8px   (padding inside cards, tight spacing)
md: 16px   (padding, standard margins)
lg: 24px   (section spacing)
xl: 32px   (page margins on mobile, gaps between major sections)
```

**Mobile Margins:** 16px left/right on viewport edges  
**Desktop Margins:** Max-width 1024px centered container (set in `Layout.astro`)

### Breakpoints

Mobile-first responsive approach (min-width breakpoints):

```
mobile:  0–479px   (default/base styles)
tablet:  480px–879px (medium screens, tablets)
desktop: 880px+     (large screens, desktops)
```

**Example Media Query:**

```css
/* Base mobile styles */
.card {
  width: 100%;
}

/* Tablet and up */
@media (min-width: 480px) {
  .card {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }
}

/* Desktop and up */
@media (min-width: 880px) {
  .card {
    grid-template-columns: 1fr 1fr 1fr;
  }
}
```

## Component Architecture

### Astro Islands Pattern

The dashboard uses **Astro Islands architecture** to minimize JavaScript:

- **Astro components** (`.astro` files): SSR-only, zero JavaScript
- **Interactive components**: Explicit client-side hydration via `client:load`
- **Styling**: Scoped with `<style>` blocks or global with `is:global`

**Design Decision:** Render-first, hydrate sparingly. Only interactive features (filters, sort buttons, map interactions) are hydrated.

### Layout Structure

**Global Layout** (`Layout.astro`):

```astro
<html>
  <head>
    <!-- Global styles with is:global -->
    <!-- Meta tags, favicon -->
  </head>
  <body>
    <Header />          <!-- Navigation, hamburger toggle -->
    <main>
      <slot />          <!-- Page content -->
    </main>
    <Footer />          <!-- Footer links -->
  </body>
</html>
```

- Max-width 1024px container centered
- 16px margins on mobile, 32px on desktop
- Full-bleed sections (e.g., map, top nav) break container with negative margins

### Common Component Patterns

#### Card Layout

```astro
<div class="card">
  <h3 class="card-title">Title</h3>
  <div class="card-content">
    <!-- Content here -->
  </div>
</div>
```

```css
.card {
  background: white;
  border: 1px solid #e0e0e0;
  border-radius: 6px;
  padding: 16px;
  margin-bottom: 16px;
}

.card-title {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 12px;
}
```

#### Table Pattern

Use semantic `<table>` elements with mobile-friendly wrapping:

```astro
<table class="data-table">
  <thead>
    <tr>
      <th>Name</th>
      <th>Value</th>
    </tr>
  </thead>
  <tbody>
    {data.map(row => (
      <tr>
        <td>{row.name}</td>
        <td>{row.value}</td>
      </tr>
    ))}
  </tbody>
</table>
```

**Mobile Responsive:**

```css
@media (max-width: 479px) {
  .data-table {
    font-size: 14px;
  }
  .data-table th {
    display: none;
  }
  .data-table tbody tr {
    display: block;
    margin-bottom: 16px;
    border: 1px solid #e0e0e0;
  }
  .data-table td {
    display: flex;
    justify-content: space-between;
    padding: 8px;
    border-bottom: 1px solid #f5f5f5;
  }
  .data-table td::before {
    content: attr(data-label);
    font-weight: 600;
  }
}
```

#### Button / Link Pattern

```astro
<a href="/page" class="btn btn-primary">Click me</a>
<button class="btn btn-secondary">Secondary</button>
```

```css
.btn {
  display: inline-block;
  padding: 10px 16px;
  border: none;
  border-radius: 4px;
  font-size: 16px;
  cursor: pointer;
  text-decoration: none;
  transition: all 150ms ease;
}

.btn-primary {
  background: #0066cc;
  color: white;
}

.btn-primary:hover {
  background: #0052a3;
  opacity: 0.9;
}
.btn-primary:active {
  transform: scale(0.98);
}

.btn-secondary {
  background: #f5f5f5;
  color: #333;
  border: 1px solid #e0e0e0;
}
```

## Mobile-First Design Strategy

### Why Mobile-First?

1. **Constraints-first thinking**: Design on small screens forces essential content prioritization
2. **Progressive enhancement**: Desktop features layer on top without regressing mobile
3. **Performance**: Mobile users typically have slower connections; keep payloads lean
4. **Usage pattern**: Finish-line time is mobile-dominant (on-site checking results)

### Mobile Optimization Checklist

- [ ] Touch targets (buttons, links) are ≥44px × 44px (WCAG 2.1 Level AAA)
- [ ] Tab/focus order is logical (top-to-bottom, left-to-right)
- [ ] All interactive elements are keyboard-accessible
- [ ] Color contrast ≥4.5:1 for normal text (WCAG AA)
- [ ] No horizontal scroll on mobile viewport
- [ ] Font size ≥16px to avoid auto-zoom on iOS
- [ ] Hamburger nav is primary on mobile, breadcrumbs on desktop

### Hamburger Navigation

**Implementation** (`Header.astro`):

- SVG hamburger that animates to "X" on open
- Click to toggle, click outside to close
- Mobile: overlay menu (full viewport), Desktop: hidden (breadcrumbs shown)
- Keyboard: ESC key closes menu

**Rationale:** Limited mobile screen space; drawer navigation maximizes content area.

## Data Display Conventions

### Date Formatting

**Display Format:** `dd-mm-yyyy` (with hyphens, not slashes)

```typescript
// Correct
const formatted = date.toLocaleDateString('en-GB').split('/').join('-');
// "02-04-2026"

// Incorrect (do not use)
date.toLocaleDateString('en-GB'); // "02/04/2026"
date.toLocaleDateString('en-US'); // "04/02/2026"
```

### Time Formatting

**Duration/Finish Times:** `HH:MM` or `HH:MM:SS`

```
23:45        — 23 minutes 45 seconds
1:23:45      — 1 hour, 23 minutes, 45 seconds
```

**Zero-Padding:** Always pad minutes/seconds to 2 digits (01:05, not 1:5)

### Number Formatting

**Integers:** No decimal places, comma separators for thousands

```
1234    → 1,234
42      → 42 (no comma needed)
```

**Decimals:** Max 1–2 decimal places depending on context

```
Temperature: 15.2°C
Percentage: 75%
```

## Accessibility Guidelines

### Color & Contrast

- Never use color alone to convey information (e.g., "green = good, red = bad")
- Pair colors with icons, textual labels, or patterns
- Test contrast ratios at [webaim.org/contrast](https://webaim.org/contrast/)

### Keyboard Navigation

All interactive elements must be reachable via Tab key:

```css
/* Ensure focus is visible */
a:focus,
button:focus,
select:focus,
textarea:focus {
  outline: 2px solid #0066cc;
  outline-offset: 2px;
}
```

### Screen Reader Support

- Use semantic HTML (`<button>`, `<nav>`, `<main>`, `<table>`)
- Provide `aria-label` for icon-only buttons
- Use `role="tablist"` for tab interfaces

```astro
<!-- Example: Icon button -->
<button aria-label="Toggle navigation menu" class="hamburger">
  {/* SVG icon */}
</button>
```

### WCAG Compliance Target

The dashboard aims for **WCAG 2.1 Level AA** minimum:

- Color contrast ≥4.5:1 (normal text)
- Focus indicators visible
- Semantic HTML structure
- Form labels properly associated

## Performance & Zero-JS Philosophy

### Why Zero-JS by Default?

- **Faster rendering**: No hydration overhead
- **Better SEO**: Content is indexable in HTML
- **Accessibility**: Works in text-mode browsers, screen readers
- **Resilience**: No JavaScript errors break page functionality

### When to Add Client-Side JavaScript

Only hydrate components that need dynamic behavior:

- **Interactive tables** (sorting, filtering)
- **Maps** (pan, zoom, click markers)
- **Charts** (hover tooltips, legend toggling)
- **Modals** (open/close logic)

**Example hydration:**

```astro
---
import { InteractiveTable } from '../components/InteractiveTable.tsx';
---

<InteractiveTable client:load data={tableData} />
```

The `client:load` directive tells Astro to hydrate this component in the browser.

### Bundle Size Impact

- Each interactive component adds ~5–50KB to JavaScript bundle (depending on library)
- Prioritize critical features for hydration; defer nice-to-haves
- Monitor bundle size during development

## New Component Checklist

When adding a new dashboard component:

### 1. Planning

- [ ] Determine if component needs interactivity (if not, keep as pure Astro)
- [ ] Define data input (props, BigQuery query)
- [ ] Sketch mobile and desktop layouts
- [ ] Identify accessibility needs (tables, forms, etc.)

### 2. File Structure

```
dashboard/src/components/
  MyComponent.astro          (pure Astro, SSR)
  MyInteractive.tsx          (if interactive, React/Preact component)
```

### 3. Styling

- [ ] Use scoped `<style>` for component-specific styles
- [ ] Use `is:global` only for typography/resets (already in Layout)
- [ ] Follow spacing scale (4px, 8px, 16px, 24px, 32px)
- [ ] Test responsive behavior (mobile, tablet, desktop)

### 4. Accessibility

- [ ] Use semantic HTML (`<section>`, `<article>`, `<header>`)
- [ ] Test color contrast (use [WebAIM](https://webaim.org/contrast/))
- [ ] Keyboard navigation (if interactive)
- [ ] Add `aria-label` if needed

### 5. Data

- [ ] Format dates with `dd-mm-yyyy` convention
- [ ] Format times with zero-padding (HH:MM:SS)
- [ ] Round numbers appropriately

### 6. Testing

- [ ] Renders without errors
- [ ] Mobile layout is usable (no horizontal scroll)
- [ ] Links/buttons are ≥44px touch targets
- [ ] Text is readable (16px+, dark text on light background)

## Common Pitfalls to Avoid

### ❌ Don't

- Use `<div>` for everything (use semantic HTML)
- Add JavaScript to every component (default to SSR-only)
- Hardcode colors instead of using palette variables
- Skip focus states on interactive elements
- Use color alone to convey meaning (add icons/labels)
- Forget to test on mobile (real device, not just browser DevTools)

### ✅ Do

- Use `<button>` for clickable elements, `<a>` for navigation
- Keep components SSR-first; hydrate only when necessary
- Use CSS variables or consistent spacing scale
- Ensure all buttons/inputs have visible focus states
- Pair colors with icons and descriptive text
- Test on actual mobile devices regularly

## Resources

- [Astro Documentation](https://docs.astro.build/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Contrast Checker](https://webaim.org/contrast/)
- [MDN Web Docs](https://developer.mozilla.org/)
- [Accessibility Tree](https://www.a11yproject.com/articles/) (A11y Project)
