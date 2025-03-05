import 'dart:async';
import 'dart:js' as js;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Flutter plugin for Razorpay SDK
class RazorpayFlutterPlugin {
  // Response codes from platform

  /// Success response code
  static const _CODE_PAYMENT_SUCCESS = 0;

  /// Error response code
  static const _CODE_PAYMENT_ERROR = 1;
  // static const _CODE_PAYMENT_EXTERNAL_WALLET = 2;

  // Payment error codes

  /// Network error code
  static const NETWORK_ERROR = 0;

  /// Invalid options error code
  static const INVALID_OPTIONS = 1;

  /// Payment cancelled error code
  static const PAYMENT_CANCELLED = 2;

  /// TLS error code
  static const TLS_ERROR = 3;

  /// Incompatible plugin error code
  static const INCOMPATIBLE_PLUGIN = 4;

  /// Unknown error code
  static const UNKNOWN_ERROR = 100;

  /// Base request error code
  static const BASE_REQUEST_ERROR = 5;

  /// Registers plugin with registrar
  static void registerWith(Registrar registrar) {
    final MethodChannel methodChannel = MethodChannel(
        'razorpay_flutter',
        const StandardMethodCodec(),
        // ignore: deprecated_member_use
        registrar.messenger);
    final RazorpayFlutterPlugin instance = RazorpayFlutterPlugin();
    methodChannel.setMethodCallHandler(instance.handleMethodCall);
  }

  /// Handles method calls over platform channel
  Future<Map<dynamic, dynamic>> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'open':
        return await startPayment(call.arguments);
      case 'resync':
      default:
        var defaultMap = {'status': 'Not implemented on web'};

        return defaultMap;
    }
  }

  /// Starts the payment flow
  Future<Map<dynamic, dynamic>> startPayment(Map<dynamic, dynamic> options) async {
    // Completer to return future response
    var completer = Completer<Map<dynamic, dynamic>>();

    var returnMap = <dynamic, dynamic>{}; // Main return object
    var dataMap = <dynamic, dynamic>{}; // Data object

    // Ensure Razorpay SDK is loaded before proceeding
    if (!js.context.hasProperty('Razorpay')) {
      completer.completeError("Razorpay SDK not loaded");
      return completer.future;
    }

    options['handler'] = (response) {
      returnMap['type'] = _CODE_PAYMENT_SUCCESS;
      dataMap['razorpay_payment_id'] = response['razorpay_payment_id'];
      dataMap['razorpay_order_id'] = response['razorpay_order_id'];
      dataMap['razorpay_signature'] = response['razorpay_signature'];
      returnMap['data'] = dataMap;
      completer.complete(returnMap);
    };

    options['modal.ondismiss'] = () {
      if (!completer.isCompleted) {
        returnMap['type'] = _CODE_PAYMENT_ERROR;
        dataMap['code'] = PAYMENT_CANCELLED;
        dataMap['message'] = 'Payment processing cancelled by user';
        returnMap['data'] = dataMap;
        completer.complete(returnMap);
      }
    };

    // Handle retry logic
    var jsObjOptions = js.JsObject.jsify(options);
    if (jsObjOptions.hasProperty('retry')) {
      if (jsObjOptions['retry']['enabled'] == true) {
        options['retry'] = true;
      } else {
        options['retry'] = false;
      }
    } else {
      options['retry'] = false;
    }

    // Initialize Razorpay instance
    var razorpay = js.JsObject.fromBrowserObject(js.context.callMethod('Razorpay', [js.JsObject.jsify(options)]));

    // Handle payment failure
    razorpay.callMethod('on', [
      'payment.failed',
      (response) {
        returnMap['type'] = _CODE_PAYMENT_ERROR;
        dataMap['code'] = BASE_REQUEST_ERROR;
        dataMap['message'] = response['error']['description'];
        var metadataMap = <dynamic, dynamic>{};
        metadataMap['payment_id'] = response['error']['metadata']['payment_id'];
        dataMap['metadata'] = metadataMap;
        dataMap['source'] = response['error']['source'];
        dataMap['step'] = response['error']['step'];
        returnMap['data'] = dataMap;
        completer.complete(returnMap);
      }
    ]);

    // Open Razorpay checkout
    razorpay.callMethod('open');

    return completer.future;
  }
}
