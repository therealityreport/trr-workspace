# Flashback: Timeline Quiz Game — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a "Flashback" timeline placement quiz game for the TRR hub, where players drag 8 reality TV moment cards onto a vertical chronological timeline, earning 2–5 points per correct placement.

**Architecture:** Next.js App Router pages under `/flashback` following the existing bravodle/realitease pattern. Supabase for all data (quiz content + game sessions + stats). Firebase Auth for player identity only. `@dnd-kit/core` for accessible drag-and-drop. Pure CSS animations (no Framer Motion) matching the existing TRR animation approach.

**Tech Stack:** Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS 4, Supabase (Postgres + client SDK), Firebase Auth, @dnd-kit/core + @dnd-kit/sortable, CSS transitions/keyframes

---

## Reference: Existing Patterns to Follow

These files define the patterns every task below must match:

| Pattern | Reference File |
|---|---|
| Cover page | `TRR-APP/apps/web/src/app/bravodle/cover/page.tsx` |
| Auth guard layout | `TRR-APP/apps/web/src/app/bravodle/layout.tsx` |
| Root redirect | `TRR-APP/apps/web/src/app/bravodle/page.tsx` |
| Game registry | `TRR-APP/apps/web/src/lib/admin/games.ts` |
| Admin games hub | `TRR-APP/apps/web/src/app/admin/games/page.tsx` |
| Shared header | `TRR-APP/apps/web/src/components/GameHeader.tsx` |
| Type definitions | `TRR-APP/apps/web/src/lib/bravodle/types.ts` |
| Manager singleton | `TRR-APP/apps/web/src/lib/bravodle/manager.ts` |
| Play page | `TRR-APP/apps/web/src/app/bravodle/play/page.tsx` |
| CSS animations | `TRR-APP/apps/web/src/styles/components.css` |

---

## Visual Design Spec

### Color Palette
| Token | Value | Usage |
|---|---|---|
| `--fb-bg` | `#E8E0D0` | Page background (warm beige) |
| `--fb-card` | `#FFFFFF` | Card background |
| `--fb-card-shadow` | `rgba(0,0,0,0.08)` | Card resting shadow |
| `--fb-card-drag-shadow` | `rgba(0,0,0,0.18)` | Card while dragging |
| `--fb-accent` | `#6B6BA0` | CTA buttons, progress current segment |
| `--fb-correct` | `#4A9E6F` | Correct year badge, progress green |
| `--fb-incorrect` | `#D4564A` | Incorrect flash, progress red |
| `--fb-confirm-border` | `#D4A843` | Yellow/gold border when placed but unconfirmed |
| `--fb-timeline` | `#C4BCB0` | Timeline vertical line |
| `--fb-text` | `#3D3D3D` | Primary text |
| `--fb-text-muted` | `#8A8478` | Secondary text (BEFORE/AFTER labels) |

### Typography
- Title: Serif (Georgia or system serif), ~28px
- Card text: Sans-serif (system), ~14px, line-height 1.4
- Year badge: Sans-serif bold, ~13px, white on green/red pill
- Point value: Sans-serif, ~12px, muted

### Animation Timing
| Animation | Duration | Easing |
|---|---|---|
| Card slide-in (new round) | 300ms | ease-out |
| Card drag lift (scale + shadow) | 150ms | ease-out |
| Drop zone expand | 200ms | ease-in-out |
| Confirm → year badge appear | 400ms | ease-out (fade + scale) |
| Incorrect → slide to correct position | 500ms | ease-in-out |
| Incorrect flash (red) | 200ms | linear |
| Score counter increment | 300ms | ease-out |
| Progress bar segment fill | 250ms | ease-out |
| Next round pause | 600ms | — |

---

## Task 1: Supabase Schema — Quiz Content Tables

**Files:**
- Create: `TRR-APP/apps/web/db/migrations/XXXXXX_create_flashback_tables.sql`

**Step 1: Write the migration SQL**

```sql
-- Flashback game tables
-- Quiz content (admin-managed), game sessions, and user stats

-- Weekly quiz definitions
CREATE TABLE IF NOT EXISTS public.flashback_quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  publish_date DATE NOT NULL UNIQUE,
  description TEXT,
  is_published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Events within each quiz (8 per quiz)
CREATE TABLE IF NOT EXISTS public.flashback_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID NOT NULL REFERENCES public.flashback_quizzes(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  image_url TEXT,
  year INTEGER NOT NULL,
  sort_order INTEGER NOT NULL,
  point_value INTEGER NOT NULL DEFAULT 3 CHECK (point_value BETWEEN 2 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (quiz_id, sort_order)
);

-- Player game sessions
CREATE TABLE IF NOT EXISTS public.flashback_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  quiz_id UUID NOT NULL REFERENCES public.flashback_quizzes(id),
  current_round INTEGER NOT NULL DEFAULT 0,
  score INTEGER NOT NULL DEFAULT 0,
  placements JSONB NOT NULL DEFAULT '[]'::jsonb,
  completed BOOLEAN NOT NULL DEFAULT false,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE (user_id, quiz_id)
);

-- Aggregated user stats
CREATE TABLE IF NOT EXISTS public.flashback_user_stats (
  user_id TEXT PRIMARY KEY,
  games_played INTEGER NOT NULL DEFAULT 0,
  total_points INTEGER NOT NULL DEFAULT 0,
  perfect_scores INTEGER NOT NULL DEFAULT 0,
  current_streak INTEGER NOT NULL DEFAULT 0,
  max_streak INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_flashback_events_quiz ON public.flashback_events(quiz_id);
CREATE INDEX idx_flashback_sessions_user ON public.flashback_sessions(user_id);
CREATE INDEX idx_flashback_sessions_quiz ON public.flashback_sessions(quiz_id);
CREATE INDEX idx_flashback_quizzes_publish ON public.flashback_quizzes(publish_date);

-- RLS policies
ALTER TABLE public.flashback_quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashback_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashback_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashback_user_stats ENABLE ROW LEVEL SECURITY;

-- Public read for published quizzes
CREATE POLICY "Published quizzes are viewable by all"
  ON public.flashback_quizzes FOR SELECT
  USING (is_published = true);

-- Public read for events of published quizzes
CREATE POLICY "Events of published quizzes are viewable"
  ON public.flashback_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.flashback_quizzes q
      WHERE q.id = flashback_events.quiz_id AND q.is_published = true
    )
  );

-- Users can read/write their own sessions
CREATE POLICY "Users manage own sessions"
  ON public.flashback_sessions FOR ALL
  USING (auth.uid()::text = user_id);

-- Users can read/write their own stats
CREATE POLICY "Users manage own stats"
  ON public.flashback_user_stats FOR ALL
  USING (auth.uid()::text = user_id);
```

**Step 2: Apply migration via Supabase MCP**

Run: `mcp__supabase__apply_migration` with the SQL above.
Expected: Migration applies successfully.

**Step 3: Commit**

```bash
git add db/migrations/
git commit -m "feat(flashback): add Supabase schema for quizzes, events, sessions, stats"
```

---

