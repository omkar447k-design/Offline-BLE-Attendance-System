// ============================================================
// FILE: teacher_app/lib/setup_screen.dart
// ADD THIS FILE to teacher_app/lib/ folder
// ============================================================

import 'package:flutter/material.dart';
import 'db_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends StatefulWidget {
  // Preloaded Data
  static const Map<String, List<String>> _preloadedData = {
    'CS':    ['A', 'B', 'C'],
    'IT':    ['A', 'B', 'C'],
    'AIDS':  ['A', 'B', 'C'],
    'ENTC':  ['A', 'B', 'C'],
    'ELEX':  ['A', 'B', 'C'],
    'INST':  ['A', 'B', 'C'],
    'CIVIL': ['A', 'B', 'C'],
    'ROBOT': ['A', 'B', 'C'],
    'MECH':  ['A', 'B', 'C'],
  };

  List<Map<String, dynamic>> _departments = [];
  Map<int, List<Map<String, dynamic>>> _divisionMap = {};
  bool _isLoading = true;
  int? _expandedDeptId;

  final _deptController = TextEditingController();
  final _divController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _deptController.dispose();
    _divController.dispose();
    super.dispose();
  }

  // ── Initialize: preload if empty ──────────────────────────
  Future<void> _initializeData() async {
    final depts = await DBService.instance.getDepartments();

    if (depts.isEmpty) {
      // First time — preload all departments & divisions
      for (final entry in _preloadedData.entries) {
        final deptId = await DBService.instance.addDepartment(entry.key);
        for (final div in entry.value) {
          await DBService.instance.addDivision(div, deptId);
        }
      }
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final depts = await DBService.instance.getDepartments();
    final Map<int, List<Map<String, dynamic>>> divMap = {};

    for (final dept in depts) {
      final divs = await DBService.instance.getDivisionsByDept(dept['id']);
      divMap[dept['id']] = divs;
    }

    setState(() {
      _departments = depts;
      _divisionMap = divMap;
      _isLoading = false;
    });
  }

  // ── Add Department Dialog ─────────────────────────────────
  void _showAddDeptDialog() {
    _deptController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Department'),
        content: TextField(
          controller: _deptController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Short name e.g. MECH',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _deptController.text.trim().toUpperCase();
              if (name.isEmpty) return;
              final deptId = await DBService.instance.addDepartment(name);
              // Auto add A, B, C divisions
              for (final div in ['A', 'B', 'C']) {
                await DBService.instance.addDivision(div, deptId);
              }
              Navigator.pop(ctx);
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name added with divisions A, B, C')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Add Division Dialog ───────────────────────────────────
  void _showAddDivDialog(int deptId, String deptName) {
    _divController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Division to $deptName'),
        content: TextField(
          controller: _divController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. D',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _divController.text.trim().toUpperCase();
              if (name.isEmpty) return;
              await DBService.instance.addDivision(name, deptId);
              Navigator.pop(ctx);
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Division $name added to $deptName')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Delete Department Confirm ─────────────────────────────
  void _confirmDeleteDept(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department?'),
        content: Text(
          'Delete $name and all its divisions & student lists?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DBService.instance.deleteDepartment(id);
              Navigator.pop(ctx);
              await _loadData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Delete Division Confirm ───────────────────────────────
  void _confirmDeleteDiv(int id, String name, String deptName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Division?'),
        content: Text('Delete $deptName - $name and its student list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DBService.instance.deleteDivision(id);
              Navigator.pop(ctx);
              await _loadData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build UI ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text('College Setup'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeptDialog,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _departments.isEmpty
              ? const Center(child: Text('No departments found.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _departments.length,
                  itemBuilder: (ctx, i) {
                    final dept = _departments[i];
                    final deptId = dept['id'] as int;
                    final deptName = dept['name'] as String;
                    final divisions = _divisionMap[deptId] ?? [];
                    final isExpanded = _expandedDeptId == deptId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Column(
                        children: [
                          // Department Header
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1565C0),
                              child: Text(
                                deptName[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              deptName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text('${divisions.length} divisions'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Color(0xFF1565C0)),
                                  tooltip: 'Add Division',
                                  onPressed: () =>
                                      _showAddDivDialog(deptId, deptName),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  tooltip: 'Delete Dept',
                                  onPressed: () =>
                                      _confirmDeleteDept(deptId, deptName),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _expandedDeptId =
                                          isExpanded ? null : deptId;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Divisions List (expandable)
                          if (isExpanded) ...[
                            const Divider(height: 1),
                            ...divisions.map((div) {
                              final divId = div['id'] as int;
                              final divName = div['name'] as String;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                leading: const Icon(Icons.subdirectory_arrow_right,
                                    color: Colors.grey),
                                title: Text('$deptName - $divName'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _confirmDeleteDiv(
                                      divId, divName, deptName),
                                ),
                              );
                            }),
                            // Add Division button inside card
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showAddDivDialog(deptId, deptName),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Division'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1565C0),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
