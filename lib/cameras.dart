import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ClassifierScreen(),
    );
  }
}

class ClassifierScreen extends StatefulWidget {
  @override
  _ClassifierScreenState createState() => _ClassifierScreenState();
}

class _ClassifierScreenState extends State<ClassifierScreen> {
  late Interpreter _interpreter;
  File? _image;
  final picker = ImagePicker();
  String _result = '';

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/model.tflite');
      print("Model loaded successfully");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _predictImage(_image!);
    }
  }

  Future<void> _predictImage(File image) async {
    // Load the image and preprocess it
    img.Image imageInput = img.decodeImage(image.readAsBytesSync())!;
    img.Image resizedImage = img.copyResize(imageInput,
        width: 224, height: 224); // Adjust size to your model input

    // Convert image to a tensor input
    List<List<List<List<double>>>> input = _imageToTensor(resizedImage);

    // Prepare output tensor (modify according to model's output)
    var output = List.filled(1 * 2, 0.0)
        .reshape([1, 2]); // Assuming 2 classes (cat and dog)

    // Run inference
    _interpreter.run(input, output);

    // Process the result
    setState(() {
      if (output[0][0] > output[0][1]) {
        _result = 'Cat';
      } else {
        _result = 'Dog';
      }
    });
  }

  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    // Create a tensor with an added batch dimension
    List<List<List<List<double>>>> tensorImage = [
      List.generate(
        224, // Assuming input size of 224x224, adjust if different
        (y) => List.generate(
          224,
          (x) {
            final pixel = image.getPixel(x, y);
            final red = pixel.r / 255.0;
            final green = pixel.g / 255.0;
            final blue = pixel.b / 255.0;
            return [red, green, blue];
          },
        ),
      )
    ];
    return tensorImage;
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cat vs Dog Classifier"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null
                ? Image.file(_image!)
                : Text("Pick an image to classify"),
            SizedBox(height: 20),
            Text(
              'Prediction: $_result',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text("Pick Image"),
            ),
          ],
        ),
      ),
    );
  }
}
