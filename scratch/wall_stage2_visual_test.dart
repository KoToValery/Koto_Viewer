import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../test/features/architect/architect_workspace_interaction_test.dart' as workspace;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_plinth_dialog.dart';
import '../test/features/architect/architect_wall_compositions_test.dart' as data;
import '../test/features/architect/architect_editing_test.dart' as editing;
void main(){
 testWidgets('Stage 2 visual review',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(()async{
   await (FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(await File('C:/Windows/Fonts/arial.ttf').readAsBytes())))).load();
   await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final p=data.project([data.wall('a',Offset.zero,const Offset(4,0))]).copyWith(units:ArchitectUnit.centimeters,distanceDecimals:0);
  final model=editing.seeded(p.activeStorey);model.restore(p);addTearDown(model.dispose);
  const key=ValueKey('capture');
  Future<void> capture(String name)async{
   await tester.pumpAndSettle();
   final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
   await tester.runAsync(()async{final image=await boundary.toImage(pixelRatio:2);final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!;await File('docs/images/$name.png').writeAsBytes(bytes.buffer.asUint8List());image.dispose();});
  }
  await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,locale:const Locale('bg'),theme:ThemeData(brightness:Brightness.dark,fontFamily:'Roboto'),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,home:ArchitectWorkspaceScreen(commandController:model))));
  await tester.pumpAndSettle();
  final context=tester.element(find.byType(ArchitectWorkspaceScreen));
  showDialog<void>(context:context,builder:(_)=>ArchitectWallCompositionEditor(project:p,type:data.composition.copyWith(name:'',labelId:'ext_25_12_eps'),allowTypeSelection:true,onApply:(_,_,_)=>false));
  await capture('architect_wall_layers_phone');
  Navigator.of(context).pop();await tester.pumpAndSettle();
  showDialog<void>(context:context,builder:(_)=>ArchitectWallPlinthDialog(project:p,values:const [ArchitectWallPlinth(enabled:true)],onApply:(_)=>false));
  await capture('architect_wall_plinth_phone');
  Navigator.of(context).pop();await tester.pumpAndSettle();
  await editing.selectTool(tester,'wall');await tester.tap(find.byKey(const ValueKey('wall-arc-toggle')));await tester.pumpAndSettle();
  for(final point in [const Offset(0,2),const Offset(4,2),const Offset(2,3)]){await tester.tapAt(workspace.screen(tester,point));await tester.pumpAndSettle();}
  await capture('architect_curved_wall_phone');
  expect(tester.takeException(),isNull);
 });
}
