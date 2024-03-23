import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Face? clicked;

  late final FocusNode focusNode;

  // tracks keyboard keys
  final Map<LogicalKeyboardKey, bool> _keyDown = {};

  // (uncomment line in Object3D constructor)
  // ignore: unused_element
  Face _fresnel(Face face) {
    final color = clicked == face ? Colors.red : Colors.blue;
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

  void _handleFrameTick(Timer _) {
    if (_keyDown[LogicalKeyboardKey.keyA] ?? false) {
      myCamera.move(Vector3(-10.0, 0.0, 0.0));
    }

    if (_keyDown[LogicalKeyboardKey.keyD] ?? false) {
      myCamera.move(Vector3(10.0, 0.0, 0.0));
    }

    if (_keyDown[LogicalKeyboardKey.keyW] ?? false) {
      myCamera.move(Vector3(0.0, 0.0, -10.0));
    }

    if (_keyDown[LogicalKeyboardKey.keyS] ?? false) {
      myCamera.move(Vector3(0.0, 0.0, 10.0));
    }

    if (_keyDown[LogicalKeyboardKey.keyQ] ?? false) {
      myCamera.move(Vector3(0.0, -10.0, 0.0));
    }

    if (_keyDown[LogicalKeyboardKey.keyE] ?? false) {
      myCamera.move(Vector3(0.0, 10.0, 0.0));
    }

    if (_keyDown[LogicalKeyboardKey.keyR] ?? false) {
      // will rotate the camera to look at the origin from anywhere
      myCamera.look(Vector3(0.0, 0.0, 0.0));
    }

    if (_keyDown[LogicalKeyboardKey.space] ?? false) {
      // reset
      myCamera.warp(Vector3(0.0, 0.0, -200.0));
    }
  }

  void _handleRayHit(Face face) {
    clicked = face;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object 3D Example'),
      ),
      body: Center(
        child: KeyboardListener(
          focusNode: focusNode,
          autofocus: true,
          onKeyEvent: (e) => _keyDown[e.logicalKey] = !(e is KeyUpEvent),
          child: Object3D(
            cam: myCamera,
            path: "assets/file.obj",
            modelScale: 100,
            adaptiveViewport: true,
            color: Colors.blue,
            onTick: _handleFrameTick,
            onRayHit: _handleRayHit,
            //faceColorFunc: _fresnel, // uncomment to see in action
          ),
        ),
      ),
    );
  }
}
