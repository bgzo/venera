part of 'settings_page.dart';

class SuperResolutionSettings extends StatefulWidget {
  const SuperResolutionSettings({super.key});

  @override
  State<SuperResolutionSettings> createState() =>
      _SuperResolutionSettingsState();
}

class _SuperResolutionSettingsState extends State<SuperResolutionSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Super Resolution".tl)),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("How it works".tl, style: ts.s16),
              const SizedBox(height: 6),
              Text(
                "The current upscaling algorithm is Anime4K, tuned for line art, manga and comic edge enhancement. For images that are already blurry or heavily compressed, the improvement is usually limited."
                    .tl,
                style: ts.s12.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ).toSliver(),
        _SwitchSetting(
          title: "Enable".tl,
          settingKey: 'enableAnime4K',
          subtitle:
              "When enabled, the reader upscales pages in the background.".tl,
          onChanged: () {
            setState(() {});
          },
        ).toSliver(),
        if (appdata.settings['enableAnime4K'] == true)
          _SwitchSetting(
            title: "Network Images".tl,
            settingKey: 'enableAnime4KForNetwork',
            subtitle:
                "Also upscale when reading online. Images are replaced once processed, which adds latency and memory usage."
                    .tl,
            onChanged: () {
              setState(() {});
            },
          ).toSliver(),
        if (appdata.settings['enableAnime4K'] == true)
          _SliderSetting(
            title: "Scale Factor".tl,
            settingsIndex: 'anime4KScaleFactor',
            interval: 0.5,
            min: 1.0,
            max: 4.0,
            subtitle:
                "Recommended: 1.5 - 2.0. The higher the factor, the sharper the edges, but processing time and memory usage rise noticeably."
                    .tl,
            onChanged: () {
              setState(() {});
            },
          ).toSliver(),
        if (appdata.settings['enableAnime4K'] == true)
          _SliderSetting(
            title: "Line Refinement Strength".tl,
            settingsIndex: 'anime4KPushStrength',
            interval: 0.01,
            min: 0.0,
            max: 1.0,
            subtitle:
                "Recommended: 0.2 - 0.4. Higher values make black lines sharper; too high may look harsh, cause jaggies, or lose detail."
                    .tl,
            onChanged: () {
              setState(() {});
            },
          ).toSliver(),
        if (appdata.settings['enableAnime4K'] == true)
          _SliderSetting(
            title: "Edge Refinement Strength".tl,
            settingsIndex: 'anime4KPushGradStrength',
            interval: 0.01,
            min: 0.0,
            max: 2.0,
            subtitle:
                "Recommended: 0.8 - 1.2. Enhances edge transitions; too high may make noise and compression artifacts more obvious."
                    .tl,
            onChanged: () {
              setState(() {});
            },
          ).toSliver(),
        if (appdata.settings['enableAnime4K'] == true)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tuning Tips".tl, style: ts.s14),
                const SizedBox(height: 4),
                Text(
                  'Start with scale factor 2.0, then fine-tune "Line Refinement Strength" and "Edge Refinement Strength". Anime4K focuses on edge enhancement and cannot turn a low-quality compressed image back into a high-resolution original.'
                      .tl,
                  style: ts.s12.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ).toSliver(),
      ],
    );
  }
}
