import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_page.dart';
import '../shared/ui.dart';
import '../weather/weather_repository.dart';
import '../weather/weather_settings.dart';

/// 启动流程使用的本地配置键，统一管理方便后续扩展调试开关。
class StartupPreferenceKeys {
  const StartupPreferenceKeys._();

  static const String skipSplash = 'startup.skip_splash';
  static const String skipLockScreen = 'startup.skip_lockscreen';
  static const String passcode = 'security.passcode';
}

enum StartupStage { splash, lockScreen, passcodeUnlock, passcodeSetup, home }

class StartupBootstrap {
  const StartupBootstrap({
    required this.preferences,
    required this.shouldSkipSplash,
    required this.shouldSkipLockScreen,
    required this.hasPasscode,
  });

  final SharedPreferences preferences;
  final bool shouldSkipSplash;
  final bool shouldSkipLockScreen;
  final bool hasPasscode;

  /// 加载启动阶段依赖，保证日期格式和本地密码配置在首屏前可用。
  static Future<StartupBootstrap> load({
    SharedPreferences? sharedPreferences,
  }) async {
    await initializeDateFormatting('zh_CN');
    final preferences = sharedPreferences ?? await SharedPreferences.getInstance();

    return StartupBootstrap(
      preferences: preferences,
      shouldSkipSplash:
          preferences.getBool(StartupPreferenceKeys.skipSplash) ?? false,
      shouldSkipLockScreen:
          preferences.getBool(StartupPreferenceKeys.skipLockScreen) ?? false,
      hasPasscode:
          (preferences.getString(StartupPreferenceKeys.passcode) ?? '').length ==
          6,
    );
  }

  StartupBootstrap copyWith({
    SharedPreferences? preferences,
    bool? shouldSkipSplash,
    bool? shouldSkipLockScreen,
    bool? hasPasscode,
  }) {
    return StartupBootstrap(
      preferences: preferences ?? this.preferences,
      shouldSkipSplash: shouldSkipSplash ?? this.shouldSkipSplash,
      shouldSkipLockScreen:
          shouldSkipLockScreen ?? this.shouldSkipLockScreen,
      hasPasscode: hasPasscode ?? this.hasPasscode,
    );
  }
}

class StartupFlowPage extends StatefulWidget {
  const StartupFlowPage({
    super.key,
    required this.weatherRepository,
    required this.weatherSettingsStore,
    this.sharedPreferences,
  });

  final WeatherRepository weatherRepository;
  final WeatherSettingsStore weatherSettingsStore;
  final SharedPreferences? sharedPreferences;

  @override
  State<StartupFlowPage> createState() => _StartupFlowPageState();
}

class _StartupFlowPageState extends State<StartupFlowPage> {
  late final Future<void> _bootstrapFuture;

