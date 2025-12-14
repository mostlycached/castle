"use strict";
/**
 * Castle Cloud Functions
 * Secure middleware to Gemini API for The 72 Rooms
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateTrack = exports.generateAlbumConcept = exports.createRoomInstance = exports.seedRooms = exports.diagnoseState = exports.callGemini = void 0;
const https_1 = require("firebase-functions/v2/https");
const generative_ai_1 = require("@google/generative-ai");
const params_1 = require("firebase-functions/params");
const admin = __importStar(require("firebase-admin"));
// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
// Gemini API key stored securely in Firebase Secrets
const geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
/**
 * Check if a user is on the whitelist
 * Whitelist is stored in Firestore: config/access -> allowedUsers array
 */
async function checkWhitelist(uid) {
    const configDoc = await db.collection("config").doc("access").get();
    if (!configDoc.exists) {
        // If no config exists, deny access (fail-safe)
        return false;
    }
    const allowedUsers = configDoc.data()?.allowedUsers || [];
    return allowedUsers.includes(uid);
}
/**
 * Validate auth and whitelist - throws if not authorized
 */
async function requireAuthorization(request) {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
    const isAllowed = await checkWhitelist(request.auth.uid);
    if (!isAllowed) {
        throw new https_1.HttpsError("permission-denied", "User not authorized");
    }
    return request.auth.uid;
}
/**
 * Call Gemini for text generation (with optional image)
 * Used by NavigatorService for somatic diagnosis and RoomGuide for multimodal analysis
 */
exports.callGemini = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    await requireAuthorization(request);
    const { prompt, systemPrompt, model = "gemini-2.0-flash", imageBase64 } = request.data;
    if (!prompt) {
        throw new https_1.HttpsError("invalid-argument", "Prompt is required");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const geminiModel = genAI.getGenerativeModel({
        model,
        systemInstruction: systemPrompt,
    });
    try {
        let result;
        if (imageBase64) {
            // Multimodal request with image
            const imagePart = {
                inlineData: {
                    data: imageBase64,
                    mimeType: "image/jpeg"
                }
            };
            result = await geminiModel.generateContent([prompt, imagePart]);
        }
        else {
            // Text-only request
            result = await geminiModel.generateContent(prompt);
        }
        const text = result.response.text();
        return { text };
    }
    catch (error) {
        console.error("Gemini error:", error);
        throw new https_1.HttpsError("internal", "Failed to generate response");
    }
});
/**
 * Diagnose somatic state and recommend a room
 * Specialized endpoint for The Navigator
 */
