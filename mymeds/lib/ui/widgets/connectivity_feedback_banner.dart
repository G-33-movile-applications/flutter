import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// Widget that displays connectivity status feedback as a persistent banner
/// 
/// Shows warning when no internet connection is available
/// Automatically hides when connection is restored
class ConnectivityFeedbackBanner extends StatefulWidget {
  final bool showOfflineMessage;
  final String? customMessage;

  const ConnectivityFeedbackBanner({
    super.key,
    this.showOfflineMessage = true,
    this.customMessage,
  });

  @override
  State<ConnectivityFeedbackBanner> createState() => _ConnectivityFeedbackBannerState();
}

class _ConnectivityFeedbackBannerState extends State<ConnectivityFeedbackBanner> {
  final ConnectivityService _connectivityService = ConnectivityService();
  late Stream<ConnectionType> _connectionStream;

  @override
  void initState() {
    super.initState();
    _connectionStream = _connectivityService.connectionStream;
  }

  bool _isOffline(ConnectionType connectionType) {
    return connectionType == ConnectionType.none;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionType>(
      stream: _connectionStream,
      initialData: _connectivityService.currentConnectionType,
      builder: (context, snapshot) {
        final connectionType = snapshot.data ?? ConnectionType.none;

        final isOffline = _isOffline(connectionType);

        // Don't show banner if online or if custom message and no offline flag
        if (!isOffline && !widget.showOfflineMessage) {
          return const SizedBox.shrink();
        }

        if (!isOffline && widget.customMessage == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOffline 
                  ? Colors.orangeAccent.withValues(alpha: 0.9)
                  : Colors.indigoAccent.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Icon(
                  isOffline 
                      ? Icons.wifi_off_rounded
                      : Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                
                // Message
                Expanded(
                  child: Text(
                    widget.customMessage ?? _getDefaultMessage(isOffline),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Connection type indicator
                if (!isOffline)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildConnectionTypeIcon(connectionType),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getDefaultMessage(bool isOffline) {
    if (isOffline) {
      return 'Sin conexión a internet. Algunas funciones no estarán disponibles.';
    }
    return 'Conectado';
  }

  Widget _buildConnectionTypeIcon(ConnectionType connectionType) {
    IconData icon;
    String tooltip;
    
    switch (connectionType) {
      case ConnectionType.wifi:
        icon = Icons.wifi_rounded;
        tooltip = 'Wi-Fi conectado';
        break;
      case ConnectionType.mobile:
        icon = Icons.signal_cellular_alt_rounded;
        tooltip = 'Datos móviles conectados';
        break;
      case ConnectionType.none:
        icon = Icons.wifi_off_rounded;
        tooltip = 'Sin conexión';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
