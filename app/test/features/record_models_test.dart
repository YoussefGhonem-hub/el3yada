import 'package:el3yada/features/records/domain/record_models.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The medical files models against backend/docs/api-phase-3-files.md.
void main() {
  test('a record view reads the contract sample', () {
    final record = MedicalRecordView.fromJson({
      'recordId': 'r1',
      'patientId': 'p1',
      'category': 'other',
      'otherType': 'sickLeave',
      'otherTypeText': null,
      'title': 'إجازة مرضية',
      'documentDate': '2026-11-17',
      'notes': null,
      'session': {
        'sessionId': 's1',
        'type': 'examination',
        'createdAt': '2026-11-17T09:00:00.000Z',
      },
      'source': 'scan',
      'createdAt': '2026-11-17T09:10:00.000Z',
      'updatedAt': '2026-11-17T09:10:00.000Z',
      'createdBy': {'userId': 'u1', 'role': 'assistant', 'name': 'سارة محمود'},
      'attachments': [
        {
          'attachmentId': 'a1',
          'fileName': 'scan.pdf',
          'mimeType': 'application/pdf',
          'sizeBytes': 812300,
          'storedSizeBytes': 812300,
          'pageCount': 3,
          'hasThumbnail': true,
          'previewable': true,
        },
      ],
      'totalSizeBytes': 812300,
    });

    expect(record.category, RecordCategory.other);
    expect(record.otherType, RecordOtherType.sickLeave);
    expect(record.documentDate, DateTime.utc(2026, 11, 17));
    expect(record.session!.type, SessionType.examination);
    expect(record.source, RecordSource.scan);
    expect(record.createdBy.isAssistant, isTrue);
    expect(record.attachments.single.isPdf, isTrue);
    expect(record.attachments.single.pageCount, 3);
    expect(record.cover!.attachmentId, 'a1');
    expect(record.totalSizeBytes, 812300);
  });

  test('a page has the counts for the chips', () {
    final page = RecordPage.fromJson({
      'items': [],
      'page': 1,
      'pageSize': 30,
      'totalCount': 0,
      'counts': {'radiology': 2, 'lab': 5, 'prescription': 1, 'other': 0},
    });
    expect(page.counts.total, 8);
    expect(page.counts.of(null), 8);
    expect(page.counts.of(RecordCategory.lab), 5);
  });

  test('an upload answer keeps the three sizes', () {
    final upload = UploadedFile.fromJson({
      'uploadId': 'u1',
      'fileName': 'scan-1.jpg',
      'mimeType': 'image/jpeg',
      'sizeBytes': 612034,
      'storedSizeBytes': 612034,
      'originalSizeBytes': 4380112,
      'pageCount': null,
      'hasThumbnail': true,
      'optimized': true,
      'expiresAt': '2026-11-18T09:00:00.000Z',
    });
    expect(upload.originalSizeBytes, greaterThan(upload.sizeBytes));
    expect(upload.optimized, isTrue);
  });

  test('the draft sends what the API expects', () {
    final other = RecordDraft(
      category: RecordCategory.other,
      otherType: RecordOtherType.custom,
      otherTypeText: '  نتائج معمل ',
      title: '   ',
      documentDate: DateTime.utc(2026, 11, 3),
      notes: '',
    ).toJson();
    expect(other, {
      'category': 'other',
      'otherType': 'custom',
      'otherTypeText': 'نتائج معمل',
      'title': null,
      'documentDate': '2026-11-03',
      'notes': null,
      'sessionId': null,
    });

    final lab = RecordDraft(
      category: RecordCategory.lab,
      otherType: RecordOtherType.sickLeave,
      otherTypeText: 'ignored',
      documentDate: DateTime.utc(2026, 11, 3),
      sessionId: 's1',
    ).toJson();
    expect(lab['otherType'], isNull, reason: 'a type is only for Other');
    expect(lab['otherTypeText'], isNull);
    expect(lab['sessionId'], 's1');
  });
}
