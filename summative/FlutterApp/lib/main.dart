import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StudentPredictorApp());
}

class StudentPredictorApp extends StatelessWidget {
  const StudentPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PISA Student Reading Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), // Deep Indigo
          primary: const Color(0xFF3F51B5),
          secondary: const Color(0xFF00BCD4), // Cyan accent
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controller for API Base URL
  final TextEditingController _urlController = TextEditingController(
    text: "https://linear-regression-model-summit.onrender.com" // Default placeholder production URL
  );

  // Controllers for the 8 variables
  final TextEditingController _gradeController = TextEditingController(text: "10");
  final TextEditingController _maleController = TextEditingController(text: "0");
  final TextEditingController _raceethController = TextEditingController(text: "White");
  final TextEditingController _expectBachelorsController = TextEditingController(text: "1");
  final TextEditingController _read30MinsController = TextEditingController(text: "1");
  final TextEditingController _englishMinutesController = TextEditingController(text: "250");
  final TextEditingController _englishStudentsController = TextEditingController(text: "25");
  final TextEditingController _schoolSizeController = TextEditingController(text: "1200");

  bool _isLoading = false;
  String? _predictedScore;
  String? _errorMessage;

  // List of valid raceeth options for user reference
  final List<String> _validEthnicities = [
    "White", 
    "Hispanic", 
    "Black", 
    "Asian", 
    "More than one race", 
    "American Indian/Alaska Native", 
    "Native Hawaiian/Other Pacific Islander"
  ];

  Future<void> _getPrediction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _predictedScore = null;
      _errorMessage = null;
    });

    final String baseUrl = _urlController.text.trim();
    // Ensure path ends with /predict
    final String fullUrl = baseUrl.endsWith('/') ? '${baseUrl}predict' : '$baseUrl/predict';

    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "grade": int.parse(_gradeController.text.trim()),
          "male": int.parse(_maleController.text.trim()),
          "raceeth": _raceethController.text.trim(),
          "expectBachelors": double.parse(_expectBachelorsController.text.trim()),
          "read30MinsADay": double.parse(_read30MinsController.text.trim()),
          "minutesPerWeekEnglish": double.parse(_englishMinutesController.text.trim()),
          "studentsInEnglish": double.parse(_englishStudentsController.text.trim()),
          "schoolSize": double.parse(_schoolSizeController.text.trim()),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _predictedScore = data['predicted_reading_score'].toStringAsFixed(2);
        });
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['detail'] ?? "API error: status code ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection failed. Please verify the API Base URL is running and accessible.\nDetails: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PISA Performance Predictor',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        elevation: 2,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50.withValues(alpha: 0.3),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. API Settings Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'API Endpoint Settings',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'API Base URL',
                            hintText: 'e.g., https://my-render-api.com',
                            prefixIcon: Icon(Icons.link),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'API Base URL cannot be empty';
                            }
                            if (!value.startsWith('http://') && !value.startsWith('https://')) {
                              return 'URL must start with http:// or https://';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Input Fields Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student & School Characteristics',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                        ),
                        const SizedBox(height: 16),

                        // Field 1: Grade
                        TextFormField(
                          controller: _gradeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Grade Level (8-12)',
                            hintText: 'Enter student grade (e.g. 10)',
                            prefixIcon: Icon(Icons.school),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter grade';
                            final val = int.tryParse(value);
                            if (val == null || val < 8 || val > 12) {
                              return 'Grade must be an integer between 8 and 12';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 2: Gender (male)
                        TextFormField(
                          controller: _maleController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Male Indicator (0 = Female, 1 = Male)',
                            hintText: 'Enter 0 or 1',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter gender';
                            final val = int.tryParse(value);
                            if (val != 0 && val != 1) {
                              return 'Gender must be 0 (Female) or 1 (Male)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 3: Race/Ethnicity (raceeth)
                        TextFormField(
                          controller: _raceethController,
                          decoration: const InputDecoration(
                            labelText: 'Race / Ethnicity',
                            hintText: 'e.g. White, Hispanic, Black, Asian',
                            prefixIcon: Icon(Icons.public),
                            helperText: 'Options: White, Hispanic, Black, Asian, More than one race, etc.',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Please enter ethnicity';
                            if (!_validEthnicities.contains(value.trim())) {
                              return 'Must match one of the valid PISA category spellings';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 4: Expect Bachelors
                        TextFormField(
                          controller: _expectBachelorsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Expects Bachelor\'s Degree (0 = No, 1 = Yes)',
                            hintText: 'Enter 0 or 1',
                            prefixIcon: Icon(Icons.history_edu),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please fill this field';
                            final val = double.tryParse(value);
                            if (val == null || (val != 0 && val != 1)) {
                              return 'Value must be 0 (No) or 1 (Yes)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 5: Reads 30 Mins a Day
                        TextFormField(
                          controller: _read30MinsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reads 30+ Mins a Day (0 = No, 1 = Yes)',
                            hintText: 'Enter 0 or 1',
                            prefixIcon: Icon(Icons.menu_book),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please fill this field';
                            final val = double.tryParse(value);
                            if (val == null || (val != 0 && val != 1)) {
                              return 'Value must be 0 (No) or 1 (Yes)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 6: minutesPerWeekEnglish
                        TextFormField(
                          controller: _englishMinutesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'English Class Minutes per Week (0-3000)',
                            hintText: 'e.g. 250',
                            prefixIcon: Icon(Icons.timer),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter class minutes';
                            final val = double.tryParse(value);
                            if (val == null || val < 0 || val > 3000) {
                              return 'Must be a numeric value between 0 and 3000';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 7: studentsInEnglish
                        TextFormField(
                          controller: _englishStudentsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'English Class Student Count (0-100)',
                            hintText: 'e.g. 25',
                            prefixIcon: Icon(Icons.groups),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter student count';
                            final val = double.tryParse(value);
                            if (val == null || val < 0 || val > 100) {
                              return 'Must be a numeric value between 0 and 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Field 8: schoolSize
                        TextFormField(
                          controller: _schoolSizeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Total School Size (0-10000)',
                            hintText: 'e.g. 1200',
                            prefixIcon: Icon(Icons.domain),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter school size';
                            final val = double.tryParse(value);
                            if (val == null || val < 0 || val > 10000) {
                              return 'Must be a numeric value between 0 and 10000';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Predict Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _getPrediction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Predict',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),

                // 4. Output Display Area
                if (_predictedScore != null)
                  Card(
                    color: Colors.green.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.green.shade200, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'PREDICTED SCORE',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _predictedScore!,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Estimated reading competency score on the PISA metric scale.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_errorMessage != null)
                  Card(
                    color: Colors.red.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.red.shade200, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'ERROR',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
