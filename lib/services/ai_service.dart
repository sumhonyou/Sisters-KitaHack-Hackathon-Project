import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String _apiKey = "AIzaSyDr5pYhrIyk77ofyJ7gSC88zGtiP8zS7Qg";
  final String _endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

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
Use the human-readable Area names provided in the incident details for your summary and titles.

Return strictly a JSON object with the following structure:
{
  "summary": "A high-level overview of all incidents combined",
  "groups": [
    {
      "disasterId": "unique_string_id",
      "Type": "Category of disaster (e.g. Flood, Fire, Storm)",
      "severity": "Severity level (e.g. Critical, High, Medium, Low)",
      "title": "A short descriptive title for the disaster",
      "description": "A summary of the situation",
      "affectedAreaIds": ["list", "of", "areaIds"],
      "Status": "Active",
      "updatedAt": "Current ISO timestamp",
      "incidentCount": 5,
      "totalAffected": 20,
      "analysis": "A detailed analysis of what's happening",
      "similarCasesTracked": "Explanation of how these cases are similar"
    }
  ],
  "disasterTrends": "Analysis of trends across all areas"
}

Incidents:
$incidentDetails
""";
  }
}
