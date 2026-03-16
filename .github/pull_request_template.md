## Summary

<!-- What does this PR do and why? -->

## Changes

<!-- Key files changed and the reason for each -->

## Test plan

- [ ] `./build.sh` passes
- [ ] `./test.sh` passes (all geometry tests green, integration tests skip gracefully)
- [ ] Manually tested the affected snap actions

## Checklist

- [ ] New `WindowAction` case has a geometry test (`Tests/GeometryTests.swift`)
- [ ] CLAUDE.md keyboard shortcuts table updated (if new hotkeys added)
- [ ] PR title follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) (`feat:`, `fix:`, `docs:`, etc.)
- [ ] No coordinate conversions inlined outside `axRect(from:primaryScreenHeight:)` in `Geometry.swift`
- [ ] No SPM or Xcode project files introduced
