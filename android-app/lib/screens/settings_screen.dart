import 'package:flutter/material.dart';
import '../models/station.dart';
import '../repositories/station_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StationRepository _repo = StationRepository();
  List<Station> _stations = [];

  final _nameC = TextEditingController();
  final _stationIdC = TextEditingController();
  final _apiKeyC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future _load() async {
    final list = await _repo.getAll();
    setState(() => _stations = list);
  }

  Future _add() async {
    final name = _nameC.text.trim();
    final sid = _stationIdC.text.trim();
    final key = _apiKeyC.text.trim();
    if (name.isEmpty || sid.isEmpty || key.isEmpty) return;
    await _repo.create(Station(name: name, stationId: sid, apiKey: key));
    _nameC.clear();
    _stationIdC.clear();
    _apiKeyC.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes / Estaciones')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Alias (ej. Casa, Campo)')),
            TextField(controller: _stationIdC, decoration: const InputDecoration(labelText: 'Station ID (Wunderground)')),
            TextField(controller: _apiKeyC, decoration: const InputDecoration(labelText: 'API Key')), 
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _add, child: const Text('Añadir estación')),
            const SizedBox(height: 12),
            const Text('Estaciones guardadas', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _stations.length,
                itemBuilder: (_, i) {
                  final s = _stations[i];
                  return ListTile(
                    title: Text(s.name),
                    subtitle: Text('${s.stationId}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final controller = TextEditingController(text: s.name);
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Editar alias'),
                                content: TextField(controller: controller, autofocus: true),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final name = controller.text.trim();
                              if (name.isNotEmpty) {
                                await _repo.update(Station(id: s.id, name: name, stationId: s.stationId, apiKey: s.apiKey));
                                await _load();
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await _repo.delete(s.id!);
                            await _load();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
