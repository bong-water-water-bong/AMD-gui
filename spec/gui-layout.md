# Adrenalin CNext — complete GUI layout

Recovered from the AOT-compiled QML inside `RadeonSoftware.exe` (10.24.20021.0): compiled units keep their `qrc:/Qml/RSX/...` source paths in the string table. Sources: `strings-corpus.txt`, `localisation/CNext_*.ts`, `ref/*.rcc`.

- 122 RSX panels (qrc paths), 438 unique QML files total
- UI variants: WS=47 contexts, EMBD=54, VDI=22, CRTR=22

## 1. Section map

| Section | Panels |
|---|---|
| Browser | 1 |
| Common | 1 |
| Dashboard | 17 |
| Eyefinity | 1 |
| Gaming | 24 |
| Notifications | 1 |
| Performance | 35 |
| Relive | 10 |
| Settings | 27 |
| SmartFeatures | 1 |
| Window | 3 |
| Wizard | 1 |

## 2. Full panel tree (qrc:/Qml/RSX/)

```
Browser/
  Browser.qml
Common/
  Dialogs/WindowModeSwitchDialog.qml
Dashboard/
  AmdIntelligence.qml
  Banner.qml
  CaptureControls.qml
  Dashboard.qml
  DashboardSidebar.qml
  DeviceStatus.qml
  DriverUpdate.qml
  GlobalExperienceWidget.qml
  NowPlaying.qml
  PerformanceMetrics.qml
  RecentGameMedia.qml
  RecentGames.qml
  RecentMedia.qml
  SceneSelection.qml
  StreamChat.qml
  StreamingPreview.qml
  UpgradeAdvisor.qml
Eyefinity/
  RSXEyefinity.qml
Gaming/
  Display.qml
  Gallery.qml
  GalleryItem.qml
  GalleryItemEdit.qml
  GalleryItemEditMenu.qml
  GalleryItemMenu.qml
  GalleryList.qml
  GalleryListItem.qml
  GalleryListListItem.qml
  GameGalleryListMenu.qml
  GameList.qml
  GameListGridCoverArtItem.qml
  GameListGridItem.qml
  GameListListItem.qml
  GamePage.qml
  GamePageSidebar.qml
  GameProfileAdvisor.qml
  GameUpgradeAdivisor.qml
  Gaming.qml
  GamingNavMenu.qml
  GamingProfileNavMenu.qml
  Graphics.qml
  RecentGameMedia.qml
  UpgradeAdvisor.qml
Notifications/
  Notifications.qml
Performance/
  Advisors.qml
  CPU.qml
  FPS.qml
  GPU.qml
  GameAdvisor.qml
  Metrics.qml
  MetricsSidebarNavMenu.qml
  MetricsSidebarNavMenuV2.qml
  Performance.qml
  PerformanceMeticsColumnLeft.qml
  PerformanceMeticsColumnRight.qml
  PerformanceMeticsOverlay.qml
  PerformanceMeticsTracking.qml
  PerformanceMeticsTracking2.qml
  PerformanceMeticsView2Column.qml
  PerformanceMeticsViewColumn.qml
  PerformanceMetricsMenu.qml
  PerformanceMetricsMenu2.qml
  PerformanceNavMenu.qml
  PresentMonSetup.qml
  RAM.qml
  SmartShift.qml
  Tuning.qml
  TuningCPU.qml
  TuningControl.qml
  TuningMenu.qml
  TuningOD5.qml
  TuningOD8.qml
  TuningODN.qml
  TuningODN_Pre_fanCurve.qml
  TuningSmartSystem.qml
  TuningSystem.qml
  TuningWSOD8.qml
  TuningWSODN.qml
  VRAM.qml
Relive/
  Relive.qml
  ReliveNavMenu.qml
  ReliveWizard.qml
  SceneEditor.qml
  SceneSelectionItem.qml
  StreamAndRecord.qml
  Streaming.qml
  StreamingChatPanel.qml
  StreamingControlPanel.qml
  StreamingSidebar.qml
Settings/
  AMDLinkLauncher.qml
  AccountGridItem.qml
  Accounts.qml
  Camera.qml
  DeviceItem.qml
  Devices.qml
  DvrGeneral.qml
  DvrSettings/DvrSettingsMedia.qml
  DvrSettings/DvrSettingsRecording.qml
  DvrSettings/DvrSettingsStreaming.qml
  EDID.qml
  EDIDEmulate.qml
  EDIDMain.qml
  General.qml
  Hotkeys.qml
  Import.qml
  ImportMenu.qml
  Performance.qml
  PerformanceSetting.qml
  PreferencesSetting.qml
  ReliveVR.qml
  SafeMode.qml
  Settings.qml
  SettingsNavMenu.qml
  System.qml
  Video.qml
  VrStreamingSetting.qml
SmartFeatures/
  SmartFeatures.qml
Window/
  TopBar.qml
  TopBarSafeMode.qml
  TopBarSimple.qml
Wizard/
  Wizard.qml
```

## 3. Variant contexts

### CNext_WS (47)

