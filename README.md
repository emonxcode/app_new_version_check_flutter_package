# App New Version Check

A simple Flutter package to check new version available to the store, and show update popup. It simply used pubspec.yaml file to extract the current version of the app and maches wth the version availabe in the store.

## How to use
Add this package to pubspec.yaml and then import.

```dart
 import 'package:app_new_version_check/app_new_version_check.dart';
 ```

Add "- pubspec.yaml" to the assets section in pubspec.yaml file
 ```dart
  assets:
    - pubspec.yaml
 ```

 ```dart
 AppVersion().checkAppUpdate(
    context: context,
    applicationPackageId: "com.example.app", // flutter application package id
 );
 ```


# Thanks
