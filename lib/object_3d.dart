library object_3d;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart'
    show Vector2, Vector3, Vector4, Matrix4;

typedef FaceColorFunc = Face Function(Face face);
typedef TickFunc = void Function(Timer timer);
typedef RayHitFunc = void Function(Face face);

/// Represents a face (3 vertices) with color data
class Face {
  Vector3 _v1, _v2, _v3;
  Vector3? _cachedNormal;
  Color c1 = Colors.white, c2 = Colors.white, c3 = Colors.white;
  Face(this._v1, this._v2, this._v3);

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
    return _v1;
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
}

/// Represents the ViewProjection matrix
class Camera {
  final Matrix4 view = Matrix4.identity();
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
    view.row0 = Vector4(_right.x, _right.y, _right.z, 0);
    view.row1 = Vector4(_up.x, _up.y, _up.z, 0);
    view.row2 = Vector4(_forward.x, _forward.y, _forward.z, 0);
    view.row3 = Vector4(0, 0, 0, 1.0);

    // preserve position by multiplying by translation matrix P
    final Matrix4 p = Matrix4.identity()
      ..setColumn(3, Vector4(eye.x, eye.y, eye.z, 1.0));
    view.multiply(p);
    _pos = view.getTranslation();

    _dirtyView = true;
  }

  /// Reset orientation and position of camera.
  /// Does not reset the projection matrix.
  void warp(Vector3 pos) {
    _forward = Vector3(0, 0, -1);
    _right = Vector3(1, 0, 0);
    _up = Vector3(0, 1, 0);

    // Overwrite
    view.row0 = Vector4(_right.x, _right.y, _right.z, 0);
    view.row1 = Vector4(_up.x, _up.y, _up.z, 0);
    view.row2 = Vector4(_forward.x, _forward.y, _forward.z, 0);
    view.row3 = Vector4(0, 0, 0, 1.0);

    // preserve position by multiplying by translation matrix P
    final Matrix4 p = Matrix4.identity()
      ..setColumn(3, Vector4(pos.x, pos.y, pos.z, 1.0));
    view.multiply(p);
    _pos = view.getTranslation();

    _dirtyView = true;
  }

  /// Move relative to the camera orientation
  /// e.g. -/+x will always be left/right, -/+y is up/down, etc.
  void move(Vector3 amount) {
    _pos += (_forward * amount.z) + (_up * amount.y) + (_right * amount.x);
    view.setTranslation(_pos);
    _dirtyView = true;
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
  List<Vector3> vertices = <Vector3>[];
  List<List<int>> faces = <List<int>>[];
  late Timer _updateTimer;

  @override
  void initState() {
    if (widget.path != null) {
      // Load the object file from assets
      rootBundle.loadString(widget.path!).then(_parseObj);
    } else if (widget.object != null) {
      // Load the object from a string
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
    final List<List<int>> faces = <List<int>>[];
    final List<String> lines = obj.split('\n');
    for (String line in lines) {
      const String space = ' ';
      line = line.replaceAll(RegExp(r'\s+'), space);

      // Split into tokens and drop empty tokens
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
        faces.add(face);
      }
    }
    setState(() {
      this.vertices = vertices;
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

    // TODO: remove after ray tests are working
    _pendingRay = data.localPosition;
  }

  // Invalidates _previousX and _previousY
  void _handlePanEnd(DragEndDetails _) {
    _previousX = null;
    _previousY = null;
  }

  // Queues a 2D point for casting and testing a ray in the next repaint
  void _handleRayTest(TapDownDetails data) {
    _pendingRay = data.localPosition;
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
      onDoubleTapDown: _handleRayTest,
      child: ClipRect(
        child: CustomPaint(
          size: widget.cam.viewPort,
          painter: _ObjectPainter(
            cam: widget.cam,
            modelScale: widget.modelScale,
            pitch: _pitch,
            yaw: _yaw,
            roll: 0,
            vertices: vertices,
            color: widget.color,
            faces: faces,
            faceColorFunc: widget.faceColorFunc,
            rayHitFunc: widget.onRayHit,
            pendingRay: _pendingRay,
          ),
        ),
      ),
    );
  }
}

class _ObjectPainter extends CustomPainter {
  /// Fundamentally, the 3D object's model matrix parts
  final double pitch, yaw, roll, modelScale;

  final Color color;

  final List<Vector3> vertices;
  final List<List<int>> faces;

  final Camera cam;

  final FaceColorFunc? faceColorFunc;
  final RayHitFunc? rayHitFunc;
  final Offset? pendingRay;

  _ObjectPainter({
    required this.cam,
    required this.modelScale,
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.vertices,
    required this.color,
    required this.faces,
    this.faceColorFunc,
    this.rayHitFunc,
    this.pendingRay,
  });

  /// Calculate the position of a vertex in the 3D space
  Vector3 _calcVertex(Vector3 vertex) {
    final Matrix4 model = Matrix4.identity();
    model.scale(modelScale, modelScale);
    model.rotateX(_degreeToRadian(pitch));
    model.rotateY(_degreeToRadian(yaw));
    model.rotateZ(_degreeToRadian(roll));
    return model.transform3(vertex);
  }

  /// Convert degree to radian.
  double _degreeToRadian(double degree) {
    return degree * (math.pi / 180.0);
  }

  /// Calculate the 2D-positions of a vertex in the 3D space.
  List<Offset> _drawFace(List<Vector3> vertices, List<int> face) {
    final List<Offset> coordinates = <Offset>[];
    for (int i = 0; i < face.length; i++) {
      Vector3 iV;
      if (i < face.length - 1) {
        iV = vertices[face[i + 1] - 1];
      } else {
        iV = vertices[face[0] - 1];
      }

      final Offset center = cam.viewPort.center(Offset.zero);
      final Matrix4 vp = cam.proj * cam.view;
      final Vector4 v = vp * Vector4(iV.x, iV.y, iV.z, 1.0);

      final double x = ((v.x / v.w) * center.dx);
      final double y = ((v.y / v.w) * center.dy);

      coordinates.add(Offset(x, y) + center);
    }
    return coordinates;
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

  /// Order vertices by the distance to the camera.
  List<AvgZ> _sortVertices(List<Vector3> vertices) {
    final List<AvgZ> avgOfZ = <AvgZ>[];
    for (int i = 0; i < faces.length; i++) {
      final List<int> face = faces[i];
      double z = 0.0;
      for (final int i in face) {
        z += vertices[i - 1].z;
      }
      avgOfZ.add(AvgZ(i, z));
    }
    avgOfZ.sort((AvgZ a, AvgZ b) => a.z.compareTo(b.z));
    return avgOfZ;
  }

  bool _pointInTriangle(Vector2 p, Face t) {
    Vector2 a = t.v1.xy;
    Vector2 b = t.v2.xy;
    Vector2 c = t.v3.xy;

    a -= p;
    b -= p;
    c -= p;

    final double ab = a.dot(b);
    final double ac = a.dot(c);
    final double bc = b.dot(c);
    final double cc = c.dot(c);

    if (bc * ac - cc * ab < 0.0) return false;

    final double bb = b.dot(b);
    if (ab * bc - ac * bb < 0.0) return false;

    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the position of the vertices in the 3D space.
    final List<Vector3> verticesToDraw = <Vector3>[];
    for (final Vector3 vertex in vertices) {
      final Vector3 defV = _calcVertex(Vector3.copy(vertex));
      verticesToDraw.add(defV);
    }
    // Order vertices by the distance to the camera.
    final List<AvgZ> avgOfZ = _sortVertices(verticesToDraw);

    // Calculate the position of the vertices in the 2D space
    // and calculate the colors of the vertices.
    final List<Offset> offsets = <Offset>[];
    final List<Color> colors = <Color>[];
    for (int i = 0; i < faces.length; i++) {
      final List<int> faceIdx = faces[avgOfZ[i].index];

      // Allocate list with a fixed size of 3
      final List<Vector3> verts =
          List<Vector3>.filled(3, Vector3.zero(), growable: false);

      verts[0] = verticesToDraw[faceIdx[0] - 1];
      verts[1] = verticesToDraw[faceIdx[1] - 1];
      verts[2] = verticesToDraw[faceIdx[2] - 1];

      Face face = Face(
        verts[0],
        verts[1],
        verts[2],
      );

      // Fallback on default color func if a custom one is not provided
      face = faceColorFunc?.call(face) ?? _defaultFaceColor(face);

      // TODO: remove from tests
      if (pendingRay != null) {
        final Offset center = cam.viewPort.center(Offset.zero);
        final Matrix4 invProj = Matrix4.copy(cam.proj * cam.view)..invert();
        final Vector3 ray = invProj.transform3(
          Vector3(pendingRay!.dx - center.dx, pendingRay!.dy - center.dy, 0),
        );

        // Test the point if it falls within a triangle
        if (_pointInTriangle(Vector2(ray.x, ray.y), face)) {
          rayHitFunc?.call(face);
          face
            ..c1 = Colors.green
            ..c2 = Colors.green
            ..c3 = Colors.green;
        }
      }

      colors.addAll(<Color>[face.c1, face.c2, face.c3]);
      offsets.addAll(_drawFace(verticesToDraw, faceIdx));
    }

    // Draw the vertices.
    final Paint paint = Paint();
    paint.style = PaintingStyle.fill;
    paint.color = color;
    final Vertices v = Vertices(VertexMode.triangles, offsets, colors: colors);
    canvas.drawVertices(v, BlendMode.clear, paint);
  }

  @override
  bool shouldRepaint(_ObjectPainter old) =>
      old.cam != cam ||
      old.cam.needsRedraw ||
      old.modelScale != modelScale ||
      old.vertices != vertices ||
      old.faces != faces ||
      old.pitch != pitch ||
      old.yaw != yaw ||
      old.roll != roll;
}

class AvgZ {
  int index;
  double z;

  AvgZ(this.index, this.z);
}
