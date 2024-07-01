import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:fuccini_template/transaction.dart';
import 'package:fuccini_template/local_storage.dart';

class HandlerFileController {
  static final HandlerFileController _instance = HandlerFileController._internal();
  factory HandlerFileController() => _instance;
  HandlerFileController._internal();

  Future<FilePickerResult?> getFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    return result;
  }

  Future<void> exportFile(FilePickerResult result, int machineId, Function callback) async{
    var excel;
    var jsonData = <Map<String, dynamic>>[];
    try {
      if(kIsWeb) {
        var bytes = result.files.single.bytes;
        excel = Excel.decodeBytes(bytes!);
      }else {                           // project suport web for debug and Window
        var bytes = File(result.files.single.path!).readAsBytesSync();
        excel = Excel.decodeBytes(bytes);
      }

      // Lấy sheet đầu tiên
      var sheet = excel.tables.keys.first;
      var table = excel.tables[sheet]!;

      // Lấy danh sách các cột
      var columns = table!.rows.first.map((cell) => cell.value.toString()).toList();

      // Lấy dữ liệu từ các dòng tiếp theo và chuyển đổi thành đối tượng JSON

      for (var row in table.rows.skip(1)) {
        var rowData = <String, dynamic>{};
        for (var i = 0; i < columns.length; i++) {
          if (row[i]?.value != null) {
            rowData[columns[i]] = row[i].value.toString();
          }
        }
        jsonData.add(rowData);
        print('jsonData: ${jsonData}');
      }
    }catch(e) {
      print('e: $e');
      callback('Có lỗi xảy ra trong quá trình đọc dữ liệu');
    }

    try {
      var dataList = jsonData.map((json) => Transaction.fromJson(json)).toList();
      String callbackData = await handlerDataWithFormatFucini(dataList, machineId);
      print('callbackData: \n$callbackData');
    }catch (e){
      callback('Có lỗi xảy ra trong quá trình chuyển đổi dữ liệu');
    }
  }

  Future<String> handlerDataWithFormatFucini(List<Transaction> listData, int machineId) async {
    print('handlerDataWithFormatFucini');
    StringBuffer resultData = StringBuffer();

    //date time
    String date = listData[0].thoiGian.toString();
    DateTime parsedDate = DateTime.parse(date);
    String formattedDate = DateFormat('ddMMyyyy').format(parsedDate);

    //batchID
    int batchID = await LocalStorage().getBatchId(formattedDate);

    for (int hour = 0; hour < 24; hour++) {
      // Format the hour to always have two digits
      String formattedHour = hour.toString().padLeft(2, '0');

      int receiptCount = 0;
      int totalAmountVISA = 0;
      int totalAmountMASTER = 0;
      int totalAmountAMEX = 0;
      int totalAmountOrther = 0;

      for (var row in listData) {
        if(row == null) {
          break;
        }
        //kiểm tra các gd cùng 1 ngày
        DateTime parsedDate = DateTime.parse(row.thoiGian.toString());
        String dateInRow = DateFormat('ddMMyyyy').format(parsedDate);
        if ((formattedDate == dateInRow) && parsedDate.hour >= hour && parsedDate.hour < (hour + 1)) {
          receiptCount++;

          if (row.loaiThe!.contains('VISA')) {
            totalAmountVISA += int.parse(row.soTien.toString().replaceAll(',', '') ?? '0');
          } else if (row.loaiThe!.contains('MASTER')) {
            totalAmountMASTER += int.parse(row.soTien.toString().replaceAll(',', '') ?? '0');
          } else if (row.loaiThe!.contains('AMEX')) {
            totalAmountAMEX += int.parse(row.soTien.toString().replaceAll(',', '') ?? '0');
          } else if (row.loaiThe!.contains('QR')) {
            totalAmountOrther += int.parse(row.soTien.toString().replaceAll(',', '') ?? '0');
          }
        }
      }

      resultData.write(putDataToFuciniFormat(machineId: machineId, batchId: batchID, hour: formattedHour, receiptCount: receiptCount, date: int.parse(formattedDate), amountVisa: formatAmount(totalAmountVISA), amountMasterCard: formatAmount(totalAmountMASTER), amountAmex: formatAmount(totalAmountAMEX), amountOthers: formatAmount(totalAmountOrther)));
    }

    LocalStorage().saveBatchId(formattedDate, batchID, machineId);
    return resultData.toString();
  }

  String formatAmount(int amount) {
    // NumberFormat numberFormat = NumberFormat("#.00", "en_US");
    // return numberFormat.format(amount);

    return amount.toString() + '.00';
  }

  String putDataToFuciniFormat(
      {required String hour,
        int? machineId,
        int? batchId,
        int? date,
        int? receiptCount,
        int? GTOSales,
        int? VAT,
        int? discount,
        int? service_charge,
        int? noPax,
        int? cash,
        String? amountVisa,
        String? amountMasterCard,
        String? amountAmex,
        String? amountOthers,
      }) {
    String result =
        '${machineId ?? '0'}'   // mc cung cấp
        '|${batchId ?? '0'}'    // Nó phải là một số tuần tự bắt đầu từ 1 cho tệp đầu tiên được tạo. Nó sẽ được tăng lên 1 cho mỗi tệp tiếp theo được tạo. Nó phải có nghĩa là duy nhất rằng không có 2 ngày nào có thể có cùng một Batch ID.
        '|${date ?? '0'}'                     // ngày
        '|${hour}'                            // giờ
        '|${receiptCount ?? 0}'             // Số lượng giao dịch / biên nhận được phát hành trong giờ
        '|${GTOSales ?? '0.00'}'        // Doanh số thuần sau khi chiết khấu và trước thuế VAT. Chỉ bao gồm phí dịch vụ cho Đồ ăn và thức uống
        '|${VAT ?? '0.00'}'             // Thuế giá trị gia tăng
        '|${discount ?? '0.00'}'        // Giảm giá
        '|${service_charge ?? '0.00'}'  // Phí dịch vụ chỉ dành cho F&B
        '|${noPax ?? '0'}'              // Số Pax chỉ dành cho F&B
        '|${cash ?? '0.00'}'            // Tiền mặt - Số tiền bán hàng ròng sau khi chiết khấu và trước VAT. Chỉ bao gồm phí dịch vụ cho F&B
        '|${'0.00'}'              // ATM / DEBIT CARD - Số tiền bán hàng ròng sau khi chiết khấu và trước thuế VAT. Chỉ bao gồm phí dịch vụ đối với Đồ ăn và thức uống
        '|${amountVisa ?? '0.00'}'              // Visa - Doanh thu thuần sau chiết khấu và trước VAT. Chỉ bao gồm phí dịch vụ đối với Đồ ăn và Thức uống
        '|${amountMasterCard ?? '0.00'}'              // MasterCard - Số tiền bán ròng sau chiết khấu và trước VAT. Chỉ bao gồm phí dịch vụ đối với Đồ ăn và thức uống
        '|${amountAmex ?? '0.00'}'              // Amex - Số tiền bán ròng sau chiết khấu và trước VAT. Chỉ bao gồm phí dịch vụ đối với Đồ ăn và thức uống
        '|${'0.00'}'              // Voucher - Số tiền bán ròng sau khi chiết khấu và trước VAT. Chỉ bao gồm phí dịch vụ cho Đồ ăn và thức uống
        '|${amountOthers ?? '0.00'}'              // Others - Số tiền bán ròng sau khi chiết khấu và trước VAT. Chỉ bao gồm phí dịch vụ cho F&B) * Áp dụng cho thanh toán qua Ví điện tử và v.v.
        '|${'N'}';              // VAT Registered - Thuế giá trị gia tang đã đăng ký

    return result.replaceAll('\n', '').replaceAll('\r', '')+'\n';
  }

  Future<void> saveFile(String data) async{
    final path = await FileSaver.instance.saveFile(
      name: 'trans.txt',
      ext: data,
      mimeType: MimeType.text,
    );

    print('path: $path');

    //save file
    // String? outputFile = await FilePicker.platform.saveFile(
    //     type: FileType.custom,
    //     dialogTitle: 'Save Your File to desired location',
    //     fileName: 'trans.txt');
    //
    // try {
    //   File returnedFile = File('$outputFile');
    //   await returnedFile.writeAsString(data);
    // } catch (e) {}
  }
}