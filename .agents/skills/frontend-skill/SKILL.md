---
name: frontend-skill
description: GPT-5.4 frontend execution guide for TRR. Use when building or polishing landing pages, app surfaces, or admin interfaces with a composition-first, delight-focused workflow.
---

# Frontend Skill

This skill adapts the OpenAI guidance from "Designing delightful frontends with GPT-5.4" into TRR-ready execution rules. Use it for new surface work and major visual polish passes. Keep `redesign-existing-projects` focused on retrofit audits; use this skill when you want a decisive visual direction and an implementation workflow that is already structured.

## Working Model

- Default to `gpt-5.4` with low reasoning for initial layout and direction.
- Raise to medium reasoning only for ambitious interaction systems, difficult responsive behavior, or unusually dense information architecture.
- Do not spend extra reasoning tokens on ornamental exploration. Lock the direction quickly, then execute.

## Inputs Required Before Coding

- Surface type: `landing/promotional`, `app/admin/product`, or `game`.
- `visual thesis`: one sentence describing the intended visual impression.
- `content plan`: ordered section sequence before layout work begins.
- `interaction thesis`: the small set of interactions that should feel best in use.
- Real content context: product purpose, audience, workflow, or editorial angle.
- Visual references: attached screenshots, mood boards, or approved local reference assets.
- Design constraints: one H1, section cap, two typefaces max, one accent color, one primary CTA above the fold.

## Beautiful Defaults

- Composition first, components second.
- One dominant visual move per surface.
- Sparse copy with real nouns and verbs.
- Brand presence should be obvious in the first viewport.
- Cards are allowed only when they improve comprehension or enable interaction.
- Motion is restrained and intentional: one entrance sequence, one depth/scroll move, one affordance transition.
- Avoid gradients by default. In TRR work, treat gradients as disallowed unless the user explicitly asks for one.
- Default background is white.
- Default text is black.
- Do not use drop shadows or decorative blurs as baseline styling.
- Do not introduce colors outside TRR-approved palette values; default to black, white, and one approved TRR accent.

## Landing Page Rules

- Default to a full-bleed first viewport.
- Use one dominant image or one dominant visual anchor, not a collage.
- Lead with brand, then purpose, then action.
- Keep the hero copy short and avoid stat strips, badge walls, or stacked feature cards.
- Do not put text over busy imagery.
- Avoid generic SaaS grids and interchangeable testimonial sections.

## App And Admin Rules

- No hero by default.
- Start with the working surface: search, status, controls, actions, navigation.
- Use utility copy over campaign copy.
- Every heading should orient the operator or help them act.
- Decorative sections should be removed unless they communicate state or priority.
- A dashboard cannot just be stacked white cards with empty summaries.

## Imagery Rules

- Prefer approved local assets, real product screenshots, or mood-board references captured into the repo.
- Keep stable tonal zones behind text.
- Do not fake in-image UI chrome.
- Do not use collage-style hero imagery unless the composition itself is the concept and text remains legible.

## Copy Rules

- Use plain, specific language.
- Avoid placeholder names, filler slogans, or inflated product language.
- Keep landing copy sparse.
- Keep app/admin labels operational and scannable.
- Headings must either orient, prioritize, or invite action.

## Motion Rules

- Favor transform and opacity.
- Keep motion smooth on mobile.
- Remove motion that does not clarify hierarchy, focus, or affordance.
- Prefer CSS transitions and keyframes first. Add a motion library only when the interaction warrants it.

## Build Sequence

1. Classify the surface type.
2. Write the visual thesis, content plan, and interaction thesis.
3. Lock tokens and typography roles before composing sections.
4. Gather or generate the visual references and choose one direction.
5. Build the layout composition-first.
6. Apply landing or app rules based on surface type.
7. Add only the few motions that materially help.
8. Verify at desktop and mobile widths with Playwright and screenshots.
9. Run the litmus checks before declaring the surface done.

## Litmus Checks

- Would a human designer believe this surface had a clear visual point of view?
- Does the first viewport communicate brand and purpose without extra explanation?
- Is there exactly one dominant action above the fold?
- Is the copy shorter and more specific than the first draft wanted it to be?
- Are there any default cards, hero cards, or filler stat rows that can be removed?
- For app/admin surfaces, does the page become useful before the user scrolls?

## Reject These Failures

- Generic card grids
- Weak or hidden branding
- Overwritten hero copy
- Busy imagery behind text
- Repeated sections with the same visual rhythm
- Carousels without narrative value
- App shells that are just stacked bordered panels

## TRR Notes

- Respect existing TRR brand fonts and language.
- Keep public/auth surfaces more editorial and atmospheric.
- Keep admin surfaces direct, operational, and high-signal.
- Default to a white page, black text, black borders, and one approved TRR palette accent.
- Gradients, shadows, and off-palette neutrals should be treated as rule violations unless explicitly approved.
- Document the chosen visual thesis in the repo when the work is substantial.
