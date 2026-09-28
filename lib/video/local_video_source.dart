import 'package:flutter/services.dart';

class LocalVideoSource {
  const LocalVideoSource({
    this.assetPath = pigHouseDemoAsset,
  });

  static const String pigHouseDemoAsset = 'assets/videos/pig_house_demo.mp4';

  final String assetPath;

  Future<bool> isAvailable({AssetBundle? bundle}) async {
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      return manifest.listAssets().contains(assetPath);
    } on Object {
      return false;
    }
  }
}
