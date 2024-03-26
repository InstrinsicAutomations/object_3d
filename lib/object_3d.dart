library object_3d;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Vector4, Matrix4;

typedef FaceColorFunc = Face Function(Face face);
typedef TickFunc = void Function(Timer timer);
typedef RayHitFunc = void Function(Face face);

/// Represents a face (3 vertices) with color data
class Face {
  Vector3 _v1, _v2, _v3;
  Vector3? _cachedNormal;
  Color c1 = Colors.white, c2 = Colors.white, c3 = Colors.white;
  Face(this._v1, this._v2, this._v3);

  Face.copy(Face other)
      : _v1 = Vector3.copy(other._v1),
        _v2 = Vector3.copy(other._v2),
        _v3 = Vector3.copy(other._v3),
        _cachedNormal = other._cachedNormal != null
            ? Vector3.copy(other._cachedNormal!)
            : null,
        c1 = other.c1,
        c2 = other.c2,
        c3 = other.c3;

  void setColors(Color c1, Color c2, Color c3) {
    this.c1 = c1;
    this.c2 = c2;
    this.c3 = c3;
  }

  /// getters
  Vector3 get v1 {
    return _v1;
  }

  Vector3 get v2 {
    return _v2;
  }

  Vector3 get v3 {
    return _v3;
  }

  double get avgZ {
    return (_v1.z + _v2.z + _v3.z) / 3.0;
  }

  List<Color> get colors {
    return <Color>[c1, c2, c3];
  }

  /// setters - invalidate normal cache
  set v1(Vector3 v) {
    _cachedNormal = null;
    _v1 = v;
  }

  set v2(Vector3 v) {
    _cachedNormal = null;
    _v2 = v;
  }

  set v3(Vector3 v) {
    _cachedNormal = null;
    _v3 = v;
  }

  /// Calculate the unit normal vector of a face and cache the result
  Vector3 get normal {
    if (_cachedNormal != null) return Vector3.copy(_cachedNormal!);

    // Normal needs recalculating
    final Vector3 p = Vector3.copy(_v2)..sub(_v1);
    final Vector3 q = Vector3.copy(_v2)..sub(_v3);
    _cachedNormal = p.cross(q).normalized();

    return Vector3.copy(_cachedNormal!);
  }

  /// Misc. functions to appear iterable and reduce refactoring
  int get length {
    return 3;
  }

  Vector3 operator [](int index) {
    assert(index < 3, 'Face only has 3 elements!');

    if (index == 0) return _v1;
    if (index == 1) return _v2;

    //else
    return _v3;
  }

  operator []=(int index, Vector3 rhs) {
    assert(index < 3, 'Face only has 3 elements!');

    if (index == 0) {
      _v1 = rhs;
      return;
    }

    if (index == 1) {
      _v2 = rhs;
      return;
    }

    // else
    _v3 = rhs;
  }
}

/// Represents the ViewProjection matrix
class Camera {
  final Matrix4 _mat = Matrix4.identity();
  final Matrix4 proj = Matrix4.identity();
  Vector3 _up = Vector3(0, 1, 0);
  Vector3 _forward = Vector3(0, 0, -1);
  Vector3 _right = Vector3(1, 0, 0);
  Vector3 _pos = Vector3(0, 0, 0);
  Size _viewPort;
  double _fov; // in degrees
  double _near;
  double _far;
  bool _dirtyView = false;
  bool _dirtyFrustum = false;

  Camera({
    required Size viewPort,
    required double fov,
    required double near,
    required double far,
  })  : _viewPort = viewPort,
        _fov = fov,
        _near = near,
        _far = far {
    _calculateFrustum(viewPort, fov, near, far);
    look(Vector3.zero());
  }

