import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

Directory generalDownloadDir = Directory('/storage/emulated/0/Download');

class Record {
  String LcscCode = "";
  int pcs = 0;
}

List<Record> records = [];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: BarcodeScannerWithController(),
    );
  }
}

class BarcodeScannerWithController extends StatefulWidget {
  const BarcodeScannerWithController({Key? key}) : super(key: key);

  @override
  _BarcodeScannerWithControllerState createState() =>
      _BarcodeScannerWithControllerState();
}

class _BarcodeScannerWithControllerState
    extends State<BarcodeScannerWithController>
    with SingleTickerProviderStateMixin {
  BarcodeCapture? barcode;

  final MobileScannerController controller = MobileScannerController(
    torchEnabled: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          return Column(
            children: [
              SizedBox(
                height: 300,
                child: MobileScanner(
                  controller: controller,
                  errorBuilder: (context, error, child) {
                    return Text(':(');
                  },
                  onDetect: (barcode) async {
                    if(!barcode.barcodes.last.displayValue!.startsWith("{")){
                      return;
                    }
                    if (this
                            .barcode
                            ?.barcodes
                            .last
                            .rawValue
                            ?.compareTo(barcode.barcodes.last.rawValue!) ==
                        0) {
                      return;
                    }
                    this.barcode = barcode;
                    SystemSound.play(SystemSoundType.alert);
                    Vibration.vibrate(duration: 500);
                    try {
                      var file = await writeFile(
                          barcode.barcodes.last.displayValue!, 'name');
                      Fluttertoast.showToast(msg: "saved!");
                    } catch (e) {
                      Fluttertoast.showToast(msg: "error while saving");
                    }

                    setState(() {
                      this.barcode = barcode;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.bottomCenter,
                  height: 200,
                  child: Column(
                    children: [
                      Center(
                        child: FittedBox(
                          child: Text(
                            barcode?.barcodes.first.rawValue ?? 'Scan something!',
                            overflow: TextOverflow.fade,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: GridView.count(
                            crossAxisCount: 5,
                            childAspectRatio: 3,
                            children: records.map((record) {
                              return SizedBox(
                                height: 5,
                                child: Text("${record.LcscCode}:${record.pcs}\n",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(color: Colors.white),),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String recordsToText() {
    String txt = " ";
    for (Record record in records) {
      txt += "${record.LcscCode}:${record.pcs}\n";
    }
    return txt;
  }

  Future<File> writeFile(String data, String name) async {
    //fuckery to parse badly formatted json and save result to records
    YamlMap yaml = loadYaml(data.toString());
    Record rec = Record();
    for (YamlScalar str in yaml.nodes.keys) {
      var entry = str.value.split(":");

      if (entry[0] == "pc") {
        rec.LcscCode = entry[1];
      }
      if (entry[0] == "qty") {
        rec.pcs = int.parse(entry[1]);
      }
    }
    records.add(rec);

    //save
    //records.add(Record()..LcscCode)
    // storage permission ask
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    // the downloads folder path
    Directory tempDir = Directory("/storage/emulated/0/Download");
    String tempPath = tempDir.path;
    var filePath = tempPath + '/$name';
    //

    // save the data in the path
    return File(filePath)
        .writeAsBytes(utf8.encode(data), mode: FileMode.append);
  }
}
