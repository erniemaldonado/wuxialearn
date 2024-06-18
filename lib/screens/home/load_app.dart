import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:hsk_learner/screens/home/home_page.dart';
import 'package:hsk_learner/sql/schema_migration.dart';
import 'package:hsk_learner/sql/sql_helper.dart';
import '../settings/backup.dart';
import '../settings/preferences.dart';
import 'package:http/http.dart' as http;

class LoadApp extends StatefulWidget {
  final bool fdroid;
  const LoadApp({Key? key, this.fdroid = false}) : super(key: key);

  @override
  State<LoadApp> createState() => _LoadAppState();
}

class _LoadAppState extends State<LoadApp> {
  bool isLoading = true;
  @override
  void initState() {
    SchemaMigration.run();
    getPreferences();
    super.initState();
  }
  void getPreferences() async {
    final data = await SQLHelper.getPreferences();
    await Preferences.loadDefaultPreferences();
    Preferences.setPreferences(data);
    init();
  }
  void init(){
    final String currentVersion = Preferences.getPreference("db_version");
    final String latestVersion = Preferences.getPreference("latest_db_version_constant");
    print(currentVersion);
    print(latestVersion);
    print(currentVersion == latestVersion);
    if(currentVersion != latestVersion){
      print("backing up...");
      Backup.startBackupFromTempDir();
    }
    final bool check = Preferences.getPreference("check_for_new_version_on_start");
    final bool isFirstRun =  Preferences.getPreference("isFirstRun");
    if(check && !isFirstRun) {
      checkForDbUpdate();
    }
    setState(() {
      isLoading = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    if(isLoading){
      return const Loading();
    }else{
      final bool isFirstRun =  Preferences.getPreference("isFirstRun");
      if(isFirstRun){
        if(widget.fdroid){
          Future.delayed(const Duration(seconds: 0)).then((_) {
            _showActionSheet(context);
          });
        }else{
          setFirstRun();
          enableCheckForUpdate();
          checkForDbUpdate();
        }
        return const MyHomePage(tab: 0);
      }else{
        return const MyHomePage(tab: 0);
      }
    }
  }

  void  _showActionSheet<bool>(BuildContext context) {
    showCupertinoModalPopup<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Check for update on app start? (recommended)'),
        actions:
        [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              setFirstRun();
              enableCheckForUpdate();
              Navigator.pop(context, true);
              checkForDbUpdate();
            },
            child: const Text("Yes"),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              setFirstRun();
              disableCheckForUpdate();
              Navigator.pop(context, true);
            },
            child: const Text("No"),
          ),
        ]
      ),
    );
  }

  void setFirstRun(){
    SQLHelper.setPreference(name: "isFirstRun", value: "0", type: "bool");
    Preferences.setPreference(name: "isFirstRun", value: false);
  }

  void enableCheckForUpdate(){
    SQLHelper.setPreference(name: "check_for_new_version_on_start", value: "1", type: "bool");
    Preferences.setPreference(name: "check_for_new_version_on_start", value: true);
  }

  void disableCheckForUpdate(){
    SQLHelper.setPreference(name: "check_for_new_version_on_start", value: "0", type: "bool");
    Preferences.setPreference(name: "check_for_new_version_on_start", value: false);
  }

  void checkForDbUpdate() async {
      const String dbPref = 'db_version';
      final prefs = Preferences.getAllPreferences();
      print("checking for update");
      print(prefs);
      final test = Preferences.getPreference("check_for_new_version_on_start");
      print(test);
      final String lastVersion = Preferences.getPreference(dbPref);
      const String versionUrl = 'https://cdn.jsdelivr.net/gh/wuxialearn/data@main/version';
      final req = await http.get(Uri.parse(versionUrl));
      final String version = req.body.trim();
      if(version != lastVersion){
        await SQLHelper.updateSqliteFromCsv();
        Preferences.setPreference(name: dbPref, value: version);
        SQLHelper.setPreference(name: dbPref, value: version, type: 'string');
        //todo: when we implement real state management we should update the courses screen here
        setState(() {

        });
      }
  }
}

class Loading extends StatelessWidget {
  const Loading({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: !kIsWeb?
      SizedBox(height: 10,):
      Visibility(
        visible: false,
          maintainState: true,
          maintainSize: true,
          maintainAnimation: true,
          maintainInteractivity: true,
          maintainSemantics: true,
          child: Text("Load zh 中文")
      ),
    );
  }
}