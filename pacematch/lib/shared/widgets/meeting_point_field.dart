import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/geocoding_service.dart';

/// Meeting point text field with live address suggestions (Nominatim).
class MeetingPointField extends StatefulWidget {
  const MeetingPointField({
    super.key,
    required this.controller,
    this.biasNear,
    this.onPlaceSelected,
    this.enabled = true,
    /// When true (route planned): fixed start label, no address suggestions.
    this.readOnly = false,
  });

  final TextEditingController controller;
  final LatLng? biasNear;
  final ValueChanged<PlaceSuggestion>? onPlaceSelected;
  final bool enabled;
  final bool readOnly;

  @override
  State<MeetingPointField> createState() => _MeetingPointFieldState();
}

class _MeetingPointFieldState extends State<MeetingPointField> {
  final _geocoder = GeocodingService();
  final _focus = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _suppressSearch = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    _geocoder.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MeetingPointField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.readOnly && !oldWidget.readOnly) {
      _debounce?.cancel();
      _requestId++;
      if (_suggestions.isNotEmpty || _loading) {
        setState(() {
          _suggestions = const [];
          _loading = false;
        });
      }
    }
  }

  void _onTextChanged() {
    if (_suppressSearch || widget.readOnly || !widget.enabled) return;
    _debounce?.cancel();
    final q = widget.controller.text.trim();
    if (q.length < 3) {
      if (_suggestions.isNotEmpty || _loading) {
        setState(() {
          _suggestions = const [];
          _loading = false;
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String query) async {
    if (widget.readOnly || !widget.enabled) return;
    final id = ++_requestId;
    setState(() => _loading = true);
    try {
      final results = await _geocoder.search(query, near: widget.biasNear);
      if (!mounted || id != _requestId || widget.readOnly) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
    }
  }

  void _select(PlaceSuggestion place) {
    _suppressSearch = true;
    widget.controller.text = place.label;
    widget.controller.selection = TextSelection.collapsed(
      offset: place.label.length,
    );
    widget.onPlaceSelected?.call(place);
    setState(() => _suggestions = const []);
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.readOnly;
    final showSuggestions =
        !locked && widget.enabled && _suggestions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          readOnly: locked,
          enableInteractiveSelection: !locked,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Meeting point',
            hintText: locked ? null : 'Address or place name',
            helperText: locked
                ? 'Locked from route start'
                : 'Type an address for suggestions, or edit freely',
            suffixIcon: (!locked && _loading)
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(locked ? Icons.lock_outline : Icons.place_outlined),
          ),
        ),
        if (showSuggestions) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, size: 20),
                  title: Text(
                    s.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () => _select(s),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