## Task 2: TypeScript Types & Supabase Client Helpers

**Files:**
- Create: `TRR-APP/apps/web/src/lib/flashback/types.ts`
- Create: `TRR-APP/apps/web/src/lib/flashback/supabase.ts`

**Step 1: Define TypeScript types**

```typescript
// types.ts

/** A weekly Flashback quiz */
export interface FlashbackQuiz {
  id: string;
  title: string;
  publish_date: string; // ISO date string YYYY-MM-DD
  description: string | null;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

/** A single event within a quiz */
export interface FlashbackEvent {
  id: string;
  quiz_id: string;
  description: string;
  image_url: string | null;
  year: number;
  sort_order: number; // 1-8, chronological order (1 = earliest)
  point_value: number; // 2-5
}

/** A single placement the player made */
export interface FlashbackPlacement {
  event_id: string;
  placed_position: number; // where the player put it (0-indexed in timeline)
  correct_position: number; // where it should be
  is_correct: boolean;
  points_earned: number;
  round: number; // 1-8
}

/** Player's active game session */
export interface FlashbackSession {
  id: string;
  user_id: string;
  quiz_id: string;
  current_round: number; // 0 = not started, 1-8 = active, 9 = complete
  score: number;
  placements: FlashbackPlacement[];
  completed: boolean;
  started_at: string;
  completed_at: string | null;
}

/** Aggregated user stats */
export interface FlashbackUserStats {
  user_id: string;
  games_played: number;
  total_points: number;
  perfect_scores: number;
  current_streak: number;
  max_streak: number;
}

/** The runtime game state used by the play page */
export interface FlashbackGameState {
  quiz: FlashbackQuiz;
  events: FlashbackEvent[]; // all 8 events, sorted by sort_order
  session: FlashbackSession;
  stats: FlashbackUserStats | null;
}

/** Presentation order for dealing cards to the player.
 *  This is NOT chronological — it's the shuffled order events are revealed. */
export type DealOrder = number[]; // indices into the events array

/** A placed card on the timeline (UI state) */
export interface TimelineCard {
  event: FlashbackEvent;
  yearRevealed: boolean;
  isCorrect: boolean | null; // null = unconfirmed
}
```

**Step 2: Write Supabase client helpers**

```typescript
// supabase.ts
import { createClient } from "@/lib/supabase/client";
import type {
  FlashbackQuiz,
  FlashbackEvent,
  FlashbackSession,
  FlashbackUserStats,
  FlashbackPlacement,
} from "./types";

const supabase = () => createClient();

/** Get today's published quiz */
export async function getTodaysQuiz(): Promise<FlashbackQuiz | null> {
  const today = new Date().toISOString().split("T")[0];
  const { data, error } = await supabase()
    .from("flashback_quizzes")
    .select("*")
    .eq("publish_date", today)
    .eq("is_published", true)
    .single();
  if (error || !data) return null;
  return data as FlashbackQuiz;
}

/** Get events for a quiz (sorted by sort_order — chronological) */
export async function getQuizEvents(
  quizId: string,
): Promise<FlashbackEvent[]> {
  const { data, error } = await supabase()
    .from("flashback_events")
    .select("*")
    .eq("quiz_id", quizId)
    .order("sort_order", { ascending: true });
  if (error || !data) return [];
  return data as FlashbackEvent[];
}

/** Get or create a session for the current user + quiz */
export async function getOrCreateSession(
  userId: string,
  quizId: string,
): Promise<FlashbackSession> {
  // Try to find existing
  const { data: existing } = await supabase()
    .from("flashback_sessions")
    .select("*")
    .eq("user_id", userId)
    .eq("quiz_id", quizId)
    .single();
  if (existing) return existing as FlashbackSession;

  // Create new
  const { data: created, error } = await supabase()
    .from("flashback_sessions")
    .insert({ user_id: userId, quiz_id: quizId })
    .select()
    .single();
  if (error || !created) throw new Error("Failed to create session");
  return created as FlashbackSession;
}

/** Save a placement and advance the round */
export async function savePlacement(
  sessionId: string,
  placement: FlashbackPlacement,
  newScore: number,
  newRound: number,
  completed: boolean,
): Promise<void> {
  const { data: session } = await supabase()
    .from("flashback_sessions")
    .select("placements")
    .eq("id", sessionId)
    .single();

  const placements = [
    ...((session?.placements as FlashbackPlacement[]) ?? []),
    placement,
  ];

  await supabase()
    .from("flashback_sessions")
    .update({
      placements,
      score: newScore,
      current_round: newRound,
      completed,
      ...(completed ? { completed_at: new Date().toISOString() } : {}),
    })
    .eq("id", sessionId);
}

/** Update user stats after game completion */
export async function updateUserStats(
  userId: string,
  pointsEarned: number,
  isPerfect: boolean,
): Promise<void> {
  const { data: existing } = await supabase()
    .from("flashback_user_stats")
    .select("*")
    .eq("user_id", userId)
    .single();

  if (existing) {
    const stats = existing as FlashbackUserStats;
    await supabase()
      .from("flashback_user_stats")
      .update({
        games_played: stats.games_played + 1,
        total_points: stats.total_points + pointsEarned,
        perfect_scores: stats.perfect_scores + (isPerfect ? 1 : 0),
        current_streak: stats.current_streak + 1,
        max_streak: Math.max(stats.max_streak, stats.current_streak + 1),
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);
  } else {
    await supabase()
      .from("flashback_user_stats")
      .insert({
        user_id: userId,
        games_played: 1,
        total_points: pointsEarned,
        perfect_scores: isPerfect ? 1 : 0,
        current_streak: 1,
        max_streak: 1,
      });
  }
}

/** Get user stats */
export async function getUserStats(
  userId: string,
): Promise<FlashbackUserStats | null> {
  const { data } = await supabase()
    .from("flashback_user_stats")
    .select("*")
    .eq("user_id", userId)
    .single();
  return (data as FlashbackUserStats) ?? null;
}
```

**Step 3: Commit**

```bash
git add src/lib/flashback/
git commit -m "feat(flashback): add TypeScript types and Supabase client helpers"
```

---

## Task 3: Game Manager Hook

**Files:**
- Create: `TRR-APP/apps/web/src/lib/flashback/manager.ts`
- Create: `TRR-APP/apps/web/src/lib/flashback/deal-order.ts`

**Step 1: Write the deal-order utility**

The deal order determines which events are shown in which round. The first event placed is the "anchor" (already on the timeline when the game starts). The remaining 7 are shuffled for the player to place.

