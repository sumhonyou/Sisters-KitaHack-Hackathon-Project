import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String _apiKey = "AIzaSyDr5pYhrIyk77ofyJ7gSC88zGtiP8zS7Qg";
  final String _endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

  Future<Map<String, dynamic>> summarizeIncidents(
    List<Map<String, dynamic>> incidents,
  ) async {
    if (incidents.isEmpty) {
      return {"summary": "No incidents to analyze.", "groups": []};
    }

    final prompt = _buildPrompt(incidents);

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

  String _buildPrompt(List<Map<String, dynamic>> incidents) {
    String incidentDetails = incidents
        .map((i) {
          return "- ID: ${i['caseId']}, Category: ${i['category']}, Severity: ${i['severity']}, Area: ${i['areaId']}, Affected: ${i['peopleAffected']}, Description: ${i['description']}";
        })
        .join("\n");

    return """
You are a disaster management analyst. Analyze the following recent incidents.
Group related incidents that are reported from the same areas.
For each group, provide a summary of the situation, the total people affected in that area, and the collective severity level.

Return strictly a JSON object with the following structure:
{
  "summary": "A high-level overview of all incidents combined",
  "groups": [
    {
      "area": "Area Name",
      "incidentCount": 5,
      "totalAffected": 20,
      "collectiveSeverity": "High",
      "analysis": "A detailed analysis of what's happening in this area",
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
