# Halyard landing page - design brief

This brief is binding. Names, ids and values in it are the contract other
teams build against; nothing here is a suggestion.

## Files

| file | holds |
|---|---|
| `index.html` | the whole page |
| `css/tokens.css` | custom properties, and nothing else |
| `css/layout.css` | the container and the two grids |
| `css/components.css` | the pieces: skip link, buttons, plans, focus |

`index.html` links them in that order: tokens, layout, components. No other
stylesheet, no `<style>` block, no `style` attribute, no `<script>`.

## Document

- `<html lang="en">`
- `<title>Halyard - release automation</title>`
- `<meta name="description" content="...">` with a sentence of your own
- the first element inside `<body>` is
  `<a class="skip-link" href="#main">Skip to content</a>`
- then `<header class="site-header">`, then `<main id="main">`, then
  `<footer class="site-footer">`, in that order, as direct children of
  `<body>`

### Header

```
<header class="site-header">
  <div class="container site-header__inner">
    <a class="site-header__brand" href="/">Halyard</a>
    <nav class="site-nav" aria-label="Primary">
      <ul>  ...four <li> each with exactly one <a>...  </ul>
    </nav>
  </div>
</header>
```

The four navigation links, in order, point at `#features`, `#pricing`,
`#faq`, `#contact` and read `Features`, `Pricing`, `FAQ`, `Contact`.

### Main

`<main id="main">` holds five `<section>` elements, in this order, with these
ids: `hero`, `features`, `pricing`, `faq`, `contact`. Each section carries
`aria-labelledby` pointing at its own heading, whose id is the section id
plus `-title`:

| section | heading | heading id |
|---|---|---|
| `hero` | `<h1>` | `hero-title` |
| `features` | `<h2>` | `features-title` |
| `pricing` | `<h2>` | `pricing-title` |
| `faq` | `<h2>` | `faq-title` |
| `contact` | `<h2>` | `contact-title` |

The page has exactly one `<h1>`.

**hero** also holds `<p class="hero__lede">` and
`<a class="btn btn--primary" href="#contact">Start a free trial</a>`.

**features** holds `<ul class="feature-grid">` with exactly three
`<li class="feature">`, each holding `<h3 class="feature__title">` and
`<p class="feature__text">`.

**pricing** holds `<div class="plan-grid">` with exactly three
`<article class="plan">`. Exactly one of them also carries `plan--featured`.
Each plan holds `<h3 class="plan__name">`, `<p class="plan__price">`,
`<ul class="plan__features">` with at least two `<li>`, and one
`<a class="btn btn--primary">`.

**faq** holds exactly four `<details class="faq__item">`, each starting with
`<summary class="faq__q">`. None of them is `open`.

**contact** holds `<form class="contact-form" action="/trial" method="post">`
containing:

- `<label for="contact-email">` with text `Work email`
- `<input class="field__input" type="email" id="contact-email" name="email"
  required autocomplete="email" aria-describedby="contact-hint">`
- `<p class="field__hint" id="contact-hint">` with a sentence of your own
- `<button type="submit" class="btn btn--primary">Start a free trial</button>`

No control carries a `placeholder`.

### Footer

`<footer class="site-footer">` holds `<nav aria-label="Footer">` with a `<ul>`
of at least three links, and a `<p class="site-footer__legal">`.

## css/tokens.css

Nothing but `:root` blocks. The light palette, on bare `:root`:

```
--color-bg: #ffffff;
--color-surface: #f5f8fd;
--color-fg: #14181f;
--color-muted: #58616f;
--color-accent: #1a4fd6;
--color-accent-fg: #ffffff;
--color-border: #d5dce8;
--space-1: 0.25rem;
--space-2: 0.5rem;
--space-3: 1rem;
--space-4: 1.5rem;
--space-5: 2rem;
--space-6: 3rem;
--radius: 10px;
--measure: 68ch;
--container: 72rem;
```

Then, inside `@media (prefers-color-scheme: dark)`, a `:root` block that
redefines exactly these five:

```
--color-bg: #0d1117;
--color-surface: #161b22;
--color-fg: #e8edf5;
--color-muted: #9aa5b4;
--color-border: #2a323d;
```

The accent stays the same in both schemes.

## css/layout.css

- the universal border-box reset:
  `*, *::before, *::after { box-sizing: border-box; }`
- `.container` - `width: 100%`, `max-width: var(--container)`,
  `margin-inline: auto`, `padding-inline: var(--space-3)`
- `.site-header__inner` - `display: flex`, `align-items: center`,
  `justify-content: space-between`, `gap: var(--space-4)`
- `.feature-grid` - `display: grid`,
  `grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr))`,
  `gap: var(--space-4)`, `list-style: none`, `margin: 0`, `padding: 0`
- `.plan-grid` - `display: grid`, `grid-template-columns: 1fr`,
  `gap: var(--space-4)`
- inside `@media (min-width: 48rem)`, `.plan-grid` becomes
  `grid-template-columns: repeat(3, 1fr)`
- `.hero__lede` - `max-width: var(--measure)`

## css/components.css

- `.skip-link` is off screen by default (`position: absolute` and a `left`
  further than `-1000px`), and a `:focus` or `:focus-visible` rule on it
  restores a `left` that is not negative
- `.btn` - `display: inline-block`, `padding: var(--space-2) var(--space-4)`,
  `border-radius: var(--radius)`, `text-decoration: none`
- `.btn--primary` - `background: var(--color-accent)`,
  `color: var(--color-accent-fg)`
- a `:focus-visible` rule declaring a visible `outline` (not `none`, not `0`)
- `.plan--featured` - `border-color: var(--color-accent)`
- inside `@media (prefers-reduced-motion: reduce)`, a rule covering `*` that
  sets both `animation-duration` and `transition-duration` to `0.01ms`

Every colour outside `css/tokens.css` comes from a token: no hex literal may
appear in `layout.css` or `components.css`.
