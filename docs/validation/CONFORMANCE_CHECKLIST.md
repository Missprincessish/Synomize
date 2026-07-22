# Synomize Conformance Checklist

## Tier 1: Tile Templates
- [ ] Every built-in tile has a deterministic template ID
- [ ] Placeholder names match the IR mapping
- [ ] Unsupported operations fail explicitly

## Tier 2: Language Templates
- [ ] Python pack complete
- [ ] GDScript pack complete
- [ ] JavaScript pack complete
- [ ] C# pack complete
- [ ] All packs share the same Tier 1 template IDs

## Tiers 3-5: Versioning, Marketplace, Safety
- [ ] Version selection uses IR metadata
- [ ] Missing versions fail without fallback
- [ ] Capability declarations are enforced
- [ ] Unsafe output patterns are rejected
- [ ] Published versions are immutable

## Tiers 6-10: Schema, IR, Graph, Types
- [ ] Placeholder schema validates required types
- [ ] Tile definitions map deterministically to IR
- [ ] All IR nodes conform to supported operations
- [ ] Graph validation rejects cycles unless recursive
- [ ] Type validation rejects implicit conversions

## Tiers 11-12: Binding and Assembly
- [ ] Every placeholder is fully bound
- [ ] Output order matches IR order
- [ ] Imports are deterministic and deduplicated
- [ ] Indentation and block structure are valid
- [ ] No template, placeholder, or IR leakage remains
- [ ] Final file passes target-language syntax validation

## Required proof milestone
- [ ] One tile graph emits valid Python
- [ ] Same graph emits valid GDScript
- [ ] Same graph emits valid JavaScript
- [ ] Same graph emits valid C#
- [ ] All four outputs produce equivalent behavior