`Banner` `CNStyles` `DvrSettingsMedia` `DvrSettingsRecording` `DvrTrackingEulaDialog` `GalleryListMenu` `GameList` `GameListGridStats` `GameListMenu` `GamePage` `GameProfile` `GameSearchBar` `GameStatsBox` `GameStreamingSetting` `Gaming` `GamingNavMenu` `GamingProfileNavMenu` `Hotkeys` `HotkeysRSX` `LastPlayed` `Main` `NotificationToast` `Notifications` `NotificationsRuntime` `NowPlaying` `PerformanceSetting` `PreferencesSetting` `QObject` `RecentGames` `ReliveWizard` `SearchKeywords` `SidebarNavMenu` `Style` `Style1` `System` `SystemInfo` `SystemTray` `TopBar` `TopBarSimple` `Tuning` `UI_GameManager::GameManager` `UI_RSX::BannerListModelController` `Utilities::Hotkeys` `WindowChrome` `WindowModeSwitchDialog` `Wizard` `YoutubeTermsDialog`

### CNext_EMBD (54)

`AppView` `Banner` `CNStyles` `Display` `DvrSettingsMedia` `DvrSettingsRecording` `Eyefinity` `GalleryListMenu` `GameDetails` `GameEyefinity` `GameList` `GameListGridStats` `GameListMenu` `GamePage` `GameProfile` `GameSearchBar` `GameStatsBox` `GameStreamingSetting` `GamingNavMenu` `GamingProfileNavMenu` `Graphics` `HotkeysRSX` `Infocenter` `LastPlayed` `Main` `NotificationToast` `Notifications` `NotificationsRuntime` `NowPlaying` `OverdriveNext` `PerformanceSetting` `PrefMenu` `PreferencesSetting` `QObject` `Radeon3D` `Radeon3d` `RecentGames` `ReliveWizard` `SearchKeywords` `SidebarNavMenu` `Style` `Style1` `Style3` `System` `SystemInfo` `SystemTray` `TopBar` `TopBarSimple` `Tuning` `UI_GameManager::GameManager` `UI_GameManager::RadeonUI` `Utilities::Hotkeys` `VirtualResolution` `WindowChrome`

### CNext_VDI (22)

`BasicGraphicsSettings` `CNStyles` `DriverUpdateContent` `DvrTrackingEulaDialog` `Hotkeys` `Infocenter` `Main` `NotificationsRuntime` `PrefMenu` `QObject` `SearchKeywords` `Style1` `Style3` `System` `SystemInfo` `TopBar` `TopBarSimple` `TuningCPU` `UI_RSX::BannerListModelController` `WindowChrome` `WizardWelcome` `YoutubeTermsDialog`

### CNext_CRTR (22)

`BasicGraphicsSettings` `CNStyles` `DriverUpdateContent` `DvrTrackingEulaDialog` `Hotkeys` `Infocenter` `Main` `NotificationsRuntime` `PrefMenu` `QObject` `SearchKeywords` `Style1` `Style3` `System` `SystemInfo` `TopBar` `TopBarSimple` `TuningCPU` `UI_RSX::BannerListModelController` `WindowChrome` `WizardWelcome` `YoutubeTermsDialog`

## 4. Shared components (not in RSX tree)

319 shared/leaf components, e.g.:

`AMDLinkBusyIndicator.qml` `AccessibilityDiag.qml` `AdvancedGraphicsSettings.qml` `AmdIntelligenceContent.qml` `AppPageAnimation.qml` `AppView.qml` `AudioNoiseSuppressionToggle.qml` `AudioWizard.qml` `AutoTuningPopup.qml` `AutoTuningResultPopup.qml` `BackgroundWithShadow.qml` `BaseButton.qml` `BaseFileDialog.qml` `BaseText.qml` `BasicButton.qml` `BasicGraphicsSettings.qml` `BasicTuningSettings.qml` `BorderGlow.qml` `BusyIndicatorPopUp.qml` `BusyIndicatorWindow.qml` `CNStyles.qml` `CNText.qml` `CodecNotFoundDialog.qml` `ComboBoxButton.qml` `ComboBoxDropDown.qml` `ComboBoxRadioButton.qml` `ComboBoxToggle.qml` `ConfirmMessageBox.qml` `CoolerMasterRGBLEDUpdate.qml` `CustomBusyIndicator.qml` `CustomDropShadow.qml` `CustomGridView.qml` `CustomMenu.qml` `CustomMenuItem.qml` `CustomPollingTimer.qml` `CustomPopupLabel.qml` `CustomPopupTextInput.qml` `CustomProgressBar.qml` `CustomScrollView.qml` `CustomSlider.qml` `CustomStackView.qml` `CustomTextImage.qml` `CustomTextInput.qml` `CustomToggle.qml` `CustomToolTip.qml` `DPIScale.qml` `DashboardColumnLeft.qml` `DashboardColumnMiddle.qml` `DashboardColumnRight.qml` `DashboardPanel.qml` `DelayLoader.qml` `DeviceButton.qml` `DeviceItemV2.qml` `DeviceStatusContent.qml` `DeviceStatusContentCompact.qml` `DialogBox.qml` `DisplayCVDCSetting.qml` `DisplayCustomColor.qml` `DisplayCustomResolutionsPopup.qml` `DisplayPortButton.qml` `DotsAnimation.qml` `DoubleColumnPage.qml` `DriverUpdateContent.qml` `DropDown.qml` `DvrButton.qml` `DvrConfigPopup.qml` `DvrRsProDialog.qml` `DvrTrackingEulaDialog.qml` `EULApopup.qml` `EasyrenderUpdate.qml` `ExpanderButton.qml` `FanCurveOD8.qml` `FanFineTuning.qml` `FlexibleColumnFlow.qml` `FrameTimeGraph.qml` `FramegenWizard.qml` `FullTabBar.qml` `GalleryDeleteDialog.qml` `GalleryGameListItem.qml` `GalleryGameSearchBar.qml`
