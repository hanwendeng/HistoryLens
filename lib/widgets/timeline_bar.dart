// Bottom bar with a decade slider to filter photos by time.

import 'package:flutter/material.dart';
import '../services/photo_store.dart';

class TimelineBar extends StatelessWidget {
  final int? selectedDecade;
  final ValueChanged<int?> onDecadeChanged;
  final int totalPhotos;

  const TimelineBar({
    super.key,
    required this.selectedDecade,
    required this.onDecadeChanged,
    required this.totalPhotos,
  });

  int get _sliderMin {
    final photos = PhotoStore.all;
    int? lo;
    for (final p in photos) {
      final d = p.decade;
      if (d == null) continue;
      lo = lo == null ? d : (d < lo ? d : lo);
    }
    return lo != null ? (lo ~/ 10) * 10 : 1900;
  }

  int get _sliderMax {
    final photos = PhotoStore.all;
    int? hi;
    for (final p in photos) {
      final d = p.decade;
      if (d == null) continue;
      hi = hi == null ? d : (d > hi ? d : hi);
    }
    return hi != null ? ((hi ~/ 10) + 1) * 10 : 2020;
  }

  bool get _hasRange {
    final photos = PhotoStore.all;
    return photos.any((p) => p.decade != null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRange) return const SizedBox.shrink();

    final sliderValue =
        selectedDecade?.toDouble() ?? _sliderMin.toDouble() - 10;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        border: const Border(top: BorderSide(color: Color(0x20000000))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onDecadeChanged(null),
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selectedDecade == null
                    ? Colors.brown
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('$totalPhotos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selectedDecade == null
                            ? Colors.white
                            : Colors.black87,
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.brown,
                inactiveTrackColor: Colors.brown.shade100,
                thumbColor: Colors.brown,
                overlayColor: Colors.brown.withAlpha(30),
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                tickMarkShape:
                    const RoundSliderTickMarkShape(tickMarkRadius: 2),
                showValueIndicator: ShowValueIndicator.onlyForDiscrete,
                valueIndicatorColor: Colors.brown,
                valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white, fontSize: 11),
              ),
              child: Slider(
                value: sliderValue.clamp(
                    _sliderMin.toDouble() - 10, _sliderMax.toDouble()),
                min: _sliderMin.toDouble() - 10,
                max: _sliderMax.toDouble(),
                divisions: ((_sliderMax - _sliderMin) ~/ 10) + 1,
                label:
                    selectedDecade != null ? '${selectedDecade}s' : 'All',
                onChangeStart: (_) {},
                onChangeEnd: (_) {},
                onChanged: (v) {
                  if (v < _sliderMin) {
                    onDecadeChanged(null);
                  } else {
                    final decade = (v ~/ 10) * 10;
                    onDecadeChanged(
                        decade == selectedDecade ? null : decade);
                  }
                },
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: selectedDecade != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${selectedDecade}s',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(
                          '${PhotoStore.all.where((p) => p.decade == selectedDecade).length} photos',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  )
                : const Center(
                    child: Text('All',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
