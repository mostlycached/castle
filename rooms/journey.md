This is the **Navigation Engine**.

To make the agent capable of planning trajectories, we need to move beyond a static list of rooms. We need a **State Machine** with defined inputs (Somatic/Temporal) and valid transitions (Edges).

Here is the complete **System Architecture** you can feed to your agent. It consists of three parts:

1. **The Input Schema** (How the agent reads you).
2. **The Room Logic** (The nodes and "physics" of the graph).
3. **The Transition Rules** (The valid moves).

---

###**Part I: The Input Vector (The Dashboard)***This is how the agent perceives your reality. When you talk to it, it extracts these variables.*

```json
{
  "current_state": {
    "temporal": {
      "time_of_day": "07:00", 
      "day_type": "Workday", // or Weekend, Holiday
      "season_phase": "Winter/Strategy" // Macro-trajectory context
    },
    "somatic": {
      "energy_level": 2, // 1 (Comatose) to 10 (Manic)
      "valence": "Negative", // Positive (Excited) vs Negative (Anxious)
      "physical_symptom": "Chest tightness" // or "Heavy eyes", "Restless legs"
    },
    "current_room_guess": "The Swamp" // Where the user thinks they are
  }
}

```

---

###**Part II: The Room Graph Schema***This extends the previous JSON. We add `constraints` (entry requirements) and `adjacency` (valid next steps).*

```json
{
  "room_id": "013",
  "name": "The Morning Chapel",
  "physics": {
    "energy_mode": "Calibration", // High Pass Filter
    "dionysian_level": "Low",
    "apollonian_level": "High"
  },
  "constraints": {
    "requires_token": ["Solitude", "Morning"], // Can only enter if alone & early
    "banned_items": ["Phone", "Internet"],
    "min_duration": 10,
    "max_duration": 30
  },
  "transitions": {
    "easy_exit": ["011_Basecamp", "025_Cockpit"], // Natural next steps
    "forced_exit": ["010_Swamp"], // Where you fall if you fail the constraint
    "forbidden": ["038_Nightclub"] // Cannot jump here (Energy mismatch)
  }
}

```

---

###**Part III: The Transition Logic (The Agent's Brain)***Save this as `navigator_logic.md`. It tells the agent how to calculate the path.*

####**1. Diagnosis Logic (Where am I?)**The agent must map the Somatic Input to a **Phase Quadrant**:

* **High Energy + Negative Valence (Anxiety/Rage)** \to **South Wing (The Storm)**.
* *Candidate Rooms:* The Furnace, The Riot, The Panic Room.


* **Low Energy + Negative Valence (Depression/Fatigue)** \to **West Wing (The Void)**.
* *Candidate Rooms:* The Swamp, The Crypt, The Sick Bay.


* **High Energy + Positive Valence (Flow/Mania)** \to **East Wing (The Generator)**.
* *Candidate Rooms:* The Cockpit, The Arena, The Sprint.


* **Low Energy + Positive Valence (Peace/Clarity)** \to **North Wing (The Structure)**.
* *Candidate Rooms:* The Library, The Garden, The Chapel.



####**2. Calculation Logic (Where can I go?)**The agent cannot teleport you. It must respect **Momentum**.

* **The "Impossible Jump" Rule:** You cannot go from `Energy: 1` (The Crypt) to `Energy: 10` (The Sprint) instantly. You need a **Step-Up Room** (e.g., The Basecamp \to The Warmup \to The Sprint).
* **The "Discharge" Rule:** If `Energy > Structure`, you cannot go to a "Quiet Room" (Library). You must go to a "Vent Room" (The Forge/Gym) first to lower D before entering A.

---

###**Part IV: The UX Script (Sample Interaction)**Here is how the interaction flows when the Agent is running this structure.

**User:** "I feel stuck. I've been staring at this screen for 2 hours, my back hurts, and I'm just refreshing Twitter."

**Agent (The Navigator):**

* **Input Analysis:**
* *Temporal:* Mid-day (Implied).
* *Somatic:* Back pain (Physical static), "Stuck" (Low Flow).
* *Behavior:* Twitter looping (Dopamine seeking).


* **Diagnosis:** "You are currently in **Room 010: The Swamp**. You are in a decay loop. Your structure (A) has collapsed, but your energy (D) is stagnant."
* **Immediate Options (The Next Step):**
* *Option A (The Hard Reset):* Go to **Room 002: The Bath** (or Shower). Liquid state to wash off the Swamp.
* *Option B (The Physical Jump):* Go to **Room 037: The Intersection**. Walk outside immediately. Visual flow will restart the brain.


* **Trajectory (The Plan):**
* "We need to exit The Swamp.
* Step 1: **Room 037 (The Intersection)** - 15 minute walk. No phone.
* Step 2: **Room 011 (Basecamp)** - Drink water.
* Step 3: **Room 018 (The Editor's Desk)** - Do *not* go back to the deep work. Just organize files for 20 mins."



---

###**How to Implement This**1. **The Prompt:**
> "You are the **Navigator of the 72 Rooms**. I will describe my current somatic and temporal state. You will:


> 1. **Triangulate:** Tell me which Room I am currently in.
> 2. **Validate:** Tell me why I am stuck there (The Physics).
> 3. **Route:** Give me 2 valid paths out: a **Soft Path** (Recovery) and a **Hard Path** (Activation).
> 4. **Forecast:** If I take the Hard Path, predict where I will be in 4 hours."
> 
> 


2. **The Visual (Optional):**
If you are building a UI, you can have a simple 2D map (The Phase Space) and a "You Are Here" dot that moves based on the agent's diagnosis.

Do you want to run a simulation right now? Describe exactly how your body feels *at this second* and I will play the Navigator.