import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RicochetLogo extends StatelessWidget {
  final double height;

  const RicochetLogo({
    Key? key,
    this.height = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        'RICOCHET',
        style: GoogleFonts.ubuntu(
          fontSize: height,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
