# SIGNAL SMASH — Project Context

## Overview
SIGNAL SMASH is a 3D crew-based party-fighter where WISP technicians and engineers battle using real networking knowledge as their weapon. Built in Godot 4 for the WISPA/WISPMX/ABRINT communities.

## Tech Stack
- **Engine:** Godot 4.x
- **Language:** GDScript
- **3D Modeling:** Blender (low-poly)
- **Audio:** AI-generated music + procedural SFX

## Art Style
- Low-poly 3D with flat shading
- 8-segment cylinders, geometric shapes
- Per-city color palettes
- NOC dashboard aesthetic for UI
- Reference: Totally Accurate Battle Simulator meets Smash Bros

## Design Documents
- Game Brief: `~/_bmad-output/game-brief.md`
- GDD: `~/_bmad-output/gdd.md`
- Epics: `~/_bmad-output/epics.md`
- Brainstorming: `~/_bmad-output/brainstorming-session-2026-03-21.md`
- Art Reference: `~/_bmad-output/art-style-reference.md`

## Architecture Conventions
- **File naming:** snake_case for all files and variables
- **Class names:** PascalCase with `class_name` declarations
- **Scene structure:** One .tscn + one .gd per scene
- **Project structure:**
  - `scenes/` — All .tscn scene files organized by type
  - `scripts/` — Shared/core GDScript files
  - `resources/` — Godot Resource files (.tres)
  - `data/` — JSON data files (vendors, characters, localization)
  - `assets/` — Models (.glb), audio, fonts

## Core Pillars
1. **Fellowship** — Everything serves the crew (highest priority)
2. **Knowledge is Power** — Real networking concepts = game mechanics
3. **Conference Energy** — Built for live events

## Characters
- Rico (Cable Specialist) — Blue/Yellow
- Ing. Vero (Spectrum Engineer) — Purple/Cyan
- Don Aurelio (Old School Veteran) — Brown/Amber
- MorXel (Reality Hacker) — Green/Matrix Green