```typescript
// deal-order.ts

/**
 * Generate a deterministic deal order for a quiz.
 * The anchor event (shown pre-placed on timeline) is chosen
 * near the middle of the chronological list to give the player
 * context in both directions.
 *
 * Returns: { anchorIndex: number, dealOrder: number[] }
 * where dealOrder is the shuffled indices of the 7 non-anchor events.
 */
export function generateDealOrder(
  eventCount: number,
  seed: string,
): { anchorIndex: number; dealOrder: number[] } {
  // Anchor is roughly middle (index 3 or 4 for 8 events)
  const anchorIndex = Math.floor(eventCount / 2);

  // Collect non-anchor indices
  const remaining = Array.from({ length: eventCount }, (_, i) => i).filter(
    (i) => i !== anchorIndex,
  );

  // Seeded shuffle (Fisher-Yates with simple hash)
  const hash = simpleHash(seed);
  let h = hash;
  for (let i = remaining.length - 1; i > 0; i--) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    const j = h % (i + 1);
    [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
  }

  return { anchorIndex, dealOrder: remaining };
}

function simpleHash(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  return Math.abs(hash);
}
```

**Step 2: Write the game manager hook**

```typescript
// manager.ts
"use client";

import { useState, useCallback, useRef } from "react";
import type {
  FlashbackGameState,
  FlashbackPlacement,
  TimelineCard,
  FlashbackEvent,
} from "./types";
import {
  getTodaysQuiz,
  getQuizEvents,
  getOrCreateSession,
  savePlacement,
  updateUserStats,
  getUserStats,
} from "./supabase";
import { generateDealOrder } from "./deal-order";

export type GamePhase =
  | "loading"
  | "ready" // cover screen, quiz loaded
  | "playing" // active round
  | "confirming" // card placed, awaiting tap-to-place
  | "revealing" // showing correct/incorrect feedback
  | "completed"; // all 8 rounds done

export interface FlashbackManager {
  phase: GamePhase;
  gameState: FlashbackGameState | null;
  timeline: TimelineCard[];
  currentCard: FlashbackEvent | null;
  currentRound: number; // 1-8
  score: number;
  roundResults: ("correct" | "incorrect" | "pending" | "current")[];
  pendingPosition: number | null; // where card is placed but unconfirmed
  error: string | null;

  // Actions
  bootstrap: (userId: string) => Promise<void>;
  startGame: () => void;
  placeCard: (position: number) => void;
  repositionCard: (newPosition: number) => void;
  confirmPlacement: () => Promise<void>;
}

export function useFlashbackManager(): FlashbackManager {
  const [phase, setPhase] = useState<GamePhase>("loading");
  const [gameState, setGameState] = useState<FlashbackGameState | null>(null);
  const [timeline, setTimeline] = useState<TimelineCard[]>([]);
  const [currentRound, setCurrentRound] = useState(0);
  const [score, setScore] = useState(0);
  const [roundResults, setRoundResults] = useState<
    ("correct" | "incorrect" | "pending" | "current")[]
  >([]);
  const [pendingPosition, setPendingPosition] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const dealOrderRef = useRef<{
    anchorIndex: number;
    dealOrder: number[];
  } | null>(null);
  const userIdRef = useRef<string>("");

  const getCurrentCard = useCallback((): FlashbackEvent | null => {
    if (!gameState || !dealOrderRef.current) return null;
    if (currentRound < 1 || currentRound > dealOrderRef.current.dealOrder.length)
      return null;
    const eventIndex = dealOrderRef.current.dealOrder[currentRound - 1];
    return gameState.events[eventIndex];
  }, [gameState, currentRound]);

  const bootstrap = useCallback(async (userId: string) => {
    try {
      userIdRef.current = userId;
      const quiz = await getTodaysQuiz();
      if (!quiz) {
        setError("No quiz available today");
        setPhase("loading");
        return;
      }
      const events = await getQuizEvents(quiz.id);
      if (events.length < 2) {
        setError("Quiz has insufficient events");
        return;
      }
      const session = await getOrCreateSession(userId, quiz.id);
      const stats = await getUserStats(userId);

      const state: FlashbackGameState = { quiz, events, session, stats };
      setGameState(state);

      // Generate deal order (seeded by quiz id + user id for consistency)
      const deal = generateDealOrder(events.length, quiz.id + userId);
      dealOrderRef.current = deal;

      // Restore state if session is in progress
      if (session.completed) {
        // Rebuild timeline from placements
        const placed = rebuildTimeline(events, session.placements, deal.anchorIndex);
        setTimeline(placed);
        setScore(session.score);
        setCurrentRound(events.length);
        setRoundResults(
          session.placements.map((p) =>
            p.is_correct ? "correct" : "incorrect",
          ),
        );
        setPhase("completed");
      } else if (session.current_round > 0) {
        // Resume in-progress game
        const placed = rebuildTimeline(
          events,
          session.placements,
          deal.anchorIndex,
        );
        setTimeline(placed);
        setScore(session.score);
        setCurrentRound(session.current_round);
        setRoundResults([
          ...session.placements.map((p: FlashbackPlacement) =>
            p.is_correct ? "correct" as const : "incorrect" as const,
          ),
          "current" as const,
          ...Array(
            deal.dealOrder.length - session.current_round,
          ).fill("pending" as const),
        ]);
        setPhase("playing");
      } else {
        setPhase("ready");
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load game");
    }
  }, []);

  const startGame = useCallback(() => {
    if (!gameState || !dealOrderRef.current) return;
    const { anchorIndex } = dealOrderRef.current;
    const anchorEvent = gameState.events[anchorIndex];

    // Place anchor on timeline
    setTimeline([
      {
        event: anchorEvent,
        yearRevealed: true,
        isCorrect: true,
      },
    ]);
    setCurrentRound(1);
    setRoundResults([
      "current",
      ...Array(dealOrderRef.current.dealOrder.length - 1).fill("pending"),
    ]);
    setPhase("playing");
  }, [gameState]);

  const placeCard = useCallback((position: number) => {
    setPendingPosition(position);
    setPhase("confirming");
  }, []);

  const repositionCard = useCallback((newPosition: number) => {
    setPendingPosition(newPosition);
  }, []);

  const confirmPlacement = useCallback(async () => {
    if (!gameState || !dealOrderRef.current || pendingPosition === null) return;

    const card = getCurrentCard();
    if (!card) return;

    // Determine correct position in current timeline
    const correctPos = findCorrectPosition(timeline, card);
    const isCorrect = pendingPosition === correctPos;
    const pointsEarned = isCorrect ? card.point_value : 0;
    const newScore = score + pointsEarned;

    const placement: FlashbackPlacement = {
      event_id: card.id,
      placed_position: pendingPosition,
      correct_position: correctPos,
      is_correct: isCorrect,
      points_earned: pointsEarned,
      round: currentRound,
    };

    // Update round results
    const newResults = [...roundResults];
    newResults[currentRound - 1] = isCorrect ? "correct" : "incorrect";

    setPhase("revealing");
    setRoundResults(newResults);
    setScore(newScore);

    // Insert card into timeline at correct position (animate if wrong)
    const newCard: TimelineCard = {
      event: card,
      yearRevealed: true,
      isCorrect,
    };

    const newTimeline = [...timeline];
    newTimeline.splice(correctPos, 0, newCard);
    setTimeline(newTimeline);
    setPendingPosition(null);

    // Persist to Supabase
    const nextRound = currentRound + 1;
    const isLastRound = currentRound >= dealOrderRef.current.dealOrder.length;

    await savePlacement(
      gameState.session.id,
      placement,
      newScore,
      nextRound,
      isLastRound,
    );

    // After reveal animation delay, advance to next round
    await new Promise((resolve) => setTimeout(resolve, 1200));

    if (isLastRound) {
      const perfectScore = gameState.events.reduce(
        (sum, e) => sum + e.point_value,
        0,
      );
      await updateUserStats(
        userIdRef.current,
        newScore,
        newScore === perfectScore,
      );
      setPhase("completed");
    } else {
      setCurrentRound(nextRound);
      newResults[nextRound - 1] = "current";
      setRoundResults(newResults);
      setPhase("playing");
    }
  }, [gameState, pendingPosition, timeline, score, currentRound, roundResults, getCurrentCard]);

  return {
    phase,
    gameState,
    timeline,
    currentCard: getCurrentCard(),
    currentRound,
    score,
    roundResults,
    pendingPosition,
    error,
    bootstrap,
    startGame,
    placeCard,
    repositionCard,
    confirmPlacement,
  };
}

// --- Helpers ---

function findCorrectPosition(
  timeline: TimelineCard[],
  card: FlashbackEvent,
): number {
  for (let i = 0; i < timeline.length; i++) {
    if (card.year < timeline[i].event.year) return i;
    if (
      card.year === timeline[i].event.year &&
      card.sort_order < timeline[i].event.sort_order
    )
      return i;
  }
  return timeline.length;
}

function rebuildTimeline(
  events: FlashbackEvent[],
  placements: FlashbackPlacement[],
  anchorIndex: number,
): TimelineCard[] {
  const anchor = events[anchorIndex];
  const cards: TimelineCard[] = [
    { event: anchor, yearRevealed: true, isCorrect: true },
  ];
  for (const p of placements) {
    const event = events.find((e) => e.id === p.event_id);
    if (!event) continue;
    cards.push({ event, yearRevealed: true, isCorrect: p.is_correct });
  }
  // Sort by year for correct timeline display
  cards.sort((a, b) => a.event.year - b.event.year || a.event.sort_order - b.event.sort_order);
  return cards;
}
```

