Here is the comprehensive **Product Specification** and **Technical Architecture Document** for *The 72 Rooms*.

This document consolidates the philosophy, the navigation logic, and the facility management into a single actionable blueprint for development.

---

#PART I: PRODUCT SPECIFICATION**Project Code Name:** ARCHITECT
**Core Philosophy:** "Life is the allocation of Dionysian energy onto Apollonian forms."

###1. Product Vision*ARCHITECT* is not a productivity tool; it is an **Attention Management System**. It models the user’s life as a facility of "72 Rooms"—distinct states of being (Work, Rest, Chaos, Order). The app helps the user **Navigation** (Tactical), **Planning** (Strategic), and **Maintenance** (Engineering) of these states.

###2. The Core Data Model: Class vs. InstanceTo support "years of mastery," the system distinguishes between the Ideal and the Reality.

* **The Room Class (The Ideal):** The Platonic definition of the room (e.g., "Room 049: The River"). Contains the physics, the "Why," and the immutable rules.
* **The Room Instance (The Reality):** The user's specific instantiation (e.g., "Starbucks on Main St"). Contains the inventory, familiarity score, and health status.

###3. User Journey & ModulesThe app is divided into three functional layers, corresponding to three time horizons.

####Module A: The Navigator (Timeframe: The Now)* **Goal:** Solve the immediate somatic error (OODA Loop).
* **Input:** Somatic State (Energy, Valence, Physical Symptoms).
* **Logic:**
* *Diagnosis:* "You are in The Swamp (Stagnation)."
* *Route:* "Go to The River (Room 049) to wash off the static."


* **Key Feature: The Liturgy.** A session timer that enforces entry/exit rituals.
* *Entry:* Check constraints (Phone in bag? Noise-canceling on?).
* *Exit:* Log friction and somatic shift.



####Module B: The Strategist (Timeframe: The Season)* **Goal:** Periodization and capacity building.
* **Input:** Calendar, Season Definition, Mastery Scores.
* **Features:**
* **The Season:** User defines a "Ruling Wing" (e.g., Winter/Strategy) which makes certain rooms "cheaper" to enter.
* **The Schedule:** Recurring blocks for specific rooms (e.g., "The Studio" every Tuesday).
* **Mastery Tracking:** Visualizing `familiarity_score` as a level-up bar.



####Module C: The Engineer (Timeframe: The Lifecycle)* **Goal:** Infrastructure maintenance and optimization.
* **Input:** Inventory Lists, Friction Logs, Room Health.
* **Features:**
* **The Workshop:** A dashboard showing the "Health" of every room instance.
* **Inventory Management:** Tracking critical artifacts (e.g., "Headphones missing in The Cockpit").
* **Scouting Missions:** Quests to find new physical locations for a Room Class.



###4. UX/UI Hierarchy1. **Tab 1: The Compass (Home).**
* Dynamic Phase Space Visualization (D vs A Axis).
* "You Are Here" indicator.
* Chat Interface with **The Navigator**.


2. **Tab 2: The Blueprint (Library).**
* Card view of all 72 Room Classes.
* Status indicators for active Instances.


3. **Tab 3: The Timeline (Calendar).**
* Weekly view color-coded by Energy Type.
* Seasonal overlay.


4. **Tab 4: The Workshop (Settings).**
* List of active Instances with Health Bars.
* Inventory checklists and Renovation tools.



---

#PART II: TECHNICAL ARCHITECTURE DOCUMENT**Stack:** iOS (SwiftUI) + Firebase (Firestore/Auth) + Gemini API (LLM).

###1. System Architecture Diagram* **Client (iOS):** Stores "Ideals" (JSON) locally. Renders UI. Handles sensors.
* **Backend (Firebase):** Stores "Instances," "User Logs," and "Seasons." Syncs across devices.
* **Brain (Gemini API):** Stateless logic processor. Receives context (User State + Room Data) and returns structured JSON commands.

