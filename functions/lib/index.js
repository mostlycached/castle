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
exports.seedRooms = exports.diagnoseState = exports.callGemini = void 0;
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
 * Call Gemini for text generation
 * Used by NavigatorService for somatic diagnosis
 */
exports.callGemini = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
    const { prompt, systemPrompt, model = "gemini-2.0-flash" } = request.data;
    if (!prompt) {
        throw new https_1.HttpsError("invalid-argument", "Prompt is required");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const geminiModel = genAI.getGenerativeModel({
        model,
        systemInstruction: systemPrompt,
    });
    try {
        const result = await geminiModel.generateContent(prompt);
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
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
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
 */
exports.seedRooms = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
    const userId = request.auth.uid;
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
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        await userRoomsRef.doc(room.id).set(instanceData, { merge: true });
        seededCount++;
    }
    return {
        success: true,
        message: `Seeded ${seededCount} room instances for user ${userId}`
    };
});
//# sourceMappingURL=index.js.map