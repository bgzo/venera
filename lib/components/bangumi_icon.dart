part of 'components.dart';

/// The Bangumi brand icon, rendered from the bundled PNG asset.
class BangumiIcon extends StatelessWidget {
  const BangumiIcon({this.size = 24, this.monochrome = false, super.key});

  final double size;

  /// When true, inherits the surrounding [IconTheme] color so it matches the
  /// other icons (used on settings pages). When false, keeps the brand color.
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    if (monochrome) {
      return ImageIcon(const AssetImage('assets/bangumi.png'), size: size);
    }
    return Image.asset(
      'assets/bangumi.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}
