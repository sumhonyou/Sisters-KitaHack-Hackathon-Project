const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

admin.initializeApp();
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// ─── Gemini Integration ───────────────────────────────────────────────────

async function callGemini(reports) {
  const apiKey = GEMINI_API_KEY.value();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

  const reportData = reports.map(r => ({
    caseId: r.caseId,
    description: r.description,
    category: r.category,
    areaId: r.areaId,
    peopleAffected: r.peopleAffected,
    createdAt: r.timestamp ? r.timestamp.toDate().toISOString() : new Date().toISOString()
  }));

  const prompt = `
You are an expert disaster coordinator. Analyze these incident reports and group them into "disasters".
A disaster is a cluster of related incidents of the same type in the same area.

Input Reports:
${JSON.stringify(reportData, null, 2)}

Requirements:
1. Group incidents into clusters (disasters). Use logic to see if people are describing the same event.
2. For each disaster, determine:
   - disasterId: "disaster_{type}_{zone_name}" (lowercase, underscores)
   - type: One of "FLOOD", "FIRE", "STORM", "EARTHQUAKE", "TSUNAMI", "OTHER"
   - severity: "critical" (immediate danger/trapped), "high" (serious damage), "medium" (minor)
   - title: "TYPE - Zone/Area Name" (e.g. "FLOOD - Wangsa Maju")
   - description: 1 short sentence summarizing the situation.
   - locationLabel: Short area or landmark name.
   - affectedAreaIds: List of unique areaIds from the grouped reports.
   - affectedCount: SUM of peopleAffected from the grouped reports.
   - caseCount: Total number of individual reports grouped into this cluster.
   - updatedAt: The latest timestamp among the grouped reports in ISO format.

Output Format: STRICT JSON ONLY. No markdown fences.
{
  "disasters": [
    {
      "disasterId": "...",
      "type": "...",
      "severity": "...",
      "title": "...",
      "description": "...",
      "locationLabel": "...",
      "affectedAreaIds": ["..."],
      "affectedCount": 0,
      "caseCount": 0,
      "updatedAt": "..."
    }
  ]
}
`;

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" }
    }),
  });

  const json = await response.json();

  if (json.error) {
    console.error("Gemini API Error Detail:", JSON.stringify(json.error, null, 2));
    throw new Error(`Gemini API Error: ${json.error.message || "Unknown error"}`);
  }

  if (!json.candidates || json.candidates.length === 0 || !json.candidates[0].content) {
    console.error("Gemini Unexpected Response:", JSON.stringify(json, null, 2));
    throw new Error("Invalid Gemini response: No candidates or content found.");
  }

  const text = json.candidates[0].content.parts[0].text;
  try {
    return JSON.parse(text);
  } catch (parseErr) {
    console.error("Failed to parse Gemini JSON:", text);
    throw new Error("Gemini returned invalid JSON format.");
  }
}

// ─── Core Aggregation Logic ────────────────────────────────────────────────

async function aggregateDisasters() {
  const db = getFirestore();

  // 1. Clear existing disasters
  const disastersSnap = await db.collection("disasters").get();
  if (!disastersSnap.empty) {
    const batchDelete = db.batch();
    disastersSnap.docs.forEach(doc => batchDelete.delete(doc.ref));
    await batchDelete.commit();
    console.log(`Cleared ${disastersSnap.size} existing disasters.`);
  }

  // 2. Fetch reports from last 7 days
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const reportsSnap = await db.collection("reported_cases")
    .where("timestamp", ">=", Timestamp.fromDate(sevenDaysAgo))
    .get();

  if (reportsSnap.empty) return;

  const reports = reportsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  // 3. Call Gemini to cluster
  const result = await callGemini(reports);
  const disasters = result.disasters || [];

  // 4. Upsert into Firestore with Area Title Lookup
  for (const d of disasters) {
    // Fetch Title from Areas collection if possible
    let finalTitle = d.title || "Unknown Disaster";
    if (d.affectedAreaIds && d.affectedAreaIds.length > 0) {
      const primaryAreaId = d.affectedAreaIds[0];
      const areaDoc = await db.collection("Areas").doc(primaryAreaId).get();
      if (areaDoc.exists) {
        finalTitle = areaDoc.data().name || finalTitle;
      }
    }

    const ref = db.collection("disasters").doc(d.disasterId);
    await ref.set({
      disasterId: d.disasterId,
      type: d.type,
      severity: d.severity,
      title: finalTitle,
      description: d.description,
      // Keep locationLabel as fallback
      locationLabel: d.locationLabel || finalTitle,
      affectedAreaIds: d.affectedAreaIds,
      affectedCount: d.affectedCount,
      caseCount: d.caseCount || 0,
      updatedAt: Timestamp.fromDate(new Date(d.updatedAt))
    }, { merge: true });
  }

  console.log(`Aggregation complete. ${disasters.length} disasters processed.`);
}

// ─── Exported Functions ───────────────────────────────────────────────────

exports.onReportCreated = onDocumentCreated(
  {
    document: "reported_cases/{docId}",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    console.log("New report created. Triggering aggregation...");
    await aggregateDisasters();
  }
);

exports.reaggregateDisasters = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    try {
      await aggregateDisasters();
      return { success: true };
    } catch (err) {
      console.error(err);
      throw new HttpsError("internal", err.message);
    }
  }
);
