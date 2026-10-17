# Общ GPU viewport — втори етап

Архитектурата, конструкциите и IFC използват една и съща постоянна Filament сцена през Thermion 0.5.0. Включеното по подразбиране „Ускорено 3D“ избира GPU texture на Windows и Android arm64. При грешка при инициализация/качване се използва native software depth renderer, а след него Canvas. Другите платформи запазват резервното визуализиране. Изборът „Съвместим режим“ изключва GPU сцената.

## Реализация

- `Cad3DGpuSurface` подава позиции, нормали, линейни vertex цветове и индекси директно към Filament. Не прави GLTF/IFC export. Сцената остава в GPU паметта при навигация; няма CPU сортиране или връщане на пиксели към Dart за всеки кадър.
- Камерата пази съществуващите Z-up координати, pan, zoom, presets и разходка. Геометрията се центрира и нормализира само в render адаптера; BIM моделът и числовите единици не се променят. Отделни model/projection матрици запазват правилните нормали, осветление и frustum culling.
- PBR материалите използват оригиналните цветове, неметална повърхност и roughness 0.72. Непрозрачни/прозрачни и едностранни/двустранни лица се групират отделно. Това не е нов каталог на физически BIM материали или текстури.
- Една насочена светлина със сенки, постоянно SH околно осветление, SSAO и ACES tone mapping. Filament поддържа една насочена светлина: допълнителни directional „fill“ светлини не заместват околното осветление.
- FXAA е използван вместо неподдържания MSAA върху Windows Vulkan/D3D shared target.
- GPU линиите показват boundary/material/crease контури; копланарните триангулационни диагонали се скриват в CAD режим. Wireframe запазва триангулацията. Прозрачният режим използва alpha blending.
- Качването е на части до 20 000 триъгълника. Кадрите не качват геометрия отново. Texture resize е отложен със 100 ms при промяна на прозореца; физическата дълга страна е ограничена до 2560 пиксела.
- Инициализация, качване, camera update, resize и teardown са сериализирани. Изчаква се операция в ход, преди да се освободи view. Освобождават се scene assets, ръчно създадените material instances, tone mapper, platform texture и неизползваните swapchains на този viewer.
- Скритият viewport и background спират визуализирането за съответния view. Глобалният frame scheduler не се спира от един viewport, защото други сцени могат да го ползват.

## Зависимости

`thermion_flutter` и `thermion_dart` са фиксирани на 0.5.0. Native адаптерът изолира две implementation API зависимости: SH осветление и texture descriptor. Това трябва да се провери при бъдещ upgrade на Thermion.

Thermion 0.5 използва `hooks` 1.x. Съществуващият `ffigen` 21 изисква `hooks` 2.x, затова C binding generator е преместен на съвместимия 20.1.1. Resolver-ът съответно избира съвместими `code_assets`, `native_toolchain_c`, `objective_c` и `path_provider_foundation`; няма произволен общ dependency upgrade. Съществуващият `archive` override е запазен; Windows и Android native build hooks се изпълняват успешно с него.

## Проверки и граници

`test/features/cad_3d/cad_3d_filament_camera_test.dart` сравнява GPU проекцията с CAD проекцията за шестте presets, телефонен и desktop viewport, метри и големи CAD единици, pan, zoom и fly позиция: 24 теста.

`tool/qa/cad_3d_gpu_smoke.dart` е самостоятелно Flutter приложение с реален Windows plugin host. То заснема самия GPU render target, проверява небланково изображение, shaded/CAD edges/wireframe/transparent режими, resize и повторно отваряне. При финалния teardown проверява, че няма останали swapchains. Заснемането е само за QA: frame scheduler се спира и източва преди диагностичния readback.

```powershell
flutter build windows --profile --target tool/qa/cad_3d_gpu_smoke.dart
# Стартиране от root папката; JSON и PNG резултатите са в build/cad-3d-qa.
flutter build apk --debug --target-platform android-arm64
```

Реалният Windows тест разпозна Vulkan върху NVIDIA GeForce GTX 1080 Ti. Android arm64 APK се компилира; проверка върху физически Android телефон още няма. Не се заявява измерен FPS или ускорение в проценти: такова сравнение изисква profile/release сцени с еднакво качество и реални големи BIM файлове.

Финалният GPU smoke тест премина пет цикъла с 132 архитектурни триъгълника: shaded, CAD edges при 640×400, wireframe, transparent при 360×681 и ново отваряне на shaded сцената. След последния teardown няма останали swapchains. Това е функционална GPU проверка, не benchmark на голям BIM модел.

Scoped analyzer е чист. Разширеният регресионен набор има 117 успешни теста; един допълнителен тест (`roof_composite_layers_test.dart`) не може да започне, защото очаква липсващ файл `C:\Users\Creator\Dropbox\test_files\roof.ifc`. Test fixture-ът и очакванията не са променяни. По-ранните шест IFC parser неуспеха и baseline проверката им са описани в документа за първия етап.

Windows main Release build премина успешно. Последващ build на текущата работна папка е прекъснат от паралелно редактираните покривни разрези (`fasciaHeight`/`slabId`); тези файлове и съобщенията им не са включени в 3D комита. Самостоятелният Profile GPU тест проверява окончателния render адаптер независимо от тези екрани.

GPU renderer не заменя BIM геометричния kernel. Общите копланарни ръбове се почистват, но пълните boolean връзки стена–покрив–плоча остават отделна геометрична задача. Нов интерактивен section box/clip plane не е добавен. Не е необходим нов Rust engine за този етап.
