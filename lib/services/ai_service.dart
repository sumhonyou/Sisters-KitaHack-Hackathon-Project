import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String _apiKey = "AIzaSyCzgPsCxHJJI4lK86cZIKVzDOKPavBaIdI";
  final String _endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

  Future<Map<String, dynamic>> summarizeIncidents(
    List<Map<String, dynamic>> incidents,
    Map<String, String> areaNames,
  ) async {
    if (incidents.isEmpty) {
      return {"summary": "No incidents to analyze.", "groups": []};
    }

    final prompt = _buildPrompt(incidents, areaNames);

    try {
      final response = await http.post(
        Uri.parse("$_endpoint?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {"responseMimeType": "application/json"},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        try {
          return jsonDecode(text) as Map<String, dynamic>;
        } catch (e) {
          return {"summary": "Error parsing AI response: $text", "groups": []};
        }
      } else {
        return {
          "summary":
              "Failed to generate summary. Status: ${response.statusCode}",
          "groups": [],
        };
      }
    } catch (e) {
      return {"summary": "Error calling AI: $e", "groups": []};
    }
  }

  String _buildPrompt(
    List<Map<String, dynamic>> incidents,
    Map<String, String> areaNames,
  ) {
    String incidentDetails = incidents
        .map((i) {
          final areaId = i['areaId'] ?? '';
          final areaName = areaNames[areaId] ?? areaId;
          return "- ID: ${i['caseId']}, Category: ${i['category']}, Severity: ${i['severity']}, Area: $areaName ($areaId), Affected: ${i['peopleAffected']}, Description: ${i['description']}";
        })
        .join("\n");

    return """
You are a disaster management analyst. Analyze the following recent incidents.
Group related incidents that are reported from the same areas into "disasters".

CRITICAL INSTRUCTION:
1. Always use the human-readable "Area:" name provided in the incident details for your "summary", "title", and "description". 
2. NEVER use the technical Area ID in any user-facing text.
3. Keep the "summary" to exactly ONE concise sentence.
4. Keep the "analysis" for each group to exactly ONE short, informative sentence.

Return strictly a JSON object with the following structure:
{
  "summary": "A high-level one-sentence overview of all incidents.",
  "groups": [
    {
      "disasterId": "unique_string_id",
      "Type": "Category of disaster",
      "severity": "Severity level",
      "title": "A short descriptive title",
      "description": "A very brief summary of the situation.",
      "affectedAreaIds": ["list", "of", "areaIds"],
      "Status": "Active",
      "updatedAt": "Current ISO timestamp",
      "incidentCount": 5,
      "totalAffected": 20,
      "analysis": "A single short sentence analyzing the group.",
      "similarCasesTracked": "Explanation of how these cases are similar"
    }
  ],
  "disasterTrends": "Analysis of trends across all areas using their names"
}

Incidents:
$incidentDetails
""";
  }
}