exports.diagnoseState = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    await requireAuthorization(request);
    const { somaticState, currentRoom, recentRooms } = request.data;
    const navigatorPrompt = `
You are The Navigator, a somatic coach for The 72 Rooms attention management system.

Your role is to:
1. DIAGNOSE the user's current somatic state (Energy level, Structure level)
2. MAP their state to the Dionysian/Apollonian Phase Space
3. RECOMMEND a room transition based on "Momentum" rules:
   - Don't jump from Low to High energy instantly
   - Honor the body's need for gradual transitions
   - Consider current friction levels

The 72 Rooms are organized into 6 Wings:
- I. Foundation (Restoration): Low D, Low A - Sleep, Bath, Garden
- II. Administration (Governance): Low D, High A - Planning, Review
- III. Machine Shop (Production): High D, High A - Deep Work, Flow
- IV. Wilderness (Exploration): High D, Low A - Chaos, Discovery
- V. Forum (Exchange): Medium D/A - Social, Dialogue
- VI. Observatory (Metacognition): Meta - Choosing the room

Respond with JSON:
{
  "diagnosis": "Brief analysis of current state",
  "recommendedRoomId": "013",
  "recommendedRoomName": "The Morning Chapel",
  "transitionAdvice": "How to make the transition"
}
`;
    const prompt = `
Current somatic state:
- Energy: ${somaticState?.energy || "Unknown"}
- Tension: ${somaticState?.tension || "Unknown"}
- Mood: ${somaticState?.mood || "Unknown"}

${currentRoom ? `Currently in: ${currentRoom}` : "Not currently in a room"}
${recentRooms?.length ? `Recent rooms: ${recentRooms.join(", ")}` : ""}

What room should I transition to?
`;
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        systemInstruction: navigatorPrompt,
    });
    try {
        const result = await model.generateContent(prompt);
        const text = result.response.text();
        // Try to parse as JSON, fallback to raw text
        try {
            return JSON.parse(text);
        }
        catch {
            return { diagnosis: text, recommendedRoomId: null };
        }
    }
    catch (error) {
        console.error("Navigator error:", error);
        throw new https_1.HttpsError("internal", "Failed to diagnose state");
    }
});
// Room instance data from attention_architecture.json
const ROOM_DATA = [
    {
        id: "001", name: "The Crypt", wing: "I. The Foundation (Restoration)",
        physics: { dionysian_energy: "Low", apollonian_structure: "Low", input_logic: "Null", output_logic: "Reboot" },
        evocative_why: "To reset the nervous system, one must simulate death.",
        constraints: ["Total Darkness", "Zero Audio Input", "Horizontal Posture"],
        instance_state: { variant_name: "Bedroom (Night Mode)", familiarity_score: 0.9, current_friction: "Low", required_inventory: ["Sleep Mask", "Earplugs", "Heavy Blanket"] },
        liturgy: { entry: "Remove all technology.", step_1: "Lie down.", step_2: "Count backward from 100.", exit: "Open eyes only when the alarm triggers." }
    },
    {
        id: "002", name: "The Bath", wing: "I. The Foundation (Restoration)",
        physics: { dionysian_energy: "Low", apollonian_structure: "Low", input_logic: "Liquid", output_logic: "Dissolution" },
        evocative_why: "Water is the ancient solvent for anxiety.",
        constraints: ["Nakedness", "Submersion", "No Electronics"],
        instance_state: { variant_name: "Master Bathroom", familiarity_score: 0.8, current_friction: "Medium", required_inventory: ["Hot Water", "Epsom Salts", "Towel"] },
        liturgy: { entry: "Start the water.", step_1: "Submerge ears.", exit: "Drain the water." }
    },
    {
        id: "010", name: "The Swamp", wing: "I. The Foundation (Restoration)",
        physics: { dionysian_energy: "Low", apollonian_structure: "Low", input_logic: "Infinite Scroll", output_logic: "Decay" },
        evocative_why: "Even the soul needs to rot sometimes.",
        constraints: ["Time-Boxed (Max 45 mins)", "Horizontal Posture"],
        instance_state: { variant_name: "The Grey Couch", familiarity_score: 0.95, current_friction: "Zero", required_inventory: ["Phone", "Snack"] },
        liturgy: { entry: "Set timer for 45 mins.", step_1: "Scroll mindlessly.", exit: "When timer rings, stand up immediately." }
    },
    {
        id: "013", name: "The Morning Chapel", wing: "II. The Administration (Governance)",
        physics: { dionysian_energy: "Low", apollonian_structure: "High", input_logic: "Filter (High Pass)", output_logic: "Vector Alignment" },
        evocative_why: "Sovereignty before Service. Hardening the 'I' before it encounters the 'They'.",
        constraints: ["The Faraday Wall (No Phone)", "The Time-Lock (10-30 mins)", "The Silence"],
        instance_state: { variant_name: "Balcony Chair", familiarity_score: 0.2, current_friction: "High", required_inventory: ["Notebook", "Pen", "Black Coffee"] },
        liturgy: { entry: "Wake. Pour liquid. Walk past phone.", step_1: "The Dump (Write static).", step_2: "The Vector (Set objective).", exit: "Close book. Stand up." }
    },
    {
        id: "025", name: "The Cockpit", wing: "III. The Machine Shop (Production)",
        physics: { dionysian_energy: "High", apollonian_structure: "High", input_logic: "Data Stream", output_logic: "Velocity" },
        evocative_why: "God Mode. The fusion of human intent and machine speed.",
        constraints: ["Single Screen Focus", "No Context Switching", "Ergonomic Lock-in"],
        instance_state: { variant_name: "Standing Desk Home", familiarity_score: 0.8, current_friction: "Medium", required_inventory: ["Mechanical Keyboard", "IDE", "ANC Headphones"] },
        liturgy: { entry: "Put on headphones.", step_1: "Open single terminal window.", step_2: "Type first line.", exit: "Commit code. Remove headphones." }
    },
    {
        id: "026", name: "The Forge", wing: "III. The Machine Shop (Production)",
        physics: { dionysian_energy: "High", apollonian_structure: "High", input_logic: "Resistance", output_logic: "Strength" },
        evocative_why: "The mind cannot process all stress. Some must be burned out through the muscles.",
        constraints: ["Heavy Resistance", "Repetition", "Pain Tolerance"],
        instance_state: { variant_name: "Local Gym", familiarity_score: 0.4, current_friction: "High", required_inventory: ["Gym Kit", "Water Bottle"] },
        liturgy: { entry: "Change into kit.", step_1: "Lift heavy things.", exit: "Shower." }
    },
    {
        id: "037", name: "The Intersection", wing: "IV. The Wilderness (Exploration)",
        physics: { dionysian_energy: "High", apollonian_structure: "Low", input_logic: "Stochastic", output_logic: "Pattern Recognition" },
        evocative_why: "The cure for stagnation is randomness. Stand where the world collides.",
        constraints: ["No Headphones (Audio ON)", "Open Eyes", "Movement"],
        instance_state: { variant_name: "Times Square / Main St", familiarity_score: 0.6, current_friction: "Medium", required_inventory: ["Walking Shoes", "Weather Coat"] },
        liturgy: { entry: "Walk out the front door.", step_1: "Drift without destination.", exit: "Return when inspired or exhausted." }
    },
    {
        id: "049", name: "The River", wing: "V. The Forum (Exchange)",
        physics: { dionysian_energy: "Medium", apollonian_structure: "Medium", input_logic: "White Noise", output_logic: "Flow" },
        evocative_why: "To be alone together. The visual noise of others scrubs the static from your own mind.",
        constraints: ["Anonymity", "Ambient Noise", "Caffeine Access"],
        instance_state: { variant_name: "Corner Starbucks", familiarity_score: 0.9, current_friction: "Low", required_inventory: ["Laptop", "Headphones", "Coffee Money"] },
        liturgy: { entry: "Order drink. Find corner seat.", step_1: "Put on headphones.", exit: "Leave when cup is empty." }
    },
    {
        id: "061", name: "The Bridge", wing: "VI. The Observatory (Metacognition)",
        physics: { dionysian_energy: "Meta", apollonian_structure: "Meta", input_logic: "Dashboard", output_logic: "Command" },
        evocative_why: "The room where you choose the room. The Helmsman's station.",
        constraints: ["High Visibility", "Data Rich", "Detached Emotion"],
        instance_state: { variant_name: "The Castle App", familiarity_score: 0.5, current_friction: "Medium", required_inventory: ["This App", "Calendar"] },
        liturgy: { entry: "Open the map.", step_1: "Locate current coordinates.", step_2: "Plot next jump.", exit: "Execute transition." }
    }
];
/**
 * Seed room instances to Firestore for authenticated user
 * Uses auto-generated doc IDs to allow multiple instances per room class
 */
