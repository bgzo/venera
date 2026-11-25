part of 'components.dart';

/// The Bangumi brand icon, rendered from the bundled PNG asset.
class BangumiIcon extends StatelessWidget {
  const BangumiIcon({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/bangumi.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}
