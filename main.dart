import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuccini_template/handlerFileController.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mPos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'mPos'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  FilePickerResult? filePicker;
  String? fileName;
  String? filePath;
  String machineId = '';

  updateFileName(String newFileName) {
    setState(() {
      fileName = newFileName;
    });
  }

  updateMachineId(String value) {
    setState(() {
      machineId = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('Id thiết bị: ${(machineId == '') ? 'null' : machineId}', style: TextStyle(fontWeight: FontWeight.w600),),
                SizedBox(width: 10,),
                InkWell(
                  onTap: () {
                    onClickUpdateMachineId(context);
                  },
                  child: Icon(Icons.edit, color: Colors.blueAccent,),
                ),

              ],
            ),
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  InkWell(
                    onTap: () {
                      onClickAddFile();
                    },
                    child: Icon(Icons.add_circle, size: 80, color: Colors.blueAccent,),
                  ),

                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: (fileName == null)
                        ? Text(
                      'Chọn file dữ liệu của bạn. Hỗ trợ file xlsx',
                    ) : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$fileName'),
                        SizedBox(width: 20,),
                        InkWell(
                          onTap: () {
                            onClickExportFile();
                          },
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.all(Radius.circular(10))
                            ),
                            child: Text('Xuất dữ liệu', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text('Version: 1.1.1')
              ],
            ),
          )
        ],
      ),
    );
  }

  void onClickUpdateMachineId(BuildContext context) {
    print('onClickUpdateMachineId');
    TextEditingController edtController = TextEditingController();
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Nhập mã thiết bị'),
            content: Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white
              ),
              child: TextField(
                textAlign: TextAlign.center,
                controller: edtController,
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Lưu lại'),
                onPressed: () {
                  if (edtController.text.length > 8 || int.tryParse(edtController.text) == null) {
                    showSnackBar('Mã thiết bị không hợp lệ. Mã thiết bị là số và độ dài không quá 8 ký tự.');
                    return;
                  }

                  updateMachineId(edtController.text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  void onClickAddFile() async {
    print('click add file');

    FilePickerResult? result = await HandlerFileController().getFile();
    if (result != null) {
      filePicker = result;
      String newFileName = '';
      String? newFilePath = '';
      if (kIsWeb) {
        PlatformFile file = result.files.first;
        newFileName = file.name;
        newFilePath = '';
      }else { // project suport web for debug and Window
        newFileName = result.files.single.name;
        newFilePath = result.files.single.path;
      }
      updateFileName(newFileName);
      filePath = newFilePath;
    }
  }
  
  void onClickExportFile() async {
    if (machineId == '') {
      showSnackBar('Vui lòng nhập mã thiết bị.');
    }
    if (filePicker == null) return;
    await HandlerFileController().exportFile(filePicker!, int.parse(machineId), (message) {
      showSnackBar(message);
    });
  }

  void showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text('${message}'),
      action: SnackBarAction(
        label: 'OK',
        onPressed: () {
          // Some code to undo the change.
        },
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
}
