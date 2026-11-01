import 'dart:math';
import 'package:flutter/material.dart';

const ink = Color(0xFF234B42);
const muted = Color(0xFF7E8F83);
const orange = Color(0xFFEFA064);
const paper = Color(0xFFFFFEF8);

class Animal extends StatelessWidget {
  final int species;
  final double size;
  const Animal({super.key, this.species = 0, this.size = 100});
  @override Widget build(BuildContext context) => Semantics(label: const [
    'きつね','うさぎ','ねこ','いぬ','くま','あひる','かえる','ふくろう','ぺんぎん','らいおん','りす'][species % 11],
    image: true, child: CustomPaint(size: Size.square(size), painter: AnimalPainter(species)));
}

class AnimalPainter extends CustomPainter {
  final int species;
  AnimalPainter(this.species);
  @override void paint(Canvas canvas, Size size) {
    canvas.save(); canvas.scale(size.width / 120, size.height / 120);
    final colors = [const Color(0xFFE8A26B), const Color(0xFFE9DECC),
      const Color(0xFFCEB99D), const Color(0xFFC39D73), const Color(0xFFB49478),
      const Color(0xFFF2D879), const Color(0xFF9AB985), const Color(0xFFBAA28C),
      const Color(0xFF627B82), const Color(0xFFD8AB62), const Color(0xFFC4976E)];
    final base = colors[species % 11];
    void oval(Rect r, Color c) => canvas.drawOval(r, Paint()..color = c);
    if (species % 11 == 9) {
      for (var i = 0; i < 10; i++) {
        final a = i * pi / 5;
        oval(Rect.fromCircle(center: Offset(60+33*cos(a),62+33*sin(a)),radius: 15), const Color(0xFFB77C48));
      }
    }
    if (species % 11 == 1) {
      oval(const Rect.fromLTWH(27, 0, 22, 55), base);
      oval(const Rect.fromLTWH(70, 0, 22, 55), base);
      oval(const Rect.fromLTWH(33, 6, 10, 40), const Color(0xFFE4BDB4));
      oval(const Rect.fromLTWH(76, 6, 10, 40), const Color(0xFFE4BDB4));
    } else if ([0,2,7,10].contains(species % 11)) {
      for (final x in [20.0, 75.0]) {
        canvas.drawPath(Path()..moveTo(x,55)..lineTo(x+4,14)..lineTo(x+32,45)..close(), Paint()..color=base);
        canvas.drawPath(Path()..moveTo(x+8,43)..lineTo(x+7,24)..lineTo(x+23,43)..close(), Paint()..color=const Color(0xFFECCABB));
      }
    } else if (species % 11 != 5 && species % 11 != 8) {
      oval(const Rect.fromLTWH(12, 26, 32, 38), base);
      oval(const Rect.fromLTWH(77, 26, 32, 38), base);
    }
    oval(const Rect.fromLTWH(20, 34, 80, 74), base);
    oval(const Rect.fromLTWH(32, 60, 56, 44), const Color(0xFFFAF2DE));
    if (species % 11 == 0) {
      canvas.drawPath(Path()..moveTo(20,62)..lineTo(59,87)..lineTo(36,95)..close(),Paint()..color=const Color(0xFFFAF2DE));
      canvas.drawPath(Path()..moveTo(100,62)..lineTo(61,87)..lineTo(84,95)..close(),Paint()..color=const Color(0xFFFAF2DE));
    }
    oval(const Rect.fromLTWH(39, 62, 6, 9), ink);
    oval(const Rect.fromLTWH(75, 62, 6, 9), ink);
    if (species % 11 == 5) {
      oval(const Rect.fromLTWH(47, 77, 27, 13), orange);
    } else {
      oval(const Rect.fromLTWH(55, 77, 10, 7), ink);
      canvas.drawArc(const Rect.fromLTWH(50, 78, 20, 15), 0.25, pi-0.5, false,
        Paint()..color=ink..style=PaintingStyle.stroke..strokeWidth=1.7);
    }
    oval(const Rect.fromLTWH(28, 76, 12, 6), const Color(0xFFEAB6A0).withValues(alpha:0.65));
    oval(const Rect.fromLTWH(80, 76, 12, 6), const Color(0xFFEAB6A0).withValues(alpha:0.65));
    canvas.restore();
  }
  @override bool shouldRepaint(AnimalPainter old) => old.species != species;
}

