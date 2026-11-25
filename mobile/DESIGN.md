---
version: alpha
colors:
  primary: "#C99A2E"
  secondary: "#0B132B"
  accent: "#E4B94F"
  brandGreen: "#0C8044"
  background: "#FBFAEF"
  surface: "#FFFFFF"
  darkBackground: "#0B132B"
  darkSurface: "#12233D"
typography:
  display:
    fontFamily: "Plus Jakarta Sans, Inter, sans-serif"
  body:
    fontFamily: "Plus Jakarta Sans, Inter, system-ui, sans-serif"
rounded:
  card: "12px"
  control: "8px"
spacing:
  controlHorizontal: "16px"
  controlVertical: "12px"
components:
  appBar:
    background: "transparent"
  card:
    radius: "12px"
  button:
    radius: "8px"
---

## Overview

ARKE Scholars is a focused learning product for students. It pairs a warm academic-gold action color with an assured deep-navy foundation. The official ARKE mark’s green is reserved for brand recognition and positive progress, so screens do not turn into a multicolour dashboard.

## Colors

`lib/core/theme/app_theme.dart` is the runtime token owner. Gold is used for primary actions and selected states; navy anchors headers, dark mode, and high-emphasis surfaces. Green is an official-logo and positive-status color, not a replacement primary action color. Light surfaces remain warm off-white with white cards.

## Typography

Plus Jakarta Sans is the app family, with a heavier display hierarchy and compact, readable body text. Keep labels sentence-case and avoid decorative type treatments.

## Layout

The mobile-first layout uses a 375 × 812 reference canvas. Preserve comfortable content padding, compact navigation, and stable card geometry at small widths.

## Elevation & Depth

Cards are mostly flat and separated by warm-white surfaces, subtle dividers, and restrained shadows. Do not add heavy shadows merely for decoration.

## Shapes

Cards use 12px radii; controls use 8px radii. Pills are reserved for tags, badges, and filters.

## Components

Buttons use gold for the primary commitment, navy or outline for secondary actions, and semantic green/amber/red only for success/warning/error states. Focus borders use the primary gold.

## Do's and Don'ts

Do use the source ARKE logo at its natural aspect ratio and leave clear space around it. Do preserve readable white text on navy and primary actions. Do not recolour the official logo or use the green brand mark as a generic accent throughout the UI.
