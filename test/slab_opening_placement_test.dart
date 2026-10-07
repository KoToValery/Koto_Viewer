import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/services/slab_opening_placement.dart';

List<Offset> box(double x, double y, double w, double h) =>
  [Offset(x,y), Offset(x+w,y), Offset(x+w,y+h), Offset(x,y+h)];
void main() {
  test('whole contour determines owner independent of ordering, units and winding', () {
    for(final scale in [1.0,100.0,1000.0]) {
      for(final reverse in [false,true]) {
        final ring=box(scale,scale,2*scale,3*scale);
        final slab=StructuralSlab(id:'main',polygon:box(0,0,10*scale,10*scale));
        final other=StructuralSlab(id:'other',polygon:box(20*scale,0,10*scale,10*scale));
        final result=SlabOpeningPlacement.apply(slabs:reverse?[other,slab]:[slab,other],
          polygon:reverse?ring.reversed.toList():ring,scale:scale,type:SlabOpeningType.staircase);
        expect(result.accepted,isTrue);
        expect(result.opening,('main',0));
        final owner=result.slabs!.firstWhere((s)=>s.id=='main');
        expect(owner.getOpeningType(0),SlabOpeningType.staircase);
        expect(slab.openings,isEmpty);
      }
    }
  });
  test('outside, touching, spanning two slabs and self-intersecting holes are rejected', () {
    final slabs=[StructuralSlab(id:'a',polygon:box(0,0,5,5)),
      StructuralSlab(id:'b',polygon:box(5,0,5,5))];
    for(final ring in [
      box(20,20,2,2),box(0,1,2,2),box(4,1,2,2),
      [const Offset(1,1),const Offset(3,3),const Offset(3,1),const Offset(1,3)],
    ]) {
      expect(SlabOpeningPlacement.apply(slabs:slabs,polygon:ring,scale:1).accepted,isFalse);
    }
  });
  test('centroid containment cannot accept a cut across a concavity', () {
    const slab=StructuralSlab(id:'s',polygon:[
      Offset(0,0),Offset(10,0),Offset(10,10),Offset(6,10),
      Offset(6,4),Offset(4,4),Offset(4,10),Offset(0,10)]);
    final result=SlabOpeningPlacement.apply(slabs:[slab],polygon:box(2,2,6,6),scale:1);
    expect(result.accepted,isFalse);
  });
  test('ambiguous owners and duplicate IDs are never resolved by list order', () {
    final s=StructuralSlab(id:'s',polygon:box(0,0,10,10));
    for(final second in [s.copyWith(id:'other'),s]) {
      final r=SlabOpeningPlacement.apply(slabs:[s,second],polygon:box(1,1,2,2),scale:1);
      expect(r.issue,OpeningPlacementIssue.ambiguousOwner);
    }
  });
  test('move preserves type, owner, JSON and leaves original snapshot available for undo', () {
    final a=StructuralSlab(id:'a',polygon:box(0,0,10,10))
      .addOpening(box(1,1,2,3),type:SlabOpeningType.staircase);
    final b=StructuralSlab(id:'b',polygon:box(20,0,10,10));
    final r=SlabOpeningPlacement.apply(slabs:[a,b],polygon:box(21,1,2,3),scale:1,replacing:('a',0));
    expect(r.accepted,isTrue);
    expect(r.opening,('b',0));
    expect(r.slabs![0].openings,isEmpty);
    expect(r.slabs![1].getOpeningType(0),SlabOpeningType.staircase);
    expect(a.openings.length,1);
    final restored=StructuralSlab.fromJson(jsonDecode(jsonEncode(r.slabs![1].toJson())));
    expect(restored.getOpeningType(0),SlabOpeningType.staircase);
    expect(SlabOpeningPlacement.apply(slabs:[a,b],polygon:box(21,1,2,3),scale:1,
      replacing:('a',0),allowTransfer:false).accepted,isFalse);
  });
  test('move within same owner ignores only the moved hole and keeps index', () {
    final s=StructuralSlab(id:'s',polygon:box(0,0,10,10))
      .addOpening(box(1,1,2,2),type:SlabOpeningType.staircase)
      .addOpening(box(6,1,2,2),type:SlabOpeningType.elevator);
    final r=SlabOpeningPlacement.apply(slabs:[s],polygon:box(1.2,1,2,2),scale:1,replacing:('s',0));
    expect(r.accepted,isTrue);
    expect(r.opening,('s',0));
    expect(r.slabs!.single.getOpeningType(1),SlabOpeningType.elevator);
    for(final ring in [box(5,1,2,2),box(4,1,2,2)]) {
      expect(SlabOpeningPlacement.apply(slabs:[s],polygon:ring,scale:1,replacing:('s',0)).accepted,isFalse);
    }
  });
  test('partial legacy type arrays remain aligned after removal and append', () {
    final s=StructuralSlab(id:'s',polygon:box(0,0,10,10),
      openings:[box(1,1,1,1),box(3,1,1,1)],openingTypes:[SlabOpeningType.staircase]);
    final r=s.removeOpening(0).addOpening(box(5,1,1,1),type:SlabOpeningType.elevator);
    expect(r.getOpeningType(0),SlabOpeningType.shaft);
    expect(r.getOpeningType(1),SlabOpeningType.elevator);
  });
}