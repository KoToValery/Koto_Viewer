import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dwg_document_adapter.dart';

Map<String, dynamic> _document(List<dynamic> entities) => {
  'source': 'DWG',
  'protocol': 1,
  'header': {},
  'layers': [
    {
      'name': '0',
      'flags': {'off': true, 'frozen': true},
      'color': {'Index': 7},
    },
  ],
  'blocks': [
    {'name': '*Model_Space', 'base_point': {}, 'entities': entities},
  ],
};

void main() {
  test('native linetype gaps and dots use the viewer LTYPE convention', () {
    final data = _document([]);
    data['line_types'] = [
      {
        'name': 'DASHDOT',
        'elements': [
          {'length': 1270},
          {'length': -635},
          {'length': 0},
          {'length': -635},
        ],
      },
    ];
    expect(DwgDocumentAdapter.decode(data).lineTypes['DASHDOT'], [
      1270,
      635,
      1.8,
      635,
    ]);
  });

  test(
    'constructs every existing viewer entity family from native objects',
    () {
      final objects = <Map<String, dynamic>>[
        {
          'Line': {
            'start': {'x': 2, 'y': 3},
            'end': {'x': 4, 'y': 5},
          },
        },
        {
          'Point': {
            'location': {'x': 1, 'y': 2},
          },
        },
        {
          'Circle': {'center': {}, 'radius': 5},
        },
        {
          'Arc': {
            'center': {},
            'radius': 5,
            'start_angle': 0,
            'end_angle': 3.141592653589793,
          },
        },
        {
          'Ellipse': {
            'center': {},
            'major_axis': {'x': 5, 'y': 0},
            'minor_axis_ratio': .5,
          },
        },
        {
          'LwPolyline': {
            'vertices': [
              {
                'location': {'x': 1, 'y': 2},
              },
            ],
            'is_closed': true,
          },
        },
        {
          'Polyline': {'vertices': []},
        },
        {
          'Polyline2D': {'vertices': []},
        },
        {
          'Polyline3D': {'vertices': []},
        },
        {
          'Spline': {'degree': 3, 'control_points': []},
        },
        {
          'Text': {'value': 'Кота ±0.00', 'insertion_point': {}, 'height': 2.5},
        },
        {
          'MText': {'value': r'{\H2x;Текст}\PРед 2', 'height': 2.5},
        },
        {
          'Insert': {'block_name': 'B', 'insert_point': {}, 'attributes': []},
        },
        {
          'Solid': {
            'first_corner': {},
            'second_corner': {},
            'third_corner': {},
            'fourth_corner': {},
          },
        },
        {
          'Hatch': {
            'pattern': {'name': 'SOLID'},
            'is_solid': true,
            'paths': [],
          },
        },
        {
          'Dimension': {
            'Linear': {'base': {}, 'first_point': {}, 'second_point': {}},
          },
        },
        {
          'Leader': {'vertices': []},
        },
        {
          'MultiLeader': {
            'context': {'text_string': 'Надпис', 'leader_roots': []},
          },
        },
        {
          'Viewport': {'center': {}, 'view_center': {}},
        },
        {
          'AttributeDefinition': {'tag': 'TAG', 'default_value': 'Стойност'},
        },
      ];
      final doc = DwgDocumentAdapter.decode(_document(objects));
      expect(doc.entities.length, objects.length);
      expect(doc.entities.whereType<DxfLine>().single.p1.dx, 2);
      expect(doc.entities.whereType<DxfText>().single.text, 'Кота ±0.00');
      expect(
        doc.entities.whereType<DxfMText>().single.cleanText,
        'Текст\nРед 2',
      );
      expect(doc.layers['0']!.isVisible, isFalse);
      expect(doc.layers['0']!.isFrozen, isTrue);
      expect(doc.entities.whereType<DxfEllipse>().single.minorRatio, .5);
      expect(doc.entities.whereType<DxfMLeader>().single.cleanText, 'Надпис');
    },
  );

  test(
    'keeps model and paper entities separate using native block ownership',
    () {
      final data = _document([
        {
          'Line': {
            'start': {},
            'end': {'x': 1, 'y': 1},
          },
        },
      ]);
      data['layouts'] = [
        {'name': 'Лист A', 'block_record': 42},
      ];
      (data['blocks'] as List).add({
        'name': '*Paper_Space',
        'handle': 42,
        'base_point': {},
        'entities': [
          {
            'Line': {
              'start': {'x': 100, 'y': 100},
              'end': {'x': 101, 'y': 101},
            },
          },
        ],
      });
      final doc = DwgDocumentAdapter.decode(data);
      expect(doc.layouts, contains('Лист A'));
      expect(doc.layoutEntities['Model']!.length, 1);
      expect(doc.layoutEntities['Лист A']!.length, 1);
      expect(doc.bounds.right, lessThan(5));
    },
  );

  test(
    'rejects unsupported data explicitly instead of returning a partial drawing',
    () {
      expect(
        () => DwgDocumentAdapter.decode({'source': 'DWG', 'protocol': 99}),
        throwsFormatException,
      );
      expect(
        () => DwgDocumentAdapter.decode(
          _document([
            {'Unknown': {}},
          ]),
        ),
        throwsFormatException,
      );
    },
  );
}