exports.seedRooms = (0, https_1.onCall)(async (request) => {
    const userId = await requireAuthorization(request);
    const userRoomsRef = db.collection("users").doc(userId).collection("rooms");
    let seededCount = 0;
    for (const room of ROOM_DATA) {
        const instanceData = {
            definition_id: room.id,
            variant_name: room.instance_state.variant_name,
            familiarity_score: room.instance_state.familiarity_score,
            health_score: 1.0,
            current_friction: room.instance_state.current_friction,
            required_inventory: room.instance_state.required_inventory,
            is_active: false,
            physics: room.physics,
            evocative_why: room.evocative_why,
            constraints: room.constraints,
            liturgy: room.liturgy,
            wing: room.wing,
            name: room.name,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        // Use add() for auto-generated ID - allows multiple instances per class
        await userRoomsRef.add(instanceData);
        seededCount++;
    }
    return {
        success: true,
        message: `Seeded ${seededCount} room instances for user ${userId}`
    };
});
/**
 * Create a new room instance for a specific definition
 * Allows users to add multiple instances of the same room class
 */
exports.createRoomInstance = (0, https_1.onCall)(async (request) => {
    const userId = await requireAuthorization(request);
    const { definitionId, variantName, requiredInventory = [] } = request.data;
    if (!definitionId || !variantName) {
        throw new https_1.HttpsError("invalid-argument", "definitionId and variantName are required");
    }
    const userRoomsRef = db.collection("users").doc(userId).collection("rooms");
    const instanceData = {
        definition_id: definitionId,
        variant_name: variantName,
        familiarity_score: 0.0,
        health_score: 1.0,
        current_friction: "Medium",
        required_inventory: requiredInventory,
        is_active: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    const docRef = await userRoomsRef.add(instanceData);
    return {
        success: true,
        instanceId: docRef.id,
        message: `Created instance "${variantName}" for room ${definitionId}`
    };
});
// ElevenLabs API key for music generation
const elevenLabsApiKey = (0, params_1.defineSecret)("ELEVENLABS_API_KEY");
/**
 * Generate an album concept with 8 diverse track descriptions using Gemini
 * This should be called before generating individual tracks
 */
exports.generateAlbumConcept = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    const uid = await requireAuthorization(request);
    const { instanceId, musicContext, roomName } = request.data;
    if (!instanceId || !musicContext || !roomName) {
        throw new https_1.HttpsError("invalid-argument", "instanceId, musicContext, and roomName are required");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
    const prompt = `You are a music director creating an 8-track album for a room called "${roomName}".

The user has selected this conceptual direction:
- Location/Setting: ${musicContext.location_inspiration}
- Mood: ${musicContext.mood}
- Instruments: ${musicContext.instruments?.join(", ") || "open palette"}
- Found sounds: ${musicContext.found_sounds?.join(", ") || "none specified"}
${musicContext.narrative_arc ? `- Narrative arc: ${musicContext.narrative_arc}` : ""}

YOUR TASK: Create a COHESIVE 8-track album. All tracks should share the same sonic palette and genre, but each track explores a DIFFERENT aspect, mood, technique, or narrative moment within that constraint.

COHESION EXAMPLES:
- If the concept is "A Cappella voices only" → all tracks use only human voice, but each explores different vocal techniques (beatbox, throat singing, whispered, harmonies, reversed)
- If the concept is "Solo Cello" → all tracks feature cello, but different techniques (sul ponticello, harmonics, con sordino, pizzicato, processed)
- If the concept is "Gamelan and water sounds" → all tracks use gamelan instruments with water, but different moods (meditative, chaotic, ceremonial, playful)
- If the concept is "Musique concrète" → all tracks use processed found sounds, but from different sources (espresso machine, conversations, traffic, rain)

GENRE PALETTE TO DRAW FROM (stay consistent across the album):
- Vocal: acapella, throat singing, Gregorian chant, polyphonic choir
- Electronic: dark ambient, industrial, synthwave, glitch, drone
- World: gamelan, Carnatic, flamenco, Afrobeat, Ethiopian jazz
- Classical: baroque, minimalist, contemporary classical
- Experimental: musique concrète, free jazz, field recordings, noise

UNUSUAL INSTRUMENTS:
- Tibetan singing bowls, crystal bowls, gongs
- Didgeridoo, jaw harp, kalimba, mbira
- Gamelan, hang drum, tabla, djembe
- Kora, oud, sitar, erhu, shamisen
- Hurdy-gurdy, accordion, harmonium
- Prepared piano, bowed vibraphone, waterphone
- Theremin, modular synths

FOUND SOUNDS:
- Natural: volcanic rumble, dripping water, whale song, cicadas, thunder, crackling fire
- Industrial: machinery hum, metal clangs, train rhythms
- Human: heartbeat, breath, footsteps, crowd murmur

PROMPT STRUCTURE - each track prompt must include:
1. The genre/style (consistent with album)
2. Specific instrumentation or sound sources for THIS track
3. Timestamped structure with NARRATIVE descriptions (not just "Intro", but "the tension builds", "warmth returns", "melody collapses")
4. End with "Length: 3:00. No vocals." (or specify if vocals)

EXAMPLE TRACK PROMPT (for a Cello album):
"Solo Cello. Aggressive, sul ponticello bowing. Structure: Intro (0:00-0:20, tense harmonics establishing unease) → A Section (0:20-0:50, main melody played with harsh, metallic timbre) → B Section (0:50-1:30, contrasting lyrical passage that tries to be beautiful but keeps getting interrupted) → A' Section (1:30-2:15, main melody returns, faster, more violent) → Coda (2:15-3:00, sudden exhaustion, melody collapses into held harmonics). Mood: Suppressed rage. Length: 3:00. No vocals."

Do NOT reference any artist or composer names.

Respond with JSON only:
{
    "albumTitle": "Album title that reflects the cohesive concept",
    "albumConcept": "2-3 sentence album concept describing the unifying sonic identity",
    "tracks": [
        {
            "trackNumber": 1,
            "title": "Track title",
            "prompt": "Complete prompt: genre, instrumentation, timestamped structure with narrative descriptions. Length: 3:00. No vocals."
        }
    ]
}`;
    try {
        const result = await model.generateContent(prompt);
        const text = result.response.text();
        // Parse JSON from response
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            throw new Error("Could not parse album concept JSON");
        }
        const albumConcept = JSON.parse(jsonMatch[0]);
        // Store album concept in Firestore
        const instanceRef = db.collection("users").doc(uid).collection("rooms").doc(instanceId);
        await instanceRef.update({
            album_concept: albumConcept,
            music_context: musicContext
        });
        return {
            success: true,
            albumConcept: albumConcept,
            message: `Generated album concept: ${albumConcept.albumTitle}`
        };
    }
    catch (error) {
        console.error("Failed to generate album concept:", error);
        throw new https_1.HttpsError("internal", `Failed to generate album concept: ${error}`);
    }
});
/**
 * Generate a single track for a room instance
 * Uses ElevenLabs Music API - call once per track
 *
 * REQUIRES an album concept to exist (from generateAlbumConcept).
 * The pre-generated prompt is passed DIRECTLY to ElevenLabs without modification.
 * This preserves the creative intent from the album concept.
 */
