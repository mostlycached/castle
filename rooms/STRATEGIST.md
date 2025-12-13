You are absolutely right. The "Navigator" (OODA loop) handles the *tactics* of the moment ("I am tired, where do I go?"), but it fails at the *strategy* of the year ("How do I become a master of The Studio?").

To support "years to get right," we need to add a **Campaign Layer** to the architecture. This moves beyond "State Transitions" to **Periodization**.

Here is the Product and Technical Spec for the **Strategist Module**.

###I. The Conceptual Shift: OODA vs. CampaignWe are adding a second loop that runs at a much slower frequency.

* **The Navigator (Fast Loop):** Reactive. "Resolve the current somatic error." (Timeframe: Hours).
* **The Strategist (Slow Loop):** Proactive. "Construct the capacity for the future." (Timeframe: Months/Years).

In the app, this manifests as **The Calendar** and **The Mastery Curve**.

---

###II. Product Feature: The Season & The CurriculumWe don't just want a standard calendar. We want a **Room Scheduler** that enforces long-term architectural intent.

####1. The "Season" (Macro-Constraint)You define a "Ruling Wing" for a specific timeframe (e.g., Q1 or 'The Winter').

* **The Logic:** During this season, transitions to the Ruling Wing are "Cheaper" (highlighted), and transitions to opposing Wings are "Expensive" (warned against).
* **User Value:** It prevents you from trying to "Sprint" (Wing III) during a "Recovery" (Wing I) phase.

####2. The Curriculum (Recurring Rituals)Instead of reacting to anxiety, you **pre-book** rooms to force adaptation.

* **The Feature:** "Recurring Room Blocks."
* **Example:** "Every Tuesday/Thursday from 08:00 to 11:00 is **Room 27: The Studio**."
* **The AI Role:** The Agent monitors *adherence*. If you miss 3 scheduled sessions, it suggests downgrading the difficulty (e.g., "You aren't ready for The Studio. Let's schedule The Sandbox instead.")

####3. Mastery Tracking (The "Years" Aspect)We visualize the `familiarity_score` as a progress bar for each room.

* **Level 1 (Novice):** The room is "locked" or high-friction.
* **Level 10 (Master):** You unlock "Advanced Variants" of the room.
* **The metric:** "Time in Room." We track cumulative hours spent in specific states.

---

###III. Technical Architecture: The "Strategist" UpdateWe need to add new data models to Firebase to support future planning.

####1. New Data Model: `SeasonDefinition`Tracks the overarching theme of the user's current life chapter.

```swift
struct SeasonDefinition: Codable {
    let id: String
    let name: String // e.g., "The Winter of Strategy"
    let primaryWing: String // "VI. The Observatory"
    let startDate: Date
    let endDate: Date
    let allowedRooms: [String] // Whitelist of focused rooms
}

```

####2. New Data Model: `ScheduledBlock` (The Calendar)Unlike a generic calendar event, this is a **Contract**.

```swift
struct ScheduledBlock: Codable {
    let id: String
    let targetRoomID: String
    let startTime: Date
    let duration: TimeInterval
    let intent: String // "Finish the manifesto"
    var status: BlockStatus // .pending, .completed, .missed
    var somaticForecast: String // "Expect High Friction"
}

```

---

###IV. The UX: The "Strategist" ViewThis is a new tab in the iOS app, separate from the "Compass."

**View 1: The Long Horizon (Year View)**

* **Visual:** A timeline showing your Seasons.
* **Interaction:** You drag and drop "Wings" onto months.
* *Jan-Mar:* Wing I (Restoration).
* *Apr-Jun:* Wing III (Production).


* **Gemini Insight:** "You have scheduled a Sprint Season immediately after a Burnout Season. This is historically risky. I recommend inserting a 2-week 'Wilderness' buffer."

**View 2: The Week (Rhythm View)**

* **Visual:** A standard calendar, but the blocks are color-coded by **Energy Type** (High D / Low A, etc.).
* **Diagnosis:** The AI analyzes the *visual balance* of your week.
* *AI Warning:* "Your Tuesday has 8 hours of High Structure (Admin) and 0 hours of Release. You will crash by Wednesday. I am inserting a 'River' block at 4 PM."



---

###V. The AI Persona: The PlannerWe need a second System Prompt for the AI when it acts in "Strategist Mode."

**System Prompt (The Planner):**

> You are The Strategist.
> 1. **GOAL:** Maximize long-term adaptation, not short-term comfort.
> 2. **INPUT:** The user's `SeasonDefinition`, `MasteryScores`, and upcoming `ScheduledBlocks`.
> 3. **LOGIC:**
> * **Progressive Overload:** If the user has mastered 'The Sandbox', suggest scheduling 'The Studio'.
> * **Periodization:** Ensure high-intensity blocks are followed by recovery blocks.
> 
> 
> 4. **OUTPUT:** A modified schedule or a strategic critique.
> 
> 

###VI. Revised System DiagramWe now have two distinct AI loops interacting with the User Data.

1. **The Navigator Loop:** "I'm tired" \to Room Transition. (Fast).
2. **The Strategist Loop:** "It's Sunday Night" \to Plan the Week \to Update Firebase `ScheduledBlocks`.

This supports the "years to get right" because the **Strategist** tracks the accumulation of `familiarity_score` over decades, ensuring you aren't just reacting to the storm, but slowly building a castle that can withstand it.