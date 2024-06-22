import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:hive_flutter/hive_flutter.dart';

const latestUpdateBox = 'latestUpdateBox';

enum NeedUpdateEnum { no, withLoading, noLoading }

class CachingService {
  static int _timeCachingInSecond = 30;

  static Future<void> initial({int timeCachingInSecond = 30}) async {
    _timeCachingInSecond = timeCachingInSecond;
    await Hive.initFlutter();
  }

  static Future<void> sortData({
    required dynamic data,
    required String name,
    String filterKey = '',
  }) async {
    final key = '_${filterKey}_';

    final boxUpdate = await _getBox(latestUpdateBox);

    await boxUpdate.put(name, DateTime.now().toIso8601String());

    final box = await _getBox(name);

    if (data is List && data.isNotEmpty) {
      await _clearKeysId(box: box, filterKey: filterKey);

      for (var e in data) {
        await box.put('$key${box.values.length}', jsonEncode(e));
      }

      // loggerObject.w('cached key $key count ${data.length}');

      return;
    }

    await box.put(key, jsonEncode(data));
    // loggerObject.w('cached key $key');
  }

  static Future<void> _clearKeysId({
    required Box<String> box,
    String filterKey = '',
  }) async {
    final key = '_${filterKey}_';

    final keys = box.keys.where((e) => e.startsWith(key));

    // loggerObject.e('deleted keys:\n$key \n$keys');

    await box.deleteAll(keys);
  }

  static Future<Iterable<dynamic>> getList(
    String name, {
    String filterKey = '',
  }) async {
    final key = '_${filterKey}_';

    final box = await _getBox(name);

    final f = box.keys
        .where((e) => e.startsWith(key))
        .map((e) => jsonDecode(box.get(e) ?? '{}'));

    // loggerObject.t('getList(): \nkey:$key count ${f.length}');

    return f;
  }

  static Future<dynamic> getData(
    String name, {
    String filterKey = '',
  }) async {
    final key = '_${filterKey}_';

    final box = await _getBox(name);

    final dataByKey = box.get(key);

    if (dataByKey == null) return null;

    // loggerObject.t('getList(): \nkey:$key key found $dataByKey');

    return jsonDecode(dataByKey);
  }

  static Future<Box<String>> _getBox(String name) async {
    return Hive.isBoxOpen(name)
        ? Hive.box<String>(name)
        : await Hive.openBox<String>(name);
  }

  static Future<NeedUpdateEnum> needGetData(
    String name, {
    String filterKey = '',
  }) async {
    var key = '_${filterKey}_';


    final box = await _getBox(name);
    final keyFounded = box.keys.firstWhereOrNull((e) => (e).startsWith(key));

    if (keyFounded == null) {
      // loggerObject.v(box.keys);
      // loggerObject.f('need get data (key Not Founded): \n$key With loading');
      return NeedUpdateEnum.withLoading;
    }

    final latest =
        DateTime.tryParse((await _getBox(latestUpdateBox)).get(name) ?? '');

    final haveData = (await getList(name, filterKey: filterKey)).isNotEmpty;

    if (latest == null) {
      // loggerObject.f('need get data (latest): \n$key With loading');
      return NeedUpdateEnum.withLoading;
    }

    final d = DateTime.now().difference(latest).inSeconds.abs();

    if (d > _timeCachingInSecond) {
      // loggerObject.f(
      //   'need get data :'
      //   ' \n$key data > 2 '
      //   '\n${haveData ? NeedUpdateEnum.noLoading.name : NeedUpdateEnum.withLoading.name}',
      // );

      return haveData ? NeedUpdateEnum.noLoading : NeedUpdateEnum.withLoading;
    }
    // loggerObject.f('need get data : \n$key Not get data');
    return NeedUpdateEnum.no;
  }
}