class AdventureScene extends StatelessWidget {
  const AdventureScene({super.key});
  @override Widget build(BuildContext context) => CustomPaint(painter: ScenePainter(),
    child: const SizedBox.expand());
}

class ScenePainter extends CustomPainter {
  @override void paint(Canvas c, Size size) {
    final w=size.width, h=size.height;
    c.drawRect(Offset.zero & size,Paint()..color=const Color(0xFFE6EEDB));
    c.drawCircle(Offset(w*.78,h*.21),h*.10,Paint()..color=const Color(0xFFF2CC7A));
    for (final p in [Offset(w*.19,h*.20),Offset(w*.55,h*.13)]) {
      c.drawOval(Rect.fromCenter(center:p,width:90,height:23),Paint()..color=paper.withValues(alpha:.8));
    }
    c.drawPath(Path()..moveTo(0,h*.65)..quadraticBezierTo(w*.2,h*.26,w*.48,h*.65)
      ..quadraticBezierTo(w*.7,h*.4,w,h*.62)..lineTo(w,h)..lineTo(0,h)..close(),
      Paint()..color=const Color(0xFFBDD0A7));
    c.drawPath(Path()..moveTo(0,h*.82)..quadraticBezierTo(w*.4,h*.54,w,h*.76)
      ..lineTo(w,h)..lineTo(0,h)..close(),Paint()..color=const Color(0xFF8EAD83));
    c.drawPath(Path()..moveTo(w*.66,h*.64)..cubicTo(w*.2,h*.72,w*.3,h*.8,w*.72,h)
      ..lineTo(w*.9,h)..cubicTo(w*.43,h*.78,w*.43,h*.72,w*.76,h*.65)..close(),
      Paint()..color=const Color(0xFF9BC9C3));
    for (final x in [.1,.22,.83,.94]) {
      final px=w*x, py=h*(x < 0.5 ? 0.69 : 0.77);
      c.drawLine(Offset(px,py),Offset(px,py-h*.18),Paint()..color=const Color(0xFF798C65)..strokeWidth=5);
      c.drawOval(Rect.fromCenter(center:Offset(px,py-h*.2),width:w*.08,height:h*.24),
        Paint()..color=const Color(0xFF5E8B70));
    }
    c.save(); c.translate(w*.47,h*.48); c.scale(h*.0032);
    AnimalPainter(0).paint(c,const Size(120,120)); c.restore();
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.49,h*.77,w*.24,h*.07),const Radius.circular(12)),
      Paint()..color=const Color(0xFFCEA376));
    for (final x in [.54,.67]) c.drawCircle(Offset(w*x,h*.85),h*.025,Paint()..color=ink);
    for (var i=0;i<7;i++) {
      c.drawCircle(Offset(w*(.07+i*.13),h*(.91+(i%2)*.04)),3,Paint()..color=const Color(0xFFF4E2AD));
    }
  }
  @override bool shouldRepaint(ScenePainter old) => false;
}

class MouthDiagram extends StatelessWidget {
  final String ipa;
  const MouthDiagram({super.key, required this.ipa});
  @override Widget build(BuildContext context) => Semantics(label: 'くちの かたち。せつめいも よんでね。',
    image: true, child: CustomPaint(size: const Size(160,100),painter: MouthPainter(ipa)));
}

class MouthPainter extends CustomPainter {
  final String ipa;
  MouthPainter(this.ipa);
  @override void paint(Canvas c,Size s) {
    final round=['ʃ','w','oʊ','u','ju'].contains(ipa);
    final closed=['p','b','m'].contains(ipa);
    final width=round?56.0:108.0, height=closed?6.0:round?60.0:ipa=='æ'||ipa=='ɑ'?58.0:30.0;
    c.drawOval(Rect.fromCenter(center:Offset(s.width/2,s.height/2),width:width+14,height:height+14),Paint()..color=const Color(0xFFC88779));
    c.drawOval(Rect.fromCenter(center:Offset(s.width/2,s.height/2),width:width,height:height),Paint()..color=const Color(0xFF694A44));
    if (!closed) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(s.width/2,s.height/2-height*.31),width:width*.7,height:8),const Radius.circular(3)),Paint()..color=paper);
      c.drawOval(Rect.fromCenter(center:Offset(s.width/2,s.height/2+height*.3),width:width*.55,height:12),Paint()..color=const Color(0xFFE4AAA1));
    }
  }
  @override bool shouldRepaint(MouthPainter old) => old.ipa != ipa;
}
