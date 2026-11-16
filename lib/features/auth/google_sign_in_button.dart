import 'package:flutter/material.dart';

/// "Continue with Google" button following Google's branding guidelines:
/// white background, thin grey border, and the official multi-colour "G".
///
/// The logo comes from Google's pre-approved assets
/// (developers.google.com/identity/branding-guidelines), saved as
/// assets/branding/google_g.png. Do not recolour or redraw it.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const _logoAsset = 'assets/branding/google_g.png';

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        side: const BorderSide(color: Color(0xFF747775)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            _logoAsset,
            width: 20,
            height: 20,
            semanticLabel: 'Google',
            // Until the logo file is added, show the text alone.
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
