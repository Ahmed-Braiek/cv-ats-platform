import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Shared product tokens. Flutter is the source of truth for mobile styling.
/// The UI intentionally avoids fake score data or hard-coded user progress.
abstract final class AtsPalette {
  static const ink = Color(0xFF13213B);
  static const muted = Color(0xFF73829A);
  static const brand = Color(0xFF315BEB);
  static const ocean = Color(0xFF14B8CF);
  static const canvas = Color(0xFFF5F8FD);
  static const stroke = Color(0xFFE4EBF5);
  static const success = Color(0xFF15956C);
  static const warn = Color(0xFFEEA53B);
  static const danger = Color(0xFFD95058);
  static const midnight = Color(0xFF0E1832);
}

class AtsAppearance {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
}

class AtsTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AtsPalette.brand,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AtsPalette.ink,
      error: AtsPalette.danger,
      secondary: AtsPalette.ocean,
    );
    return _theme(scheme, AtsPalette.canvas);
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF9AACFF),
      onPrimary: Color(0xFF111A36),
      surface: Color(0xFF16223B),
      onSurface: Color(0xFFF1F6FF),
      secondary: Color(0xFF63D7E5),
    );
    return _theme(scheme, const Color(0xFF0D1527));
  }

  static ThemeData _theme(ColorScheme colors, Color background) {
    final round = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(
        color: colors.onSurface.withValues(alpha: .10),
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 27, height: 1.17,
          fontWeight: FontWeight.w900,letterSpacing: -.75,color:colors.onSurface),
        headlineSmall: TextStyle(fontSize: 22,height:1.22,
          fontWeight:FontWeight.w900,letterSpacing:-.45,color:colors.onSurface),
        titleLarge: TextStyle(fontSize:19,fontWeight:FontWeight.w800,
          letterSpacing:-.25,color:colors.onSurface),
        titleMedium: TextStyle(fontSize:16,fontWeight:FontWeight.w800,
          color:colors.onSurface),
        bodyLarge: TextStyle(fontSize:15,height:1.55,color:colors.onSurface),
        bodyMedium: TextStyle(fontSize:14,height:1.52,color:colors.onSurface),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.onSurface, fontWeight: FontWeight.w800, fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: round.copyWith(
          side: BorderSide(color: colors.outline.withValues(alpha: .22)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline.withValues(alpha: .35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline.withValues(alpha: .35)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: .13),
        selectedIconTheme: IconThemeData(color: colors.primary, size: 23),
        selectedLabelTextStyle: TextStyle(
          color: colors.primary, fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: .13),
        height: 74,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.primary.withValues(alpha: .07),
        labelStyle: TextStyle(color: colors.onSurface, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onSurface,
        contentTextStyle: TextStyle(color: colors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class AtsPanel extends StatelessWidget {
  const AtsPanel({super.key, required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: dark ? Colors.white12 : AtsPalette.stroke,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AtsEyebrow extends StatelessWidget {
  const AtsEyebrow(this.label, {super.key, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: color ?? Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5,
    ),
  );
}

class AtsSectionTitle extends StatelessWidget {
  const AtsSectionTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          )),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!, style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .65),
              fontSize: 13,
            )),
          ],
        ],
      )),
      if (action != null) action!,
    ],
  );
}

class AtsEmptyState extends StatelessWidget {
  const AtsEmptyState({
    super.key, required this.icon, required this.title,
    required this.description, this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => AtsPanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 29, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          )),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(description, textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .70),
            )),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: action!,
          ),
        ],
      ]),
    ),
  );
}

class AtsStatusChip extends StatelessWidget {
  const AtsStatusChip({super.key, required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final completed = value == 'completed';
    final failed = ['failed','expired','cancelled'].contains(value);
    final color = completed ? AtsPalette.success
        : failed ? AtsPalette.danger : AtsPalette.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        value.replaceAll('_',' ').toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800,
          fontSize: 10, letterSpacing: .35),
      ),
    );
  }
}

class AtsMetric extends StatelessWidget {
  const AtsMetric({super.key, required this.label, required this.value,
    required this.icon, this.tint = AtsPalette.brand});
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => AtsPanel(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 23, color: tint),
      const SizedBox(height: 15),
      Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
      )),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .65))),
    ]),
  );
}

class AtsHeader extends StatelessWidget {
  const AtsHeader({super.key,required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
      )),
      if(subtitle != null)...[
        const SizedBox(height: 7),
        Text(subtitle!,style: TextStyle(color:
          Theme.of(context).colorScheme.onSurface.withValues(alpha:.64),
          height:1.45)),
      ],
    ]),
  );
}

class AtsPage extends StatelessWidget {
  const AtsPage({super.key,required this.title,required this.child,this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
    ),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 480 ? 16 : 24,
          20,MediaQuery.sizeOf(context).width < 480 ? 16 : 24,40),
        child: child,
      ),
    ))),
  );
}


/// Reusable animated loading placeholders. They display no guessed content:
/// the actual data is shown only after the backend responds.
class AtsSkeleton extends StatefulWidget {
  const AtsSkeleton({super.key, this.height=16, this.width=double.infinity,
    this.radius=8});
  final double height,width,radius;
  @override State<AtsSkeleton> createState()=>_AtsSkeletonState();
}
class _AtsSkeletonState extends State<AtsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation=AnimationController(
    vsync:this,duration:const Duration(milliseconds:1100),
  )..repeat(reverse:true);
  @override void dispose(){animation.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(
    animation:animation,builder:(context,_) {
      final base=Theme.of(context).colorScheme.onSurface;
      return Container(
        width:widget.width,height:widget.height,
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(widget.radius),
          color:base.withValues(alpha:.055+animation.value*.075)),
      );
    });
}
class AtsLoadingCards extends StatelessWidget {
  const AtsLoadingCards({super.key,this.count=3,this.heading=true});
  final int count;final bool heading;
  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,
    children:[
      if(heading)...[
        const AtsSkeleton(width:150,height:12),
        const SizedBox(height:11),
        const AtsSkeleton(width:230,height:27),
        const SizedBox(height:23),
      ],
      for(var i=0;i<count;i++)Padding(
        padding:const EdgeInsets.only(bottom:12),
        child:AtsPanel(child:Row(children:[
          const AtsSkeleton(width:48,height:48,radius:14),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const AtsSkeleton(height:15),
            const SizedBox(height:10),
            const AtsSkeleton(width:148,height:11),
          ])),
        ])),
      ),
    ]);
}
class AtsInfoStrip extends StatelessWidget{
  const AtsInfoStrip({super.key,required this.message,
    this.icon=Icons.info_outline_rounded,this.warning=false});
  final String message;final IconData icon;final bool warning;
  @override Widget build(BuildContext context){
    final color=warning?AtsPalette.warn:AtsPalette.brand;
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:15,vertical:14),
      decoration:BoxDecoration(
        color:color.withValues(alpha:.085),
        borderRadius:BorderRadius.circular(14)),
      child:Row(children:[
        Icon(icon,color:color,size:20),
        const SizedBox(width:11),
        Expanded(child:Text(message,style:TextStyle(
          height:1.5,fontSize:12,
          color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.82)))),
      ]),
    );
  }
}
