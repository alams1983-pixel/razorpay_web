import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razorpay_web/razorpay_web.dart';

void main() {
  group("$Razorpay", () {
    const MethodChannel channel = MethodChannel("razorpay_flutter");

    final List<MethodCall> log = <MethodCall>[];

    late Razorpay razorpay;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        log.add(call);
        return {};
      });

      razorpay = Razorpay();

      log.clear();
    });

    group("#open", () {
      setUp(() {
        WidgetsFlutterBinding.ensureInitialized();
        razorpay = Razorpay();
        // razorpay.clear();
      });

      test('passes options correctly', () async {
        var options = {
          'key': 'rzp_test_1DP5mmOlF5G5aa',
          'amount': 2000,
          'name': 'Acme Corp.',
          'description': 'Fine T-Shirt',
          'prefill': {'contact': '8888888888', 'email': 'test@razorpay.com'}
        };

        razorpay.open(options);

        expect(log, <Matcher>[isMethodCall('open', arguments: options)]);
      });

      test('throws error if key is not passed', () async {
        var options = {
          'amount': 2000,
          'name': 'Acme Corp.',
          'description': 'Fine T-Shirt',
          'prefill': {'contact': '8888888888', 'email': 'test@razorpay.com'}
        };

        errorHandler(PaymentFailureResponse response) {
          expect(response.code, equals(ResponseCodes.INVALID_OPTIONS));
        }

        razorpay.on(RazorpayEvents.EVENT_PAYMENT_ERROR, expectAsync1(errorHandler, count: 1));

        razorpay.open(options);
      });
    });
  });
}
