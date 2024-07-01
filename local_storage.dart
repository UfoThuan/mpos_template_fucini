import 'dart:convert';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuccini_template/model_batch_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const KEY_LANGUAGE_APP = 'KEY_LANGUAGE_APP';
  static const KEY_BATCHID = 'KEY_BATCHID';
  static const KEY_CURRENT_BATCHID = 'KEY_CURRENT_BATCHID';

  // static const storage = FlutterSecureStorage();

  SharedPreferences? prefs;


  static final LocalStorage _instance = LocalStorage._internal();

  factory LocalStorage() => _instance;

  LocalStorage._internal() {
    init();
  }

  void init() async {
    prefs = await SharedPreferences.getInstance();
  }
  // Future clear(String key) async {
  //   await storage.delete(key: key);
  // }
  //
  // Future clearAll() async {
  //   await storage.deleteAll();
  // }

  dynamic getData(String key, [dynamic defaultData]) async {
    if (prefs == null) {
      prefs = await SharedPreferences.getInstance();
    }

    String? value = await prefs?.getString(key);
    if (value == null) {
      return defaultData;
    } else {
      try {
        if (defaultData is bool) {
          if (value!.toLowerCase() == 'true') {
            return true;
          } else if (value.toLowerCase() == 'false') {
            return false;
          } else {
            return defaultData;
          }
        }
        else if (defaultData is int) {
          return int.parse(value!);
        } else if (defaultData is double) {
          return double.parse(value!);
        } else {
          return value;
        }
      } catch (e) {
        print(e);
        return defaultData;
      }
    }
    return defaultData;
  }

  Future<void> saveData(String key, dynamic value) async {
    if (prefs == null) {
      prefs = await SharedPreferences.getInstance();
    }
    // storage.write(key: key, value: value.toString());
    prefs?.setString(key, value.toString());
  }

  void saveBatchId(String time, int batchId, int machineId) async {
    String data = await LocalStorage().getData(LocalStorage.KEY_BATCHID, '');
    List<BatchId> listBatch = [];
    if (data.isNotEmpty) {
      List<dynamic> jsonData = json.decode(data);
      listBatch = jsonData.map((json) => BatchId.fromJson(json)).toList();

      bool isContant = false;
      for (int i = 0; i< listBatch.length; i++) {
        if (listBatch[i].batchID == batchId) {
          isContant = true;
          break;
        }
      }
      if (!isContant) {
        listBatch.add(BatchId(date: time, batchID: batchId, machineId: machineId));
      }
    } else {
      listBatch.add(BatchId(date: time, batchID: batchId, machineId: machineId));
    }
    saveData(KEY_BATCHID, json.encode(listBatch));
  }

  Future<int> getBatchId(String time) async {
    int result = 0;
    String data = await LocalStorage().getData(LocalStorage.KEY_BATCHID, '');
    if (data.isNotEmpty) {
      List<dynamic> jsonData = json.decode(data);
      List<BatchId> listBatch = jsonData.map((json) => BatchId.fromJson(json)).toList();

      bool isContant = false;
      for (int i = 0; i< listBatch.length; i++) {
        if (listBatch[i].date == time) {
          result = listBatch[i].batchID;
          isContant = true;
          break;
        }
      }

      if (!isContant) {
        int currentBatchID = await getData(LocalStorage.KEY_CURRENT_BATCHID, 0).timeout(Duration(milliseconds: 500));
        result = currentBatchID + 1;
        await LocalStorage().saveData(LocalStorage.KEY_CURRENT_BATCHID, result).timeout(Duration(milliseconds: 500));
      }

    } else {
      // lấy từ storage batchId đang sử dụng + 1
      // lưu lại batchId mới
      int currentBatchID = await getData(LocalStorage.KEY_CURRENT_BATCHID, 0).timeout(Duration(milliseconds: 500));
      result = currentBatchID + 1;
      await LocalStorage().saveData(LocalStorage.KEY_CURRENT_BATCHID, result).timeout(Duration(milliseconds: 500));
    }
    return result;
  }
}

