# App New Version Check

A flutter library to check app new version.

## How to use
Add this package to pubspec.yaml and then import.

```dart
 import 'package:app_new_version_check/app_new_version_check.dart';
 ```

Add "- pubspec.yaml" to assets in pubspec.yaml file
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
