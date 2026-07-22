# Synomize Compiler Architecture

Synomize uses a 12-tier compiler architecture that transforms human-facing VR tiles into deterministic, language-specific source code.

## Pipeline

1. Human-facing tiles
2. Language template packs
3. Template versioning
4. Marketplace rules
5. Template safety contract
6. Placeholder schema
7. Tile definition schema
8. IR operation schema
9. IR graph structure
10. IR type system
11. IR-to-template binding
12. Final code assembly

## Current language targets

- Python
- GDScript
- JavaScript
- C#

## Core principle

The tile graph is converted into typed, language-agnostic IR. Each target language supplies deterministic templates for supported operations. The backend binds typed IR values into those templates, preserves execution order, validates capabilities and safety constraints, and emits a complete source file.

## Canonical source

The master specification overview PDF should be stored in this directory as `Synomize_Master_Specification_Overview.pdf`.
