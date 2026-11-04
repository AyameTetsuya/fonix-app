import 'dart:math' as math;
import 'package:flutter/material.dart';

const ink = Color(0xFF234B42);
const muted = Color(0xFF6D8276);
const orange = Color(0xFFF58A54);
const paper = Color(0xFFFFFBF1);

const _companionAtlas = 'assets/art/companions.png';
const _adventureIsland = 'assets/art/adventure-island.png';

/// Original illustrated companions. The bundled atlas has four columns and
/// three rows of square cells; clipping selects a cell without an online fetch.
class Animal extends StatelessWidget {
  final int species;
  final double size;

  const Animal({super.key, this.species = 0, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final index = species % 11;
    return Semantics(
      label: const [
        'きつね',
        'うさぎ',
        'ねこ',
        'いぬ',
        'くま',
        'あひる',
        'かえる',
        'ふくろう',
        'ぺんぎん',
        'らいおん',
        'りす',
      ][index],
      image: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -(index % 4) * size,
                  top: -(index ~/ 4) * size,
                  width: size * 4,
                  height: size * 3,
                  child: Image.asset(
                    _companionAtlas,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-bleed, offline adventure setting with the selected travel companion.
class AdventureScene extends StatelessWidget {
  final int species;
  final bool showCompanion;

  const AdventureScene({
    super.key,
    this.species = 0,
    this.showCompanion = true,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.maxHeight;
      final width = constraints.maxWidth;
      final companionSize = math.min(height * .94, width * .42);
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _adventureIsland,
            fit: BoxFit.cover,
            alignment: const Alignment(.12, .1),
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          ),
          if (showCompanion)
            Positioned(
              right: width * .065,
              bottom: height * .035,
              child: SizedBox.square(
                dimension: companionSize,
                child: Stack(
                  children: [
                    Positioned(
                      left: companionSize * .14,
                      right: companionSize * .1,
                      bottom: companionSize * .012,
                      height: companionSize * .075,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(companionSize),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1F452A)
                                  .withValues(alpha: .35),
                              blurRadius: companionSize * .055,
                              spreadRadius: companionSize * .012,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Animal(species: species, size: companionSize),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class MouthDiagram extends StatelessWidget {
  final String ipa;
  const MouthDiagram({super.key, required this.ipa});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'くちの かたち',
    image: true,
    child: CustomPaint(
      size: const Size(160, 100),
      painter: MouthPainter(ipa),
    ),
  );
}

class MouthPainter extends CustomPainter {
  final String ipa;
  MouthPainter(this.ipa);

  @override
  void paint(Canvas canvas, Size size) {
    final round = ['ʃ', 'w', 'oʊ', 'u', 'ju'].contains(ipa);
    final closed = ['p', 'b', 'm'].contains(ipa);
    final width = round ? 56.0 : 108.0;
    final height = closed
        ? 6.0
        : round
        ? 60.0
        : ipa == 'æ' || ipa == 'ɑ'
        ? 58.0
        : 30.0;
    final center = Offset(size.width / 2, size.height / 2);
    final lips = Rect.fromCenter(
      center: center,
      width: width + 17,
      height: height + 18,
    );
    canvas.drawOval(
      lips,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDFA296), Color(0xFFC87970)],
        ).createShader(lips),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      Paint()..color = const Color(0xFF694A44),
    );
    if (!closed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - height * .31),
            width: width * .7,
            height: 8,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = paper,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + height * .3),
          width: width * .55,
          height: 12,
        ),
        Paint()..color = const Color(0xFFE4AAA1),
      );
    }
  }

  @override
  bool shouldRepaint(MouthPainter old) => old.ipa != ipa;
}