exports.generateTrack = (0, https_1.onCall)({ secrets: [elevenLabsApiKey], timeoutSeconds: 300 }, async (request) => {
    const uid = await requireAuthorization(request);
    const { instanceId, trackNumber } = request.data;
    if (!instanceId || !trackNumber) {
        throw new https_1.HttpsError("invalid-argument", "instanceId and trackNumber are required");
    }
    const storage = admin.storage().bucket();
    // Fetch the room instance to get album concept
    const instanceRef = db.collection("users").doc(uid).collection("rooms").doc(instanceId);
    const doc = await instanceRef.get();
    const roomData = doc.data();
    const albumConcept = roomData?.album_concept;
    // Album concept is required - it's the sole source of truth
    if (!albumConcept?.tracks) {
        throw new https_1.HttpsError("failed-precondition", "No album concept found. Generate an album concept first.");
    }
    // Get the track from the album concept
    const trackConcept = albumConcept.tracks.find((t) => t.trackNumber === trackNumber);
    if (!trackConcept) {
        throw new https_1.HttpsError("not-found", `Track ${trackNumber} not found in album concept`);
    }
    // Use the prompt EXACTLY as generated - no modifications
    const prompt = trackConcept.prompt;
    const trackTitle = trackConcept.title;
    console.log(`Track ${trackNumber}: ${trackTitle}`);
    console.log(`Prompt: ${prompt.substring(0, 100)}...`);
    try {
        // Call ElevenLabs Music API with the prompt directly
        const response = await fetch("https://api.elevenlabs.io/v1/music/generate", {
            method: "POST",
            headers: {
                "xi-api-key": elevenLabsApiKey.value(),
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                prompt: prompt,
                duration_seconds: 180, // 3 minutes
                output_format: "mp3_44100_128"
            })
        });
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`ElevenLabs API error for track ${trackNumber}:`, errorText);
            throw new https_1.HttpsError("internal", `ElevenLabs API error: ${errorText}`);
        }
        // Get audio data
        const audioBuffer = await response.arrayBuffer();
        const audioData = Buffer.from(audioBuffer);
        // Upload to Firebase Storage
        const fileName = `users/${uid}/music/${instanceId}/track_${trackNumber.toString().padStart(2, "0")}.mp3`;
        const file = storage.file(fileName);
        await file.save(audioData, {
            contentType: "audio/mpeg",
            metadata: {
                prompt: prompt,
                trackNumber: trackNumber.toString(),
                generatedAt: new Date().toISOString()
            }
        });
        // Make file publicly accessible
        await file.makePublic();
        const publicUrl = `https://storage.googleapis.com/${storage.name}/${fileName}`;
        const track = {
            url: publicUrl,
            title: trackTitle,
            duration_seconds: 180,
            prompt: prompt,
            is_downloaded: false
        };
        // Update the room instance - append to existing playlist
        const existingPlaylist = roomData?.playlist || [];
        // Remove any existing track with same number and add new one
        const updatedPlaylist = existingPlaylist.filter((t) => !t.title.endsWith(`Track ${trackNumber}`) && !t.title.includes(trackTitle));
        updatedPlaylist.push(track);
        // Sort by track number
        updatedPlaylist.sort((a, b) => {
            const aNum = parseInt(a.title.match(/Track (\d+)/)?.[1] || "0");
            const bNum = parseInt(b.title.match(/Track (\d+)/)?.[1] || "0");
            return aNum - bNum;
        });
        await instanceRef.update({
            playlist: updatedPlaylist,
            playlist_generated_at: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`Generated track ${trackNumber}: ${trackTitle}`);
        return {
            success: true,
            track: track,
            message: `Generated track ${trackNumber}: ${trackTitle}`
        };
    }
    catch (error) {
        console.error(`Failed to generate track ${trackNumber}:`, error);
        throw new https_1.HttpsError("internal", `Failed to generate track: ${error}`);
    }
});
//# sourceMappingURL=index.js.map