import re

with open('lib/screens.dart', 'r') as f:
    content = f.read()

# Update Health Snapshot UI
old_snapshot_row = """                    HealthMetricCard(emoji: '👟', label: 'Steps', value: '${_health.steps}', unit: '', color: kNeon),
                  ],
                ),
              ),"""

new_snapshot_row = """                    HealthMetricCard(emoji: '👟', label: 'Steps', value: '${_health.steps}', unit: '', color: kNeon),
                    // Extended Metrics
                    ..._health.extendedMetrics.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: HealthMetricCard(
                            emoji: e.value['emoji'],
                            label: e.key,
                            value: '${e.value['value']}',
                            unit: e.value['unit'],
                            color: CupertinoColors.systemGrey3,
                          ),
                        )),
                  ],
                ),
              ),"""

content = content.replace(old_snapshot_row, new_snapshot_row)

with open('lib/screens.dart', 'w') as f:
    f.write(content)