  StartupBootstrap? _bootstrap;
  StartupStage? _stage;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadBootstrap();
  }

  /// 读取本地启动配置并计算本次应用应该进入的首个页面。
  Future<void> _loadBootstrap() async {
    final bootstrap = await StartupBootstrap.load(
      sharedPreferences: widget.sharedPreferences,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _bootstrap = bootstrap;
      _stage = _resolveInitialStage(bootstrap);
      _errorText = null;
    });
  }

  /// 根据跳过开屏、锁屏和密码保存状态，恢复完整启动链路。
  StartupStage _resolveInitialStage(StartupBootstrap bootstrap) {
    if (!bootstrap.shouldSkipSplash) {
      return StartupStage.splash;
    }
    if (bootstrap.shouldSkipLockScreen) {
      return StartupStage.home;
    }
    if (bootstrap.hasPasscode) {
      return StartupStage.lockScreen;
    }
    return StartupStage.passcodeSetup;
  }

  /// 开屏结束后按当前密码状态衔接到锁屏、设密或主屏。
  void _handleSplashFinished() {
    final bootstrap = _bootstrap;
    if (bootstrap == null) {
      return;
    }

    setState(() {
      _errorText = null;
      if (bootstrap.shouldSkipLockScreen) {
        _stage = StartupStage.home;
      } else if (bootstrap.hasPasscode) {
        _stage = StartupStage.lockScreen;
      } else {
        _stage = StartupStage.passcodeSetup;
      }
    });
  }

  void _openUnlockPage() {
    setState(() {
      _stage = StartupStage.passcodeUnlock;
      _errorText = null;
    });
  }

  /// 首次设置六位数字密码，并立即把用户送入主屏幕。
  Future<void> _savePasscode(String passcode) async {
    final bootstrap = _bootstrap;
    if (bootstrap == null) {
      return;
    }
    if (passcode.length != 6) {
      setState(() {
        _errorText = '请输入 6 位数字密码';
      });
      return;
    }

    await bootstrap.preferences.setString(
      StartupPreferenceKeys.passcode,
      passcode,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _bootstrap = bootstrap.copyWith(hasPasscode: true);
      _stage = StartupStage.home;
      _errorText = null;
    });
  }

  /// 校验已保存的密码，成功后才允许进入主屏幕。
  Future<void> _unlockWithPasscode(String passcode) async {
    final bootstrap = _bootstrap;
    if (bootstrap == null) {
      return;
    }

    final savedPasscode =
        bootstrap.preferences.getString(StartupPreferenceKeys.passcode) ?? '';
    if (passcode == savedPasscode) {
      setState(() {
        _stage = StartupStage.home;
        _errorText = null;
      });
      return;
    }

    setState(() {
      _errorText = '密码不正确，请重新输入';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _bootstrap == null ||
            _stage == null) {
          return const _StartupLoadingPage();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<StartupStage>(_stage!),
            child: _buildCurrentStage(),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStage() {
    return switch (_stage!) {
      StartupStage.splash => _SplashPage(onFinished: _handleSplashFinished),
      StartupStage.lockScreen => _LockScreenPage(onTapUnlock: _openUnlockPage),
      StartupStage.passcodeUnlock => _PasscodePage(
        pageKey: const Key('startup_passcode_unlock_page'),
        title: '输入密码',
        description: '输入 6 位数字密码，回到你的汪汪机桌面',
        actionLabel: '解锁进入',
        errorText: _errorText,
        onSubmit: _unlockWithPasscode,
      ),
      StartupStage.passcodeSetup => _PasscodePage(
        pageKey: const Key('startup_passcode_setup_page'),
        title: '设置密码',
        description: '首次使用需要创建 6 位数字密码，后续解锁会用到它',
        actionLabel: '保存并进入',
        errorText: _errorText,
        onSubmit: _savePasscode,
      ),
      StartupStage.home => HomePage(
        weatherRepository: widget.weatherRepository,
        weatherSettingsStore: widget.weatherSettingsStore,
      ),
    };
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    final visuals = _StartupVisuals.of(context);

    return Scaffold(
      body: _StartupScene(
        sceneKey: const Key('startup_loading_page'),
        visuals: visuals,
        child: Center(
          child: FrostPanel(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            borderRadius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: visuals.accentPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '正在唤醒汪汪机...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: visuals.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashPage extends StatefulWidget {
  const _SplashPage({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _taglineOpacity;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..forward();
    _logoScale = Tween<double>(
      begin: 0.82,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _taglineOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 1, curve: Curves.easeOut),
      ),
    );
    _finishTimer = Timer(const Duration(milliseconds: 2350), widget.onFinished);
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _StartupVisuals.of(context);

    return Scaffold(
      body: _StartupScene(
        sceneKey: const Key('startup_splash_page'),
        visuals: visuals,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(38),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            visuals.accentSoft,
                            visuals.accentPrimary,
                            visuals.accentSecondary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: visuals.accentPrimary.withValues(alpha: 0.28),
                            blurRadius: 40,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                        size: 70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _logoOpacity,
                  child: Text(
                    '汪汪机',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: visuals.primaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    '像小狗一样陪伴你的 AI 小手机',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: visuals.secondaryText,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: visuals.badgeBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: visuals.badgeBorder),
                    ),
                    child: Text(
                      '正在进入你的陪伴世界',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: visuals.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockScreenPage extends StatefulWidget {
  const _LockScreenPage({required this.onTapUnlock});

  final VoidCallback onTapUnlock;

  @override
  State<_LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<_LockScreenPage> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _StartupVisuals.of(context);
    final timeText = DateFormat('HH:mm').format(_now);
    final dateText = DateFormat('M月d日 EEEE', 'zh_CN').format(_now);

    return Scaffold(
      body: _StartupScene(
        sceneKey: const Key('startup_lock_page'),
        visuals: visuals,
        child: GestureDetector(
          key: const Key('startup_lock_unlock_area'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTapUnlock,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    timeText,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: visuals.primaryText,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: visuals.secondaryText,
                    ),
                  ),
                  const Spacer(),
                  FrostPanel(
                    padding: const EdgeInsets.all(22),
                    borderRadius: 30,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: visuals.notificationBadge,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '微信',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: visuals.primaryText,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '小雪：我刚刚给你发了一张新照片，记得来看看哦～',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: visuals.secondaryText,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: visuals.badgeBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: visuals.badgeBorder),
                    ),
                    child: Text(
                      '轻点任意位置开始解锁',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: visuals.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: visuals.secondaryText,
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '进入密码界面',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: visuals.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasscodePage extends StatefulWidget {
  const _PasscodePage({
    required this.pageKey,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onSubmit,
    this.errorText,
  });

  final Key pageKey;
  final String title;
  final String description;
  final String actionLabel;
  final String? errorText;
  final Future<void> Function(String passcode) onSubmit;

  @override
  State<_PasscodePage> createState() => _PasscodePageState();
}

class _PasscodePageState extends State<_PasscodePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    await widget.onSubmit(_controller.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });
  }

  void _clearInput() {
    _controller.clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _StartupVisuals.of(context);

    return Scaffold(
      body: _StartupScene(
        sceneKey: widget.pageKey,
        visuals: visuals,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
          },
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: FrostPanel(
                  padding: const EdgeInsets.all(28),
                  borderRadius: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              visuals.accentPrimary,
                              visuals.accentSecondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: visuals.accentPrimary.withValues(alpha: 0.24),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: visuals.primaryText,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: visuals.secondaryText,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _PasscodeDots(
                        valueLength: _controller.text.length,
                        visuals: visuals,
                      ),
                      SizedBox(
                        height: 1,
                        child: TextField(
                          key: const Key('startup_passcode_field'),
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            _submit();
                          },
                          onChanged: (_) {
                            setState(() {});
                          },
                          inputFormatters: const [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          cursorColor: Colors.transparent,
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                            height: 0.01,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      InlineHint(
                        message: _controller.text.length < 6
                            ? '请输入 6 位数字密码'
                            : '密码长度正确，可以继续',
                      ),
                      if (widget.errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.errorText!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: visuals.errorText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('startup_passcode_submit'),
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: visuals.accentPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                visuals.accentPrimary.withValues(alpha: 0.42),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            _submitting ? '处理中...' : widget.actionLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        key: const Key('startup_passcode_clear'),
                        onPressed: _controller.text.isEmpty ? null : _clearInput,
                        child: const Text('重新输入'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasscodeDots extends StatelessWidget {
  const _PasscodeDots({
    required this.valueLength,
    required this.visuals,
  });

  final int valueLength;
  final _StartupVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      children: List.generate(6, (index) {
        final filled = index < valueLength;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? visuals.accentPrimary : visuals.dotBackground,
            border: Border.all(
              color: filled ? visuals.accentPrimary : visuals.dotBorder,
              width: 1.4,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: visuals.accentPrimary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _StartupScene extends StatelessWidget {
  const _StartupScene({
    required this.sceneKey,
    required this.visuals,
    required this.child,
  });

  final Key sceneKey;
  final _StartupVisuals visuals;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sceneKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visuals.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -76,
            left: -48,
            child: AccentOrb(
              color: visuals.accentPrimary,
              size: 240,
              opacity: visuals.orbOpacity,
            ),
          ),
          Positioned(
            right: -64,
            bottom: -88,
            child: AccentOrb(
              color: visuals.accentSecondary,
              size: 260,
              opacity: visuals.orbOpacity,
            ),
          ),
          Positioned(
            top: 180,
            right: 12,
            child: AccentOrb(
              color: visuals.accentSoft,
              size: 140,
              opacity: visuals.smallOrbOpacity,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _StartupVisuals {
  const _StartupVisuals({
    required this.backgroundGradient,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.accentSoft,
    required this.primaryText,
    required this.secondaryText,
    required this.badgeBackground,
    required this.badgeBorder,
    required this.notificationBadge,
    required this.dotBackground,
    required this.dotBorder,
    required this.errorText,
    required this.orbOpacity,
    required this.smallOrbOpacity,
  });

  final List<Color> backgroundGradient;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color accentSoft;
  final Color primaryText;
  final Color secondaryText;
  final Color badgeBackground;
  final Color badgeBorder;
  final Color notificationBadge;
  final Color dotBackground;
  final Color dotBorder;
  final Color errorText;
  final double orbOpacity;
  final double smallOrbOpacity;

  static _StartupVisuals of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _StartupVisuals(
        backgroundGradient: [
          Color(0xFF2B1736),
          Color(0xFF161223),
          Color(0xFF0C1220),
        ],
        accentPrimary: Color(0xFFFF8FA3),
        accentSecondary: Color(0xFF7D8BFF),
        accentSoft: Color(0xFFFFC2D1),
        primaryText: Colors.white,
        secondaryText: Color(0xCCFFFFFF),
        badgeBackground: Color(0x1AFFFFFF),
        badgeBorder: Color(0x2EFFFFFF),
        notificationBadge: Color(0xFF6B7CFF),
        dotBackground: Color(0x14FFFFFF),
        dotBorder: Color(0x40FFFFFF),
        errorText: Color(0xFFFFB8C4),
        orbOpacity: 0.24,
        smallOrbOpacity: 0.18,
      );
    }

    return const _StartupVisuals(
      backgroundGradient: [
        Color(0xFFFFF2F5),
        Color(0xFFF8F2FB),
        Color(0xFFEAF3FF),
      ],
      accentPrimary: Color(0xFFFA7E98),
      accentSecondary: Color(0xFF7A8CFF),
      accentSoft: Color(0xFFFFC4D0),
      primaryText: Color(0xFF30243C),
      secondaryText: Color(0xFF6D627D),
      badgeBackground: Color(0xD9FFFFFF),
      badgeBorder: Color(0x1A6B4B73),
      notificationBadge: Color(0xFF6B7CFF),
      dotBackground: Color(0xFFF4ECF4),
      dotBorder: Color(0xFFD6C9D9),
      errorText: Color(0xFFD44A6A),
      orbOpacity: 0.18,
      smallOrbOpacity: 0.14,
    );
  }
}
