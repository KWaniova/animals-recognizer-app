import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<StatefulWidget> createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  Uint8List? _image;

  CataractState _state = CataractState.initial;
  bool isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      isLoading = true;
      _state = CataractState.processing;
    });

    final ImagePicker picker = ImagePicker();
    print("source");
    print(source);
    try {
      XFile? image = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        setState(() {
          _state = CataractState.failure;
        });
      } else {
        Uint8List? result = File(image.path).readAsBytesSync();
        setState(() {
          _state = CataractState.success;
          _image = result;
        });
        print("RUN PREDICTION");
        _predictCatDog(result);
      }
    } catch (e) {
      setState(() {
        _state = CataractState.failure;
      });

      print(e);
    }
    setState(() {
      isLoading = false;
    });
  }

  //  List<List<List<double>>> _imageToTensor(img.Image image) {
  //   // Convert the image into a tensor (3D list)
  //   List<List<List<double>>> tensorImage = List.generate(
  //     224,  // Assuming input size of 224x224, adjust if different
  //     (y) => List.generate(
  //       224,
  //       (x) => [
  //         (image.getPixel(x, y) & 0xFF) / 255.0,              // Red channel
  //         ((image.getPixel(x, y) >> 8) & 0xFF) / 255.0,       // Green channel
  //         ((image.getPixel(x, y) >> 16) & 0xFF) / 255.0       // Blue channel
  //       ],
  //     ),
  //   );
  //   return tensorImage;
  // }

  void _predictCatDog(Uint8List bytes) async {
    final interpreter =
        await Interpreter.fromAsset('assets/models/model.tflite');
    // Decoding image
    final image = img.decodeImage(bytes);

    // Resizing image fpr model, [300, 300]
    final imageInput = img.copyResize(
      image!,
      width: 300,
      height: 300,
    );

    // Creating matrix representation, [300, 300, 3]
    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );
    // Set output tensor
    // Locations: [1, 10, 4]
    // Classes: [1, 10],
    // Scores: [1, 10],
    // Number of detections: [1]
    // final input = imageToByteListFloat32(imageBytes, 224, 224, 3);
    final output = {
      0: [List<List<num>>.filled(10, List<num>.filled(4, 0))],
      1: [List<num>.filled(2, 0)],
      2: [List<num>.filled(2, 0)],
      3: [0.0],
    };
    // final output = List<List<dynamic>>.filled(
    //     1, List<dynamic>.filled(1001, 0)); // Assuming 1001 output classes
    interpreter.run(imageMatrix, output);
    print(output);
    // print(output.values.toList());
  }

  @override
  void initState() {
    super.initState();

    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   _pickImage(ImageSource.camera);
    // });
  }

  Widget showImagePreview(Uint8List? image) {
    return image == null
        ? Expanded(
            child: Card(
              color: Colors.white,
              child: Container(
                alignment: Alignment.center,
                height: 100,
                child: const Text(
                  "No image selected",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          )
        : Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  image,
                  height: 100,
                  fit: BoxFit.cover,
                )),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera view"),
      ),
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: !isLoading
                ? Column(
                    children: [
                      showImagePreview(_image),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _pickImage(ImageSource.camera);
                            },
                            child: const Text("Camera"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _pickImage(ImageSource.gallery);
                            },
                            child: const Text("Gallery"),
                          ),
                        ],
                      ),
                    ],
                  )
                : SizedBox(),
          ),
        ),
        isLoading
            ? Container(
                height: double.infinity,
                width: double.infinity,
                color: Colors.white.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                  ),
                ),
              )
            : SizedBox(),
      ]),
    );
  }
}

enum CataractState {
  initial,
  selected,
  uploading,
  success,
  failure,
  completed,
  processing
}
