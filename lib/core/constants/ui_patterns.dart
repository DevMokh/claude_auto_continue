/// Every string the app uses to recognise parts of the official Claude UI.
///
/// IMPORTANT: these are educated guesses, NOT verified against a real device.
/// Use Settings > Calibration > "Capture screen tree" on your phone, then adjust
/// these lists to match what your Claude version really exposes.
/// All entries must be lower-case (they are compared after `normalizeText`).
class UiPatterns {
  UiPatterns._();

  static const String claudePackage = 'com.anthropic.claude';

  /// Control labels that mean "Claude is generating right now".
  static const List<String> stopLabels = <String>[
    'stop',
    'stop response',
    'stop generating',
    'stop streaming',
    'إيقاف',
    'إيقاف الرد',
    'إيقاف التوليد',
  ];

  /// Exact labels of the "Continue" button shown when a response is cut off.
  static const List<String> continueLabels = <String>[
    'continue',
    'continue generating',
    'متابعة',
    'استمرار',
    'واصل',
    'إكمال',
  ];

  /// Exact labels of the send button.
  static const List<String> sendLabels = <String>[
    'send',
    'send message',
    'إرسال',
    'ارسال',
  ];

  /// Substrings that indicate a usage-limit banner (matched in SHORT texts only).
  static const List<String> usageLimitPhrases = <String>[
    'usage limit',
    'reached your limit',
    'reached the limit',
    'hit your limit',
    'limit reached',
    'limit will reset',
    'limit resets',
    'out of messages',
    'out of free messages',
    'message limit',
    'حد الاستخدام',
    'وصلت إلى الحد',
    'بلغت الحد',
    'تجاوزت الحد',
    'الحد الأقصى للرسائل',
    'تم الوصول إلى الحد',
  ];

  /// Exact labels of controls that belong to a login / sign-up screen.
  static const List<String> loginLabels = <String>[
    'log in',
    'login',
    'sign in',
    'continue with google',
    'continue with apple',
    'continue with email',
    'تسجيل الدخول',
  ];

  /// Substrings that indicate a security / human verification challenge.
  static const List<String> securityPhrases = <String>[
    'captcha',
    'verify you are human',
    'security check',
    'unusual activity',
    'verification code',
    'تحقق أمني',
    'رمز التحقق',
  ];

  /// Substrings that indicate a connection or generic error banner.
  static const List<String> errorPhrases = <String>[
    'network error',
    'no internet',
    'check your connection',
    'could not connect',
    "couldn't connect",
    'connection lost',
    'something went wrong',
    'failed to send',
    'خطأ في الشبكة',
    'لا يوجد اتصال',
    'حدث خطأ ما',
  ];
}