**Step 3: Commit**

```bash
git add src/lib/flashback/
git commit -m "feat(flashback): add game manager hook with deal order and state machine"
```

---

## Task 4: Game Routes — Layout, Redirect, Cover Page

**Files:**
- Create: `TRR-APP/apps/web/src/app/flashback/layout.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/page.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/cover/page.tsx`

**Step 1: Auth guard layout** (copy bravodle pattern exactly)

```typescript
// layout.tsx — follows bravodle/layout.tsx pattern
import { redirect } from "next/navigation";
import { cookies } from "next/headers";
// Import the same guard function used by bravodle
import { gameLayoutGuard } from "@/lib/games/layout-guard";

export default async function FlashbackLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const cookieStore = await cookies();
  const guardResult = await gameLayoutGuard(cookieStore);

  if (guardResult.redirect) {
    redirect(guardResult.redirect);
  }

  return <>{children}</>;
}
```

> **Note:** If `gameLayoutGuard` doesn't exist as a shared util, extract the guard logic from `bravodle/layout.tsx` into a shared function first, then use it in both bravodle and flashback layouts.

**Step 2: Root redirect**

```typescript
// page.tsx
import { redirect } from "next/navigation";
export default function FlashbackRoot() {
  redirect("/flashback/cover");
}
```

**Step 3: Cover page** (follows bravodle cover format)

```typescript
// cover/page.tsx
"use client";

import { useEffect, useState } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "@/lib/firebase/client";
import { useFlashbackManager } from "@/lib/flashback/manager";
import { GameHeader } from "@/components/GameHeader";
import { useRouter } from "next/navigation";

export default function FlashbackCover() {
  const router = useRouter();
  const manager = useFlashbackManager();
  const [userId, setUserId] = useState<string | null>(null);
  const [showHowToPlay, setShowHowToPlay] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        setUserId(user.uid);
        manager.bootstrap(user.uid);
      }
    });
    return unsub;
  }, []);

  const handleStart = () => {
    router.push("/flashback/play");
  };

  const perfectScore = manager.gameState
    ? manager.gameState.events.reduce((sum, e) => sum + e.point_value, 0)
    : 28;

  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center"
      style={{ backgroundColor: "var(--fb-bg, #E8E0D0)" }}
    >
      <div className="w-full max-w-md bg-white rounded-xl shadow-sm p-8 text-center relative">
        <GameHeader
          gameName="Flashback"
          onHelpClick={() => setShowHowToPlay(true)}
        />

        {/* Icon */}
        <div className="text-4xl mb-4">🎬</div>

        <h1
          className="text-3xl mb-1"
          style={{ fontFamily: "Georgia, serif", color: "var(--fb-text, #3D3D3D)" }}
        >
          Flashback
        </h1>
        <p className="text-sm font-medium mb-4" style={{ color: "var(--fb-text-muted)" }}>
          {manager.gameState?.quiz.title ?? "Your Weekly Reality TV Timeline Quiz"}
        </p>

        <p className="text-base mb-6" style={{ color: "var(--fb-text)" }}>
          Can you place 8 iconic reality TV moments in chronological order?
        </p>

        {manager.phase === "loading" && (
          <button
            disabled
            className="px-8 py-3 rounded-full text-white font-medium opacity-50"
            style={{ backgroundColor: "var(--fb-accent)" }}
          >
            Loading...
          </button>
        )}

        {manager.phase === "ready" && (
          <button
            onClick={handleStart}
            className="px-8 py-3 rounded-full text-white font-medium
                       hover:opacity-90 transition-opacity cursor-pointer"
            style={{ backgroundColor: "var(--fb-accent, #6B6BA0)" }}
          >
            Start the quiz &rarr;
          </button>
        )}

        {manager.phase === "completed" && (
          <div>
            <p className="text-lg font-semibold mb-2">
              {manager.score} / {perfectScore} Points
            </p>
            <button
              onClick={() => router.push("/flashback/play")}
              className="px-8 py-3 rounded-full text-white font-medium"
              style={{ backgroundColor: "var(--fb-accent)" }}
            >
              View Results
            </button>
          </div>
        )}

        {manager.phase === "playing" && (
          <button
            onClick={() => router.push("/flashback/play")}
            className="px-8 py-3 rounded-full text-white font-medium"
            style={{ backgroundColor: "var(--fb-accent)" }}
          >
            Continue &rarr;
          </button>
        )}
      </div>

      {/* How to Play Modal */}
      {showHowToPlay && (
        <HowToPlayModal onClose={() => setShowHowToPlay(false)} />
      )}
    </div>
  );
}

function HowToPlayModal({ onClose }: { onClose: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-8 max-w-sm mx-4 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-2xl leading-none cursor-pointer"
        >
          &times;
        </button>
        <h2
          className="text-2xl mb-4"
          style={{ fontFamily: "Georgia, serif" }}
        >
          How to Play Flashback
        </h2>
        <p className="mb-4" style={{ color: "var(--fb-text)" }}>
          Place each clue card onto the timeline in chronological order:
        </p>
        <ol className="list-decimal ml-6 space-y-2 text-sm mb-4">
          <li>
            Drag clues <strong>between</strong>, <strong>before</strong> or{" "}
            <strong>after</strong> other events.
          </li>
          <li>
            Arrange cards from earliest (top) to latest (bottom).
          </li>
          <li>
            Press &ldquo;<strong>Tap to place</strong>&rdquo; to confirm.
          </li>
        </ol>
        <p className="text-sm mb-4" style={{ color: "var(--fb-text)" }}>
          Incorrect clues are moved to the right location each turn.
          Correct clues receive 2 to 5 points. A perfect score is 28 points.
        </p>
        <button
          onClick={onClose}
          className="w-full py-3 rounded-full text-white font-medium cursor-pointer"
          style={{ backgroundColor: "var(--fb-accent)" }}
        >
          Got it!
        </button>
      </div>
    </div>
  );
}
```

