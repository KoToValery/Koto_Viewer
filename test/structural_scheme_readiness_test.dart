import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_scheme_readiness.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/widgets/structural_scheme_readiness_dialog.dart';

const slab=StructuralSlab(id:'s',polygon:[Offset(0,0),Offset(10,0),Offset(10,10),Offset(0,10)]);
const stairs=[Offset(1,1),Offset(3,1),Offset(3,4),Offset(1,4)];
StructuralProject project(List<StructuralSlab> slabs) => StructuralProject(storeys:[
  StoreyLevel(id:'f',name:'f',height:2.9,slabs:slabs)]);
void main() {
  test('requires ceiling and typed staircase; elevator alone is insufficient', () {
    expect(StructuralSchemeReadiness.evaluate(project([]),1).issues,
      contains(SchemeReadinessIssue.missingSlab));
    for(final type in [SlabOpeningType.elevator,SlabOpeningType.custom,SlabOpeningType.shaft]) {
      expect(StructuralSchemeReadiness.evaluate(project([slab.addOpening(stairs,type:type)]),1).issues,
        contains(SchemeReadinessIssue.missingStaircase));
    }
  });
  test('opening references resolve the ceiling owner and concrete levels', () {
    final result=StructuralSchemeReadiness.evaluate(project([
      slab.addOpening(stairs,type:SlabOpeningType.staircase)]),1);
    expect(result.geometryReady,isTrue);
    expect(result.openings.single.storeyId,'f');
    expect(result.openings.single.slabId,'s');
    expect(result.openings.single.openingIndex,0);
    expect(result.openings.single.concreteTop,closeTo(2.85,1e-10));
    expect(result.openings.single.concreteSoffit,closeTo(2.65,1e-10));
  });
  test('rechecks editing, deletion, geometry and level changes', () {
    final s=slab.addOpening(stairs,type:SlabOpeningType.staircase);
    expect(StructuralSchemeReadiness.evaluate(project([s]),1,editing:true).geometryReady,isFalse);
    expect(StructuralSchemeReadiness.evaluate(project([s.removeOpening(0)]),1).geometryReady,isFalse);
    final bad=s.updateOpening(0,[const Offset(-1,1),const Offset(3,1),const Offset(3,4)]);
    expect(StructuralSchemeReadiness.evaluate(project([bad]),1).issues,
      contains(SchemeReadinessIssue.invalidGeometry));
    expect(StructuralSchemeReadiness.evaluate(project([s.copyWith(thickness:4)]),1).issues,
      contains(SchemeReadinessIssue.invalidSlabLevel));
  });
  test('overlapping ceilings and duplicate storey elevations block readiness', () {
    final s=slab.addOpening(stairs,type:SlabOpeningType.staircase);
    expect(StructuralSchemeReadiness.evaluate(project([s,s.copyWith(id:'b')]),1).issues,
      contains(SchemeReadinessIssue.overlappingSlabs));
    final p=project([s]);
    final duplicate=p.copyWith(storeys:[p.storeys.first,
      const StoreyLevel(id:'other',name:'other')]);
    expect(StructuralSchemeReadiness.evaluate(duplicate,1).issues,
      contains(SchemeReadinessIssue.ambiguousLevels));
  });
  test('legacy untyped holes are not inferred to be stairs', () {
    expect(StructuralSchemeReadiness.evaluate(project([slab.copyWith(openings:[stairs])]),1).issues,
      contains(SchemeReadinessIssue.missingStaircase));
  });
  for(final lang in ['bg','en']) {
    testWidgets('readiness dialog displays owner and blockers on mobile: $lang',(tester) async {
      tester.view.physicalSize=const Size(360,800);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l=await AppLocalizations.delegate.load(Locale(lang));
      Future<void> show(StructuralProject p) async {
        await tester.pumpWidget(MaterialApp(locale:Locale(lang),
          supportedLocales:AppLocalizations.supportedLocales,
          localizationsDelegates:AppLocalizations.localizationsDelegates,
          home:Scaffold(body:StructuralSchemeReadinessDialog(project:p,scale:1))));
        await tester.pumpAndSettle();
      }
      await show(project([]));
      expect(find.text(l.openingNoSlab),findsOneWidget);
      expect(find.text(l.schemeMissingStairs),findsOneWidget);
      expect(tester.takeException(),isNull);
      await show(project([slab.addOpening(stairs,type:SlabOpeningType.staircase)]));
      expect(find.text(l.schemeGeometryReady),findsOneWidget);
      expect(find.textContaining(l.ceilingSlabLevels('2.850','2.650')),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}