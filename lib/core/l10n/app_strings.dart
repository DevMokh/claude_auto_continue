import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/automation_state.dart';
import '../../models/claude_ui_state.dart';
import '../../models/log_entry.dart';

/// Minimal built-in localisation (Arabic RTL + English), no code generation.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  bool get isArabic => locale.languageCode == 'ar';

  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];
  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  /// Language code ('ar' or 'en') for a settings value such as 'system'.
  static String resolveCode(String settingCode, String systemCode) {
    if (settingCode == 'ar' || settingCode == 'en') return settingCode;
    return systemCode == 'ar' ? 'ar' : 'en';
  }

  @visibleForTesting
  static Set<String> get arabicKeys => _ar.keys.toSet();

  @visibleForTesting
  static Set<String> get englishKeys => _en.keys.toSet();

  String t(String key) => (isArabic ? _ar[key] : _en[key]) ?? _en[key] ?? key;

  String stateLabel(AutomationState s) {
    switch (s) {
      case AutomationState.idle:
        return t('state_idle');
      case AutomationState.monitoring:
        return t('state_monitoring');
      case AutomationState.claudeWorking:
        return t('state_claude_working');
      case AutomationState.waitingForUsageReset:
        return t('state_waiting_reset');
      case AutomationState.usageAvailable:
        return t('state_usage_available');
      case AutomationState.sendingContinue:
        return t('state_sending_continue');
      case AutomationState.waitingForResponse:
        return t('state_waiting_response');
      case AutomationState.needsAttention:
        return t('state_needs_attention');
      case AutomationState.stopped:
        return t('state_stopped');
    }
  }

  String claudeState(ClaudeUiState s) => t('ui_${s.name}');

  String attentionText(String code) => t('att_$code');

  String logMessage(LogEntry e) {
    final direct = t('log_${e.code}');
    if (direct != 'log_${e.code}') return direct;
    final att = t('att_${e.code}');
    if (att != 'att_${e.code}') return att;
    return e.code;
  }

  static const Map<String, String> _en = <String, String>{
    'app_name': 'Claude Auto Continue',
    'tab_home': 'Home',
    'tab_monitor': 'Monitor',
    'tab_settings': 'Settings',
    'tab_logs': 'Activity',
    'start': 'Start',
    'stop': 'Stop',
    'open_claude': 'Open Claude',
    'cancel': 'Cancel',
    'open_settings': 'Open settings',
    'copy': 'Copy',
    'close': 'Close',
    'clear': 'Clear',
    'fix': 'Fix',
    'state_idle': 'Idle',
    'state_monitoring': 'Monitoring',
    'state_claude_working': 'Claude Working',
    'state_waiting_reset': 'Waiting for Usage Reset',
    'state_usage_available': 'Usage Available',
    'state_sending_continue': 'Sending Continue',
    'state_waiting_response': 'Waiting for Response',
    'state_needs_attention': 'Needs Attention',
    'state_stopped': 'Stopped',
    'ui_unavailable': 'Accessibility off',
    'ui_notClaude': 'Claude not in front',
    'ui_needsLogin': 'Login / verification',
    'ui_offline': 'Phone offline',
    'ui_connectionError': 'Connection error',
    'ui_usageLimit': 'Usage limit',
    'ui_generating': 'Answering',
    'ui_ready': 'Ready',
    'ui_unknown': 'Unrecognized screen',
    'claude_status': 'Claude',
    'auto_status': 'Auto Continue',
    'continue_count': 'Continue sent',
    'wait_time': 'Waiting time',
    'setup_title': 'Setup checklist',
    'setup_accessibility': 'Accessibility service',
    'setup_claude': 'Claude app installed',
    'setup_notifications': 'Notifications',
    'setup_battery': 'Battery optimization off',
    'monitor_title': 'Monitor',
    'timeline': 'States',
    'last_check': 'Last check',
    'composer': 'Message box',
    'composer_ready': 'Ready',
    'composer_not_ready': 'Not ready',
    'check_interval': 'Check every',
    'limit_message': 'Limit message',
    'attention_reason': 'Needs your attention',
    'seconds': 's',
    'settings_title': 'Settings',
    's_auto_resume': 'Resume monitoring after restart',
    's_auto_resume_sub': 'Restores the saved state when the app reopens. It still verifies Claude before any action.',
    's_max_attempts': 'Maximum continue attempts',
    's_interval': 'Seconds between checks',
    's_notifications': 'Notifications',
    's_click_continue': 'Press the Continue button',
    's_send_continue': 'Send "كمل"',
    's_auto_stop': 'Stop automatically on a problem',
    's_keep_screen': 'Keep screen on while monitoring',
    's_language': 'Language',
    'lang_system': 'System',
    'lang_ar': 'العربية',
    'lang_en': 'English',
    's_calibration': 'Calibration',
    's_calibration_sub': 'Capture what the accessibility service sees in Claude, to adjust the detection patterns.',
    's_capture': 'Capture screen tree',
    's_capture_hint': 'Tap the button, switch to Claude within 8 seconds, then come back here to see the result. The capture may contain visible chat text; it stays on this phone unless you copy it.',
    'capture_started': 'Switch to Claude now. Capturing in 8 seconds...',
    's_privacy': 'Privacy',
    's_privacy_body': 'Everything stays on this phone. The app has no internet permission, stores no passwords or tokens, and only reads the Claude app window.',
    'logs_title': 'Activity log',
    'logs_empty': 'No activity yet.',
    'acs_title': 'Accessibility permission',
    'acs_body': 'To work, this app needs the Accessibility service. It is used only to read the screen of the official Claude app, to detect when Claude stops at the usage limit, and to press Continue or send the word "كمل" once when you have turned automation on. It never reads passwords, never touches other apps, and sends nothing off the phone. You can turn it off at any time in system settings.',
    'err_accessibility': 'Turn on the Accessibility service first.',
    'err_claude_missing': 'The official Claude app is not installed.',
    'notif_title_attention': 'Auto Continue needs you',
    'notif_title_info': 'Auto Continue',
    'notif_sent_suffix': 'sent',
    'att_accessibility_off': 'Accessibility service is off. Turn it on and press Start.',
    'att_login_required': 'Login or verification screen detected. Handle it yourself, then press Start.',
    'att_claude_not_foreground': 'Claude is not on screen. Open your conversation.',
    'att_ui_unrecognized': 'The Claude screen is not recognized. Check it, or calibrate the patterns.',
    'att_send_failed': 'Could not send the message safely. Nothing was retried.',
    'att_send_failed_text_remains': 'The text stayed in the message box. Check the conversation.',
    'att_send_not_confirmed': 'Could not confirm Claude started answering. Nothing was resent.',
    'att_continue_click_failed': 'Could not press Continue safely.',
    'att_engine_error': 'Unexpected internal error. Automation stopped.',
    'log_monitoring_started': 'Monitoring started',
    'log_monitoring_resumed': 'Monitoring resumed after restart (verifying Claude first)',
    'log_response_finished': 'Claude finished its response',
    'log_claude_working': 'Claude is answering',
    'log_usage_limit_detected': 'Usage limit detected',
    'log_wait_started': 'Started waiting for usage to return',
    'log_usage_available': 'Usage seems available (verified)',
    'log_usage_available_send_disabled': 'Usage available; sending is disabled, so you decide',
    'log_verification_failed': 'Final verification failed, back to waiting',
    'log_sending_continue': 'Sending "كمل"',
    'log_continue_sent': 'Sent "كمل"',
    'log_continue_button_detected': 'Continue button detected',
    'log_continue_button_clicked': 'Continue button pressed',
    'log_send_result_failed': 'Send attempt failed',
    'log_resumed_externally': 'Claude resumed without us; wait ended',
    'log_claude_not_foreground': 'Claude is not in the foreground',
    'log_ui_unrecognized': 'Claude screen not recognized',
    'log_device_offline': 'Phone is offline; holding',
    'log_claude_connection_error': 'Claude shows a connection error; holding',
    'log_attention_cleared': 'Problem cleared, back to normal',
    'log_stopped_user': 'Stopped by you',
    'log_stopped_notification': 'Stopped from the notification',
    'log_stopped_max_attempts': 'Stopped: maximum attempts reached',
    'log_max_attempts_reached': 'Maximum attempts reached',
  };

  static const Map<String, String> _ar = <String, String>{
    'app_name': 'Claude Auto Continue',
    'tab_home': 'الرئيسية',
    'tab_monitor': 'المراقبة',
    'tab_settings': 'الإعدادات',
    'tab_logs': 'السجل',
    'start': 'ابدأ',
    'stop': 'إيقاف',
    'open_claude': 'افتح Claude',
    'cancel': 'إلغاء',
    'open_settings': 'فتح الإعدادات',
    'copy': 'نسخ',
    'close': 'إغلاق',
    'clear': 'مسح',
    'fix': 'إصلاح',
    'state_idle': 'خامل',
    'state_monitoring': 'مراقبة',
    'state_claude_working': 'Claude يعمل',
    'state_waiting_reset': 'بانتظار تجدد الاستخدام',
    'state_usage_available': 'الاستخدام متاح',
    'state_sending_continue': 'جارٍ إرسال كمل',
    'state_waiting_response': 'بانتظار الرد',
    'state_needs_attention': 'يحتاج تدخلك',
    'state_stopped': 'متوقف',
    'ui_unavailable': 'الإتاحة مغلقة',
    'ui_notClaude': 'Claude ليس في المقدمة',
    'ui_needsLogin': 'تسجيل دخول / تحقق',
    'ui_offline': 'الهاتف بلا إنترنت',
    'ui_connectionError': 'خطأ اتصال',
    'ui_usageLimit': 'حد الاستخدام',
    'ui_generating': 'يكتب الرد',
    'ui_ready': 'جاهز',
    'ui_unknown': 'شاشة غير معروفة',
    'claude_status': 'Claude',
    'auto_status': 'Auto Continue',
    'continue_count': 'مرات إرسال كمل',
    'wait_time': 'وقت الانتظار',
    'setup_title': 'قائمة الإعداد',
    'setup_accessibility': 'خدمة إمكانية الوصول',
    'setup_claude': 'تطبيق Claude مثبّت',
    'setup_notifications': 'الإشعارات',
    'setup_battery': 'استثناء تحسين البطارية',
    'monitor_title': 'المراقبة',
    'timeline': 'الحالات',
    'last_check': 'آخر فحص',
    'composer': 'حقل الرسالة',
    'composer_ready': 'جاهز',
    'composer_not_ready': 'غير جاهز',
    'check_interval': 'الفحص كل',
    'limit_message': 'رسالة الحد',
    'attention_reason': 'يحتاج تدخلك',
    'seconds': 'ث',
    'settings_title': 'الإعدادات',
    's_auto_resume': 'استئناف المراقبة بعد إعادة التشغيل',
    's_auto_resume_sub': 'يستعيد الحالة المحفوظة عند فتح التطبيق، ويتحقق من Claude قبل أي إجراء.',
    's_max_attempts': 'الحد الأقصى لمحاولات الاستكمال',
    's_interval': 'الثواني بين عمليات الفحص',
    's_notifications': 'الإشعارات',
    's_click_continue': 'الضغط على زر Continue',
    's_send_continue': 'إرسال "كمل"',
    's_auto_stop': 'الإيقاف التلقائي عند وجود مشكلة',
    's_keep_screen': 'إبقاء الشاشة مضاءة أثناء المراقبة',
    's_language': 'اللغة',
    'lang_system': 'النظام',
    'lang_ar': 'العربية',
    'lang_en': 'English',
    's_calibration': 'المعايرة',
    's_calibration_sub': 'التقط ما تراه خدمة الإتاحة داخل Claude لتعديل أنماط الاكتشاف.',
    's_capture': 'التقاط شجرة الشاشة',
    's_capture_hint': 'اضغط الزر، ثم انتقل إلى Claude خلال 8 ثوانٍ، ثم ارجع هنا لترى النتيجة. قد يحتوي الالتقاط على نص المحادثة الظاهر، ويبقى على هذا الهاتف ما لم تنسخه.',
    'capture_started': 'انتقل إلى Claude الآن. سيتم الالتقاط بعد 8 ثوانٍ...',
    's_privacy': 'الخصوصية',
    's_privacy_body': 'كل شيء يبقى على هذا الهاتف. التطبيق بلا إذن إنترنت، ولا يخزّن كلمات مرور أو رموز، ولا يقرأ إلا نافذة تطبيق Claude.',
    'logs_title': 'سجل النشاط',
    'logs_empty': 'لا يوجد نشاط بعد.',
    'acs_title': 'إذن إمكانية الوصول',
    'acs_body': 'يحتاج التطبيق إلى خدمة إمكانية الوصول ليعمل. تُستخدم فقط لقراءة شاشة تطبيق Claude الرسمي، واكتشاف توقفه عند حد الاستخدام، وللضغط على Continue أو إرسال كلمة "كمل" مرة واحدة عند تفعيلك للأتمتة. لا تقرأ كلمات المرور ولا تلمس تطبيقات أخرى ولا ترسل شيئًا خارج الهاتف. يمكنك إيقافها في أي وقت من إعدادات النظام.',
    'err_accessibility': 'فعّل خدمة إمكانية الوصول أولًا.',
    'err_claude_missing': 'تطبيق Claude الرسمي غير مثبّت.',
    'notif_title_attention': 'Auto Continue يحتاجك',
    'notif_title_info': 'Auto Continue',
    'notif_sent_suffix': 'مرسلة',
    'att_accessibility_off': 'خدمة إمكانية الوصول متوقفة. فعّلها ثم اضغط ابدأ.',
    'att_login_required': 'ظهرت شاشة تسجيل دخول أو تحقق. تعامل معها بنفسك ثم اضغط ابدأ.',
    'att_claude_not_foreground': 'Claude ليس على الشاشة. افتح محادثتك.',
    'att_ui_unrecognized': 'شاشة Claude غير معروفة. راجعها أو عدّل الأنماط من المعايرة.',
    'att_send_failed': 'تعذر إرسال الرسالة بأمان. لم تتم أي إعادة محاولة.',
    'att_send_failed_text_remains': 'بقي النص داخل حقل الرسالة. راجع المحادثة.',
    'att_send_not_confirmed': 'تعذر التأكد من أن Claude بدأ بالرد. لم يُعاد الإرسال.',
    'att_continue_click_failed': 'تعذر الضغط على Continue بأمان.',
    'att_engine_error': 'خطأ داخلي غير متوقع. توقفت الأتمتة.',
    'log_monitoring_started': 'بدأت المراقبة',
    'log_monitoring_resumed': 'استؤنفت المراقبة بعد إعادة التشغيل (مع التحقق من Claude أولًا)',
    'log_response_finished': 'انتهى رد Claude',
    'log_claude_working': 'Claude يكتب الرد',
    'log_usage_limit_detected': 'تم اكتشاف حد الاستخدام',
    'log_wait_started': 'بدأ الانتظار لعودة الاستخدام',
    'log_usage_available': 'الاستخدام يبدو متاحًا (بعد التحقق)',
    'log_usage_available_send_disabled': 'الاستخدام متاح؛ الإرسال معطّل فالقرار لك',
    'log_verification_failed': 'فشل التحقق الأخير، العودة للانتظار',
    'log_sending_continue': 'جارٍ إرسال "كمل"',
    'log_continue_sent': 'تم إرسال "كمل"',
    'log_continue_button_detected': 'تم اكتشاف زر Continue',
    'log_continue_button_clicked': 'تم الضغط على زر Continue',
    'log_send_result_failed': 'فشلت محاولة الإرسال',
    'log_resumed_externally': 'Claude استأنف دوننا؛ انتهى الانتظار',
    'log_claude_not_foreground': 'Claude ليس في المقدمة',
    'log_ui_unrecognized': 'شاشة Claude غير معروفة',
    'log_device_offline': 'الهاتف بلا إنترنت؛ تعليق',
    'log_claude_connection_error': 'Claude يعرض خطأ اتصال؛ تعليق',
    'log_attention_cleared': 'زالت المشكلة، العودة للوضع الطبيعي',
    'log_stopped_user': 'أوقفته أنت',
    'log_stopped_notification': 'أُوقف من الإشعار',
    'log_stopped_max_attempts': 'توقف: بلغ الحد الأقصى للمحاولات',
    'log_max_attempts_reached': 'بلغ الحد الأقصى للمحاولات',
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
