# Pedagogy Methods Reference

Five evidence-based approaches for structuring interactive math lessons aimed at **grades 6–12**. Each has a different theory of how learning sticks, different strengths, and different failure modes. Working examples using graphing coordinates are in `pedagogy-examples/`.

---

## 1. Explore First

**Theoretical basis:** Generation Effect / Productive Struggle  
**Best for:** Curious, on-grade students; visual and pattern-based concepts  
**Grade sweet spot:** 6th–10th  
**Working example:** `pedagogy-examples/01-explore-first.html`

### Information flow

```
Hook (story + unanswered question)
  ↓
Free exploration (interactive, no instructions yet)
  ↓
Concept name (emerges from what student just noticed)
  ↓
Worked example (applies the named concept)
  ↓
Try it (1–2 practice problems)
  ↓
Insight (real-world connection or historical note)
```

### Core idea

Students play with the interactive element **before** the concept is named. The formal definition arrives as an explanation of a pattern they already observed, not as a rule handed to them cold. Research on the generation effect shows that brains that have wrestled with a problem first retain the explanation significantly better.

### How to implement in a lesson page

1. **Hook card** — A character with an unanswered question. Two to three sentences maximum. No vocabulary words yet.
2. **Explore card** — An interactive (slider, clickable grid, draggable element) with a minimal prompt like *"Try different values — what do you notice?"* The concept name does not appear here.
3. **Concept card** — Framed as *"What you just discovered has a name."* Definition is one to two sentences. Formula or rule stated here and only here.
4. **Apply card** — Worked example using the same numbers from the hook story. Steps revealed one at a time.
5. **Try it card** — One or two problems. Framed as *"Your turn"* not *"Quiz."* Immediate step-level feedback on wrong answers.
6. **Insight card** — Historical note, GPS connection, real-world use case. Reward for finishing, not motivation at the start.

### Tradeoffs

| Strength | Weakness |
|----------|----------|
| High retention when it works | Fails for students with insufficient prior knowledge — they cannot generate anything useful |
| Concept feels earned, not imposed | Requires a well-designed interactive that reveals the pattern naturally |
| Highest engagement for on-grade students | Takes longer than direct instruction |

### Failure modes to avoid

- Putting the concept name in the explore section defeats the whole approach
- If the interactive does not naturally reveal the pattern, students are just confused, not productively struggling
- Do not put more than two practice problems — fatigue and diminishing returns kick in fast at this age

---

## 2. Direct Instruction

**Theoretical basis:** Rosenshine's Principles of Instruction; John Hattie's meta-analyses  
**Best for:** Mixed-ability classes; students who are below grade level; procedural topics  
**Grade sweet spot:** All grades, especially 6th–8th for foundational skills  
**Working example:** `pedagogy-examples/02-direct-instruction.html`

### Information flow

```
Learning objective (explicit, stated upfront)
  ↓
Vocabulary / definitions (with labeled diagram)
  ↓
The rule (stated plainly in 1–2 sentences)
  ↓
Worked examples × 3 (I do — teacher models)
  ↓
Guided practice × 2 (We do — hints available)
  ↓
Independent practice × 2 (You do — no hints)
```

### Core idea

The teacher (the page) tells students exactly what they will learn before they learn it, then models the skill explicitly multiple times, then gradually transfers responsibility. There is no ambiguity about what the lesson is about. Effect sizes in meta-analyses are consistently among the highest of any instructional approach.

### How to implement in a lesson page

1. **Objective banner** — A single sentence starting *"By the end of this lesson you will be able to…"* Shown at the very top, above everything else.
2. **Definitions card** — Key vocabulary in a grid layout. Each term gets two to three sentences. A labeled static diagram accompanies the definitions.
3. **Rule box** — The procedure stated as a numbered or bulleted list. Plain language. No story yet.
4. **Worked examples (I do)** — Three examples of increasing difficulty. Each has a Next Step button that reveals steps one at a time. Student watches; they do not interact.
5. **Guided practice (We do)** — Two problems with a *Show hint* button available. Student clicks the grid/input to answer. The hint is one sentence describing the next move.
6. **Independent practice (You do)** — Two problems with no hint button. Immediate feedback: correct/incorrect with the correct answer shown if wrong.

### Tradeoffs

| Strength | Weakness |
|----------|----------|
| Highest evidence base of any approach | Lower ceiling on genuine understanding — students can follow steps without knowing why |
| Works regardless of prior knowledge level | Less engaging for students who are already curious |
| Easiest to implement consistently | Risk of passive watching during worked examples |

### Failure modes to avoid

- Skipping the explicit learning objective removes a key scaffold
- Fewer than three worked examples is usually too few before students attempt on their own
- Jumping from worked examples directly to independent practice (skipping guided) causes a frustration spike

---

## 3. Concrete → Pictorial → Abstract (CPA)