**Step 4: Commit**

```bash
git add src/app/flashback/
git commit -m "feat(flashback): add layout, redirect, and cover page"
```

---

## Task 5: Play Page — Timeline & Drag-and-Drop UI

**Files:**
- Create: `TRR-APP/apps/web/src/app/flashback/play/page.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/timeline.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/clue-card.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/progress-bar.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/drop-zone.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/year-badge.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/completed-view.tsx`

> **Important:** Install `@dnd-kit/core` and `@dnd-kit/sortable` first:
> ```bash
> cd TRR-APP && npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities
> ```

**Step 1: Build the ProgressBar component**

```typescript
// progress-bar.tsx
"use client";

interface ProgressBarProps {
  currentRound: number;
  totalRounds: number;
  results: ("correct" | "incorrect" | "pending" | "current")[];
}

const SEGMENT_COLORS = {
  correct: "var(--fb-correct, #4A9E6F)",
  incorrect: "var(--fb-incorrect, #D4564A)",
  current: "var(--fb-accent, #6B6BA0)",
  pending: "#D6D0C6",
};

export function ProgressBar({
  currentRound,
  totalRounds,
  results,
}: ProgressBarProps) {
  return (
    <div className="flex items-center gap-3 w-full px-4 py-3">
      <span className="text-sm font-medium whitespace-nowrap">
        {currentRound} of {totalRounds}
      </span>
      <div className="flex gap-1 flex-1">
        {results.map((result, i) => (
          <div
            key={i}
            className="h-2 flex-1 rounded-full transition-colors duration-250"
            style={{ backgroundColor: SEGMENT_COLORS[result] }}
          />
        ))}
      </div>
    </div>
  );
}
```

**Step 2: Build the YearBadge component**

```typescript
// year-badge.tsx
"use client";

interface YearBadgeProps {
  year: number;
  isCorrect: boolean;
  animate?: boolean;
}

export function YearBadge({ year, isCorrect, animate = false }: YearBadgeProps) {
  return (
    <span
      className={`
        inline-block px-3 py-1 rounded-full text-white text-xs font-bold
        ${animate ? "animate-badge-appear" : ""}
      `}
      style={{
        backgroundColor: isCorrect
          ? "var(--fb-correct, #4A9E6F)"
          : "var(--fb-incorrect, #D4564A)",
      }}
    >
      {year}
    </span>
  );
}
```

**Step 3: Build the ClueCard component**

```typescript
// clue-card.tsx
"use client";

import { useDraggable } from "@dnd-kit/core";
import { CSS } from "@dnd-kit/utilities";
import type { FlashbackEvent } from "@/lib/flashback/types";

interface ClueCardProps {
  event: FlashbackEvent;
  isDraggable?: boolean;
  isOnTimeline?: boolean;
  isConfirming?: boolean;
  onConfirm?: () => void;
}

export function ClueCard({
  event,
  isDraggable = false,
  isOnTimeline = false,
  isConfirming = false,
  onConfirm,
}: ClueCardProps) {
  const { attributes, listeners, setNodeRef, transform, isDragging } =
    useDraggable({
      id: `clue-${event.id}`,
      disabled: !isDraggable,
      data: { event },
    });

  const style = {
    transform: CSS.Translate.toString(transform),
    zIndex: isDragging ? 100 : undefined,
    scale: isDragging ? "1.02" : "1",
    boxShadow: isDragging
      ? "0 8px 32px var(--fb-card-drag-shadow, rgba(0,0,0,0.18))"
      : "0 2px 8px var(--fb-card-shadow, rgba(0,0,0,0.08))",
    border: isConfirming
      ? "3px solid var(--fb-confirm-border, #D4A843)"
      : "1px solid transparent",
    transition: isDragging ? "none" : "all 150ms ease-out",
  };

  return (
    <div
      ref={setNodeRef}
      {...(isDraggable ? { ...attributes, ...listeners } : {})}
      className={`
        bg-white rounded-lg overflow-hidden flex gap-3 p-3
        max-w-md w-full cursor-${isDraggable ? "grab" : "default"}
        ${isDragging ? "cursor-grabbing" : ""}
      `}
      style={style}
    >
      {event.image_url && (
        <img
          src={event.image_url}
          alt=""
          className="w-16 h-16 object-cover rounded flex-shrink-0"
          draggable={false}
        />
      )}
      <div className="flex-1 min-w-0">
        <p
          className="text-sm leading-snug"
          style={{ color: "var(--fb-text, #3D3D3D)" }}
        >
          {isOnTimeline && event.description.length > 80
            ? event.description.slice(0, 80) + "\u2026"
            : event.description}
        </p>
        {!isOnTimeline && (
          <p
            className="text-xs mt-1 text-right"
            style={{ color: "var(--fb-text-muted)" }}
          >
            {event.point_value} Points
          </p>
        )}
      </div>

      {isConfirming && onConfirm && (
        <button
          onClick={onConfirm}
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2
                     px-5 py-2 rounded-full text-white text-sm font-medium
                     cursor-pointer z-10"
          style={{ backgroundColor: "var(--fb-accent)" }}
        >
          Tap to place
        </button>
      )}
    </div>
  );
}
```

**Step 4: Build the DropZone component**

```typescript
// drop-zone.tsx
"use client";

import { useDroppable } from "@dnd-kit/core";

interface DropZoneProps {
  id: string;
  position: number;
  isActive?: boolean;
}

export function DropZone({ id, position, isActive = false }: DropZoneProps) {
  const { setNodeRef, isOver } = useDroppable({
    id,
    data: { position },
  });

  return (
    <div
      ref={setNodeRef}
      className={`
        transition-all duration-200 ease-in-out
        ${isOver || isActive ? "h-20 opacity-100" : "h-4 opacity-0"}
        flex items-center justify-center
      `}
    >
      {(isOver || isActive) && (
        <div
          className="w-full max-w-md h-1 rounded-full"
          style={{
            backgroundColor: "var(--fb-accent, #6B6BA0)",
            opacity: isOver ? 1 : 0.4,
          }}
        />
      )}
    </div>
  );
}
```

**Step 5: Build the Timeline component**

