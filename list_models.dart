import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'REDACTED_API_KEY';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  print('Fetching available models from Google...');
  
  try {
    final request = await HttpClient().getUrl(url);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      final models = data['models'] as List;
      print('\nGoogle says you have access to these models:');
      for (var m in models) {
        print('- ${m['name']}');
      }
    } else {
      print('❌ FAILED: ${response.statusCode} - $responseBody');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
