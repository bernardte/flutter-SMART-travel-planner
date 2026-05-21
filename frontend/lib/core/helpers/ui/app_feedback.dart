import 'package:flutter/material.dart';
import 'app_snackbar.dart';
import 'app_loading.dart';
import 'app_dialog.dart';

class AppFeedback {
  static void success(BuildContext context, String msg) {
    AppSnackBar.show(context, msg, type: SnackType.success);
  }

  static void error(BuildContext context, String msg) {
    AppSnackBar.show(context, msg, type: SnackType.error);
  }

  static void info(BuildContext context, String msg) {
    AppSnackBar.show(context, msg, type: SnackType.info);
  }

  static void showLoading(BuildContext context, {String msg = "Loading..."}) {
    AppLoading.show(context, message: msg);
  }

  static void hideLoading(BuildContext context) {
    AppLoading.hide(context);
  }

  static void showErrorDialog(BuildContext context, String msg) {
    AppDialog.showError(context, msg);
  }

  static void showSuccessDialog(BuildContext context, String msg) {
    AppDialog.showSuccess(context, msg);
  }

  static void showWarningDialog(BuildContext context, String msg) {
    AppDialog.showWarning(context, msg);
  }

  static void showInfoDialog(BuildContext context, String msg) {
    AppDialog.showInfo(context, msg);
  }
}