**Theoretical basis:** Jerome Bruner's enactive-iconic-symbolic model; Singapore Math curriculum  
**Best for:** Geometry, fractions, anything with a natural physical representation  
**Grade sweet spot:** 6th–8th; works for all grades on visual/spatial topics  
**Working example:** `pedagogy-examples/03-cpa.html`

### Information flow

```
Concrete stage
  Physical or story-based manipulation
  (city streets, objects, physical counting)
  ↓  [explicit transition with connection note]
Pictorial stage
  Visual diagram that mirrors the concrete
  (coordinate grid that looks like the city map)
  ↓  [explicit transition with abstraction note]
Abstract stage
  Pure symbols — numbers, variables, formulas
  (x, y) notation and practice
```

### Core idea

Students must pass through all three stages in order. The concrete stage builds intuition using things they already understand. The pictorial stage is the bridge — it looks like a math diagram but is described in terms of the concrete. The abstract stage introduces formal notation only after the underlying meaning is anchored. Skipping stages is the most common way CPA fails.

### How to implement in a lesson page

1. **Stage progress indicator** — A visible three-tab bar showing which stage is active and which are complete. Students should always know where they are in the sequence.
2. **Concrete card** — A metaphor or story that has spatial/physical properties matching the math. For coordinates: a city map with street names. Students interact with the metaphor (place pins, count blocks) without any math symbols.
3. **Transition** — An explicit note connecting the concrete to the pictorial. *"Notice how the city map transformed into a math grid — the locations are the same."* This is not optional; it is where the learning happens.
4. **Pictorial card** — The same content, now as a mathematical diagram. The interactive mirrors what the student did in the concrete stage. Labels appear but use plain language alongside symbols.
5. **Transition** — Another explicit connection note. *"In math, we write this as (3, 2)."*
6. **Abstract card** — Pure (x, y) notation. Practice problems using only symbols, no story context.

### Tradeoffs

| Strength | Weakness |
|----------|----------|
| Very strong conceptual understanding | Requires a topic with a natural concrete representation |
| Reduces "I can do the steps but don't understand why" | Takes three times longer than direct instruction |
| Works well across ability levels | The concrete stage is easy to make feel childish for older students |

### Failure modes to avoid

- Making the concrete stage feel babyish — the city map metaphor works because it is genuinely relatable to 6th graders, not because it is simplified math
- Skipping the explicit transition explanation between stages — without it, students do not connect the three representations
- Introducing (x, y) notation in the concrete or pictorial stages defeats the entire approach

---

## 4. Three-Act Structure

**Theoretical basis:** Dan Meyer's three-act math lessons; curiosity-driven learning  
**Best for:** Disengaged students; concepts where students would benefit from wanting the tool before receiving it  
**Grade sweet spot:** 6th–9th; works especially well for 6th and 7th graders  
**Working example:** `pedagogy-examples/04-three-act.html`

### Information flow

```
Act 1 — The hook (unresolvable mystery)
  A scenario that raises a clear, answerable question.
  Critical: students cannot solve it yet because information is missing.
  ↓
Act 2 — Information gathering
  Students identify and request the information they need.
  Information is revealed incrementally, on student request.
  ↓
Act 3 — Resolution
  The question is answered using the now-available information.
  Formal definition and vocabulary introduced here.
  ↓
Practice
  Two to three problems using the formal notation just introduced.
```

### Core idea

Act 1 creates a genuine information gap — students see a problem they want to solve but cannot yet, because they are missing a tool. This makes them want the concept before they receive it. Dan Meyer's original implementation used video clips; in a web lesson, a visual mystery or game scenario works well. The key is that Act 1 must be genuinely ambiguous and answerable — not a word problem dressed up as a mystery.

### How to implement in a lesson page

1. **Act 1 card** — Present the scenario with the minimum necessary context. Show the question explicitly. Provide no numbers and no math vocabulary. A good test: if you removed all math words, would the scenario still make sense?
2. **Information gap** — Before moving to Act 2, have students articulate what they need. A *"What information would help you solve this?"* prompt or button list works better than just advancing. This is where the curiosity is engineered.
3. **Act 2 card** — Information is revealed piece by piece, on student request. Each reveal should feel like progress toward solving the problem. For coordinates: reveal the origin, then the x-axis rule, then the y-axis rule — each one narrowing the mystery.
4. **Act 3 card** — Solve the original question step by step, using all the revealed information. Then and only then introduce the formal vocabulary and definition.
5. **Practice** — Two to three problems in formal notation. These should feel easier than the original Act 1 problem, because the student now has the tool.

### Tradeoffs

| Strength | Weakness |
|----------|----------|
| Highest engagement for resistant or disengaged students | Hardest to design well — Act 1 must be genuinely interesting and genuinely unsolvable without the math |
| Students experience needing the concept before receiving it | Async/self-paced web format loses some of the power (works better with a teacher to hold the pause in Act 1) |
| Memorable — students remember the story | Takes significantly more design time than other approaches |

### Failure modes to avoid