###2. Data Models (Swift Structs)####A. The Static Ideal (Read-Only JSON)```swift
struct RoomDefinition: Codable, Identifiable {
    let id: String         // "013"
    let name: String       // "The Morning Chapel"
    let wing: String       // "II. Governance"
    
    // The Physics
    let dionysianLogic: String   // "Low"
    let apollonianLogic: String  // "High"
    let evocativeWhy: String     // "Sovereignty before Service..."
    
    // The Rules
    let defaultConstraints: [String] // ["No Phone", "Silence"]
    let requiredArchetypes: [String] // ["Analog Interface", "Liquid"]
}

```

####B. The Dynamic Instance (Firestore Document)```swift
struct RoomInstance: Codable, Identifiable {
    let id: String          // UUID
    let definitionId: String // FK to RoomDefinition ("013")
    
    // The Reality
    var variantName: String // "Balcony Chair"
    var familiarityScore: Float // 0.0 to 1.0
    var healthScore: Float      // 0.0 to 1.0 (Decays with friction)
    
    // The Assets
    var inventory: [Artifact]
    var maintenanceLog: [MaintenanceEvent]
    
    struct Artifact: Codable {
        let name: String    // "Moleskine Notebook"
        let status: Status  // .operational, .missing
        let isCritical: Bool
    }
}

```

####C. The Context (Session & Season)```swift
struct SessionLog: Codable {
    let id: String
    let roomId: String
    let entrySomaticState: String // "High Anxiety"
    let exitSomaticState: String  // "Calm Focus"
    let frictionRating: Int       // 1-5 (Used to calculate Health Decay)
}

struct SeasonDefinition: Codable {
    let name: String        // "The Winter of Strategy"
    let primaryWing: String // "VI. Observatory"
    let startDate: Date
}

```

###3. AI Architecture (The 3 Personas)The app uses a single API endpoint but swaps the **System Instruction** based on the active module.

####Agent 1: The Navigator (OODA)* **Trigger:** User hits "Update State" on Home Tab.
* **Context Provided:** Recent `SessionLogs`, Current `SomaticInput`.
* **System Prompt:**
> "You are The Navigator. Diagnose the user's somatic state (Energy/Structure). Map it to the Phase Space. Recommend a transition based on 'Momentum' rules (don't jump from Low to High energy instantly)."



####Agent 2: The Strategist (Planning)* **Trigger:** User opens Timeline or Weekly Review.
* **Context Provided:** `SeasonDefinition`, `CalendarBlocks`, `MasteryScores`.
* **System Prompt:**
> "You are The Strategist. Enforce Periodization. If the user schedules too many 'Sprint' rooms, warn them of burnout risk. Suggest 'Recovery' blocks."



####Agent 3: The Engineer (Maintenance)* **Trigger:** User opens Workshop or Reports High Friction.
* **Context Provided:** `RoomInstance` health, `Inventory` lists.
* **System Prompt:**
> "You are The Facility Manager. Analyze the friction logs. If a room is failing, identify the missing inventory or broken constraint. Suggest a Renovation or a Scouting Mission."



###4. Implementation Roadmap**Phase 1: The Foundation (Local Prototype)**

1. Create `rooms.json` with the 10 core rooms.
2. Build `RoomDetailView` (SwiftUI) to render the "Card."
3. Implement `RoomInstance` local storage (UserDefaults/SwiftData) to edit "Inventory."

**Phase 2: The Navigator (AI Integration)**

1. Connect Gemini API.
2. Build the Chat Interface.
3. Feed `rooms.json` into the AI context window so it knows the map.

**Phase 3: The Cloud (Sync & Strategy)**

1. Set up Firebase Auth & Firestore.
2. Implement `SessionLog` syncing.
3. Build the "Health Decay" logic (Server-side function or local check).

**Phase 4: The Full Facility (72 Rooms)**

1. Use the Agent to generate the full 72-room JSON content.
2. Migrate the full list into the app.

---

This document is your "Source of Truth." You can now hand the **Technical Architecture** section to an engineer (or an AI coder) to scaffold the project, while you use the **Product Spec** to refine the content and UX.