```typescript
// timeline.tsx
"use client";

import type { TimelineCard as TimelineCardType } from "@/lib/flashback/types";
import { ClueCard } from "./clue-card";
import { DropZone } from "./drop-zone";
import { YearBadge } from "./year-badge";

interface TimelineProps {
  cards: TimelineCardType[];
  pendingPosition: number | null;
  pendingEvent: import("@/lib/flashback/types").FlashbackEvent | null;
  onConfirm: () => void;
  onReposition: (pos: number) => void;
  isDragging: boolean;
}

export function Timeline({
  cards,
  pendingPosition,
  pendingEvent,
  onConfirm,
  onReposition,
  isDragging,
}: TimelineProps) {
  // Build the display list: placed cards + pending card at its position
  const displayCards = [...cards];
  const hasPending = pendingPosition !== null && pendingEvent;

  return (
    <div className="relative flex flex-col items-center w-full">
      {/* BEFORE label */}
      <p
        className="text-xs font-medium tracking-wide mb-2"
        style={{ color: "var(--fb-text-muted)" }}
      >
        BEFORE
      </p>

      {/* Timeline vertical line */}
      <div className="relative w-full flex flex-col items-center">
        <div
          className="absolute left-1/2 -translate-x-1/2 top-0 bottom-0 w-px"
          style={{ backgroundColor: "var(--fb-timeline, #C4BCB0)" }}
        />

        {/* Drop zone before first card */}
        {isDragging && (
          <DropZone id="drop-0" position={0} />
        )}

        {displayCards.map((card, index) => (
          <div key={card.event.id} className="relative z-10 w-full flex flex-col items-center">
            {/* Year badge above card */}
            {card.yearRevealed && (
              <div className="mb-1">
                <YearBadge
                  year={card.event.year}
                  isCorrect={card.isCorrect ?? true}
                  animate={card.isCorrect !== null}
                />
              </div>
            )}

            {/* The card */}
            <ClueCard
              event={card.event}
              isOnTimeline
              isConfirming={false}
            />

            {/* Drop zone after this card */}
            {isDragging && (
              <DropZone id={`drop-${index + 1}`} position={index + 1} />
            )}
          </div>
        ))}

        {/* Pending card (placed but unconfirmed) */}
        {hasPending && (
          <div
            className="relative z-20 w-full flex flex-col items-center my-2"
            style={{
              order: pendingPosition,
            }}
          >
            <ClueCard
              event={pendingEvent}
              isConfirming
              onConfirm={onConfirm}
            />
            <p
              className="text-xs mt-1 font-medium"
              style={{ color: "var(--fb-text-muted)" }}
            >
              Or drag clue up or down to reposition
            </p>
          </div>
        )}
      </div>

      {/* AFTER label */}
      <p
        className="text-xs font-medium tracking-wide mt-2"
        style={{ color: "var(--fb-text-muted)" }}
      >
        AFTER
      </p>
    </div>
  );
}
```

**Step 6: Build the main Play page**

```typescript
// play/page.tsx
"use client";

import { useEffect, useState } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "@/lib/firebase/client";
import { DndContext, DragEndEvent, DragStartEvent } from "@dnd-kit/core";
import { useFlashbackManager } from "@/lib/flashback/manager";
import { ProgressBar } from "./progress-bar";
import { Timeline } from "./timeline";
import { ClueCard } from "./clue-card";
import { GameHeader } from "@/components/GameHeader";

export default function FlashbackPlay() {
  const manager = useFlashbackManager();
  const [isDragging, setIsDragging] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        manager.bootstrap(user.uid);
        if (manager.phase === "ready") {
          manager.startGame();
        }
      }
    });
    return unsub;
  }, []);

  // Start the game if we arrived here from cover
  useEffect(() => {
    if (manager.phase === "ready") {
      manager.startGame();
    }
  }, [manager.phase]);

  const handleDragStart = (_event: DragStartEvent) => {
    setIsDragging(true);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setIsDragging(false);
    const { over } = event;
    if (over?.data?.current) {
      const position = over.data.current.position as number;
      if (manager.phase === "confirming") {
        manager.repositionCard(position);
      } else {
        manager.placeCard(position);
      }
    }
  };

  if (manager.phase === "loading") {
    return (
      <div
        className="min-h-screen flex items-center justify-center"
        style={{ backgroundColor: "var(--fb-bg)" }}
      >
        <p style={{ color: "var(--fb-text-muted)" }}>Loading...</p>
      </div>
    );
  }

  if (manager.phase === "completed") {
    return <CompletedView manager={manager} />;
  }

  const totalRounds = manager.gameState
    ? manager.gameState.events.length - 1 // minus anchor
    : 7;

  return (
    <DndContext onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
      <div
        className="min-h-screen flex flex-col"
        style={{ backgroundColor: "var(--fb-bg, #E8E0D0)" }}
      >
        {/* Header bar */}
        <div className="flex items-center justify-between px-4 py-2">
          <ProgressBar
            currentRound={manager.currentRound}
            totalRounds={totalRounds}
            results={manager.roundResults}
          />
          <span className="text-sm font-bold whitespace-nowrap ml-3">
            {manager.score} Points
          </span>
        </div>

        {/* Current clue card (draggable) */}
        {manager.currentCard && manager.phase === "playing" && (
          <div className="flex flex-col items-center px-4 mb-4">
            <ClueCard event={manager.currentCard} isDraggable />
            <p
              className="text-xs mt-2 font-medium"
              style={{ color: "var(--fb-text-muted)" }}
            >
              Drag the clue onto the timeline
            </p>
          </div>
        )}

        {/* Timeline */}
        <div className="flex-1 overflow-y-auto px-4 pb-8">
          <Timeline
            cards={manager.timeline}
            pendingPosition={manager.pendingPosition}
            pendingEvent={manager.currentCard}
            onConfirm={() => manager.confirmPlacement()}
            onReposition={(pos) => manager.repositionCard(pos)}
            isDragging={isDragging}
          />
        </div>
      </div>
    </DndContext>
  );
}

function CompletedView({
  manager,
}: {
  manager: ReturnType<typeof useFlashbackManager>;
}) {
  const perfectScore = manager.gameState
    ? manager.gameState.events.reduce((sum, e) => sum + e.point_value, 0)
    : 28;
  const isPerfect = manager.score === perfectScore;

  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center p-6"
      style={{ backgroundColor: "var(--fb-bg)" }}
    >
      <div className="bg-white rounded-xl shadow-sm p-8 max-w-md w-full text-center">
        <h2
          className="text-2xl mb-2"
          style={{ fontFamily: "Georgia, serif" }}
        >
          {isPerfect ? "Perfect Score!" : "Quiz Complete!"}
        </h2>
        <p className="text-4xl font-bold mb-1">{manager.score}</p>
        <p className="text-sm mb-6" style={{ color: "var(--fb-text-muted)" }}>
          out of {perfectScore} points
        </p>

        {/* Round-by-round results */}
        <div className="flex justify-center gap-1 mb-6">
          {manager.roundResults.map((result, i) => (
            <div
              key={i}
              className="w-8 h-2 rounded-full"
              style={{
                backgroundColor:
                  result === "correct"
                    ? "var(--fb-correct)"
                    : "var(--fb-incorrect)",
              }}
            />
          ))}
        </div>

        {/* Full timeline review */}
        <div className="text-left space-y-2">
          {manager.timeline.map((card) => (
            <div
              key={card.event.id}
              className="flex items-center gap-2 text-sm"
            >
              <span
                className="inline-block px-2 py-0.5 rounded text-xs font-bold text-white"
                style={{
                  backgroundColor:
                    card.isCorrect
                      ? "var(--fb-correct)"
                      : "var(--fb-incorrect)",
                }}
              >
                {card.event.year}
              </span>
              <span className="truncate">{card.event.description}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

**Step 7: Commit**

```bash
git add src/app/flashback/play/
git commit -m "feat(flashback): add play page with timeline, drag-and-drop, and completed view"
```

---

## Task 6: CSS Animations

**Files:**
- Modify: `TRR-APP/apps/web/src/styles/components.css` (append flashback animations)

**Step 1: Add Flashback CSS custom properties and keyframes**

Append to `components.css`:

```css
/* ─── Flashback Game Animations ─── */

