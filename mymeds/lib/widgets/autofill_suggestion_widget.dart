import 'package:flutter/material.dart';
import '../services/autofill_service.dart';

/// Widget that displays smart autofill suggestions as chips
/// 
/// Features:
/// - Shows top suggestions for a field
/// - Non-intrusive design (gray chip with subtle animation)
/// - Tap to accept suggestion
/// - Automatically loads suggestions when field is focused
/// - Dismissible if user doesn't want suggestions
class AutofillSuggestionWidget extends StatefulWidget {
  final String entity;
  final String field;
  final Function(String) onSuggestionSelected;
  final TextEditingController? controller;
  final int maxSuggestions;
  final bool enabled;

  const AutofillSuggestionWidget({
    super.key,
    required this.entity,
    required this.field,
    required this.onSuggestionSelected,
    this.controller,
    this.maxSuggestions = 3,
    this.enabled = true,
  });

  @override
  State<AutofillSuggestionWidget> createState() => _AutofillSuggestionWidgetState();
}

class _AutofillSuggestionWidgetState extends State<AutofillSuggestionWidget> {
  List<String> _suggestions = [];
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _loadSuggestions();
    }
  }

  @override
  void didUpdateWidget(AutofillSuggestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload suggestions if entity or field changed
    if (oldWidget.entity != widget.entity || 
        oldWidget.field != widget.field ||
        oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _loadSuggestions();
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    if (!widget.enabled || _isDismissed) return;

    try {
      final autofillService = AutofillService();
      final suggestions = await autofillService.getSuggestions(
        entity: widget.entity,
        field: widget.field,
        topN: widget.maxSuggestions,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (e) {
      debugPrint('❌ [AutofillSuggestion] Error loading suggestions: $e');
    }
  }

  void _handleSuggestionTap(String suggestion) {
    // Update text field if controller is provided
    if (widget.controller != null) {
      widget.controller!.text = suggestion;
    }
    
    // Notify parent
    widget.onSuggestionSelected(suggestion);
    
    // Hide suggestions after selection
    setState(() {
      _suggestions = [];
    });
  }

  void _dismissSuggestions() {
    setState(() {
      _isDismissed = true;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if disabled, loading, dismissed, or no suggestions
    if (!widget.enabled || _isDismissed || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Sugerencias:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Dismiss button
              InkWell(
                onTap: _dismissSuggestions,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return _SuggestionChip(
                label: suggestion,
                onTap: () => _handleSuggestionTap(suggestion),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Individual suggestion chip component
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Autocomplete text field with smart autofill suggestions
/// 
/// This is a convenience widget that combines TextField with AutofillSuggestionWidget
class SmartAutocompleteField extends StatefulWidget {
  final String entity;
  final String field;
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final InputDecoration? decoration;
  final bool enabled;
  final TextInputType? keyboardType;

  const SmartAutocompleteField({
    super.key,
    required this.entity,
    required this.field,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.decoration,
    this.enabled = true,
    this.keyboardType,
  });

  @override
  State<SmartAutocompleteField> createState() => _SmartAutocompleteFieldState();
}

class _SmartAutocompleteFieldState extends State<SmartAutocompleteField> {
  late TextEditingController _controller;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSuggestionSelected(String value) {
    _controller.text = value;
    
    // Record selection
    AutofillService().recordSelection(
      entity: widget.entity,
      field: widget.field,
      value: value,
    );
    
    // Notify parent
    widget.onChanged?.call(value);
    
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          decoration: widget.decoration ?? InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            widget.onChanged?.call(value);
            
            // Show suggestions when field is focused and not empty
            setState(() {
              _showSuggestions = value.isEmpty;
            });
          },
          onSubmitted: (value) {
            // Record selection on submit
            if (value.isNotEmpty) {
              AutofillService().recordSelection(
                entity: widget.entity,
                field: widget.field,
                value: value,
              );
            }
            
            widget.onSubmitted?.call(value);
          },
          onTap: () {
            // Show suggestions when field is tapped
            setState(() {
              _showSuggestions = true;
            });
          },
        ),
        if (_showSuggestions && widget.enabled)
          AutofillSuggestionWidget(
            entity: widget.entity,
            field: widget.field,
            controller: _controller,
            onSuggestionSelected: _handleSuggestionSelected,
            enabled: widget.enabled,
          ),
      ],
    );
  }
}
