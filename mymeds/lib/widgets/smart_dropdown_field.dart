import 'package:flutter/material.dart';
import '../services/autofill_service.dart';
import 'autofill_suggestion_widget.dart';

/// Smart dropdown with autofill suggestions
/// 
/// This widget wraps DropdownButtonFormField and adds autofill suggestion support
class SmartDropdownField<T> extends StatefulWidget {
  final String entity;
  final String field;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?) onChanged;
  final InputDecoration? decoration;
  final bool enabled;
  final String Function(T) valueToString;

  const SmartDropdownField({
    super.key,
    required this.entity,
    required this.field,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.valueToString,
    this.decoration,
    this.enabled = true,
  });

  @override
  State<SmartDropdownField<T>> createState() => _SmartDropdownFieldState<T>();
}

class _SmartDropdownFieldState<T> extends State<SmartDropdownField<T>> {
  bool _showSuggestions = false;

  void _handleSuggestionSelected(String suggestionValue) {
    // Find matching item
    final matchingItem = widget.items.firstWhere(
      (item) => widget.valueToString(item.value as T) == suggestionValue,
      orElse: () => widget.items.first,
    );

    if (matchingItem.value != null) {
      widget.onChanged(matchingItem.value);
      
      // Record selection
      AutofillService().recordSelection(
        entity: widget.entity,
        field: widget.field,
        value: suggestionValue,
      );
    }

    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          value: widget.value,
          items: widget.items,
          decoration: widget.decoration ?? const InputDecoration(
            border: OutlineInputBorder(),
          ),
          onChanged: widget.enabled ? (value) {
            if (value != null) {
              // Record selection
              AutofillService().recordSelection(
                entity: widget.entity,
                field: widget.field,
                value: widget.valueToString(value),
              );
            }
            
            widget.onChanged(value);
            
            setState(() {
              _showSuggestions = false;
            });
          } : null,
          onTap: () {
            setState(() {
              _showSuggestions = true;
            });
          },
        ),
        if (_showSuggestions && widget.enabled && widget.value == null)
          AutofillSuggestionWidget(
            entity: widget.entity,
            field: widget.field,
            onSuggestionSelected: _handleSuggestionSelected,
            enabled: widget.enabled,
          ),
      ],
    );
  }
}
