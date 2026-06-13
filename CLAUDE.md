# Education — Math & Science Lab

Interactive single-page lessons for 6th–12th grade, deployed as static HTML via Cloudflare Workers.

## Project layout

```
_template.html              ← starting point for every new lesson (NOT web-visible)
CLAUDE.md                   ← this file (NOT web-visible)
style-demo.html             ← live theme comparison page (NOT web-visible)
sample-a/b/c.html           ← per-theme reference pages (NOT web-visible)
wrangler.jsonc              ← Cloudflare Workers config
src/
  worker.js                 ← Worker entry point; routes all traffic to public/
public/                     ← ONLY files here are served at gyanzoo.com
  index.html                ← landing page (lesson card grid)
  <subject>/<slug>.html     ← individual lesson pages
surface-area/               ← Python source scripts (NOT web-visible)
```

Subject folders inside `public/`: `statistics/`, `linear-equation/`, `surface-area/`

---

## Visual theme system

Every lesson page ships with **three built-in visual themes** that the user can switch on the fly via a sticky picker bar at the top of each page. The choice is saved in `localStorage` and applies across all lessons.

| Key | Name | Font | Feel |
|-----|------|------|------|
| `a` | Focused Explorer | Plus Jakarta Sans | Clean, white cards, Desmos-like |
| `b` | Dark Academy | Inter | Deep navy, amber accents, monospace details |
| `c` | Notebook Energy | Nunito | Warm amber gradient, frosted-glass cards |

**How it works:** each theme is a `body.theme-a / .theme-b / .theme-c` CSS class that sets a palette of custom properties (`--accent`, `--surface`, `--radius`, `--font`, etc.). A small JS snippet in the `<script>` block switches the class and persists the choice.

**Rules:**
- Never remove the three `body.theme-*` token blocks from the `<style>`.
- Never remove the theme switcher JS or the `.top-bar` HTML.
- Do not simplify or collapse the theme CSS — each block must stay independent.

---

## Creating a new lesson page

1. **Copy `_template.html`** into the right subject folder inside `public/`:
   ```
   cp _template.html public/<subject>/<slug>.html
   ```
   Naming: lowercase, hyphen-separated, descriptive (`mean-vs-median.html`).

2. **Set the subject accent for Theme A** — inside `body.theme-a { }` at the top of `<style>`, change:
   ```css
   --accent:      #1d6fa4;   /* ← replace with subject colour */
   --accent-soft: #deeef9;   /* ← replace with subject soft tint */
   ```
   Use the subject palette table below. Themes B and C keep their own fixed colours — do not touch their `--accent`.

3. **Fill in the HTML placeholders:**
   - `<title>` and `<meta name="description">`
   - `.hero-badge` text (subject + grade)
   - `<h1>` and hero `<p>`
   - The `<main class="wrap">` lesson cards (see card structure comments in template)
   - The `<script>` lesson logic and GA event slug

4. **Never remove the Google Analytics block** (`G-C19PRJPV7K`). It is already present in `_template.html` and must appear in every lesson page.

5. **Add a card to `public/index.html`** in the matching `<section>`:
   - Add a new `<a class="card">` element (or replace a placeholder if one exists).
   - Include a thumbnail `<svg viewBox="0 0 320 180">` that previews the concept visually.
   - Provide `card-label`, `card-title`, `card-desc`, and `card-arrow` elements.
   - `href` is relative from `public/` root (e.g. `statistics/mean-vs-median.html`).
   - If this is the first lesson for a subject with no section yet, add the full `<section>` block for that subject (copy the pattern from an existing section).

6. **Add a row to the lesson index** table below.

---

## Lesson index

**Keep this table up to date.** Add a row every time a new lesson page is created.

| Subject | Title | File | Grade |
|---------|-------|------|-------|
| Statistics & Data | Jump Rope & the IQR | `public/statistics/iqr-jump-rope.html` | 6–7 |
| Linear Equations | Linear Equations Lab | `public/linear-equation/index.html` | 7 |
| Linear Equations | Variables, Expressions & Equations | `public/linear-equation/variables-expressions-equations.html` | 6 |
| Proportions & Ratios | Rates & Proportional Relationships | `public/proportions-ratios/rates-proportional-relationships.html` | 7 |
| Proportions & Ratios | Percentage Basics | `public/proportions-ratios/percentage-basics.html` | 6 |
| Geometry | Box Net & Surface Area | `public/surface-area/surface_area.html` | 6 |
| Geometry | Cube Net Explorer | `public/surface-area/open-net.html` | 6 |

---

## Subject colour palette

These colours apply to **Theme A (Focused Explorer)** only. Set them as `--accent` / `--accent-soft` inside `body.theme-a { }` in the lesson's `<style>` block. Themes B and C use fixed colours regardless of subject.

| Subject              | `--accent`  | `--accent-soft` |
|----------------------|-------------|-----------------|
| Statistics & Data    | `#1d6fa4`   | `#deeef9`       |
| Linear Equations     | `#c85b1b`   | `#fce8db`       |
| Geometry             | `#1a8a5e`   | `#d3f0e5`       |
| Proportions & Ratios | `#7b38c4`   | `#ede0f9`       |
| Number Sense         | `#b5811a`   | `#fdf0d0`       |
| Science              | `#c42a5c`   | `#fcdde9`       |

---

## Lesson page design principles

- **Self-contained** — one `.html` file, no external JS libraries, no build step.
- **Interactive** — every lesson should have at least one manipulable element (slider, input, button) that changes the visual output.
- **Story-first** — ground the concept in a relatable scenario (sports, cooking, money, etc.) before introducing the formula.
- **Step-by-step reveal** — show the formula derivation one step at a time, ideally reactive to the interactive element.
- **Mobile-friendly** — use `clamp()` for font sizes, `flex-wrap`, and touch events alongside mouse events.
- **Back link** — the template's `.back-link` points to `../index.html`; adjust the depth if a lesson is nested deeper than one level.
- **Card structure** — wrap each content section in a `.card` div with a `.card-head` (icon + title + chip). See template comments for copy-paste patterns (story, callout, sliders, steps, insight).

## GA event convention

Fire a custom event when the student completes the primary interaction:

```js
gtag('event', 'lesson_complete', { lesson: 'iqr-jump-rope' });
```

Use the lesson's filename slug (without `.html`) as the `lesson` value.

---

## Deployment

Push to `main` — Cloudflare Workers picks it up automatically via `wrangler.jsonc`.
