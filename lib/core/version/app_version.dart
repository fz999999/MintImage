class AppVersion {
  const AppVersion._();

  static const current = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'v1.0.0',
  );

  // 本仓库（fork 自上游 aiqinxuancai/MintImage）。
  // 设置-关于的「开源地址」、更新检查、下载页跳转都取这里。
  static const repository = 'fz999999/MintImage';
  static const repositoryUrl = 'https://github.com/$repository';
  static const latestReleaseUrl = '$repositoryUrl/releases/latest';
}
