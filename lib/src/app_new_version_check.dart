import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class AppVersion {
  String? iOSAppStoreCountry;
  String? iOSId;
  String? version = "";

  void checkAppUpdate(
      {required BuildContext? context,
      String? iOSId,
      String? iOSAppStoreCountry,
      required String? applicationPackageId}) async {
    String? data = await rootBundle.loadString("pubspec.yaml");
    var yaml = loadYaml(data);
    version = yaml["version"];

    showAlertIfNecessary(
        context: context!, version: version, packageName: applicationPackageId);
  }

  showAlertIfNecessary(
      {required BuildContext context,
      required String? version,
      required String? packageName}) async {
    final VersionStatus? versionStatus =
        await getVersionStatus(version: version, packageName: packageName);
    if (versionStatus != null && versionStatus.canUpdate) {
      showUpdateDialog(context: context, versionStatus: versionStatus);
    }
  }

  Future<VersionStatus?> getVersionStatus(
      {required String? version, required String? packageName}) async {
    if (Platform.isIOS) {
      return _getIOSStoreVersion(version, packageName);
    } else if (Platform.isAndroid) {
      return _getAndroidStoreVersion(version, packageName);
    } else {
      debugPrint(
          'The target platform "${Platform.operatingSystem}" is not yet supported by this package.');
      return null;
    }
  }

  Future<VersionStatus?> _getAndroidStoreVersion(
      appVersion, packageName) async {
    final id = packageName;
    final uri = Uri.https(
        "play.google.com", "/store/apps/details", {"id": id, "hl": "en"});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Can\'t find an app in the Play Store with the id: $id');
      return null;
    }
    final document = parse(response.body);

    String storeVersion = '0.0.0';
    String? releaseNotes;

    final additionalInfoElements = document.getElementsByClassName('hAyfc');
    if (additionalInfoElements.isNotEmpty) {
      final versionElement = additionalInfoElements.firstWhere(
        (elm) => elm.querySelector('.BgcNfc')!.text == 'Current Version',
      );
      storeVersion = versionElement.querySelector('.htlgb')!.text;

      final sectionElements = document.getElementsByClassName('W4P4ne');
      final releaseNotesElement = sectionElements.firstWhere(
        (elm) => elm.querySelector('.wSaTQd')!.text == 'What\'s New',
      );
      releaseNotes = releaseNotesElement
          .querySelector('.PHBdkd')
          ?.querySelector('.DWPxHb')
          ?.text;
    } else {
      final scriptElements = document.getElementsByTagName('script');
      var infoScriptElement;
      try {
         infoScriptElement = scriptElements
            .firstWhere((elm) => elm.text.contains('key: \'ds:5\''));
      } catch (exception) {
        return null;
      }

      final param = infoScriptElement.text
          .substring(20, infoScriptElement.text.length - 2)
          .replaceAll('key:', '"key":')
          .replaceAll('hash:', '"hash":')
          .replaceAll('data:', '"data":')
          .replaceAll('sideChannel:', '"sideChannel":')
          .replaceAll('\'', '"');
      final parsed = json.decode(param);
      final data = parsed['data'];
      if (data.isEmpty) return null;
      storeVersion = data[1][2][140][0][0][0];
      try {
        releaseNotes = data[1][2][144][1][1];
      } catch (e) {}
    }

    return VersionStatus._(
      localVersion: _getCleanVersion(appVersion),
      storeVersion: _getCleanVersion(storeVersion),
      appStoreLink: uri.toString(),
      releaseNotes: releaseNotes,
    );
  }

  Future<VersionStatus?> _getIOSStoreVersion(appVersion, packageName) async {
    final id = iOSId ?? packageName;
    final parameters = {"bundleId": id};
    if (iOSAppStoreCountry != null) {
      parameters.addAll({"country": iOSAppStoreCountry!});
    }
    var uri = Uri.https("itunes.apple.com", "/lookup", parameters);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Failed to query iOS App Store');
      return null;
    }
    final jsonObj = json.decode(response.body);
    final List results = jsonObj['results'];
    if (results.isEmpty) {
      debugPrint('Can\'t find an app in the App Store with the id: $id');
      return null;
    }
    return VersionStatus._(
      localVersion: _getCleanVersion(appVersion),
      storeVersion: _getCleanVersion(jsonObj['results'][0]['version']),
      appStoreLink: jsonObj['results'][0]['trackViewUrl'],
      releaseNotes: jsonObj['results'][0]['releaseNotes'],
    );
  }

  String _getCleanVersion(String version) =>
      RegExp(r'\d+\.\d+\.\d+').stringMatch(version) ?? '0.0.0';

  void showUpdateDialog({
    required BuildContext context,
    required VersionStatus versionStatus,
    String dialogTitle = 'Update Available',
    String? dialogText,
    String updateButtonText = 'Update',
    bool allowDismissal = true,
    String dismissButtonText = 'Cancel',
    VoidCallback? dismissAction,
  }) async {
    final dialogTitleWidget = Text(dialogTitle);
    final dialogTextWidget = Text(
      dialogText ??
          'You can now update this app from ${versionStatus.localVersion} to ${versionStatus.storeVersion}',
    );

    final updateButtonTextWidget = Text(updateButtonText);
    final updateAction = () {
      launchAppStore(versionStatus.appStoreLink);
      if (allowDismissal) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };

    List<Widget> actions = [
      Platform.isAndroid
          ? TextButton(
              child: updateButtonTextWidget,
              onPressed: updateAction,
            )
          : CupertinoDialogAction(
              child: updateButtonTextWidget,
              onPressed: updateAction,
            ),
    ];

    if (allowDismissal) {
      final dismissButtonTextWidget = Text(dismissButtonText);
      dismissAction = dismissAction ??
          () => Navigator.of(context, rootNavigator: true).pop();
      actions.add(
        Platform.isAndroid
            ? TextButton(
                child: dismissButtonTextWidget,
                onPressed: dismissAction,
              )
            : CupertinoDialogAction(
                child: dismissButtonTextWidget,
                onPressed: dismissAction,
              ),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: allowDismissal,
      builder: (BuildContext context) {
        // ignore: deprecated_member_use
        return WillPopScope(
            child: Platform.isAndroid
                ? AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    title: dialogTitleWidget,
                    content: dialogTextWidget,
                    actions: actions,
                  )
                : CupertinoAlertDialog(
                    title: dialogTitleWidget,
                    content: dialogTextWidget,
                    actions: actions,
                  ),
            onWillPop: () => Future.value(allowDismissal));
      },
    );
  }

  Future<void> launchAppStore(String appStoreLink) async {
    debugPrint(appStoreLink);
    if (await launchUrl(Uri.parse(appStoreLink))) {
      await launchUrl(Uri.parse(appStoreLink));
    } else {
      throw 'Could not launch appStoreLink';
    }
  }
}

class VersionStatus {
  final String localVersion;
  final String storeVersion;
  final String appStoreLink;

  final String? releaseNotes;

  bool get canUpdate {
    final local = localVersion.split('.').map(int.parse).toList();
    final store = storeVersion.split('.').map(int.parse).toList();

    for (var i = 0; i < store.length; i++) {
      if (store[i] > local[i]) {
        return true;
      }
      if (local[i] > store[i]) {
        return false;
      }
    }

    return false;
  }

  VersionStatus._({
    required this.localVersion,
    required this.storeVersion,
    required this.appStoreLink,
    this.releaseNotes,
  });
}
