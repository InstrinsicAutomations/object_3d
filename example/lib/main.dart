import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:object_3d/object_3d.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Make a 400x400 viewport with 45 deg FOV, 10 near plane, and 1000 far plane
  // and then place (warp) camera -200 units away from the origin (0,0)
  Camera myCamera =
      Camera(viewPort: Size(400, 400), fov: 45.0, near: 10, far: 1000)
        ..warp(Vector3(0.0, 0.0, -200.0));

  late final FocusNode focusNode;

  // (uncomment line in Object3D constructor)
  // ignore: unused_element
  Face _fresnel(Face face) {
    final color = Colors.blue;
    final light = Vector3(0.0, 0.0, 100.0).normalized();
    double ln1 = light.dot(face.normal);
    double s1 = 1.0 + face.v1.normalized().dot(face.normal);
    double s2 = 1.0 + face.v2.normalized().dot(face.normal);
    double s3 = 1.0 + face.v3.normalized().dot(face.normal);
    double power = 2;

    Color c = Color.fromRGBO(
        (color.red + math.pow(s1, power).round()).clamp(0, 255),
        (color.green + math.pow(s2, power).round()).clamp(0, 255),
        (color.blue + math.pow(s3, power).round()).clamp(0, 255),
        1.0 - ln1.abs());
    return face..setColors(c, c, c);
  }

  void _handleCameraControls(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      myCamera.move(Vector3(-10.0, 0.0, 0.0));
    }

    if (event.logicalKey == LogicalKeyboardKey.keyD) {
      myCamera.move(Vector3(10.0, 0.0, 0.0));
    }

    if (event.logicalKey == LogicalKeyboardKey.keyW) {
      myCamera.move(Vector3(0.0, 0.0, 10.0));
    }

    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      myCamera.move(Vector3(0.0, 0.0, -10.0));
    }

    if (event.logicalKey == LogicalKeyboardKey.keyQ) {
      myCamera.move(Vector3(0.0, -10.0, 0.0));
    }

    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      myCamera.move(Vector3(0.0, 10.0, 0.0));
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      // reset
      myCamera.warp(Vector3(0.0, 0.0, -200.0));
    }
  }

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We can update the camera view frustum
    myCamera.viewPort = (MediaQuery.of(context).size);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Object 3D Example'),
      ),
      backgroundColor: Colors.red,
      body: Center(
        child: KeyboardListener(
          focusNode: focusNode,
          autofocus: true,
          onKeyEvent: _handleCameraControls,
          child: Object3D(
            cam: myCamera,
            path: "assets/file.obj",
            color: Colors.blue,
            // faceColorFunc: _fresnel, // uncomment to see in action
          ),
        ),
      ),
    );
  }
}
