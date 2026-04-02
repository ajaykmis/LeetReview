# LeetReview Agent Handoff

## Mission
Complete the SwiftUI rewrite as a clean port of the Flutter app. Do not stop at shell views, placeholder summaries, or partially wired features. Favor real data-backed behavior over static scaffolding.

## Current Snapshot
- Base branch history is staged through `Stage 5: Review Mode + Polish`.
- The live worktree contains additional uncommitted port work beyond that history, especially a new `Features/CodeEditor/` flow plus project wiring changes.
- The current local priority regressions are:
  - Problem detail shells still need to be replaced with real data-backed sections.
  - Review queue entry points and richer profile parity are still incomplete.
- Stabilization that is now done in the worktree:
  - LeetCode code submission no longer posts the same payload as `interpret_solution`.
  - Problem description HTML now self-sizes instead of being clipped.
  - Problem detail now has a real entry point into `CodeEditorView`, backed by network-loaded problem data instead of the sample snapshot.

## Orchestrator Rules
- Before handing work to subagents, keep this file updated with the current top-level plan and active workstreams.
- Prefer checkpoint branches and small reviewable commits over one large unrecoverable session.
- Do not declare parity complete while any user-visible section still says "shell", "not wired", "placeholder", or mock-only language.
- Preserve unrelated local changes unless they directly conflict with the active task.

## Ultra Top-Level Plan
1. Stabilize the current in-flight editor/detail work so the local app builds and the obvious regressions are fixed.
2. Replace shell content in problem detail with real API-backed hints, editorial, community, and similar-question data.
3. Fully wire the code editor into the app navigation, problem snapshots, and project build settings.
4. Wire review-queue entry points from browse/detail flows so Review is reachable from real solved-problem actions.
5. Run a parity pass against the Flutter app goals and remove residual placeholder copy, mock wording, and dead-end screens.
6. Review, checkpoint, and push after each meaningful vertical slice so recovery is cheap.

## Suggested Subagent Workstreams

### Workstream A: Stabilization
- Scope: fix active regressions in the current dirty worktree.
- Goals:
  - fix submit payload / result parsing
  - fix problem description height/scroll behavior
  - wire the editor into problem detail
  - verify project compiles with the in-flight code editor files included

### Workstream B: Problem Detail Parity
- Scope: `Features/ProblemDetail/`, GraphQL hooks, related models.
- Goals:
  - replace generated hints with `question.hints`
  - replace editorial shell with `officialSolution`
  - replace community shell with `communitySolutions`
  - replace similar shell with `similarQuestions`

### Workstream C: Editor Integration
- Scope: `Features/CodeEditor/`, problem-to-editor navigation, project wiring.
- Goals:
  - create a real path from problem detail into the editor
  - build `CodeEditorProblemSnapshot` from network data
  - remove "mock" copy where the flow now uses live APIs
  - verify run/submit/result states end-to-end

### Workstream D: Review Queue Integration
- Scope: review entry points and data flow.
- Goals:
  - add "add to review" actions from problems/detail/submissions where appropriate
  - ensure Review tab can be populated from normal app usage
  - keep SM-2 storage behavior intact

### Workstream E: Final Parity / QA
- Scope: app-wide.
- Goals:
  - remove placeholder text and unfinished-shell wording
  - confirm auth, dashboard, problems, detail, submissions, editor, profile, review, settings all work as real flows
  - checkpoint and push

## Resume Protocol
- Start by reading `git status --short`, this file, and the memory note.
- If the session died mid-task, finish the active workstream before starting a new one.
- If build verification has not been run since the last change, run it before pushing.
- If a checkpoint branch exists for the current slice, continue on it rather than reopening `main`.

## Active Focus
- Stabilization is complete enough to checkpoint.
- Next focus is problem-detail parity, then review entry points, then profile parity work.
