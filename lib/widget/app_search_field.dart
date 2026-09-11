import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

/// One consistent look for every text-search box in the app — filled,
/// rounded, borderless, with a properly-centered magnifying-glass prefix
/// icon. Several screens (SongBook's artist/All-Songs search, the Chords
/// page search, the Ctrl+K quick-search dialog, the admin song picker) had
/// each hand-rolled a near-identical InputDecoration for this; two others
/// (the admin dashboard's user search, the admin artists search) never got
/// that treatment and used the bare default TextField style instead, whose
/// default 48x48 prefixIcon tap-target box doesn't center against a
/// isDense field's shorter height — visible as the icon sitting off-center
/// against the hint text. An explicit `prefixIconConstraints` sized to
/// match this field's own compact height is what actually fixes that,
/// rather than the icon's own size/padding.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
    this.maxWidth,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(AppRadius.md);
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      style: TextStyle(color: scheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
        prefixIcon: FaIcon(
          FontAwesomeIcons.magnifyingGlass,
          size: 16,
          color: scheme.onSurface.withOpacity(0.5),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 20,
        ),
        isDense: true,
        filled: true,
        fillColor: scheme.onSurface.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.onSurface.withOpacity(0.3)),
        ),
      ),
    );
    if (maxWidth == null) return field;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: field,
    );
  }
}
