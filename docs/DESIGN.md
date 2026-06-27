# DESIGN.md

# Design Philosophy

This application should feel like a friendly illustrated notebook rather than a corporate mobile app.

Imagine the UI was sketched by an artist with a black ink pen on high-quality paper.

Users should feel:

* approachable
* playful
* comforting
* creative
* handcrafted
* warm

Never make the UI look like a standard Material Design application.

---

# Overall Style

Inspired by:

* Story books
* Sketchbooks
* Hand-drawn journals
* Children's illustrations
* Cozy indie games
* Animal Crossing
* Paper Mario
* Scribblenauts
* Pokemon menus
* Moleskine notebooks

Avoid:

* Enterprise dashboards
* Glassmorphism
* Heavy gradients
* Neon cyberpunk
* Sharp rectangles
* Clinical white interfaces
* Default Material widgets

---

# Color Palette

Primary Paper

```
#FFFAF0
```

Secondary Paper

```
#FFF7E8
```

Ink

```
#222222
```

Soft Gray

```
#666666
```

Accent colors should be muted rather than saturated.

Examples:

* sage green
* warm orange
* dusty blue
* muted yellow
* soft coral

Never use pure black (#000000).

---

# Typography

Friendly rounded fonts.

Examples:

* Nunito
* Quicksand
* Fredoka
* Patrick Hand
* Kalam

Body text should always be highly readable.

Headings may be playful.

---

# Components

## Text Fields

Every text field should look hand drawn.

Characteristics:

* uneven outline
* thick ink border
* rounded corners
* paper background
* generous padding

Never use the default Flutter outlined text field.

Create a reusable widget:

```
SketchTextField
```

---

## Buttons

Buttons should resemble paper labels.

Characteristics:

* thick outline
* rounded corners
* slight shadow
* subtle rotation on press
* soft animation

Create:

```
SketchButton
```

---

## Cards

Cards resemble note cards.

Characteristics:

* paper background
* slightly irregular outline
* subtle shadow
* rounded corners

Create:

```
SketchCard
```

---

## Dialogs

Dialogs should resemble a notebook page.

Avoid Material dialogs.

---

## Checkboxes

Use rounded playful checkboxes.

Avoid square Windows-style controls.

---

## Sliders

Large thumb.

Rounded track.

Friendly interaction.

---

## Switches

Rounded.

Chunky.

Animated.

---

# Icons

Prefer:

* outlined
* hand-drawn
* rounded

Avoid:

* overly sharp icons
* enterprise iconography

---

# Animations

Everything should feel alive.

Recommended:

* gentle bounce
* slight wiggle
* breathing
* fade
* squash and stretch

Avoid:

* fast mechanical animations

Target duration:

```
150–350 ms
```

---

# Layout

Use generous spacing.

Avoid cramped layouts.

Recommended spacing scale:

```
8
12
16
24
32
48
```

---

# Corners

Nothing should be perfectly rectangular.

Recommended radius:

```
12–24 px
```

Slightly vary border radii where appropriate.

---

# Shadows

Use soft shadows.

Prefer:

```
Offset(2,2)

Blur 0–6
```

Not heavy elevation.

---

# Borders

Borders should resemble pen strokes.

Preferred:

```
2–3 px
```

Dark ink.

Slightly irregular.

Where possible, use CustomPainter to render sketch-style borders.

---

# Illustrations

Illustrations should feel:

* cute
* friendly
* expressive

Avoid:

* hyper realistic
* corporate stock art

---

# Empty States

Every empty state should include:

* illustration
* friendly message
* encouragement

Never display:

"No Data"

Instead:

"Looks like nothing lives here yet!"

---

# Error Messages

Errors should be supportive.

Instead of:

```
Invalid input
```

Use:

```
Oops! That doesn't look quite right.
Let's try again.
```

---

# Accessibility

Maintain:

* large touch targets
* readable fonts
* high contrast
* screen reader compatibility

Playful should never reduce usability.

---

# Flutter Architecture

Create reusable widgets before building screens.

Required components:

```
SketchTheme
SketchCard
SketchButton
SketchTextField
SketchDialog
SketchCheckbox
SketchSlider
SketchSwitch
SketchChip
SketchBadge
```

Feature screens should compose these widgets rather than implementing custom styles repeatedly.

---

# Agent Instructions

When generating UI:

1. Build reusable design system widgets first.
2. Never use default Material components directly.
3. Prioritize consistency over novelty.
4. If a new component is needed, add it to the design system before using it.
5. Keep every screen visually cohesive.
6. Favor warm, handcrafted aesthetics over polished corporate design.
7. Prefer composition over one-off styling.
8. When in doubt, ask: "Would this feel at home in a hand-drawn sketchbook?"

The design system is the single source of truth for the application's appearance.