  void look(Vector3 point) {
    final Vector3 eye = _pos;
    _forward = (point - eye).normalized();
    _right = _up.cross(_forward).normalized();
    _up = _forward.cross(_right).normalized();

    // Overwrite
    _mat.row0 = Vector4(_right.x, _right.y, _right.z, 0);
    _mat.row1 = Vector4(_up.x, _up.y, _up.z, 0);
    _mat.row2 = Vector4(_forward.x, _forward.y, _forward.z, 0);
    _mat.row3 = Vector4(0, 0, 0, 1.0);

    // preserve position by multiplying by translation matrix P
    final Matrix4 p = Matrix4.identity()
      ..setColumn(3, Vector4(eye.x, eye.y, eye.z, 1.0));
    _mat.multiply(p);
    _pos = _mat.getTranslation();

    _dirtyView = true;
  }

  /// Reset orientation and position of camera.
  /// Does not reset the projection matrix.
  void warp(Vector3 pos) {
    _forward = Vector3(0, 0, -1);
    _right = Vector3(1, 0, 0);
    _up = Vector3(0, 1, 0);

    // Overwrite
    _mat.row0 = Vector4(_right.x, _right.y, _right.z, 0);
    _mat.row1 = Vector4(_up.x, _up.y, _up.z, 0);
    _mat.row2 = Vector4(_forward.x, _forward.y, _forward.z, 0);
    _mat.row3 = Vector4(0, 0, 0, 1.0);

    // preserve position by multiplying by translation matrix P
    final Matrix4 p = Matrix4.identity()
      ..setColumn(3, Vector4(pos.x, pos.y, pos.z, 1.0));
    _mat.multiply(p);
    _pos = _mat.getTranslation();

    _dirtyView = true;
  }

  /// Move relative to the camera orientation (negate amount)
  /// e.g. -/+x will always be left/right, -/+y is up/down, etc.
  void move(Vector3 amount) {
    _pos -= (_forward * amount.z) + (_up * amount.y) + (_right * amount.x);
    _mat.setTranslation(_pos);
    _dirtyView = true;
  }

  Matrix4 get view {
    return Matrix4.zero()..copyInverse(_mat);
  }

  bool get needsRedraw {
    bool redraw = false;

    if (_dirtyView) {
      redraw = true;
    }

    if (_dirtyFrustum) {
      redraw = true;
      _calculateFrustum(_viewPort, _fov, _near, _far);
    }

    _dirtyView = false;
    _dirtyFrustum = false;

    return redraw;
  }

  //
  // Changes to these fields require rebuilding frustum
  //
  Size get viewPort {
    return _viewPort;
  }

  // angle is in degrees
  set fov(double angle) {
    _fov = angle;
    _dirtyFrustum = true;
  }

  // fov angle is in degrees
  double get fov {
    return _fov;
  }

  set near(double n) {
    _near = n;
    _dirtyFrustum = true;
  }

  double get near {
    return _near;
  }

  set far(double f) {
    _far = f;
    _dirtyFrustum = true;
  }

  double get far {
    return _far;
  }

  void _calculateFrustum(Size bounds, double fov, double near, double far) {
    final double a = bounds.width / bounds.height;
    final double theta = (fov * math.pi) / 180.0;
    final double ta = math.tan(theta / 2.0);
    final double farSubNear = far - near;

    proj[0] = 1.0 / (ta * a);
    proj[5] = 1.0 / ta;
    proj[10] = -(far + near) / farSubNear;
    proj[11] = -1.0;
    proj[14] = (-2.0 * far * near) / farSubNear;
    proj[15] = 0.0;
  }
}

class Object3D extends StatefulWidget {
  const Object3D({
    required this.cam,
    super.key,
    this.color = Colors.white,
    this.object,
    this.path,
    this.modelScale = 1.0,
    this.swipeCoef = 0.1,
    this.dampCoef = 0.92,
    this.maxSpeed = 10.0,
    this.adaptiveViewport = false,
    this.reversePitch = true,
    this.reverseYaw = false,
    this.faceColorFunc,
    this.onTick,
    this.onRayHit,
  })  : assert(
          object != null || path != null,
          'You must provide an object or a path',
        ),
        assert(
          object == null || path == null,
          'You must provide an object or a path, not both',
        ),
        assert(
          swipeCoef > 0,
          'Parameter swipeCoef must be a positive, non-zero real number.',
        ),
        assert(
          dampCoef >= 0.001 && dampCoef <= 0.999,
          'Parameter dampCoef must be in the range [0.001, 0.999].',
        ),
        assert(
          maxSpeed > 0,
          'Parameter maxSpeed must be positive, non-zero real number.',
        );

