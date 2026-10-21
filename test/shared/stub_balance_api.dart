import 'package:mint_image/core/api/balance_query_api.dart';
import 'package:mint_image/core/models/balance_query.dart';
import 'package:mint_image/core/models/settings_model.dart';

/// 测试用的假余额接口：不发网络请求，直接返回固定余额。
class StubBalanceApi extends BalanceQueryApi {
  const StubBalanceApi({this.text = r'$10.00'});

  final String text;

  @override
  Future<BalanceQueryResult> query({
    required ApiProfile profile,
    required BalanceQueryConfig config,
    int timeoutSeconds = 15,
  }) async {
    return BalanceQueryResult(
      text: text,
      mode: config.mode,
      source: 'stub',
      detail: '测试数据',
      amount: 10,
    );
  }
}
