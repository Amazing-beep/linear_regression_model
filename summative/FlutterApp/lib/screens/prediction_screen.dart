import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prediction_request.dart';
import '../models/prediction_response.dart';
import '../services/prediction_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/prediction_card.dart';

/// The primary prediction page containing input controls for all 8 variables,
/// form validation, API submission, and result display.
class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final PredictionService _predictionService = PredictionService();

  // API Base URL controller
  final TextEditingController _urlController = TextEditingController(
    text: PredictionService.defaultBaseUrl,
  );

  // Controllers for Numeric TextFields
  final TextEditingController _englishMinutesController = TextEditingController(
    text: '250',
  );
  final TextEditingController _englishStudentsController =
      TextEditingController(text: '25');
  final TextEditingController _schoolSizeController = TextEditingController(
    text: '1200',
  );

  // State variables for Dropdowns
  int _selectedGrade = 10;
  String _selectedGender = 'Female'; // 'Male' -> 1, 'Female' -> 0
  String _selectedRaceEth = 'White';
  String _selectedExpectBachelors = 'Yes'; // 'Yes' -> 1.0, 'No' -> 0.0
  String _selectedRead30Mins = 'Yes'; // 'Yes' -> 1.0, 'No' -> 0.0

  // UI state tracking
  bool _isLoading = false;
  PredictionResponse? _predictionResponse;
  String? _errorMessage;

  // Dropdown option constants
  static const List<int> _gradeOptions = [8, 9, 10, 11, 12];
  static const List<String> _genderOptions = ['Female', 'Male'];
  static const List<String> _raceEthOptions = [
    'White',
    'Hispanic',
    'Black',
    'Asian',
    'More than one race',
    'American Indian/Alaska Native',
    'Native Hawaiian/Other Pacific Islander',
  ];
  static const List<String> _yesNoOptions = ['Yes', 'No'];

  @override
  void dispose() {
    _urlController.dispose();
    _englishMinutesController.dispose();
    _englishStudentsController.dispose();
    _schoolSizeController.dispose();
    super.dispose();
  }

  Future<void> _handlePrediction() async {
    // Validate form inputs before attempting API submission
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionResponse = null;
      _errorMessage = null;
    });

    final request = PredictionRequest(
      grade: _selectedGrade,
      male: _selectedGender == 'Male' ? 1 : 0,
      raceeth: _selectedRaceEth,
      expectBachelors: _selectedExpectBachelors == 'Yes' ? 1.0 : 0.0,
      read30MinsADay: _selectedRead30Mins == 'Yes' ? 1.0 : 0.0,
      minutesPerWeekEnglish: double.parse(
        _englishMinutesController.text.trim(),
      ),
      studentsInEnglish: double.parse(_englishStudentsController.text.trim()),
      schoolSize: double.parse(_schoolSizeController.text.trim()),
    );

    try {
      final response = await _predictionService.predict(
        request,
        baseUrl: _urlController.text.trim(),
      );

      setState(() {
        _predictionResponse = response;
      });
    } on PredictionException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
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
          'PISA Reading Score Predictor',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner & Subtitle
              Card(
                elevation: 0,
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PISA Reading Score Predictor',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Predict a student's reading assessment score using the trained machine learning model.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // API Endpoint Settings Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_queue_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'API Endpoint Configuration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'e.g., https://my-app.onrender.com',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'API Base URL cannot be empty';
                          }
                          if (!value.trim().startsWith('http://') &&
                              !value.trim().startsWith('https://')) {
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

              // Inputs Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Student & School Inputs (8 Features)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input 1: Grade (Dropdown)
                      DropdownButtonFormField<int>(
                        initialValue: _selectedGrade,
                        decoration: const InputDecoration(
                          labelText: '1. Grade',
                          prefixIcon: Icon(Icons.school_rounded),
                        ),
                        items: _gradeOptions.map((grade) {
                          return DropdownMenuItem<int>(
                            value: grade,
                            child: Text('Grade $grade'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGrade = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 2: Gender (Dropdown)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: '2. Gender',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        items: _genderOptions.map((gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGender = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 3: Race / Ethnicity (Dropdown)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRaceEth,
                        decoration: const InputDecoration(
                          labelText: '3. Race / Ethnicity',
                          prefixIcon: Icon(Icons.public_rounded),
                        ),
                        isExpanded: true,
                        items: _raceEthOptions.map((race) {
                          return DropdownMenuItem<String>(
                            value: race,
                            child: Text(race, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRaceEth = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 4: Expects Bachelor's Degree (Dropdown)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedExpectBachelors,
                        decoration: const InputDecoration(
                          labelText: '4. Expects Bachelor\'s Degree',
                          prefixIcon: Icon(Icons.history_edu_rounded),
                        ),
                        items: _yesNoOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedExpectBachelors = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 5: Reads 30 Minutes Daily (Dropdown)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRead30Mins,
                        decoration: const InputDecoration(
                          labelText: '5. Reads 30 Minutes Daily',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                        items: _yesNoOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRead30Mins = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 6: Minutes Per Week English (Numeric TextField)
                      TextFormField(
                        controller: _englishMinutesController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: '6. Minutes Per Week English',
                          hintText: 'e.g. 250',
                          prefixIcon: Icon(Icons.timer_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter English class minutes';
                          }
                          final val = double.tryParse(value.trim());
                          if (val == null) {
                            return 'Please enter a valid numeric value';
                          }
                          if (val < 0 || val > 3000) {
                            return 'Minutes must be between 0 and 3000';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 7: Students In English Class (Numeric TextField)
                      TextFormField(
                        controller: _englishStudentsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: '7. Students In English Class',
                          hintText: 'e.g. 25',
                          prefixIcon: Icon(Icons.groups_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter class student count';
                          }
                          final val = double.tryParse(value.trim());
                          if (val == null) {
                            return 'Please enter a valid numeric value';
                          }
                          if (val < 0 || val > 100) {
                            return 'Student count must be between 0 and 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 8: School Size (Numeric TextField)
                      TextFormField(
                        controller: _schoolSizeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: '8. School Size',
                          hintText: 'e.g. 1200',
                          prefixIcon: Icon(Icons.domain_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter school enrollment size';
                          }
                          final val = double.tryParse(value.trim());
                          if (val == null) {
                            return 'Please enter a valid numeric value';
                          }
                          if (val < 0 || val > 10000) {
                            return 'School size must be between 0 and 10000';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Predict Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePrediction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Loading State Indicator
              if (_isLoading) const LoadingWidget(),

              // Output Display Area (Prediction Card)
              if (_predictionResponse != null)
                PredictionCard(
                  score: _predictionResponse!.predictedReadingScore,
                  modelName: _predictionResponse!.model,
                ),

              // Error Display Area
              if (_errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red.shade700,
                            ),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
