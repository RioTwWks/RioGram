import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import '../models/location_models.dart';

/// Форма отправки геолокации, live location или venue.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    this.initialMode = LocationSendMode.staticPoint,
  });

  final LocationSendMode initialMode;

  static Future<LocationSendRequest?> show(
    BuildContext context, {
    LocationSendMode initialMode = LocationSendMode.staticPoint,
  }) {
    return showModalBottomSheet<LocationSendRequest>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: LocationPickerSheet(initialMode: initialMode),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late LocationSendMode _mode = widget.initialMode;
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _venueTitleController = TextEditingController();
  final _venueAddressController = TextEditingController();
  int _livePeriod = 3600;
  bool _startBroadcast = true;
  bool _loadingGps = false;
  String? _error;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _venueTitleController.dispose();
    _venueAddressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _loadingGps = true;
      _error = null;
    });
    final point = await context.read<ChatManager>().getCurrentLocation();
    if (!mounted) {
      return;
    }
    if (point == null) {
      setState(() {
        _loadingGps = false;
        _error = 'Не удалось получить GPS. Проверьте разрешения.';
      });
      return;
    }
    _latitudeController.text = point.latitude.toStringAsFixed(6);
    _longitudeController.text = point.longitude.toStringAsFixed(6);
    setState(() => _loadingGps = false);
  }

  void _submit() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) {
      setState(() => _error = 'Введите корректные координаты');
      return;
    }

    final point = LocationPoint(latitude: latitude, longitude: longitude);
    if (!point.isValid) {
      setState(() => _error = 'Координаты вне допустимого диапазона');
      return;
    }

    if (_mode == LocationSendMode.venue &&
        _venueTitleController.text.trim().isEmpty) {
      setState(() => _error = 'Укажите название места');
      return;
    }

    Navigator.pop(
      context,
      LocationSendRequest(
        mode: _mode,
        point: point,
        livePeriod: _livePeriod,
        venueTitle: _venueTitleController.text.trim(),
        venueAddress: _venueAddressController.text.trim(),
        startBroadcast:
            _mode == LocationSendMode.liveLocation && _startBroadcast,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Геолокация',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<LocationSendMode>(
              segments: const [
                ButtonSegment(
                  value: LocationSendMode.staticPoint,
                  label: Text('Точка'),
                  icon: Icon(Icons.location_on_outlined),
                ),
                ButtonSegment(
                  value: LocationSendMode.liveLocation,
                  label: Text('Live'),
                  icon: Icon(Icons.my_location),
                ),
                ButtonSegment(
                  value: LocationSendMode.venue,
                  label: Text('Место'),
                  icon: Icon(Icons.place_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (values) {
                setState(() => _mode = values.first);
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadingGps ? null : _useCurrentLocation,
              icon: _loadingGps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: const Text('Текущая позиция'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Широта',
                      hintText: '55.7558',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d*'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Долгота',
                      hintText: '37.6173',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d*'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_mode == LocationSendMode.liveLocation) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _livePeriod,
                decoration: const InputDecoration(labelText: 'Длительность'),
                items: const [
                  DropdownMenuItem(value: 900, child: Text('15 минут')),
                  DropdownMenuItem(value: 3600, child: Text('1 час')),
                  DropdownMenuItem(value: 28800, child: Text('8 часов')),
                  DropdownMenuItem(
                    value: LiveLocationMeta.permanentPeriod,
                    child: Text('Постоянно'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _livePeriod = value);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Транслировать GPS'),
                subtitle: const Text(
                  'Автообновление через editMessageLiveLocation',
                ),
                value: _startBroadcast,
                onChanged: (value) => setState(() => _startBroadcast = value),
              ),
            ],
            if (_mode == LocationSendMode.venue) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _venueTitleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _venueAddressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
                minLines: 1,
                maxLines: 2,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }
}
