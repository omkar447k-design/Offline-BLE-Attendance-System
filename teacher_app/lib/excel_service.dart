// ============================================================
// FILE: teacher_app/lib/excel_service.dart
// ADD THIS FILE to teacher_app/lib/ folder
// ============================================================

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'db_service.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._init();
  ExcelService._init();

  // ════════════════════════════════════════════════════════════
  // SINGLE SESSION SHEET
  // Only present students — no ticks, simple list
  // ════════════════════════════════════════════════════════════

  Future<void> exportSessionSheet({
    required BuildContext context,
    required int sessionId,
    required String subject,
    required String classroom,
    required String dept,
    required String div,
    required DateTime sessionDate,
  }) async {
    try {
      // Get attendance data
      final attendanceList =
          await DBService.instance.getAttendanceBySession(sessionId);

      final excel = Excel.createExcel();
      final sheetName = '$subject-$dept$div';
      final Sheet sheet = excel[sheetName];
      excel.delete('Sheet1');

      // ── Header Info ──────────────────────────────────────
      _setCell(sheet, 0, 0, 'Subject:', bold: true);
      _setCell(sheet, 0, 1, subject);
      _setCell(sheet, 1, 0, 'Department:', bold: true);
      _setCell(sheet, 1, 1, '$dept - Division $div');
      _setCell(sheet, 2, 0, 'Classroom:', bold: true);
      _setCell(sheet, 2, 1, classroom);
      _setCell(sheet, 3, 0, 'Date:', bold: true);
      _setCell(sheet, 3, 1, _formatDate(sessionDate));
      _setCell(sheet, 4, 0, 'Total Present:', bold: true);
      _setCell(sheet, 4, 1, '${attendanceList.length} students');

      // ── Blank row ────────────────────────────────────────
      // Row 5 blank

      // ── Table Header ─────────────────────────────────────
      _setCell(sheet, 6, 0, 'Sr.No', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');
      _setCell(sheet, 6, 1, 'PRN', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');
      _setCell(sheet, 6, 2, 'Student Name', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');
      _setCell(sheet, 6, 3, 'Time', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');

      // ── Student Rows ──────────────────────────────────────
      for (int i = 0; i < attendanceList.length; i++) {
        final student = attendanceList[i];
        final markedTime = DateTime.fromMillisecondsSinceEpoch(
            student['marked_time'] as int);
        final bgColor = i % 2 == 0 ? 'FFFFFF' : 'F0F4FF';

        _setCell(sheet, 7 + i, 0, '${i + 1}', bgColor: bgColor);
        _setCell(sheet, 7 + i, 1, student['prn'] as String, bgColor: bgColor);
        _setCell(sheet, 7 + i, 2, student['student_name'] as String, bgColor: bgColor);
        _setCell(sheet, 7 + i, 3, _formatTime(markedTime), bgColor: bgColor);
      }

      // ── Column Widths ─────────────────────────────────────
      sheet.setColWidth(0, 8);
      sheet.setColWidth(1, 15);
      sheet.setColWidth(2, 25);
      sheet.setColWidth(3, 12);

      // ── Save & Share ──────────────────────────────────────
      final fileName =
          '${subject}_${dept}${div}_${_formatDateFile(sessionDate)}.xlsx';
      await _saveAndShare(excel, fileName, context);
    } catch (e) {
      debugPrint('Export session error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // MASTER SHEET
  // All lectures — ✅ present, ❌ absent, with % and total
  // ════════════════════════════════════════════════════════════

  Future<void> exportMasterSheet({
    required BuildContext context,
    required String subject,
    required String dept,
    required String div,
  }) async {
    try {
      // Get division ID
      final divisionId = await DBService.instance.getDivisionId(dept, div);
      if (divisionId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Division not found! Please import class list first.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get all students in division (class list)
      final allStudents =
          await DBService.instance.getStudentsByDivision(divisionId);

      // Get all sessions for this subject+dept+div
      final sessions = await DBService.instance.getSessionsFiltered(
        subject: subject,
        department: dept,
        division: div,
      );

      if (sessions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No sessions found for this subject!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get all attendance data
      final allAttendance = await DBService.instance.getAttendanceForMasterSheet(
        subject: subject,
        department: dept,
        division: div,
      );

      // Build attendance map: {prn: {sessionId: true}}
      final Map<String, Map<int, bool>> attendanceMap = {};
      for (final record in allAttendance) {
        final prn = record['prn'] as String;
        final sessionId = record['session_id'] as int;
        attendanceMap[prn] ??= {};
        attendanceMap[prn]![sessionId] = true;
      }

      // ── Create Excel ─────────────────────────────────────
      final excel = Excel.createExcel();
      final sheetName = '$subject-$dept$div-Master';
      final Sheet sheet = excel[sheetName];
      excel.delete('Sheet1');

      // ── Header Info ──────────────────────────────────────
      _setCell(sheet, 0, 0, 'Subject:', bold: true);
      _setCell(sheet, 0, 1, subject);
      _setCell(sheet, 1, 0, 'Department:', bold: true);
      _setCell(sheet, 1, 1, '$dept - Division $div');
      _setCell(sheet, 2, 0, 'Total Lectures:', bold: true);
      _setCell(sheet, 2, 1, '${sessions.length}');
      _setCell(sheet, 3, 0, 'Total Students:', bold: true);
      _setCell(sheet, 3, 1, '${allStudents.length}');

      // ── Table Header Row ─────────────────────────────────
      _setCell(sheet, 5, 0, 'Sr.No', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');
      _setCell(sheet, 5, 1, 'PRN', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');
      _setCell(sheet, 5, 2, 'Student Name', bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');

      // Date columns
      for (int s = 0; s < sessions.length; s++) {
        final sessionDate = DateTime.fromMillisecondsSinceEpoch(
            sessions[s]['start_time'] as int);
        _setCell(sheet, 5, 3 + s, _formatDateShort(sessionDate),
            bold: true, bgColor: '1565C0', fontColor: 'FFFFFF');
      }

      _setCell(sheet, 5, 3 + sessions.length, 'Total',
          bold: true, bgColor: '0D47A1', fontColor: 'FFFFFF');
      _setCell(sheet, 5, 4 + sessions.length, 'Percentage',
          bold: true, bgColor: '0D47A1', fontColor: 'FFFFFF');

      // ── Student Rows ──────────────────────────────────────
      for (int i = 0; i < allStudents.length; i++) {
        final student = allStudents[i];
        final prn = student['prn'] as String;
        final name = student['name'] as String;
        int presentCount = 0;

        final rowBg = i % 2 == 0 ? 'FFFFFF' : 'F0F4FF';

        _setCell(sheet, 6 + i, 0, '${i + 1}', bgColor: rowBg);
        _setCell(sheet, 6 + i, 1, prn, bgColor: rowBg);
        _setCell(sheet, 6 + i, 2, name, bgColor: rowBg);

        // Attendance columns
        for (int s = 0; s < sessions.length; s++) {
          final sessionId = sessions[s]['id'] as int;
          final isPresent = attendanceMap[prn]?[sessionId] ?? false;

          if (isPresent) {
            presentCount++;
            _setCell(sheet, 6 + i, 3 + s, '✅',
                bgColor: 'E8F5E9'); // light green
          } else {
            _setCell(sheet, 6 + i, 3 + s, '❌',
                bgColor: 'FFEBEE'); // light red
          }
        }

        // Total & Percentage
        final percentage = sessions.isEmpty
            ? 0.0
            : (presentCount / sessions.length) * 100;
        final percentStr = '${percentage.toStringAsFixed(1)}%';

        // Color code percentage
        String percentBg = 'C8E6C9'; // green > 75%
        if (percentage < 60) {
          percentBg = 'FFCDD2'; // red < 60%
        } else if (percentage < 75) {
          percentBg = 'FFF9C4'; // yellow 60-75%
        }

        _setCell(sheet, 6 + i, 3 + sessions.length,
            '$presentCount/${sessions.length}',
            bold: true, bgColor: rowBg);
        _setCell(sheet, 6 + i, 4 + sessions.length, percentStr,
            bold: true, bgColor: percentBg);
      }

      // ── Column Widths ─────────────────────────────────────
      sheet.setColWidth(0, 8);
      sheet.setColWidth(1, 15);
      sheet.setColWidth(2, 25);
      for (int s = 0; s < sessions.length; s++) {
        sheet.setColWidth(3 + s, 10);
      }
      sheet.setColWidth(3 + sessions.length, 10);
      sheet.setColWidth(4 + sessions.length, 12);

      // ── Save & Share ──────────────────────────────────────
      final fileName =
          '${subject}_${dept}${div}_MasterSheet.xlsx';
      await _saveAndShare(excel, fileName, context);
    } catch (e) {
      debugPrint('Export master sheet error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  void _setCell(
    Sheet sheet,
    int row,
    int col,
    String value, {
    bool bold = false,
    String? bgColor,
    String? fontColor,
  }) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);

    final style = CellStyle(
      bold: bold,
      backgroundColorHex: bgColor != null ? ExcelColor.fromHexString(bgColor) : null,
      fontColorHex: fontColor != null ? ExcelColor.fromHexString(fontColor) : null,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    cell.cellStyle = style;
  }

  Future<void> _saveAndShare(
      Excel excel, String fileName, BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';
    final fileBytes = excel.save();

    if (fileBytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to generate file'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: fileName,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  String _formatDateFile(DateTime dt) {
    return '${dt.day}${dt.month}${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
