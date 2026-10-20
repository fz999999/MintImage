import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  test('initial settings use a 600 second timeout', () {
    final settings = SettingsModel.initial();

    expect(
      settings.requestTimeoutSeconds,
      SettingsModel.defaultRequestTimeoutSeconds,
    );
    expect(settings.responseFormat, isNull);
    expect(settings.lastSizePreset, SizePreset.auto);
    expect(settings.lastCustomWidth, 0);
    expect(settings.lastCustomHeight, 0);
    expect(settings.lastQuality, ImageQuality.auto);
    expect(settings.lastOutputFormat, ImageOutputFormat.png);
  });

  test('settings round-trip preserves request timeout', () {
    final optimizer = PromptOptimizationProfile(
      id: 'optimizer-1',
      name: '优化',
      baseUrl: 'https://right.codes/codex/v1',
      apiKey: 'key',
      model: 'gpt-5.5',
      protocol: PromptOptimizationProtocol.openAiResponses,
    );
    final settings = SettingsModel.initial().copyWith(
      requestTimeoutSeconds: 900,
      promptOptimizationProfiles: [optimizer],
      activePromptOptimizationProfileId: optimizer.id,
      lastSizePreset: SizePreset.wide2k,
      lastCustomWidth: 2560,
      lastCustomHeight: 1440,
      lastQuality: ImageQuality.high,
      lastOutputFormat: ImageOutputFormat.webp,
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.requestTimeoutSeconds, 900);
    expect(decoded.promptOptimizationProfiles, hasLength(1));
    expect(decoded.activePromptOptimizationProfile?.id, 'optimizer-1');
    expect(
      decoded.activePromptOptimizationProfile?.protocol,
      PromptOptimizationProtocol.openAiResponses,
    );
    expect(decoded.lastSizePreset, SizePreset.wide2k);
    expect(decoded.lastCustomWidth, 2560);
    expect(decoded.lastCustomHeight, 1440);
    expect(decoded.lastQuality, ImageQuality.high);
    expect(decoded.lastOutputFormat, ImageOutputFormat.webp);
  });

  test('settings round-trip preserves WebDAV backup config', () {
    final settings = SettingsModel.initial().copyWith(
      webDavBackupConfig: const WebDavBackupConfig(
        baseUrl: 'https://example.com/dav',
        username: 'user',
        password: 'pass',
        remoteDirectory: 'MintImage/backups',
      ),
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.webDavBackupConfig?.baseUrl, 'https://example.com/dav');
    expect(decoded.webDavBackupConfig?.username, 'user');
    expect(decoded.webDavBackupConfig?.password, 'pass');
    expect(decoded.webDavBackupConfig?.remoteDirectory, 'MintImage/backups');
  });

  test('legacy settings default to no prompt optimization profiles', () {
    final decoded = SettingsModel.fromJson({
      'profiles': [
        {
          'id': '1',
          'name': '默认',
          'baseUrl': 'https://api.openai.com',
          'apiKey': 'key',
          'model': 'gpt-image-2',
        },
      ],
      'activeProfileId': '1',
      'requestTimeoutSeconds': 600,
    });

    expect(decoded.promptOptimizationProfiles, isEmpty);
    expect(decoded.activePromptOptimizationProfile, isNull);
    expect(decoded.activeProfile.apiMode, ImageGenerationApiMode.images);
    expect(decoded.lastSizePreset, SizePreset.auto);
    expect(decoded.lastQuality, ImageQuality.auto);
    expect(decoded.lastOutputFormat, ImageOutputFormat.png);
  });

  test('image API mode is persisted per profile', () {
    final settings = SettingsModel.initial();
    final profile = settings.activeProfile.copyWith(
      model: 'gpt-5.5',
      apiMode: ImageGenerationApiMode.responses,
    );
    final updated = settings.copyWith(profiles: [profile]);

    final decoded = SettingsModel.decode(updated.encode());

    expect(decoded.activeProfile.apiMode, ImageGenerationApiMode.responses);
    expect(decoded.activeProfile.generationEndpoint, contains('/v1/responses'));
  });

  test('legacy b64_json responseFormat is normalized to null', () {
    final decoded = SettingsModel.fromJson({
      'profiles': [
        {
          'id': '1',
          'name': '默认',
          'baseUrl': 'https://api.openai.com',
          'apiKey': 'key',
          'model': 'gpt-image-2',
        },
      ],
      'activeProfileId': '1',
      'responseFormat': 'b64_json',
      'requestTimeoutSeconds': 600,
    });

    expect(decoded.responseFormat, isNull);
  });

  test('legacy single model json parses into models list', () {
    final profile = ApiProfile.fromJson({
      'id': '1',
      'name': '默认',
      'baseUrl': 'https://api.openai.com',
      'apiKey': 'key',
      'model': 'gpt-image-2',
    });

    expect(profile.models, ['gpt-image-2']);
    expect(profile.model, 'gpt-image-2');
  });

  test('models list round-trips through json', () {
    final profile = ApiProfile(
      id: '1',
      name: '默认',
      baseUrl: 'https://api.openai.com',
      apiKey: 'key',
      models: const ['a', 'b'],
    );

    final decoded = ApiProfile.fromJson(profile.toJson());

    expect(decoded.models, ['a', 'b']);
    expect(decoded.toJson()['model'], 'a');
  });

  test('models are trimmed and de-duplicated', () {
    final profile = ApiProfile(
      id: '1',
      name: '默认',
      baseUrl: 'https://api.openai.com',
      apiKey: 'key',
      models: const [' a ', 'a', '', 'b'],
    );

    expect(profile.models, ['a', 'b']);
  });

  test('copyWith model locks the profile to a single model', () {
    final profile = ApiProfile(
      id: '1',
      name: '默认',
      baseUrl: 'https://api.openai.com',
      apiKey: 'key',
      models: const ['a', 'b'],
    );

    final locked = profile.copyWith(model: 'b');

    expect(locked.models, ['b']);
    expect(locked.model, 'b');
  });

  test('active model selection round-trips', () {
    final settings = SettingsModel.initial();
    final profile = settings.activeProfile.copyWith(models: const ['a', 'b']);
    final updated = settings.copyWith(
      profiles: [profile],
      activeModelByProfileId: {profile.id: 'b'},
    );

    final decoded = SettingsModel.decode(updated.encode());

    expect(decoded.activeModelByProfileId, {profile.id: 'b'});
    expect(decoded.modelForProfile(decoded.activeProfile), 'b');
  });

  test('invalid active model selections are dropped on decode', () {
    final decoded = SettingsModel.fromJson({
      'profiles': [
        {
          'id': '1',
          'name': '默认',
          'baseUrl': 'https://api.openai.com',
          'apiKey': 'key',
          'models': ['a', 'b'],
        },
      ],
      'activeProfileId': '1',
      'activeModelByProfileId': {'1': 'missing', 'unknown': 'a', '2': 'a'},
    });

    expect(decoded.activeModelByProfileId, isEmpty);
    expect(decoded.modelForProfile(decoded.activeProfile), 'a');
  });

  test('modelForProfile falls back to the first model', () {
    final settings = SettingsModel.initial();
    final profile = settings.activeProfile.copyWith(models: const ['a', 'b']);
    final withSelection = settings.copyWith(
      profiles: [profile],
      activeModelByProfileId: {profile.id: 'b'},
    );

    expect(withSelection.modelForProfile(profile), 'b');
    expect(
      withSelection.modelForProfile(profile.copyWith(models: const ['a'])),
      'a',
    );
  });
}