  final Camera cam;
  final String? path;
  final String? object;
  final Color color;
  final double swipeCoef; // pan delta intensity
  final double dampCoef; // psuedo-friction 0.001-0.999
  final double maxSpeed; // in rots per 16 ms
  final double modelScale; // Scale of the .obj model (default: 1:1)
  final bool adaptiveViewport; // If true, calculates the viewport from parent
  final bool reversePitch; // if true, rotation direction is flipped for pitch
  final bool reverseYaw; // if true, rotation direction is flipped for yaw
  final FaceColorFunc? faceColorFunc; // If unset, uses _defaultFaceColor()
  final TickFunc? onTick; // Optional callback to perform extra ops on tick
  final RayHitFunc? onRayHit; // Optional callback to perform a ray hit check

  @override
  State<Object3D> createState() => _Object3DState();
}

class _Object3DState extends State<Object3D> {
  double _pitch = 0.0, _yaw = 0.0;
  double? _previousX, _previousY;
  double _deltaX = 0.0, _deltaY = 0.0;
  Offset? _pendingRay;
  List<Face> faces = <Face>[];
  late Timer _updateTimer;

  @override
  void initState() {
    if (widget.path != null) {
      // Load the object file from assets.
      rootBundle.loadString(widget.path!).then(_parseObj);
    } else if (widget.object != null) {
      // Load the object from a string.
      _parseObj(widget.object!);
    }

    _updateTimer =
        Timer.periodic(const Duration(milliseconds: 16), (Timer timer) {
      if (!mounted) return;
      widget.onTick?.call(timer);
      setState(() {
        final double adx = _deltaX.abs();
        final double ady = _deltaY.abs();
        final int sx = _deltaX < 0 ? -1 : 1;
        final int sy = _deltaY < 0 ? -1 : 1;

        _deltaX = math.min(widget.maxSpeed, adx) * sx * widget.dampCoef;
        _deltaY = math.min(widget.maxSpeed, ady) * sy * widget.dampCoef;

        _yaw = _yaw - (_deltaX * (widget.reversePitch ? -1 : 1));
        _pitch = _pitch - (_deltaY * (widget.reverseYaw ? -1 : 1));
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _updateTimer.cancel();
  }

  /// Parse the object file.
  void _parseObj(String obj) {
    final List<Vector3> vertices = <Vector3>[];
    final List<List<int>> faceIdx = <List<int>>[];
    final List<Face> faces = <Face>[];
    final List<String> lines = obj.split('\n');
    for (String line in lines) {
      const String space = ' ';
      line = line.replaceAll(RegExp(r'\s+'), space);

      // Split into tokens and drop empty tokens.
      final List<String> chars = line
          .split(space)
          .where((String v) => v.isNotEmpty)
          .toList(growable: false);

      if (chars.isEmpty) continue;

      if (chars[0] == 'v') {
        vertices.add(
          Vector3(
            double.parse(chars[1]),
            double.parse(chars[2]),
            double.parse(chars[3]),
          ),
        );
      } else if (chars[0] == 'f') {
        final List<int> face = <int>[];
        for (int i = 1; i < chars.length; i++) {
          face.add(int.parse(chars[i].split('/')[0]));
        }
        faceIdx.add(face);
      }
    }

    for (int i = 0; i < faceIdx.length; i++) {
      final List<int> verts = faceIdx[i];
      final Vector3 v1 = vertices[verts[0] - 1];
      final Vector3 v2 = vertices[verts[1] - 1];
      final Vector3 v3 = vertices[verts[2] - 1];
      faces.add(Face(v1, v2, v3));
    }

    setState(() {
      this.faces = faces;
    });
  }

  /// Update the angle of rotation based on the change in position.
  void _handlePanDelta(DragUpdateDetails data) {
    if (_previousY != null) {
      _deltaY += widget.swipeCoef * (_previousY! - data.globalPosition.dy);
    }
    _previousY = data.globalPosition.dy;

    if (_previousX != null) {
      _deltaX += widget.swipeCoef * (_previousX! - data.globalPosition.dx);
    }
    _previousX = data.globalPosition.dx;
  }

  // Invalidates _previousX and _previousY.
  void _handlePanEnd(DragEndDetails _) {
    _previousX = null;
    _previousY = null;
  }

  // Queues a 2D point for casting and testing a ray in the next repaint.
  void _handleRayTestStart(TapDownDetails data) {
    _pendingRay = data.localPosition;
  }

  void _forwardRayHit(Face face) {
    _pendingRay = null;
    widget.onRayHit?.call(face);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.adaptiveViewport) {
      widget.cam._viewPort = (MediaQuery.of(context).size);
      widget.cam._dirtyFrustum = true;
    }

    return GestureDetector(
      onPanUpdate: _handlePanDelta,
      onPanEnd: _handlePanEnd,
      onDoubleTapDown: _handleRayTestStart,
      child: ClipRect(
        child: CustomPaint(
          size: widget.cam.viewPort,
          painter: _ObjectPainter(
            cam: widget.cam,
            modelScale: widget.modelScale,
            pitch: _pitch,
            yaw: _yaw,
            roll: 0,
            color: widget.color,
            faces: faces,
            faceColorFunc: widget.faceColorFunc,
            rayHitFunc: _forwardRayHit,
            pendingRay: _pendingRay,
          ),
        ),
      ),
    );
  }
}

class _ObjectPainter extends CustomPainter {
  /// Fundamentally, the 3D object's model matrix parts.
  final double pitch, yaw, roll, modelScale;

  /// The calculated model matrix for reverse projection later.
  final Matrix4 mat = Matrix4.identity();

  final Color color;
  final List<Face> faces;
  final Camera cam;

  final FaceColorFunc? faceColorFunc;
  final RayHitFunc? rayHitFunc;
  final Offset? pendingRay;

  late final List<Face?> clipFaces;
  late final List<Color> clipColors;
  late final List<Offset> clipOffsets;

  _ObjectPainter({
    required this.cam,
    required this.modelScale,
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.color,
    required this.faces,
    this.faceColorFunc,
    this.rayHitFunc,
    this.pendingRay,
  }) {
    mat.scale(modelScale, modelScale);
    mat.rotateX(_degreeToRadian(pitch));
    mat.rotateY(_degreeToRadian(yaw));
    mat.rotateZ(_degreeToRadian(roll));

    // Allocate enough space for clip values
    clipFaces = List<Face?>.generate(
      faces.length,
      (int index) => null,
      growable: false,
    );

    clipColors = List<Color>.generate(
      faces.length * 3,
      (int _) => Colors.black,
      growable: false,
    );

    // Draw the vertices.
    clipOffsets = List<Offset>.generate(
      faces.length * 3,
      (int _) => Offset.zero,
      growable: false,
    );
  }

  /// Convert degree to radian.
  double _degreeToRadian(double degree) {
    return degree * (math.pi / 180.0);
  }

  /// Calculate the 2D-positions of a vertex in the 3D space.
  Face? _clipSpace(Face input, Matrix4 viewProj, Offset center) {
    final Face out = Face.copy(input);

    for (int i = 0; i < out.length; i++) {
      final Vector3 iV = out[i];
      final Vector4 v = viewProj * Vector4(iV.x, iV.y, iV.z, 1.0);
      final double w = v.w;

      // Outside of frustum. Discard.
      if (v.x < -w || v.x > w || v.y < -w || v.y > w || v.z < -w || v.z > w) {
        return null;
      }

      final double x = (v.x / w) * center.dx;
      final double y = (v.y / w) * center.dy;
      final double z = v.z / w;

      out[i] = Vector3(x + center.dx, y + center.dy, z);
    }
    return out;
  }

  /// Calculate the color of a vertex based on the
  /// position of the vertex and the light.
  Face _defaultFaceColor(Face face) {
    final Vector3 light = Vector3(0.0, 0.0, -1.0);

    final double s = face.normal.dot(light);
    final num coefficient = math.max(0, s);
    final Color c = Color.fromRGBO(
      (color.red * coefficient).round(),
      (color.green * coefficient).round(),
      (color.blue * coefficient).round(),
      1,
    );
    face.setColors(c, c, c);
    return face;
  }

  bool _rayIntersects(Vector3 from, Vector3 to, Face face) {
    final Vector3 ab = face.v2 - face.v1;
    final Vector3 ac = face.v3 - face.v1;
    final Vector3 qp = from - to;

    final Vector3 n = ab.cross(ac);
    final double d = qp.dot(n);

    if (d <= 0) return false;

    final Vector3 ap = from - face.v1;
    final double t = ap.dot(n);
    if (t < 0) return false;

    final Vector3 e = qp.cross(ap);
    final double v = ac.dot(e);
    if (v < 0 || v > d) return false;
    final double w = -ab.dot(e);
    if (w < 0 || v + w > d) return false;

    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Used for mouse reprojection later
    final Offset center = cam.viewPort.center(Offset.zero);
    final Matrix4 viewProj = cam.proj * cam.view;
    final Matrix4 invViewProj = Matrix4.zero()..copyInverse(viewProj);

    // Growble list for potential geometry to ray-test
    final List<Face> rayTestResults = <Face>[];

    // Track how many faces are actually drawn
    int faceLen = 0;

    for (int i = 0; i < faces.length; i++) {
      final Face face = Face.copy(faces[i]);

      // Apply world transformation on face
      face[0] = mat * face[0];
      face[1] = mat * face[1];
      face[2] = mat * face[2];

      // Fallback on default color func if a custom one is not provided.
      faceColorFunc?.call(face) ?? _defaultFaceColor(face);

      if (pendingRay != null) {
        // Reverse NDC correction.
        final Vector4 screenPoint = Vector4(
          (pendingRay!.dx - center.dx) / center.dx,
          (pendingRay!.dy - center.dy) / center.dy,
          1,
          1,
        );

        // Calculate ray from screen-space point.
        final Vector4 worldPoint = invViewProj * screenPoint;

        if (worldPoint.w != 0) {
          worldPoint.xyzw /= worldPoint.w;
        }

        // Test the ray if it falls within a 3D surface (triangle).
        if (_rayIntersects(worldPoint.xyz, cam._pos, face)) {
          rayTestResults.add(face);
        }
      }

      final Face? out = _clipSpace(face, viewProj, center);

      if (out == null) continue;

      clipFaces[faceLen++] = out;
    }

    // Emit the closest face hit by the ray test.
    if (rayTestResults.isNotEmpty) {
      // If set this function can change the color of the face
      // or use it in some other computation.
      rayHitFunc?.call(rayTestResults.last);
    }

    // Order points by the distance to the camera.
    // TODO: this is so slow!
    /*clipFaces.sort((Face? a, Face? b) {
      if (b == null) return a?.avgZ.floor() ?? 0;
      if (a == null) return -b.avgZ.floor();

      return a.avgZ.compareTo(b.avgZ);
    });*/

    // Extract the final colors and verts from the faces.
    final int dataLen = faceLen * 3;
    for (int i = 0; i < dataLen; i++) {
      final Face face = clipFaces[i ~/ 3]!;
      final int idx = i % 3;
      clipColors[i] = face.colors[idx];

      final Vector3 vert = face[idx];
      clipOffsets[i] = Offset(vert.x, vert.y);
    }

    final Paint paint = Paint();
    paint.style = PaintingStyle.fill;
    paint.color = color;
    final Vertices v =
        Vertices(VertexMode.triangles, clipOffsets, colors: clipColors);
    canvas.drawVertices(v, BlendMode.srcOver, paint);
  }

  @override
  bool shouldRepaint(_ObjectPainter old) =>
      old.cam != cam ||
      old.cam.needsRedraw ||
      old.modelScale != modelScale ||
      old.faces != faces ||
      old.pitch != pitch ||
      old.yaw != yaw ||
      old.roll != roll;
}
