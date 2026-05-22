import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  final apiKey = 'REDACTED_API_KEY'; // Provided by user
  
  print('Testing Gemini 1.5 Flash...');
  try {
    final modelFlash = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    final responseFlash = await modelFlash.generateContent([Content.text('Hello! Are you working?')]);
    print('✅ SUCCESS (1.5 Flash)! Response: ${responseFlash.text}');
  } catch (e) {
    print('❌ ERROR (1.5 Flash): $e');
  }

  print('\nTesting Gemini Pro (older text model)...');
  try {
    final modelPro = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    final responsePro = await modelPro.generateContent([Content.text('Hello! Are you working?')]);
    print('✅ SUCCESS (Pro)! Response: ${responsePro.text}');
  } catch (e) {
    print('❌ ERROR (Pro): $e');
  }

  print('\nTesting Gemini Pro Vision (older vision model)...');
  try {
    final modelVision = GenerativeModel(model: 'gemini-pro-vision', apiKey: apiKey);
    final responseVision = await modelVision.generateContent([Content.text('Hello!')]);
    print('✅ SUCCESS (Pro Vision)! Response: ${responseVision.text}');
  } catch (e) {
    print('❌ ERROR (Pro Vision): $e');
  }
}
