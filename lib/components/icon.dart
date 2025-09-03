import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';

class CNIcon extends StatefulWidget {
  const CNIcon({
    super.key,
    required this.symbol,
    this.size,
    this.color,
    this.mode,
    this.gradient,
    this.height,
  });

  final CNSymbol symbol;
  final double? size;
  final Color? color;
  final CNSFSymbolRenderingMode? mode;
  final bool? gradient;
  final double? height;

  @override
  State<CNIcon> createState() => _CNIconState();
}

class _CNIconState extends State<CNIcon> {
  MethodChannel? _channel;
  bool? _lastIsDark;
  String? _lastName;
  double? _lastSize;
  int? _lastColor;
  String? _lastMode;
  bool? _lastGradient;
  // No intrinsic sizing storage; icons use explicit size.

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CNIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const viewType = 'CupertinoNativeIcon';

    final symbol = widget.symbol;
    final creationParams = <String, dynamic>{
      'name': symbol.name,
      'isDark': _isDark,
      'style': <String, dynamic>{
        'iconSize': (widget.size ?? symbol.size),
        if ((widget.color ?? symbol.color) != null)
          'iconColor': resolveColorToArgb(widget.color ?? symbol.color, context),
        if ((widget.mode ?? symbol.mode) != null)
          'iconRenderingMode': (widget.mode ?? symbol.mode)!.name,
        if ((widget.gradient ?? symbol.gradient) != null)
          'iconGradientEnabled': (widget.gradient ?? symbol.gradient) == true,
      if (symbol.paletteColors != null)
        'iconPaletteColors': symbol.paletteColors!
            .map((c) => resolveColorToArgb(c, context))
            .toList(),
      },
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: creationParams,
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : AppKitView(
            viewType: viewType,
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: creationParams,
            onPlatformViewCreated: _onPlatformViewCreated,
          );

    // Ensure the platform view always has finite constraints
    final fallbackSize = widget.size ?? widget.symbol.size;
    final h = widget.height ?? fallbackSize;
    final w = fallbackSize;
    return SizedBox(width: w, height: h, child: platformView);
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('CupertinoNativeIcon_$id')
      ..setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
    // No intrinsic measurement needed.
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    return null;
  }

  void _cacheCurrentProps() {
    _lastIsDark = _isDark;
    _lastName = widget.symbol.name;
    _lastSize = widget.size ?? widget.symbol.size;
    _lastColor = resolveColorToArgb(widget.color ?? widget.symbol.color, context);
    _lastMode = (widget.mode ?? widget.symbol.mode)?.name;
    _lastGradient = widget.gradient ?? widget.symbol.gradient;
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    // Resolve before any awaits
    final name = widget.symbol.name;
    final size = widget.size ?? widget.symbol.size;
    final color = resolveColorToArgb(widget.color ?? widget.symbol.color, context);
    final mode = (widget.mode ?? widget.symbol.mode)?.name;
    final gradient = widget.gradient ?? widget.symbol.gradient;

    if (_lastName != name) {
      await channel.invokeMethod('setSymbol', {'name': name});
      _lastName = name;
    }

    final style = <String, dynamic>{};
    if (_lastSize != size) {
      style['iconSize'] = size;
      _lastSize = size;
    }
    if (_lastColor != color && color != null) {
      style['iconColor'] = color;
      _lastColor = color;
    }
    if (_lastMode != mode && mode != null) {
      style['iconRenderingMode'] = mode;
      _lastMode = mode;
    }
    if (_lastGradient != gradient && gradient != null) {
      style['iconGradientEnabled'] = gradient;
      _lastGradient = gradient;
    }
    if (style.isNotEmpty) {
      await channel.invokeMethod('setStyle', style);
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      await channel.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
  }

  // No intrinsic sizing API: platform view is wrapped with fixed constraints.
}