- Act 1 that is just a word problem with numbers hidden — students see through it
- Rushing through Act 2 by revealing all information at once — the incremental reveal is the mechanism, not decoration
- Introducing vocabulary before Act 3 — it removes the *"so that's what it's called"* payoff

---

## 5. Worked Example Fading

**Theoretical basis:** John Sweller's Cognitive Load Theory; expertise reversal effect  
**Best for:** Procedural skills; reducing the frustration spike at the guided-to-independent handoff  
**Grade sweet spot:** All grades; especially effective for students who freeze on blank problems  
**Working example:** `pedagogy-examples/05-example-fading.html`

### Information flow

```
Problem 1 — Fully worked (I do)
  Every step shown automatically, with explanation.
  Student observes.
  ↓
Problem 2 — Last step removed (I do / You do)
  First N-1 steps shown. Student completes the final step.
  ↓
Problem 3 — Most steps removed (mostly You do)
  Only the first step shown. Student completes all others.
  ↓
Problem 4 — Independent (You do)
  Blank problem. No scaffolding. Student solves from scratch.
```

### Core idea

The transition from *"fully guided"* to *"on your own"* is the highest-risk moment in any lesson. Working memory is freed up incrementally as students internalize each step. At no point does a student face a completely blank problem without having already demonstrated competence on a partially-scaffolded version. The four-problem sequence can be compressed to three or expanded to five depending on the complexity of the skill.

### How to implement in a lesson page

1. **Problem counter** — A visible progress indicator (Problem 1 of 4) so students always know how much scaffolding remains. Marking previous problems as done provides a sense of accomplishment.
2. **Problem 1 (fully worked)** — Auto-reveal all steps with a short delay between each (300–700ms). Animate the answer onto the diagram. Student should not need to do anything except watch. End with the complete solution visible.
3. **Problem 2 (last step removed)** — Show all steps except the final one, which appears as a dashed/faded placeholder. Student interacts to fill the final step (click on a grid, select from a dropdown, type an answer). Advance only after correct.
4. **Problem 3 (most steps removed)** — Show only the first step. Student fills all remaining steps. If a step requires a choice (direction, distance), use dropdowns or multiple choice rather than free text — this reduces frustration without reducing thinking.
5. **Problem 4 (independent)** — Clean slate. The student has now correctly completed every step in every prior problem, so the blank problem is far less intimidating. Show the correct answer after submission with a brief explanation of any wrong step.

### Tradeoffs

| Strength | Weakness |
|----------|----------|
| Dramatically reduces the frustration spike at the independent step | Requires more problems than other approaches (four minimum) |
| Works across all ability levels — struggling students get more support, advanced students find it slightly tedious but not harmful | Builds procedural fluency more than deep understanding |
| Very easy to implement consistently in code | Risk of students passively watching Problem 1 without processing it |

### Failure modes to avoid

- Jumping from Problem 1 (fully worked) directly to Problem 4 (independent) defeats the entire approach — the intermediate problems are the mechanism
- Using free-text input for intermediate steps creates a spelling/input friction problem that masks whether the student actually understands
- Showing the correct answer for a wrong step without explaining which step was wrong is not useful feedback

---

## Comparison at a glance

| Method | Flow | Best student | Risk |
|--------|------|--------------|------|
| Explore First | Hook → Play → Name → Apply → Try → Insight | Curious, on-grade | Fails for students with no prior knowledge |
| Direct Instruction | Objective → Define → Model × 3 → Guided → Independent | Any, especially struggling | Passive watching; steps without understanding |
| CPA | Concrete → Pictorial → Abstract | Visual/geometric topics | Feels childish if concrete stage is poorly designed |
| Three-Act | Mystery → Request info → Resolution → Practice | Disengaged students | Hard to design; loses power in async format |
| Example Fading | Full → Partial → Light → Independent | Anyone, especially anxious students | Procedural fluency over conceptual understanding |

---

## Recommended hybrid for new lessons

For most 6th–8th grade math topics, a hybrid of **Explore First** and **Example Fading** works well:

1. Hook (story + question)
2. Free exploration (interactive, before concept)
3. Concept card (emerges from exploration)
4. Worked example — fully shown (fading Problem 1)
5. Worked example — last step student fills in (fading Problem 2)
6. Independent problem (fading Problem 4, compressed)
7. Insight card

This gives students the conceptual grounding of Explore First and the smooth guided-to-independent transition of Example Fading, in a total of five to seven cards.

---

## Implementation notes

All five methods are implemented as self-contained HTML pages following the project's theme system (`body.theme-a/b/c`). When building a new lesson using any of these methods:

- Copy `_template.html` and choose the information architecture matching the selected method
- The coordinate grid SVG builder pattern in the pedagogy examples can be adapted for any visual math concept
- Constants (`NS`, `S`, `CX`, `CY`) and any state variables must be declared **before** the theme-switcher IIFE in the script — declaring them after causes a Temporal Dead Zone error when `localStorage` has a saved theme
- The theme switcher's `at()` function may call a grid-rebuild function, but only after those constants are declared