:root {
  --fb-bg: #E8E0D0;
  --fb-card: #FFFFFF;
  --fb-card-shadow: rgba(0, 0, 0, 0.08);
  --fb-card-drag-shadow: rgba(0, 0, 0, 0.18);
  --fb-accent: #6B6BA0;
  --fb-correct: #4A9E6F;
  --fb-incorrect: #D4564A;
  --fb-confirm-border: #D4A843;
  --fb-timeline: #C4BCB0;
  --fb-text: #3D3D3D;
  --fb-text-muted: #8A8478;
}

/* Card slide-in from top */
@keyframes fb-slide-in {
  from {
    opacity: 0;
    transform: translateY(-24px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fb-slide-in {
  animation: fb-slide-in 300ms ease-out forwards;
}

/* Year badge appear (scale + fade) */
@keyframes fb-badge-appear {
  from {
    opacity: 0;
    transform: scale(0.6);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.animate-badge-appear {
  animation: fb-badge-appear 400ms ease-out forwards;
}

/* Incorrect flash (red pulse) */
@keyframes fb-incorrect-flash {
  0% { background-color: var(--fb-card); }
  30% { background-color: rgba(212, 86, 74, 0.15); }
  100% { background-color: var(--fb-card); }
}

.animate-fb-incorrect-flash {
  animation: fb-incorrect-flash 200ms linear;
}

/* Card slide to correct position */
@keyframes fb-slide-correct {
  from {
    opacity: 0.7;
    transform: translateY(var(--fb-slide-offset, 0px));
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fb-slide-correct {
  animation: fb-slide-correct 500ms ease-in-out forwards;
}

/* Score counter pop */
@keyframes fb-score-pop {
  0% { transform: scale(1); }
  50% { transform: scale(1.2); }
  100% { transform: scale(1); }
}

.animate-fb-score-pop {
  animation: fb-score-pop 300ms ease-out;
}
```

**Step 2: Commit**

```bash
git add src/styles/components.css
git commit -m "feat(flashback): add CSS custom properties and keyframe animations"
```

---

## Task 7: Admin Page — Quiz Management

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/games.ts` (add flashback to registry)
- Create: `TRR-APP/apps/web/src/app/admin/games/flashback/page.tsx`

**Step 1: Add flashback to the game registry**

In `lib/admin/games.ts`, add `"flashback"` to the `AdminGameKey` type and add an entry to `ADMIN_GAMES`:

```typescript
// Add to AdminGameKey type:
export type AdminGameKey = "bravodle" | "realitease" | "flashback";

// Add to ADMIN_GAMES array:
{
  key: "flashback",
  name: "Flashback",
  description: "Weekly timeline quiz — place 8 reality TV moments in chronological order.",
  route: "/admin/games/flashback",
  liveRoute: "/flashback",
  color: "#6B6BA0",
}
```

**Step 2: Build the admin quiz management page**

```typescript
// admin/games/flashback/page.tsx
"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useAdminGuard } from "@/hooks/useAdminGuard";
import type { FlashbackQuiz, FlashbackEvent } from "@/lib/flashback/types";

export default function FlashbackAdmin() {
  const { isAdmin, loading: guardLoading } = useAdminGuard();
  const [quizzes, setQuizzes] = useState<FlashbackQuiz[]>([]);
  const [selectedQuiz, setSelectedQuiz] = useState<FlashbackQuiz | null>(null);
  const [events, setEvents] = useState<FlashbackEvent[]>([]);
  const [loading, setLoading] = useState(true);

  const supabase = createClient();

  useEffect(() => {
    if (!isAdmin) return;
    loadQuizzes();
  }, [isAdmin]);

  async function loadQuizzes() {
    setLoading(true);
    const { data } = await supabase
      .from("flashback_quizzes")
      .select("*")
      .order("publish_date", { ascending: false });
    setQuizzes((data as FlashbackQuiz[]) ?? []);
    setLoading(false);
  }

  async function loadEvents(quizId: string) {
    const { data } = await supabase
      .from("flashback_events")
      .select("*")
      .eq("quiz_id", quizId)
      .order("sort_order");
    setEvents((data as FlashbackEvent[]) ?? []);
  }

  async function createQuiz() {
    const title = prompt("Quiz title:");
    const publishDate = prompt("Publish date (YYYY-MM-DD):");
    if (!title || !publishDate) return;

    const { data, error } = await supabase
      .from("flashback_quizzes")
      .insert({ title, publish_date: publishDate })
      .select()
      .single();

    if (error) {
      alert("Error: " + error.message);
      return;
    }
    await loadQuizzes();
    if (data) {
      setSelectedQuiz(data as FlashbackQuiz);
      setEvents([]);
    }
  }

  async function addEvent() {
    if (!selectedQuiz) return;
    const description = prompt("Event description:");
    const year = prompt("Year:");
    const imageUrl = prompt("Image URL (optional):") || null;
    const pointValue = prompt("Point value (2-5):", "3");
    if (!description || !year) return;

    const sortOrder = events.length + 1;
    const { error } = await supabase.from("flashback_events").insert({
      quiz_id: selectedQuiz.id,
      description,
      year: parseInt(year),
      image_url: imageUrl,
      sort_order: sortOrder,
      point_value: parseInt(pointValue ?? "3"),
    });

    if (error) {
      alert("Error: " + error.message);
      return;
    }
    await loadEvents(selectedQuiz.id);
  }

  async function togglePublish(quiz: FlashbackQuiz) {
    await supabase
      .from("flashback_quizzes")
      .update({ is_published: !quiz.is_published })
      .eq("id", quiz.id);
    await loadQuizzes();
  }

  if (guardLoading || loading) {
    return <div className="p-8">Loading...</div>;
  }

  if (!isAdmin) {
    return <div className="p-8">Access denied</div>;
  }

  return (
    <div className="p-8 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Flashback Quiz Manager</h1>

      <button
        onClick={createQuiz}
        className="mb-6 px-4 py-2 bg-indigo-600 text-white rounded-lg
                   hover:bg-indigo-700 cursor-pointer"
      >
        + Create New Quiz
      </button>

      {/* Quiz list */}
      <div className="space-y-3 mb-8">
        {quizzes.map((quiz) => (
          <div
            key={quiz.id}
            className={`p-4 border rounded-lg cursor-pointer transition-colors ${
              selectedQuiz?.id === quiz.id
                ? "border-indigo-500 bg-indigo-50"
                : "border-gray-200 hover:border-gray-300"
            }`}
            onClick={() => {
              setSelectedQuiz(quiz);
              loadEvents(quiz.id);
            }}
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-medium">{quiz.title}</h3>
                <p className="text-sm text-gray-500">
                  {quiz.publish_date}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <span
                  className={`text-xs px-2 py-1 rounded ${
                    quiz.is_published
                      ? "bg-green-100 text-green-700"
                      : "bg-gray-100 text-gray-500"
                  }`}
                >
                  {quiz.is_published ? "Published" : "Draft"}
                </span>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    togglePublish(quiz);
                  }}
                  className="text-xs underline text-indigo-600 cursor-pointer"
                >
                  {quiz.is_published ? "Unpublish" : "Publish"}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Event editor */}
      {selectedQuiz && (
        <div>
          <h2 className="text-xl font-semibold mb-4">
            Events for: {selectedQuiz.title}
          </h2>

          <button
            onClick={addEvent}
            className="mb-4 px-3 py-1.5 bg-green-600 text-white text-sm
                       rounded hover:bg-green-700 cursor-pointer"
            disabled={events.length >= 8}
          >
            + Add Event ({events.length}/8)
          </button>

          <div className="space-y-2">
            {events.map((event, i) => (
              <div
                key={event.id}
                className="flex items-center gap-3 p-3 border rounded-lg"
              >
                <span className="text-sm font-mono text-gray-400 w-6">
                  {i + 1}.
                </span>
                {event.image_url && (
                  <img
                    src={event.image_url}
                    alt=""
                    className="w-10 h-10 object-cover rounded"
                  />
                )}
                <div className="flex-1">
                  <p className="text-sm">{event.description}</p>
                  <p className="text-xs text-gray-400">
                    Year: {event.year} | Points: {event.point_value}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
```

**Step 3: Commit**

```bash
git add src/lib/admin/games.ts src/app/admin/games/flashback/
git commit -m "feat(flashback): add admin quiz management page and game registry entry"
```

---

## Task 8: Hub Integration

**Files:**
- Modify: Hub page to include Flashback game card (find the hub page that lists games)

**Step 1: Locate and modify the hub game list**

Find the hub page that renders Realitease, Bravodle, etc. and add Flashback:

```typescript
// Add to the games list/grid:
{
  name: "Flashback",
  route: "/flashback",
  description: "Place reality TV moments on a timeline",
  icon: "🎬", // or a custom SVG
}
```

**Step 2: Commit**

```bash
git add src/app/hub/
git commit -m "feat(flashback): add Flashback to hub game listing"
```

---

## Task 9: Testing

**Files:**
- Create: `TRR-APP/apps/web/src/lib/flashback/__tests__/deal-order.test.ts`
- Create: `TRR-APP/apps/web/src/lib/flashback/__tests__/manager.test.ts`

**Step 1: Test deal order determinism and distribution**

```typescript
// deal-order.test.ts
import { describe, it, expect } from "vitest";
import { generateDealOrder } from "../deal-order";

describe("generateDealOrder", () => {
  it("returns anchor near the middle", () => {
    const { anchorIndex } = generateDealOrder(8, "test-seed");
    expect(anchorIndex).toBe(4); // floor(8/2)
  });

  it("returns 7 deal indices for 8 events", () => {
    const { dealOrder } = generateDealOrder(8, "test-seed");
    expect(dealOrder).toHaveLength(7);
  });

  it("does not include anchor in deal order", () => {
    const { anchorIndex, dealOrder } = generateDealOrder(8, "test-seed");
    expect(dealOrder).not.toContain(anchorIndex);
  });

  it("is deterministic for same seed", () => {
    const a = generateDealOrder(8, "quiz-abc-user-123");
    const b = generateDealOrder(8, "quiz-abc-user-123");
    expect(a.dealOrder).toEqual(b.dealOrder);
  });

  it("produces different orders for different seeds", () => {
    const a = generateDealOrder(8, "seed-1");
    const b = generateDealOrder(8, "seed-2");
    expect(a.dealOrder).not.toEqual(b.dealOrder);
  });

  it("includes all non-anchor indices", () => {
    const { anchorIndex, dealOrder } = generateDealOrder(8, "test");
    const allIndices = [...dealOrder, anchorIndex].sort((a, b) => a - b);
    expect(allIndices).toEqual([0, 1, 2, 3, 4, 5, 6, 7]);
  });
});
```

**Step 2: Run tests**

```bash
cd TRR-APP && npx vitest run src/lib/flashback/__tests__/deal-order.test.ts
```

**Step 3: Commit**

```bash
git add src/lib/flashback/__tests__/
git commit -m "test(flashback): add unit tests for deal order generation"
```

---

## Task 10: Accessibility — Tap-to-Place Mode

**Files:**
- Modify: `TRR-APP/apps/web/src/app/flashback/play/page.tsx`
- Create: `TRR-APP/apps/web/src/app/flashback/play/tap-mode-timeline.tsx`

**Step 1: Add tap mode as alternative to drag**

For users who check "Move events by tapping instead of dragging" on the cover page, render clickable drop zones instead of drag-and-drop. Each zone between timeline cards becomes a button the user can tap.

The tap mode component should:
- Render the same timeline visually
- Replace drag with: tap the clue card (highlights it), then tap a drop zone position
- Use the same `manager.placeCard(position)` and `manager.confirmPlacement()` APIs
- Wrap in `aria-live="polite"` for screen readers

**Step 2: Store tap mode preference in localStorage**

```typescript
const [tapMode, setTapMode] = useState(() => {
  if (typeof window !== "undefined") {
    return localStorage.getItem("flashback-tap-mode") === "true";
  }
  return false;
});
```

**Step 3: Commit**

```bash
git add src/app/flashback/play/
git commit -m "feat(flashback): add tap-to-place accessibility mode"
```

---

## Summary — Execution Order

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | Supabase schema migration | None |
| 2 | TypeScript types + Supabase helpers | Task 1 |
| 3 | Game manager hook + deal order | Task 2 |
| 4 | Routes: layout, redirect, cover page | Task 3 |
| 5 | Play page: timeline, drag-drop, cards | Tasks 3, 4 |
| 6 | CSS animations | None (can parallel with 2-5) |
| 7 | Admin quiz management page | Task 1 |
| 8 | Hub integration | Task 4 |
| 9 | Unit tests | Task 3 |
| 10 | Accessibility tap mode | Task 5 |

**Parallelizable:** Tasks 6+7 can run alongside Tasks 2-5. Task 9 can run alongside Task 5.

**Install step (before Task 5):**
```bash
cd TRR-APP && npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities
```
