import 'package:flutter/widgets.dart';

/// 支持的语言。
enum AppLanguage {
  zhHans('zh-hans', '简体中文'),
  zhHant('zh-hant', '繁體中文');

  const AppLanguage(this.code, this.nativeName);

  final String code;

  /// 用各自语言显示的名字（语言选择器里用）
  final String nativeName;

  static AppLanguage fromCode(String? code) {
    if (code == 'zh-hant') return AppLanguage.zhHant;
    return AppLanguage.zhHans;
  }
}

/// 界面文案。
///
/// 目前覆盖：底部导航、设置页、通用按钮。其余页面在后续补全时逐步迁移过来。
class AppStrings {
  const AppStrings({
    required this.language,
    required this.tabHome,
    required this.tabSessions,
    required this.tabTools,
    required this.tabFiles,
    required this.settingsTitle,
    required this.sectionAppearance,
    required this.modeTitle,
    required this.modeSystem,
    required this.modeLight,
    required this.modeDark,
    required this.followWallpaper,
    required this.followWallpaperDesc,
    required this.accentColor,
    required this.accentDynamicHint,
    required this.accentManualHint,
    required this.sectionTerminal,
    required this.terminalFontSize,
    required this.decrease,
    required this.increase,
    required this.sectionDesignLanguage,
    required this.designLanguageDesc,
    required this.sectionLanguage,
    required this.sectionData,
    required this.importConfig,
    required this.importConfigDesc,
    required this.webdavBackup,
    required this.webdavBackupDesc,
    required this.sectionPermissions,
    required this.permissionUsage,
    required this.permissionPhone,
    required this.permissionLocation,
    required this.permissionWifi,
    required this.permissionGranted,
    required this.permissionDenied,
    required this.permissionGoGrant,
    required this.clearData,
    required this.clearDataDesc,
    required this.clearDataDone,
    required this.about,
    required this.aboutDesc,
    required this.frameStage,
    required this.commonCancel,
    required this.commonSave,
    required this.commonDelete,
    required this.commonAdd,
    required this.commonConfirm,
    required this.commonRefresh,
    required this.commonRetry,
    required this.commonTodo,
    required this.commonEdit,
    required this.checkUpdate,
    required this.checkUpdateDesc,
    required this.checkingUpdate,
    required this.autoCheckUpdate,
    required this.autoCheckUpdateDesc,
    required this.updateAvailableTemplate,
    required this.updateLatest,
    required this.updateFailedTemplate,
    required this.updateNoRepo,
    required this.commonName,
    required this.commonHost,
    required this.commonProxy,
    required this.commonPort,
    required this.commonUser,
    required this.commonPassword,
    required this.commonGroup,
    required this.commonCommand,
    required this.commonSelect,
    required this.commonClear,
    required this.sessionsTitle,
    required this.sessionsNew,
    required this.sessionsImport,
    required this.sessionsEmpty,
    required this.sessionsImporting,
    required this.sessionsImportBtn,
    required this.sessionsSearchHint,
    required this.sessionsDefaultGroup,
    required this.sessionsNoMatchTemplate,
    required this.sessionsCountTemplate,
    required this.sessionsMatchTemplate,
    required this.sessionsTotalTemplate,
    required this.sessionsImportedTemplate,
    required this.sessionsAddedTemplate,
    required this.sessionsSavedTemplate,
    required this.sessionsDeletedTemplate,
    required this.sessionsDeleteTitle,
    required this.sessionsDeleteConfirmTemplate,
    required this.sessionsNoConfigInZip,
    required this.sessionsBadConfig,
    required this.sessionsImportFailedTemplate,
    required this.sessionsProtocolTodoTemplate,
    required this.sessionsKeyTodo,
    required this.sessionsEdit,
    required this.sessionsNameHint,
    required this.sessionsHostHint,
    required this.sessionsGroupHint,
    required this.sessionsKeySection,
    required this.sessionsUsingPwd,
    required this.sessionsNoKeyFile,
    required this.sessionsPassphrase,
    required this.sessionsPassphraseHint,
    required this.sessionsProxySection,
    required this.sessionsProxyDirect,
    required this.sessionsProxyHostHint,
    required this.sessionsProxyUserHint,
    required this.sessionsProxyPwdHint,
    required this.sessionsHostRequired,
    required this.sessionsPickKeyFailedTemplate,
    required this.memoTitle,
    required this.memoAdd,
    required this.memoEmpty,
    required this.memoEmptyDesc,
    required this.memoAddItem,
    required this.memoEditItem,
    required this.memoCopied,
    required this.memoUnnamed,
    required this.memoCopy,
    required this.memoNoGroup,
    required this.memoDefaultGroup,
    required this.memoCountTemplate,
    required this.memoCmdRequired,
    required this.commonQuery,
    required this.filesTitle,
    required this.lanTitle,
    required this.trafficTitle,
    required this.browserEmptyDir,
    required this.settingsAppDir,
    required this.commonHostRequired,
    required this.backupReadFailedTemplate,
    required this.speedCustomNodeRequired,
    required this.termReconnectFailed,
    required this.deviceIphone,
    required this.deviceWindowsRdp,
    required this.deviceWindows,
    required this.devicePrinter,
    required this.deviceNas,
    required this.deviceCamera,
    required this.deviceRouter,
    required this.deviceAndroid,
    required this.deviceLinux,
    required this.deviceWeb,
    required this.deviceUnknown,
    required this.deviceAirplay,
    required this.deviceApple,
    required this.deviceCast,
    required this.deviceMijia,
    required this.deviceHomekit,
    required this.deviceSpeaker,
    required this.deviceWorkstation,
    required this.deviceBonjour,
    required this.termReconnectCountdownTemplate,
    required this.termDisconnected,
    required this.termAuthFailed,
    required this.termNetworkLost,
    required this.termConnRefused,
    required this.termNetworkUnreachable,
    required this.termConnectFailedTemplate,
    required this.termNoMemos,
    required this.termMemoSheetTitle,
    required this.termSentTemplate,
    required this.termConnecting,
    required this.termConnectedTemplate,
    required this.termDisconnectedState,
    required this.termConnectingToTemplate,
    required this.commonBack,
    required this.whoisTargetRequired,
    required this.whoisTimeout,
    required this.whoisServerRefused,
    required this.whoisFailedTemplate,
    required this.whoisCopyResult,
    required this.commonCopied,
    required this.whoisTarget,
    required this.whoisTargetHint,
    required this.whoisSourceTemplate,
    required this.sessionsNoMatchShortTemplate,
    required this.commonStop,
    required this.speedCloudflare,
    required this.speedPreparing,
    required this.speedFailedTemplate,
    required this.speedStopped,
    required this.speedTitle,
    required this.speedNode,
    required this.speedDownload,
    required this.speedUpload,
    required this.speedUploadHint,
    required this.speedLatency,
    required this.speedPhaseLatency,
    required this.speedPhaseDownload,
    required this.speedPhaseUpload,
    required this.speedTesting,
    required this.backupAddrRequired,
    required this.backupDoneTemplate,
    required this.backupFailedTemplate,
    required this.backupRestoreTitle,
    required this.backupRestoreConfirmTemplate,
    required this.backupRestoreBtn,
    required this.backupNoConfig,
    required this.backupConfigReadFailed,
    required this.backupRestoredTemplate,
    required this.backupRestoreFailedTemplate,
    required this.backupTitle,
    required this.backupRefresh,
    required this.backupInProgress,
    required this.backupDoNow,
    required this.backupRemoteCountTemplate,
    required this.backupHint,
    required this.backupNoFiles,
    required this.iperfNoBinary,
    required this.iperfServerRequired,
    required this.iperfServer,
    required this.iperfProtocol,
    required this.iperfDirection,
    required this.iperfUp,
    required this.iperfDown,
    required this.iperfBoth,
    required this.iperfStreams,
    required this.iperfDuration,
    required this.iperfSeconds,
    required this.iperfBandwidth,
    required this.iperfPresets,
    required this.iperfTestingTemplate,
    required this.iperfBidirTemplate,
    required this.iperfRetransmits,
    required this.iperfJitter,
    required this.iperfLoss,
    required this.iperfLossTemplate,
    required this.portInvalidFormat,
    required this.scanErrorTemplate,
    required this.scanTitle,
    required this.portRange,
    required this.portCommon,
    required this.portCustom,
    required this.portAll,
    required this.portCommonHintTemplate,
    required this.portAllHint,
    required this.portEstimateTemplate,
    required this.portScannedTemplate,
    required this.portOpenCountTemplate,
    required this.portShowOpenOnly,
    required this.portShowAll,
    required this.portSecondsTemplate,
    required this.portMinutesTemplate,
    required this.pingIcmpFallback,
    required this.commonTimeout,
    required this.pingExecFailedTemplate,
    required this.pingMode,
    required this.pingSentReceived,
    required this.pingLoss,
    required this.pingMinAvgMax,
    required this.commonFailed,
    required this.ipInvalidFormat,
    required this.ipTitle,
    required this.ipAddress,
    required this.ipPrefix,
    required this.ipMask,
    required this.ipWildcard,
    required this.ipNetwork,
    required this.ipBroadcast,
    required this.ipRange,
    required this.ipHosts,
    required this.ipClass,
    required this.ipPrivate,
    required this.commonYes,
    required this.commonNo,
    required this.ipMillionTemplate,
    required this.settingsAppDirDesc,
    required this.settingsDownloads,
    required this.settingsDownloadsDesc,
    required this.settingsImportedTemplate,
    required this.settingsImportFailedTemplate,
    required this.settingsBgImageSet,
    required this.settingsBgImageFailedTemplate,
    required this.settingsBgImageCleared,
    required this.settingsExportCancelled,
    required this.settingsExported,
    required this.settingsExportFailedTemplate,
    required this.settingsAppearanceSub,
    required this.settingsTerminalLook,
    required this.settingsTerminalLookDesc,
    required this.settingsTextColor,
    required this.settingsBgColor,
    required this.settingsBgImageUnset,
    required this.settingsBgImageSetDesc,
    required this.settingsPickImage,
    required this.settingsDataSub,
    required this.settingsExportLocal,
    required this.settingsExportLocalDesc,
    required this.settingsDownloadLocation,
    required this.settingsPermissionsSub,
    required this.settingsMonitorTitle,
    required this.settingsSelectNodes,
    required this.settingsSelectAll,
    required this.settingsSelectNone,
    required this.settingsMonitoring,
    required this.settingsStopMonitor,
    required this.settingsStartMonitor,
    required this.settingsNoNodes,
    required this.settingsNodesHint,
    required this.settingsReadList,
    required this.settingsNodesCountTemplate,
    required this.settingsAddNode,
    required this.settingsEditNode,
    required this.settingsNodeNameRequired,
    required this.browserBack,
    required this.browserRetry,
    required this.browserNewFolder,
    required this.browserFolderName,
    required this.browserCreate,
    required this.browserCancel,
    required this.browserDelete,
    required this.browserDeleteConfirmTemplate,
    required this.browserDeletedTemplate,
    required this.browserDeleteFailedTemplate,
    required this.browserRenameFailedTemplate,
    required this.browserRenamedTemplate,
    required this.browserOpenFailedTemplate,
    required this.browserDownloadFailedTemplate,
    required this.browserUploadFailedTemplate,
    required this.browserUploadCancelled,
    required this.browserDownloadCancelled,
    required this.browserDownloadedTemplate,
    required this.browserUploadedTemplate,
    required this.browserCreateFailedTemplate,
    required this.browserConnectFailedTemplate,
    required this.browserReadDirFailedTemplate,
    required this.browserUnsupportedProtoTemplate,
    required this.browserUpload,
    required this.browserDownloadLabel,
    required this.browserExitHint,
    required this.browserFolder,
    required this.trafficTotal,
    required this.trafficDown,
    required this.trafficUp,
    required this.trafficRxTemplate,
    required this.trafficTxTemplate,
    required this.trafficAppUsage,
    required this.trafficNoAppData,
    required this.trafficNeedUsage,
    required this.trafficUsageDesc1,
    required this.trafficUsageDesc2,
    required this.trafficGoGrant,
    required this.trafficReadFailedTemplate,
    required this.cellTitle,
    required this.cellNoSim,
    required this.cellCarrier,
    required this.cellSimCarrier,
    required this.cellNetwork,
    required this.cellServing,
    required this.cellDataNet,
    required this.cellCellId,
    required this.cellBand,
    required this.cellSignal,
    required this.cellSampling,
    required this.cellMinute,
    required this.cellNow,
    required this.cellNeighborsTemplate,
    required this.cellNoNeighbors,
    required this.cellLocation,
    required this.cellTypeTemplate,
    required this.cellNetLocate,
    required this.cellPassive,
    required this.cellViewLocation,
    required this.cellShowReal,
    required this.cellHideReal,
    required this.cellMasked,
    required this.cellNoLocation,
    required this.cellHide,
    required this.cellShow,
    required this.cellLatitude,
    required this.cellLongitude,
    required this.cellAccuracy,
    required this.cellAltitude,
    required this.cellSpeed,
    required this.cellSource,
    required this.cellUpdatedAt,
    required this.cellSlotTemplate,
    required this.cellNoCarrier,
    required this.cellNoSignalTemplate,
    required this.cellRat,
    required this.cellBandShort,
    required this.lanRescan,
    required this.lanScanningSubnet,
    required this.lanSelfTemplate,
    required this.lanProgressTemplate,
    required this.lanEmpty,
    required this.lanEmptyDesc,
    required this.lanCountTemplate,
    required this.lanCooldownTemplate,
    required this.lanCooldownDesc,
    required this.lanScanNow,
    required this.lanScanErrorTemplate,
    required this.lanUnknownDevice,
    required this.nodeCopiedTemplate,
    required this.nodeReverseDns,
    required this.nodePtrEmpty,
    required this.nodeTools,
    required this.nodePingDesc,
    required this.nodePortScanDesc,
    required this.nodeWhoisDesc,
    required this.nodeUpnpDesc,
    required this.commonCopy,
    required this.filesRefresh,
    required this.filesAddServerTemplate,
    required this.filesEmptyHint,
    required this.filesNoConnections,
    required this.filesConnCountTemplate,
    required this.filesWebdav,
    required this.filesFtp,
    required this.filesSmb,
    required this.filesServerLabel,
    required this.filesAddrRequired,
    required this.filesWebdavUrlInvalid,
    required this.filesSmbShareRequired,
    required this.filesEditServerTemplate,
    required this.filesAddServerTitleTemplate,
    required this.filesServerNameHint,
    required this.filesServerAddr,
    required this.filesServerShare,
    required this.filesServerShareHint,
    required this.filesDeleteServerTitle,
    required this.filesDeleteServerConfirmTemplate,
    required this.filesOpen,
    required this.filesDownload,
    required this.filesRename,
    required this.filesProperties,
    required this.filesType,
    required this.filesFolder,
    required this.filesFile,
    required this.filesSize,
    required this.filesModified,
    required this.filesPath,
    required this.filesExtra,
    required this.filesClose,
    required this.filesNewName,
    required this.commonConfirmBtn,
    required this.commonQuerying,
    required this.commonScanning,
    required this.commonStartScan,
    required this.commonStartDetect,
    required this.commonDetecting,
    required this.commonStartTest,
    required this.commonTesting,
    required this.commonStartSpeed,
    required this.commonStartTraceroute,
    required this.commonTracing,
    required this.commonSendMagic,
    required this.commonSending,
    required this.commonHostLabel,
    required this.commonStartPing,
    required this.groupDiagnostics,
    required this.groupPerformance,
    required this.groupLan,
    required this.groupCompute,
    required this.toolsTitle,
    required this.toolPingSub,
    required this.toolMultiPing,
    required this.toolMultiPingSub,
    required this.toolMonitor,
    required this.toolMonitorSub,
    required this.toolGeoPingSub,
    required this.toolTracerouteSub,
    required this.toolPortScan,
    required this.toolPortScanSub,
    required this.toolWhoisSub,
    required this.toolDnsSub,
    required this.toolIperfSub,
    required this.toolSpeed,
    required this.toolSpeedSub,
    required this.toolSubnet,
    required this.toolSubnetSub,
    required this.toolUpnp,
    required this.toolUpnpSub,
    required this.toolWol,
    required this.toolWolSub,
    required this.toolIpCalc,
    required this.toolIpCalcSub,
    required this.toolTodoTemplate,
    required this.terminalCopy,
    required this.terminalPaste,
    required this.terminalSelectFirst,
    required this.terminalSelectionEmpty,
    required this.terminalClipboardEmpty,
    required this.terminalCopiedTemplate,    required this.homeNetworkType,
    required this.homePublicIpv4,
    required this.homePublicIpv6,
    required this.homeGatewayIpv4,
    required this.homeGatewayIpv6,
    required this.homeLocalIp,
    required this.homeLocal,
    required this.homeUpstream,
    required this.homePublic,
    required this.homeDefaultGateway,
    required this.homeDirectExit,
    required this.homeProxyExit,
    required this.homeRegion,
    required this.homeNetworkStatus,
    required this.homeTopology,
    required this.homeCell,
    required this.homeWifi,
    required this.homeTraffic,
    required this.homeNotConnectedWifi,
    required this.homeSsidPermission,
    required this.homeWaitPermission,
    required this.homeExplanation,
    required this.homeExplanationDesc,
    required this.homeDomesticLine,
    required this.commonUnknown,
    required this.commonNotObtained,
    required this.commonNone,
    required this.commonNotProbed,
    required this.homeUpdatedTemplate,
    required this.homeSamplingTemplate,
    required this.homeCopiedTemplate,
  });

  final AppLanguage language;

  // 导航
  final String tabHome;
  final String tabSessions;
  final String tabTools;
  final String tabFiles;

  // 设置
  final String settingsTitle;
  final String sectionAppearance;
  final String modeTitle;
  final String modeSystem;
  final String modeLight;
  final String modeDark;
  final String followWallpaper;
  final String followWallpaperDesc;
  final String accentColor;
  final String accentDynamicHint;
  final String accentManualHint;
  final String sectionTerminal;
  final String terminalFontSize;
  final String decrease;
  final String increase;
  final String sectionDesignLanguage;
  final String designLanguageDesc;
  final String sectionLanguage;
  final String sectionData;
  final String importConfig;
  final String importConfigDesc;
  final String webdavBackup;
  final String webdavBackupDesc;
  final String sectionPermissions;
  final String permissionUsage;
  final String permissionPhone;
  final String permissionLocation;
  final String permissionWifi;
  final String permissionGranted;
  final String permissionDenied;
  final String permissionGoGrant;
  final String clearData;
  final String clearDataDesc;
  final String clearDataDone;
  final String about;
  final String aboutDesc;
  final String frameStage;

  final String commonEdit;
  final String checkUpdate;
  final String checkUpdateDesc;
  final String checkingUpdate;
  final String autoCheckUpdate;
  final String autoCheckUpdateDesc;
  final String updateAvailableTemplate;
  final String updateLatest;
  final String updateFailedTemplate;
  final String updateNoRepo;
  final String commonName;
  final String commonHost;
  final String commonProxy;
  final String commonPort;
  final String commonUser;
  final String commonPassword;
  final String commonGroup;
  final String commonCommand;
  final String commonSelect;
  final String commonClear;
  final String sessionsTitle;
  final String sessionsNew;
  final String sessionsImport;
  final String sessionsEmpty;
  final String sessionsImporting;
  final String sessionsImportBtn;
  final String sessionsSearchHint;
  final String sessionsDefaultGroup;
  final String sessionsNoMatchTemplate;
  final String sessionsCountTemplate;
  final String sessionsMatchTemplate;
  final String sessionsTotalTemplate;
  final String sessionsImportedTemplate;
  final String sessionsAddedTemplate;
  final String sessionsSavedTemplate;
  final String sessionsDeletedTemplate;
  final String sessionsDeleteTitle;
  final String sessionsDeleteConfirmTemplate;
  final String sessionsNoConfigInZip;
  final String sessionsBadConfig;
  final String sessionsImportFailedTemplate;
  final String sessionsProtocolTodoTemplate;
  final String sessionsKeyTodo;
  final String sessionsEdit;
  final String sessionsNameHint;
  final String sessionsHostHint;
  final String sessionsGroupHint;
  final String sessionsKeySection;
  final String sessionsUsingPwd;
  final String sessionsNoKeyFile;
  final String sessionsPassphrase;
  final String sessionsPassphraseHint;
  final String sessionsProxySection;
  final String sessionsProxyDirect;
  final String sessionsProxyHostHint;
  final String sessionsProxyUserHint;
  final String sessionsProxyPwdHint;
  final String sessionsHostRequired;
  final String sessionsPickKeyFailedTemplate;
  final String memoTitle;
  final String memoAdd;
  final String memoEmpty;
  final String memoEmptyDesc;
  final String memoAddItem;
  final String memoEditItem;
  final String memoCopied;
  final String memoUnnamed;
  final String memoCopy;
  final String memoNoGroup;
  final String memoDefaultGroup;
  final String memoCountTemplate;
  final String memoCmdRequired;
  final String commonQuery;
  final String filesTitle;
  final String lanTitle;
  final String trafficTitle;
  final String browserEmptyDir;
  final String settingsAppDir;
  final String commonHostRequired;
  final String backupReadFailedTemplate;
  final String speedCustomNodeRequired;
  final String termReconnectFailed;
  final String deviceIphone;
  final String deviceWindowsRdp;
  final String deviceWindows;
  final String devicePrinter;
  final String deviceNas;
  final String deviceCamera;
  final String deviceRouter;
  final String deviceAndroid;
  final String deviceLinux;
  final String deviceWeb;
  final String deviceUnknown;
  final String deviceAirplay;
  final String deviceApple;
  final String deviceCast;
  final String deviceMijia;
  final String deviceHomekit;
  final String deviceSpeaker;
  final String deviceWorkstation;
  final String deviceBonjour;
  final String termReconnectCountdownTemplate;
  final String termDisconnected;
  final String termAuthFailed;
  final String termNetworkLost;
  final String termConnRefused;
  final String termNetworkUnreachable;
  final String termConnectFailedTemplate;
  final String termNoMemos;
  final String termMemoSheetTitle;
  final String termSentTemplate;
  final String termConnecting;
  final String termConnectedTemplate;
  final String termDisconnectedState;
  final String termConnectingToTemplate;
  final String commonBack;
  final String whoisTargetRequired;
  final String whoisTimeout;
  final String whoisServerRefused;
  final String whoisFailedTemplate;
  final String whoisCopyResult;
  final String commonCopied;
  final String whoisTarget;
  final String whoisTargetHint;
  final String whoisSourceTemplate;
  final String sessionsNoMatchShortTemplate;
  final String commonStop;
  final String speedCloudflare;
  final String speedPreparing;
  final String speedFailedTemplate;
  final String speedStopped;
  final String speedTitle;
  final String speedNode;
  final String speedDownload;
  final String speedUpload;
  final String speedUploadHint;
  final String speedLatency;
  final String speedPhaseLatency;
  final String speedPhaseDownload;
  final String speedPhaseUpload;
  final String speedTesting;
  final String backupAddrRequired;
  final String backupDoneTemplate;
  final String backupFailedTemplate;
  final String backupRestoreTitle;
  final String backupRestoreConfirmTemplate;
  final String backupRestoreBtn;
  final String backupNoConfig;
  final String backupConfigReadFailed;
  final String backupRestoredTemplate;
  final String backupRestoreFailedTemplate;
  final String backupTitle;
  final String backupRefresh;
  final String backupInProgress;
  final String backupDoNow;
  final String backupRemoteCountTemplate;
  final String backupHint;
  final String backupNoFiles;
  final String iperfNoBinary;
  final String iperfServerRequired;
  final String iperfServer;
  final String iperfProtocol;
  final String iperfDirection;
  final String iperfUp;
  final String iperfDown;
  final String iperfBoth;
  final String iperfStreams;
  final String iperfDuration;
  final String iperfSeconds;
  final String iperfBandwidth;
  final String iperfPresets;
  final String iperfTestingTemplate;
  final String iperfBidirTemplate;
  final String iperfRetransmits;
  final String iperfJitter;
  final String iperfLoss;
  final String iperfLossTemplate;
  final String portInvalidFormat;
  final String scanErrorTemplate;
  final String scanTitle;
  final String portRange;
  final String portCommon;
  final String portCustom;
  final String portAll;
  final String portCommonHintTemplate;
  final String portAllHint;
  final String portEstimateTemplate;
  final String portScannedTemplate;
  final String portOpenCountTemplate;
  final String portShowOpenOnly;
  final String portShowAll;
  final String portSecondsTemplate;
  final String portMinutesTemplate;
  final String pingIcmpFallback;
  final String commonTimeout;
  final String pingExecFailedTemplate;
  final String pingMode;
  final String pingSentReceived;
  final String pingLoss;
  final String pingMinAvgMax;
  final String commonFailed;
  final String ipInvalidFormat;
  final String ipTitle;
  final String ipAddress;
  final String ipPrefix;
  final String ipMask;
  final String ipWildcard;
  final String ipNetwork;
  final String ipBroadcast;
  final String ipRange;
  final String ipHosts;
  final String ipClass;
  final String ipPrivate;
  final String commonYes;
  final String commonNo;
  final String ipMillionTemplate;
  final String settingsAppDirDesc;
  final String settingsDownloads;
  final String settingsDownloadsDesc;
  final String settingsImportedTemplate;
  final String settingsImportFailedTemplate;
  final String settingsBgImageSet;
  final String settingsBgImageFailedTemplate;
  final String settingsBgImageCleared;
  final String settingsExportCancelled;
  final String settingsExported;
  final String settingsExportFailedTemplate;
  final String settingsAppearanceSub;
  final String settingsTerminalLook;
  final String settingsTerminalLookDesc;
  final String settingsTextColor;
  final String settingsBgColor;
  final String settingsBgImageUnset;
  final String settingsBgImageSetDesc;
  final String settingsPickImage;
  final String settingsDataSub;
  final String settingsExportLocal;
  final String settingsExportLocalDesc;
  final String settingsDownloadLocation;
  final String settingsPermissionsSub;
  final String settingsMonitorTitle;
  final String settingsSelectNodes;
  final String settingsSelectAll;
  final String settingsSelectNone;
  final String settingsMonitoring;
  final String settingsStopMonitor;
  final String settingsStartMonitor;
  final String settingsNoNodes;
  final String settingsNodesHint;
  final String settingsReadList;
  final String settingsNodesCountTemplate;
  final String settingsAddNode;
  final String settingsEditNode;
  final String settingsNodeNameRequired;
  final String browserBack;
  final String browserRetry;
  final String browserNewFolder;
  final String browserFolderName;
  final String browserCreate;
  final String browserCancel;
  final String browserDelete;
  final String browserDeleteConfirmTemplate;
  final String browserDeletedTemplate;
  final String browserDeleteFailedTemplate;
  final String browserRenameFailedTemplate;
  final String browserRenamedTemplate;
  final String browserOpenFailedTemplate;
  final String browserDownloadFailedTemplate;
  final String browserUploadFailedTemplate;
  final String browserUploadCancelled;
  final String browserDownloadCancelled;
  final String browserDownloadedTemplate;
  final String browserUploadedTemplate;
  final String browserCreateFailedTemplate;
  final String browserConnectFailedTemplate;
  final String browserReadDirFailedTemplate;
  final String browserUnsupportedProtoTemplate;
  final String browserUpload;
  final String browserDownloadLabel;
  final String browserExitHint;
  final String browserFolder;
  final String trafficTotal;
  final String trafficDown;
  final String trafficUp;
  final String trafficRxTemplate;
  final String trafficTxTemplate;
  final String trafficAppUsage;
  final String trafficNoAppData;
  final String trafficNeedUsage;
  final String trafficUsageDesc1;
  final String trafficUsageDesc2;
  final String trafficGoGrant;
  final String trafficReadFailedTemplate;
  final String cellTitle;
  final String cellNoSim;
  final String cellCarrier;
  final String cellSimCarrier;
  final String cellNetwork;
  final String cellServing;
  final String cellDataNet;
  final String cellCellId;
  final String cellBand;
  final String cellSignal;
  final String cellSampling;
  final String cellMinute;
  final String cellNow;
  final String cellNeighborsTemplate;
  final String cellNoNeighbors;
  final String cellLocation;
  final String cellTypeTemplate;
  final String cellNetLocate;
  final String cellPassive;
  final String cellViewLocation;
  final String cellShowReal;
  final String cellHideReal;
  final String cellMasked;
  final String cellNoLocation;
  final String cellHide;
  final String cellShow;
  final String cellLatitude;
  final String cellLongitude;
  final String cellAccuracy;
  final String cellAltitude;
  final String cellSpeed;
  final String cellSource;
  final String cellUpdatedAt;
  final String cellSlotTemplate;
  final String cellNoCarrier;
  final String cellNoSignalTemplate;
  final String cellRat;
  final String cellBandShort;
  final String lanRescan;
  final String lanScanningSubnet;
  final String lanSelfTemplate;
  final String lanProgressTemplate;
  final String lanEmpty;
  final String lanEmptyDesc;
  final String lanCountTemplate;
  final String lanCooldownTemplate;
  final String lanCooldownDesc;
  final String lanScanNow;
  final String lanScanErrorTemplate;
  final String lanUnknownDevice;
  final String nodeCopiedTemplate;
  final String nodeReverseDns;
  final String nodePtrEmpty;
  final String nodeTools;
  final String nodePingDesc;
  final String nodePortScanDesc;
  final String nodeWhoisDesc;
  final String nodeUpnpDesc;
  final String commonCopy;
  final String filesRefresh;
  final String filesAddServerTemplate;
  final String filesEmptyHint;
  final String filesNoConnections;
  final String filesConnCountTemplate;
  final String filesWebdav;
  final String filesFtp;
  final String filesSmb;
  final String filesServerLabel;
  final String filesAddrRequired;
  final String filesWebdavUrlInvalid;
  final String filesSmbShareRequired;
  final String filesEditServerTemplate;
  final String filesAddServerTitleTemplate;
  final String filesServerNameHint;
  final String filesServerAddr;
  final String filesServerShare;
  final String filesServerShareHint;
  final String filesDeleteServerTitle;
  final String filesDeleteServerConfirmTemplate;
  final String filesOpen;
  final String filesDownload;
  final String filesRename;
  final String filesProperties;
  final String filesType;
  final String filesFolder;
  final String filesFile;
  final String filesSize;
  final String filesModified;
  final String filesPath;
  final String filesExtra;
  final String filesClose;
  final String filesNewName;
  final String commonConfirmBtn;
  final String commonQuerying;
  final String commonScanning;
  final String commonStartScan;
  final String commonStartDetect;
  final String commonDetecting;
  final String commonStartTest;
  final String commonTesting;
  final String commonStartSpeed;
  final String commonStartTraceroute;
  final String commonTracing;
  final String commonSendMagic;
  final String commonSending;
  final String commonHostLabel;
  final String commonStartPing;
  final String groupDiagnostics;
  final String groupPerformance;
  final String groupLan;
  final String groupCompute;
  final String toolsTitle;
  final String toolPingSub;
  final String toolMultiPing;
  final String toolMultiPingSub;
  final String toolMonitor;
  final String toolMonitorSub;
  final String toolGeoPingSub;
  final String toolTracerouteSub;
  final String toolPortScan;
  final String toolPortScanSub;
  final String toolWhoisSub;
  final String toolDnsSub;
  final String toolIperfSub;
  final String toolSpeed;
  final String toolSpeedSub;
  final String toolSubnet;
  final String toolSubnetSub;
  final String toolUpnp;
  final String toolUpnpSub;
  final String toolWol;
  final String toolWolSub;
  final String toolIpCalc;
  final String toolIpCalcSub;
  final String toolTodoTemplate;
  final String terminalCopy;
  final String terminalPaste;
  final String terminalSelectFirst;
  final String terminalSelectionEmpty;
  final String terminalClipboardEmpty;
  final String terminalCopiedTemplate;
  // 主页
  final String homeNetworkType;
  final String homePublicIpv4;
  final String homePublicIpv6;
  final String homeGatewayIpv4;
  final String homeGatewayIpv6;
  final String homeLocalIp;
  final String homeLocal;
  final String homeUpstream;
  final String homePublic;
  final String homeDefaultGateway;
  final String homeDirectExit;
  final String homeProxyExit;
  final String homeRegion;
  final String homeNetworkStatus;
  final String homeTopology;
  final String homeCell;
  final String homeWifi;
  final String homeTraffic;
  final String homeNotConnectedWifi;
  final String homeSsidPermission;
  final String homeWaitPermission;
  final String homeExplanation;
  final String homeExplanationDesc;
  final String homeDomesticLine;
  final String homeUpdatedTemplate;
  final String homeSamplingTemplate;
  final String homeCopiedTemplate;

  // 通用
  final String commonUnknown;
  final String commonNotObtained;
  final String commonNone;
  final String commonNotProbed;
  final String commonCancel;
  final String commonSave;
  final String commonDelete;
  final String commonAdd;
  final String commonConfirm;
  final String commonRefresh;
  final String commonRetry;
  final String commonTodo;

  static const AppStrings zhHans = AppStrings(
    language: AppLanguage.zhHans,
    tabHome: '主页',
    tabSessions: '会话',
    tabTools: '工具',
    tabFiles: '文件',
    settingsTitle: '设置',
    sectionAppearance: '外观',
    modeTitle: '昼夜模式',
    modeSystem: '系统',
    modeLight: '浅色',
    modeDark: '深色',
    followWallpaper: '跟随壁纸取色',
    followWallpaperDesc: 'Material You：强调色跟随系统壁纸，关掉后用下方手选色',
    accentColor: '强调色',
    accentDynamicHint: '当前：跟随壁纸（手选色作为未取到壁纸色时的兜底）',
    accentManualHint: '当前：手选强调色',
    sectionTerminal: '终端',
    terminalFontSize: '终端字号',
    decrease: '缩小',
    increase: '放大',
    sectionDesignLanguage: '设计语言',
    designLanguageDesc: '当前只实现了 MD3；出 MD4 时在这里新增一项，页面代码不用改。',
    sectionLanguage: '语言',
    sectionData: '数据',
    importConfig: '导入桌面版配置',
    importConfigDesc: '支持 config.json 与备份 zip',
    webdavBackup: 'WebDAV 备份',
    webdavBackupDesc: '把配置与服务器列表备份到 WebDAV，或从中恢复',
    sectionPermissions: '权限',
    permissionUsage: '使用情况访问',
    permissionPhone: '电话状态',
    permissionLocation: '位置信息',
    permissionWifi: '附近设备',
    permissionGranted: '已授权',
    permissionDenied: '未授权',
    permissionGoGrant: '前往授权',
    clearData: '清除本地数据',
    clearDataDesc: '清空导入的配置、服务器列表和界面设置',
    clearDataDone: '已清除',
    about: '关于',
    aboutDesc: '多功能网络工具箱 + SSH 终端',
    frameStage: 'QShell Android',
    commonCancel: '取消',
    commonSave: '保存',
    commonDelete: '删除',
    commonAdd: '添加',
    commonConfirm: '确定',
    commonRefresh: '刷新',
    commonRetry: '重试',
    checkUpdate: '检查更新',
    checkUpdateDesc: '从 GitHub Releases 获取最新版本',
    checkingUpdate: '正在检查…',
    autoCheckUpdate: '自动检查更新',
    autoCheckUpdateDesc: '启动应用时自动检测一次新版本',
    updateAvailableTemplate: '发现新版本 {v}',
    updateLatest: '已是最新版本',
    updateFailedTemplate: '检查失败：{msg}',
    updateNoRepo: '尚未配置更新源',
    commonEdit: '编辑',
    commonName: '名称',
    commonHost: '主机',
    commonProxy: '跳板',
    commonPort: '端口',
    commonUser: '用户',
    commonPassword: '密码',
    commonGroup: '分组',
    commonCommand: '命令',
    commonSelect: '选择',
    commonClear: '清除',
    sessionsTitle: '会话',
    sessionsNew: '新建连接',
    sessionsImport: '导入桌面版配置',
    sessionsEmpty: '暂无连接',
    sessionsImporting: '导入中…',
    sessionsImportBtn: '导入配置',
    sessionsSearchHint: '搜索名称 / 主机 / 用户',
    sessionsDefaultGroup: '我的连接',
    sessionsNoMatchTemplate: '没有匹配「{q}」的连接',
    sessionsCountTemplate: '{n} 条连接',
    sessionsMatchTemplate: '匹配 {a} / {b} 条',
    sessionsTotalTemplate: '共 {n} 条连接',
    sessionsImportedTemplate: '已导入 {n} 条连接',
    sessionsAddedTemplate: '已添加 {name}',
    sessionsSavedTemplate: '已保存 {name}',
    sessionsDeletedTemplate: '已删除 {name}',
    sessionsDeleteTitle: '删除连接',
    sessionsDeleteConfirmTemplate: '确定删除「{name}」（{sub}）？',
    sessionsNoConfigInZip: '备份包里没有找到 qshell_config.json',
    sessionsBadConfig: '配置文件格式不对（需要桌面版导出的 config.json 或备份 zip）',
    sessionsImportFailedTemplate: '导入失败：{msg}',
    sessionsProtocolTodoTemplate: '{proto} 协议暂未接入，先支持 SSH',
    sessionsKeyTodo: '该连接使用私钥登录，私钥登录暂未支持',
    sessionsEdit: '编辑连接',
    sessionsNameHint: '留空就用主机名',
    sessionsHostHint: 'IP 或域名',
    sessionsGroupHint: '填新名字就是新分组',
    sessionsKeySection: '私钥登录（可选）',
    sessionsUsingPwd: '当前使用密码登录',
    sessionsNoKeyFile: '未选择私钥文件',
    sessionsPassphrase: '短语',
    sessionsPassphraseHint: '加密私钥才需要',
    sessionsProxySection: '跳板机（可选）',
    sessionsProxyDirect: '未配置，直连',
    sessionsProxyHostHint: 'IP 或域名，留空直连',
    sessionsProxyUserHint: '留空同目标用户',
    sessionsProxyPwdHint: '留空同目标密码',
    sessionsHostRequired: '主机不能为空',
    sessionsPickKeyFailedTemplate: '选择私钥失败：{msg}',
    memoTitle: '备忘录',
    memoAdd: '新增',
    memoEmpty: '暂无备忘录',
    memoEmptyDesc: '用于保存常用命令，点击即可复制',
    memoAddItem: '新增备忘录',
    memoEditItem: '编辑备忘录',
    memoCopied: '已复制命令',
    memoUnnamed: '未命名',
    memoCopy: '复制命令',
    memoNoGroup: '未分组',
    memoDefaultGroup: '常用',
    memoCountTemplate: '{g} 个分组 · {n} 条',
    memoCmdRequired: '命令不能为空',
    deviceIphone: 'iPhone / iPad',
    deviceWindowsRdp: 'Windows（远程桌面）',
    deviceWindows: 'Windows',
    devicePrinter: '打印机',
    deviceNas: 'NAS',
    deviceCamera: '摄像头',
    deviceRouter: '路由器',
    deviceAndroid: 'Android',
    deviceLinux: 'Linux 主机',
    deviceWeb: 'Web 设备',
    deviceUnknown: '未知设备',
    deviceAirplay: 'Apple 设备（AirPlay）',
    deviceApple: 'Apple 设备',
    deviceCast: 'Chromecast / 安卓 TV',
    deviceMijia: '小米智能设备',
    deviceHomekit: 'HomeKit 设备',
    deviceSpeaker: '智能音箱',
    deviceWorkstation: '工作站',
    deviceBonjour: '支持 Bonjour 的设备',
    termReconnectFailed: '[重连失败，请返回后重新连接]',
    termReconnectCountdownTemplate: '[{d} 秒后自动重连（第 {n} 次）]',
    termDisconnected: '[连接已断开]',
    termAuthFailed: '认证失败：用户名或密码不对',
    termNetworkLost: '网络中断（可能切到后台被系统断网）',
    termConnRefused: '目标拒绝连接（端口不对或服务未开）',
    termNetworkUnreachable: '网络不可达',
    termConnectFailedTemplate: '连接失败：{msg}',
    termNoMemos: '暂无备忘录，可在会话页添加',
    termMemoSheetTitle: '备忘录 · 点击发送到终端',
    termSentTemplate: '已发送：{cmd}',
    termConnecting: '连接中…',
    termConnectedTemplate: '已连接 · {port}',
    termDisconnectedState: '已断开',
    termConnectingToTemplate: '正在连接 {host}:{port}',
    commonBack: '返回',
    whoisTargetRequired: '请输入域名或 IP 地址',
    whoisTimeout: '查询超时，请更换网络后重试',
    whoisServerRefused: '服务器拒绝连接',
    whoisFailedTemplate: '查询失败：{msg}',
    whoisCopyResult: '复制结果',
    commonCopied: '已复制',
    whoisTarget: '目标',
    whoisTargetHint: 'example.com 或 8.8.8.8',
    whoisSourceTemplate: '来源 {server}',
    sessionsNoMatchShortTemplate: '没有匹配「{q}」的连接',
    speedCustomNodeRequired: '自定义节点需要填下载 URL',
    commonStop: '停止',
    speedCloudflare: 'Cloudflare',
    speedPreparing: '准备中…',
    speedFailedTemplate: '测速失败：{msg}',
    speedStopped: '已停止',
    speedTitle: '网速测试',
    speedNode: '节点',
    speedDownload: '下载',
    speedUpload: '上传',
    speedUploadHint: '可选，留空则跳过',
    speedLatency: '延迟',
    speedPhaseLatency: '测延迟…',
    speedPhaseDownload: '下载测速…',
    speedPhaseUpload: '上传测速…',
    speedTesting: '测速中…',
    backupReadFailedTemplate: '读取备份列表失败：{msg}',
    backupAddrRequired: '请输入 WebDAV 地址',
    backupDoneTemplate: '已备份：{name}',
    backupFailedTemplate: '备份失败：{msg}',
    backupRestoreTitle: '从备份恢复',
    backupRestoreConfirmTemplate: '将用「{name}」覆盖当前的连接配置和服务器列表，确定？',
    backupRestoreBtn: '恢复',
    backupNoConfig: '备份里没有 qshell_config.json',
    backupConfigReadFailed: '配置文件读取失败',
    backupRestoredTemplate: '已恢复：{g} 个分组 · {s} 个服务器',
    backupRestoreFailedTemplate: '恢复失败：{msg}',
    backupTitle: 'WebDAV 备份',
    backupRefresh: '刷新备份列表',
    backupInProgress: '处理中…',
    backupDoNow: '立即备份到 WebDAV',
    backupRemoteCountTemplate: '远端备份（{n}）',
    backupHint: '请先填写上方位址，再执行备份或刷新',
    backupNoFiles: '暂无备份文件',
    iperfNoBinary: '没有找到内置的 iperf3（当前 ABI 没打包），需要重新构建 APK',
    iperfServerRequired: '请输入服务器地址',
    iperfServer: '服务器',
    iperfProtocol: '协议',
    iperfDirection: '方向',
    iperfUp: '上行',
    iperfDown: '下行',
    iperfBoth: '双向',
    iperfStreams: '流数',
    iperfDuration: '时长',
    iperfSeconds: '秒',
    iperfBandwidth: '带宽',
    iperfPresets: '快捷预设',
    iperfTestingTemplate: '测试中（{s}s）…',
    iperfBidirTemplate: '上行 {up} · 下行 {down} Mbps',
    iperfRetransmits: '重传次数',
    iperfJitter: '抖动',
    iperfLoss: '丢包',
    iperfLossTemplate: '{p}%（{n} 个）',
    portInvalidFormat: '端口格式不对，例如 80,443,8000-8100',
    scanErrorTemplate: '扫描出错：{msg}',
    scanTitle: '端口扫描',
    portRange: '范围',
    portCommon: '常用',
    portCustom: '自定义',
    portAll: '全部',
    portCommonHintTemplate: '常用端口 {n} 个：{list}',
    portAllHint: '全部端口 1~65535（耗时较长）',
    portEstimateTemplate: '共 {n} 个端口，预计 {t}',
    portScannedTemplate: '已扫描 {a} / {b}',
    portOpenCountTemplate: '开放端口 {n}',
    portShowOpenOnly: '只看开放',
    portShowAll: '显示全部',
    portSecondsTemplate: '{n} 秒',
    portMinutesTemplate: '{n} 分钟',
    commonHostRequired: '请输入主机地址',
    pingIcmpFallback: '当前设备不支持 ICMP，已自动切换至 TCP 探测',
    commonTimeout: '超时',
    pingExecFailedTemplate: '执行失败：{msg}',
    pingMode: '方式',
    pingSentReceived: '发送 / 接收',
    pingLoss: '丢包率',
    pingMinAvgMax: '最小 / 平均 / 最大',
    commonFailed: '失败',
    ipInvalidFormat: '格式不对，试试 192.168.1.0/24 或 "192.168.1.10 255.255.255.0"',
    ipTitle: 'IP 计算器',
    ipAddress: '地址',
    ipPrefix: '前缀',
    ipMask: '子网掩码',
    ipWildcard: '反掩码',
    ipNetwork: '网络地址',
    ipBroadcast: '广播地址',
    ipRange: '可用范围',
    ipHosts: '可用主机',
    ipClass: '地址类别',
    ipPrivate: '私有地址',
    commonYes: '是',
    commonNo: '否',
    ipMillionTemplate: '{n}（约 {m} 百万）',
    settingsAppDir: '应用私有目录',
    settingsAppDirDesc: '默认，只有 QShell 能访问',
    settingsDownloads: '系统下载目录',
    settingsDownloadsDesc: 'Download/QShell，其他 App 也能看到',
    settingsImportedTemplate: '已导入 {n} 条连接（{g} 个分组）',
    settingsImportFailedTemplate: '导入失败：{msg}',
    settingsBgImageSet: '已设置终端背景图片',
    settingsBgImageFailedTemplate: '设置背景失败：{msg}',
    settingsBgImageCleared: '已清除终端背景图片',
    settingsExportCancelled: '已取消导出',
    settingsExported: '已导出 qshell_backup.zip',
    settingsExportFailedTemplate: '导出失败：{msg}',
    settingsAppearanceSub: '昼夜模式 / 取色 / 强调色',
    settingsTerminalLook: '终端外观',
    settingsTerminalLookDesc: '字号 / 文字色 / 背景色 / 背景图',
    settingsTextColor: '文字颜色',
    settingsBgColor: '背景颜色',
    settingsBgImageUnset: '背景图片：未设置',
    settingsBgImageSetDesc: '背景图片：已设置（覆盖背景色）',
    settingsPickImage: '选择图片',
    settingsDataSub: '导入 / 导出 / 下载位置 / WebDAV 备份',
    settingsExportLocal: '导出到本地',
    settingsExportLocalDesc: '打包成 zip（含 qshell_config.json），可与桌面版互导',
    settingsDownloadLocation: '下载位置',
    settingsPermissionsSub: '使用时访问 / 电话 / 位置 / 附近设备',
    settingsMonitorTitle: '节点监视',
    settingsSelectNodes: '选择监视节点',
    settingsSelectAll: '全选',
    settingsSelectNone: '全不选',
    settingsMonitoring: '监视中',
    settingsStopMonitor: '停止监视',
    settingsStartMonitor: '开始监视',
    settingsNoNodes: '暂无监视节点',
    settingsNodesHint: '节点来自「会话」页的连接列表',
    settingsReadList: '读取 SSH 会话列表',
    settingsNodesCountTemplate: '{n} 个节点 · 在线 {on}',
    settingsAddNode: '添加节点',
    settingsEditNode: '编辑节点',
    settingsNodeNameRequired: '主机不能为空',
    browserEmptyDir: '空目录',
    browserBack: '返回上级',
    browserRetry: '重试',
    browserNewFolder: '新建文件夹',
    browserFolderName: '文件夹名',
    browserCreate: '创建',
    browserCancel: '取消',
    browserDelete: '删除',
    browserDeleteConfirmTemplate: '确定删除 {name}？',
    browserDeletedTemplate: '已删除 {name}',
    browserDeleteFailedTemplate: '删除失败：{msg}',
    browserRenameFailedTemplate: '重命名失败：{msg}',
    browserRenamedTemplate: '已重命名为 {name}',
    browserOpenFailedTemplate: '打开失败：{msg}',
    browserDownloadFailedTemplate: '下载失败：{msg}',
    browserUploadFailedTemplate: '上传失败：{msg}',
    browserUploadCancelled: '已取消上传',
    browserDownloadCancelled: '已取消下载 {name}',
    browserDownloadedTemplate: '已下载 {name}',
    browserUploadedTemplate: '已上传 {name}',
    browserCreateFailedTemplate: '创建失败：{msg}',
    browserConnectFailedTemplate: '连接失败：{msg}',
    browserReadDirFailedTemplate: '读取目录失败：{msg}',
    browserUnsupportedProtoTemplate: '不支持的协议：{kind}',
    browserUpload: '上传',
    browserDownloadLabel: '下载',
    browserExitHint: '再按一次以退出',
    browserFolder: '文件夹',
    trafficTitle: '流量',
    trafficTotal: '累计流量',
    trafficDown: '下行',
    trafficUp: '上行',
    trafficRxTemplate: '累计收 {v}',
    trafficTxTemplate: '累计发 {v}',
    trafficAppUsage: '应用用量（近 24 小时，含后台）',
    trafficNoAppData: '未读取到应用流量数据',
    trafficNeedUsage: '需要「使用情况访问」权限',
    trafficUsageDesc1: 'Android 从 10 开始，读取每个应用的流量必须由你在系统设置里手动授权。',
    trafficUsageDesc2: '授权后回到本页即可看到列表。',
    trafficGoGrant: '前往授权',
    trafficReadFailedTemplate: '读取应用流量失败：{msg}',
    cellTitle: '蜂窝信号',
    cellNoSim: '未读取到 SIM 卡信息（需电话权限且已插卡）',
    cellCarrier: '网络运营商',
    cellSimCarrier: 'SIM/运营商',
    cellNetwork: '网络',
    cellServing: '服务小区',
    cellDataNet: '数据网',
    cellCellId: '小区 ID',
    cellBand: '频段',
    cellSignal: '信号强度',
    cellSampling: '正在采样…',
    cellMinute: '1 分钟',
    cellNow: '现在',
    cellNeighborsTemplate: '邻小区（{n}）',
    cellNoNeighbors: '未获取到邻近小区数据（部分 ROM 不开放 allCellInfo）',
    cellLocation: '位置信息',
    cellTypeTemplate: '类型 {type}',
    cellNetLocate: '网络定位',
    cellPassive: '被动（其他应用触发）',
    cellViewLocation: '查看位置',
    cellShowReal: '已显示真实坐标',
    cellHideReal: '显示真实坐标',
    cellMasked: '默认遮罩隐藏',
    cellNoLocation: '暂无可用位置记录：请先在地图应用中定位一次，或检查位置权限。',
    cellHide: '隐藏',
    cellShow: '显示',
    cellLatitude: '纬度',
    cellLongitude: '经度',
    cellAccuracy: '精度',
    cellAltitude: '海拔',
    cellSpeed: '速度',
    cellSource: '来源',
    cellUpdatedAt: '更新时间',
    cellSlotTemplate: '卡槽 {n}',
    cellNoCarrier: '无运营商',
    cellNoSignalTemplate: '{type} · 无信号数据',
    cellRat: '制式',
    cellBandShort: '频段',
    lanTitle: '局域网设备',
    lanRescan: '重新扫描',
    lanScanningSubnet: '正在获取网段…',
    lanSelfTemplate: '本机 {ip} · 扫描 {subnet}',
    lanProgressTemplate: '扫描中 {a} / {b} · 已发现 {n} 台',
    lanEmpty: '未发现其他设备',
    lanEmptyDesc: '路由器可能启用了设备隔离，或对端不响应 ARP 请求',
    lanCountTemplate: '共 {n} 台设备',
    lanCooldownTemplate: '冷却中：{n} 秒后可自动扫描',
    lanCooldownDesc: '两次完整扫描间隔 30 秒；扫到一半退出不计入冷却。想立刻扫点右侧按钮',
    lanScanNow: '立即扫描',
    lanScanErrorTemplate: '扫描出错：{msg}',
    lanUnknownDevice: '未知设备',
    nodeCopiedTemplate: '已复制 {ip}',
    nodeReverseDns: '反向 DNS',
    nodePtrEmpty: '没有 PTR 记录（设备未提供主机名）',
    nodeTools: '诊断工具',
    nodePingDesc: 'ICMP / TCP 连通性与延迟',
    nodePortScanDesc: 'TCP connect 探测开放端口',
    nodeWhoisDesc: '查询归属与注册信息',
    nodeUpnpDesc: '发现网关暴露的服务',
    commonCopy: '复制',
    filesTitle: '文件',
    filesRefresh: '刷新',
    filesAddServerTemplate: '添加 {name}',
    filesEmptyHint: '暂无配置，可点击右上角 + 添加',
    filesNoConnections: '暂无连接。请先在「会话」页导入配置或新建连接。',
    filesConnCountTemplate: '{n} 个连接',
    filesWebdav: 'WebDAV 服务器',
    filesFtp: 'FTP 服务器',
    filesSmb: 'SMB 服务器',
    filesServerLabel: '服务器',
    filesAddrRequired: '地址不能为空',
    filesWebdavUrlInvalid: 'WebDAV 地址要以 http:// 或 https:// 开头',
    filesSmbShareRequired: 'SMB 需要填共享名',
    filesEditServerTemplate: '编辑 {name}',
    filesAddServerTitleTemplate: '添加 {name}',
    filesServerNameHint: '给这台服务器起个好认的名字',
    filesServerAddr: '地址',
    filesServerShare: '共享',
    filesServerShareHint: '如 Music / 影视',
    filesDeleteServerTitle: '删除服务器',
    filesDeleteServerConfirmTemplate: '确定删除「{name}」？',
    filesOpen: '打开',
    filesDownload: '下载',
    filesRename: '重命名',
    filesProperties: '属性',
    filesType: '类型',
    filesFolder: '文件夹',
    filesFile: '文件',
    filesSize: '大小',
    filesModified: '修改时间',
    filesPath: '路径',
    filesExtra: '附加',
    filesClose: '关闭',
    filesNewName: '新名称',
    commonConfirmBtn: '确定',
    commonQuery: '查询',
    commonQuerying: '查询中…',
    commonScanning: '扫描中…',
    commonStartScan: '开始扫描',
    commonStartDetect: '开始探测',
    commonDetecting: '探测中…',
    commonStartTest: '开始测试',
    commonTesting: '测试中…',
    commonStartSpeed: '开始测速',
    commonStartTraceroute: '开始追踪',
    commonTracing: '追踪中…',
    commonSendMagic: '发送魔术包',
    commonSending: '发送中…',
    commonHostLabel: '主机',
    commonStartPing: '开始 Ping',
    groupDiagnostics: '诊断',
    groupPerformance: '性能',
    groupLan: '局域网',
    groupCompute: '计算',
    toolsTitle: '工具',
    toolPingSub: 'TCP 探测 + 丢包统计',
    toolMultiPing: '多设备 Ping',
    toolMultiPingSub: '同时探测多个目标',
    toolMonitor: '节点监视',
    toolMonitorSub: '定时监控在线状态',
    toolGeoPingSub: '从多地节点探测',
    toolTracerouteSub: '逐跳路径',
    toolPortScan: '端口扫描',
    toolPortScanSub: '常用 / 自定义 / 全部',
    toolWhoisSub: '域名与 IP 归属',
    toolDnsSub: 'A / AAAA / MX / TXT',
    toolIperfSub: '预设配置 + 结果解读',
    toolSpeed: '网速测试',
    toolSpeedSub: '下载 / 上传 / 延迟',
    toolSubnet: '子网扫描',
    toolSubnetSub: '局域网设备发现',
    toolUpnp: 'UPnP 扫描',
    toolUpnpSub: 'SSDP 发现网关服务',
    toolWol: 'Wake On LAN',
    toolWolSub: 'UDP 魔术包',
    toolIpCalc: 'IP 计算器',
    toolIpCalcSub: '掩码 / 网段 / 可用地址',
    toolTodoTemplate: '{name}：暂未实现',
    terminalCopy: '复制选中',
    terminalPaste: '粘贴',
    terminalSelectFirst: '先长按选中要复制的内容',
    terminalSelectionEmpty: '选区是空的',
    terminalClipboardEmpty: '剪贴板是空的',
    terminalCopiedTemplate: '已复制 {n} 个字符',    homeNetworkType: '网络类型',
    homePublicIpv4: '公网 IPv4',
    homePublicIpv6: '公网 IPv6',
    homeGatewayIpv4: '网关 IPv4',
    homeGatewayIpv6: '网关 IPv6',
    homeLocalIp: '本机 IP',
    homeLocal: '本机',
    homeUpstream: '上级设备',
    homePublic: '公网',
    homeDefaultGateway: '默认网关',
    homeDirectExit: '直连出口',
    homeProxyExit: '代理出口',
    homeRegion: '归属地',
    homeNetworkStatus: '网络状态',
    homeTopology: '链路拓扑',
    homeCell: '蜂窝',
    homeWifi: 'Wi-Fi',
    homeTraffic: '流量',
    homeNotConnectedWifi: '未连接 Wi-Fi',
    homeSsidPermission: 'SSID 需要附近设备/位置权限',
    homeWaitPermission: '等待权限或未插卡',
    homeExplanation: '说明',
    homeExplanationDesc: '不走代理时的真实出口，和公网出口不同说明在走代理',
    homeDomesticLine: '国内线路',
    homeUpdatedTemplate: '{kind} · {time} 更新',
    homeSamplingTemplate: '每秒采样中 · 已采样 {n} 次',
    homeCopiedTemplate: '已复制 {title}：{value}',
    commonUnknown: '未知',
    commonNotObtained: '未获取',
    commonNone: '无',
    commonNotProbed: '未探测',    commonTodo: '暂未实现',
  );

  static const AppStrings zhHant = AppStrings(
    language: AppLanguage.zhHant,
    tabHome: '主頁',
    tabSessions: '會話',
    tabTools: '工具',
    tabFiles: '檔案',
    settingsTitle: '設定',
    sectionAppearance: '外觀',
    modeTitle: '晝夜模式',
    modeSystem: '系統',
    modeLight: '淺色',
    modeDark: '深色',
    followWallpaper: '跟隨壁紙取色',
    followWallpaperDesc: 'Material You：強調色跟隨系統壁紙，關掉後用下方手選色',
    accentColor: '強調色',
    accentDynamicHint: '目前：跟隨壁紙（手選色作為未取到壁紙色時的備援）',
    accentManualHint: '目前：手選強調色',
    sectionTerminal: '終端',
    terminalFontSize: '終端字號',
    decrease: '縮小',
    increase: '放大',
    sectionDesignLanguage: '設計語言',
    designLanguageDesc: '目前只實作了 MD3；出 MD4 時在這裡新增一項，頁面程式碼不用改。',
    sectionLanguage: '語言',
    sectionData: '資料',
    importConfig: '匯入桌面版設定',
    importConfigDesc: '支援 config.json 與備份 zip',
    webdavBackup: 'WebDAV 備份',
    webdavBackupDesc: '把設定與伺服器清單備份到 WebDAV，或從中還原',
    sectionPermissions: '權限',
    permissionUsage: '使用情況存取',
    permissionPhone: '電話狀態',
    permissionLocation: '位置資訊',
    permissionWifi: '鄰近裝置',
    permissionGranted: '已授權',
    permissionDenied: '未授權',
    permissionGoGrant: '前往授權',
    clearData: '清除本機資料',
    clearDataDesc: '清空匯入的設定、伺服器清單與介面設定',
    clearDataDone: '已清除',
    about: '關於',
    aboutDesc: '多功能網路工具箱 + SSH 終端',
    frameStage: 'QShell Android',
    commonCancel: '取消',
    commonSave: '儲存',
    commonDelete: '刪除',
    commonAdd: '新增',
    commonConfirm: '確定',
    commonRefresh: '重新整理',
    commonRetry: '重試',
    checkUpdate: '檢查更新',
    checkUpdateDesc: '從 GitHub Releases 取得最新版本',
    checkingUpdate: '正在檢查…',
    autoCheckUpdate: '自動檢查更新',
    autoCheckUpdateDesc: '啟動應用程式時自動偵測一次新版本',
    updateAvailableTemplate: '發現新版本 {v}',
    updateLatest: '已是最新版本',
    updateFailedTemplate: '檢查失敗：{msg}',
    updateNoRepo: '尚未設定更新來源',
    commonEdit: '編輯',
    commonName: '名稱',
    commonHost: '主機',
    commonProxy: '跳板',
    commonPort: '連接埠',
    commonUser: '使用者',
    commonPassword: '密碼',
    commonGroup: '群組',
    commonCommand: '指令',
    commonSelect: '選擇',
    commonClear: '清除',
    sessionsTitle: '會話',
    sessionsNew: '新增連線',
    sessionsImport: '匯入桌面版設定',
    sessionsEmpty: '暫無連線',
    sessionsImporting: '匯入中…',
    sessionsImportBtn: '匯入設定',
    sessionsSearchHint: '搜尋名稱 / 主機 / 使用者',
    sessionsDefaultGroup: '我的連線',
    sessionsNoMatchTemplate: '沒有符合「{q}」的連線',
    sessionsCountTemplate: '{n} 條連線',
    sessionsMatchTemplate: '符合 {a} / {b} 條',
    sessionsTotalTemplate: '共 {n} 條連線',
    sessionsImportedTemplate: '已匯入 {n} 條連線',
    sessionsAddedTemplate: '已新增 {name}',
    sessionsSavedTemplate: '已儲存 {name}',
    sessionsDeletedTemplate: '已刪除 {name}',
    sessionsDeleteTitle: '刪除連線',
    sessionsDeleteConfirmTemplate: '確定刪除「{name}」（{sub}）？',
    sessionsNoConfigInZip: '備份檔裡找不到 qshell_config.json',
    sessionsBadConfig: '設定檔格式不正確（需要桌面版匯出的 config.json 或備份 zip）',
    sessionsImportFailedTemplate: '匯入失敗：{msg}',
    sessionsProtocolTodoTemplate: '{proto} 協定尚未支援，目前僅支援 SSH',
    sessionsKeyTodo: '這條連線使用私鑰登入，私鑰登入尚未支援',
    sessionsEdit: '編輯連線',
    sessionsNameHint: '留空則使用主機名',
    sessionsHostHint: 'IP 或網域',
    sessionsGroupHint: '填新名稱即成新群組',
    sessionsKeySection: '私鑰登入（選填）',
    sessionsUsingPwd: '目前使用密碼登入',
    sessionsNoKeyFile: '未選擇私鑰檔案',
    sessionsPassphrase: '密語',
    sessionsPassphraseHint: '僅加密私鑰需要',
    sessionsProxySection: '跳板機（選填）',
    sessionsProxyDirect: '未設定，直連',
    sessionsProxyHostHint: 'IP 或網域，留空直連',
    sessionsProxyUserHint: '留空同目標使用者',
    sessionsProxyPwdHint: '留空同目標密碼',
    sessionsHostRequired: '主機不能為空',
    sessionsPickKeyFailedTemplate: '選擇私鑰失敗：{msg}',
    memoTitle: '備忘錄',
    memoAdd: '新增',
    memoEmpty: '暫無備忘錄',
    memoEmptyDesc: '用於儲存常用指令，點擊即可複製',
    memoAddItem: '新增備忘錄',
    memoEditItem: '編輯備忘錄',
    memoCopied: '已複製指令',
    memoUnnamed: '未命名',
    memoCopy: '複製指令',
    memoNoGroup: '未分組',
    memoDefaultGroup: '常用',
    memoCountTemplate: '{g} 個群組 · {n} 條',
    memoCmdRequired: '指令不能為空',
    deviceIphone: 'iPhone / iPad',
    deviceWindowsRdp: 'Windows（遠程桌面）',
    deviceWindows: 'Windows',
    devicePrinter: '打印機',
    deviceNas: 'NAS',
    deviceCamera: '攝像頭',
    deviceRouter: '路由器',
    deviceAndroid: 'Android',
    deviceLinux: 'Linux 主機',
    deviceWeb: 'Web 設備',
    deviceUnknown: '未知設備',
    deviceAirplay: 'Apple 設備（AirPlay）',
    deviceApple: 'Apple 設備',
    deviceCast: 'Chromecast / 安卓 TV',
    deviceMijia: '小米智能設備',
    deviceHomekit: 'HomeKit 設備',
    deviceSpeaker: '智能音箱',
    deviceWorkstation: '工作站',
    deviceBonjour: '支持 Bonjour 的設備',
    termReconnectFailed: '[重連失敗，請返回後重新連接]',
    termReconnectCountdownTemplate: '[{d} 秒後自動重連（第 {n} 次）]',
    termDisconnected: '[連接已斷開]',
    termAuthFailed: '認證失敗：用戶名或密碼不對',
    termNetworkLost: '網絡中斷（可能切到後台被系統斷網）',
    termConnRefused: '目標拒絕連接（端口不對或服務未開）',
    termNetworkUnreachable: '網絡不可達',
    termConnectFailedTemplate: '連接失敗：{msg}',
    termNoMemos: '暫無備忘錄，可於會話頁新增',
    termMemoSheetTitle: '備忘錄 · 點擊發送到終端',
    termSentTemplate: '已發送：{cmd}',
    termConnecting: '連接中…',
    termConnectedTemplate: '已連接 · {port}',
    termDisconnectedState: '已斷開',
    termConnectingToTemplate: '正在連接 {host}:{port}',
    commonBack: '返回',
    whoisTargetRequired: '请输入域名或 IP 地址',
    whoisTimeout: '查詢逾時，請更換網路後重試',
    whoisServerRefused: '服務器拒絕連接',
    whoisFailedTemplate: '查詢失敗：{msg}',
    whoisCopyResult: '復制結果',
    commonCopied: '已復制',
    whoisTarget: '目標',
    whoisTargetHint: 'example.com 或 8.8.8.8',
    whoisSourceTemplate: '來源 {server}',
    sessionsNoMatchShortTemplate: '沒有匹配「{q}」的連接',
    speedCustomNodeRequired: '自定義節點需要填下載 URL',
    commonStop: '停止',
    speedCloudflare: 'Cloudflare',
    speedPreparing: '準備中…',
    speedFailedTemplate: '測速失敗：{msg}',
    speedStopped: '已停止',
    speedTitle: '網速測試',
    speedNode: '節點',
    speedDownload: '下載',
    speedUpload: '上傳',
    speedUploadHint: '可選，留空則跳過',
    speedLatency: '延遲',
    speedPhaseLatency: '測延遲…',
    speedPhaseDownload: '下載測速…',
    speedPhaseUpload: '上傳測速…',
    speedTesting: '測速中…',
    backupReadFailedTemplate: '讀取備份列表失敗：{msg}',
    backupAddrRequired: '请输入 WebDAV 地址',
    backupDoneTemplate: '已備份：{name}',
    backupFailedTemplate: '備份失敗：{msg}',
    backupRestoreTitle: '從備份恢復',
    backupRestoreConfirmTemplate: '將用「{name}」覆蓋當前的連接配置和服務器列表，確定？',
    backupRestoreBtn: '恢復',
    backupNoConfig: '備份里沒有 qshell_config.json',
    backupConfigReadFailed: '配置文件讀取失敗',
    backupRestoredTemplate: '已恢復：{g} 個分組 · {s} 個服務器',
    backupRestoreFailedTemplate: '恢復失敗：{msg}',
    backupTitle: 'WebDAV 備份',
    backupRefresh: '刷新備份列表',
    backupInProgress: '處理中…',
    backupDoNow: '立即備份到 WebDAV',
    backupRemoteCountTemplate: '遠端備份（{n}）',
    backupHint: '請先填寫上位址，再執行備份或重新整理',
    backupNoFiles: '暫無備份檔案',
    iperfNoBinary: '沒有找到內置的 iperf3（當前 ABI 沒打包），需要重新構建 APK',
    iperfServerRequired: '請輸入伺服器位址',
    iperfServer: '服務器',
    iperfProtocol: '協議',
    iperfDirection: '方向',
    iperfUp: '上行',
    iperfDown: '下行',
    iperfBoth: '雙向',
    iperfStreams: '流數',
    iperfDuration: '時長',
    iperfSeconds: '秒',
    iperfBandwidth: '帶寬',
    iperfPresets: '快捷預設',
    iperfTestingTemplate: '測試中（{s}s）…',
    iperfBidirTemplate: '上行 {up} · 下行 {down} Mbps',
    iperfRetransmits: '重傳次數',
    iperfJitter: '抖動',
    iperfLoss: '丟包',
    iperfLossTemplate: '{p}%（{n} 個）',
    portInvalidFormat: '端口格式不對，例如 80,443,8000-8100',
    scanErrorTemplate: '掃描出錯：{msg}',
    scanTitle: '端口掃描',
    portRange: '範圍',
    portCommon: '常用',
    portCustom: '自定義',
    portAll: '全部',
    portCommonHintTemplate: '常用端口 {n} 個：{list}',
    portAllHint: '全部端口 1~65535（耗時較長）',
    portEstimateTemplate: '共 {n} 個端口，預計 {t}',
    portScannedTemplate: '已掃描 {a} / {b}',
    portOpenCountTemplate: '開放端口 {n}',
    portShowOpenOnly: '只看開放',
    portShowAll: '顯示全部',
    portSecondsTemplate: '{n} 秒',
    portMinutesTemplate: '{n} 分鐘',
    commonHostRequired: '請輸入主機位址',
    pingIcmpFallback: '這台設備不允許 App 發 ICMP，已自動切換到 TCP 探測',
    commonTimeout: '超時',
    pingExecFailedTemplate: '執行失敗：{msg}',
    pingMode: '方式',
    pingSentReceived: '發送 / 接收',
    pingLoss: '丟包率',
    pingMinAvgMax: '最小 / 平均 / 最大',
    commonFailed: '失敗',
    ipInvalidFormat: '格式不對，試試 192.168.1.0/24 或 "192.168.1.10 255.255.255.0"',
    ipTitle: 'IP 計算器',
    ipAddress: '地址',
    ipPrefix: '前缀',
    ipMask: '子網掩碼',
    ipWildcard: '反掩碼',
    ipNetwork: '網絡地址',
    ipBroadcast: '廣播地址',
    ipRange: '可用範圍',
    ipHosts: '可用主機',
    ipClass: '地址類別',
    ipPrivate: '私有地址',
    commonYes: '是',
    commonNo: '否',
    ipMillionTemplate: '{n}（约 {m} 百万）',
    settingsAppDir: '應用私有目錄',
    settingsAppDirDesc: '默認，只有 QShell 能訪問',
    settingsDownloads: '系統下載目錄',
    settingsDownloadsDesc: 'Download/QShell，其他 App 也能看到',
    settingsImportedTemplate: '已導入 {n} 條連接（{g} 個分組）',
    settingsImportFailedTemplate: '導入失敗：{msg}',
    settingsBgImageSet: '已設置終端背景圖片',
    settingsBgImageFailedTemplate: '設置背景失敗：{msg}',
    settingsBgImageCleared: '已清除終端背景圖片',
    settingsExportCancelled: '已取消導出',
    settingsExported: '已導出 qshell_backup.zip',
    settingsExportFailedTemplate: '導出失敗：{msg}',
    settingsAppearanceSub: '晝夜模式 / 取色 / 強調色',
    settingsTerminalLook: '終端外觀',
    settingsTerminalLookDesc: '字號 / 文字色 / 背景色 / 背景圖',
    settingsTextColor: '文字顏色',
    settingsBgColor: '背景顏色',
    settingsBgImageUnset: '背景圖片：未設置',
    settingsBgImageSetDesc: '背景圖片：已設置（覆蓋背景色）',
    settingsPickImage: '選擇圖片',
    settingsDataSub: '導入 / 導出 / 下載位置 / WebDAV 備份',
    settingsExportLocal: '導出到本地',
    settingsExportLocalDesc: '打包成 zip（含 qshell_config.json），可與桌面版互導',
    settingsDownloadLocation: '下載位置',
    settingsPermissionsSub: '使用時訪問 / 電話 / 位置 / 附近設備',
    settingsMonitorTitle: '節點監視',
    settingsSelectNodes: '選擇監視節點',
    settingsSelectAll: '全選',
    settingsSelectNone: '全不選',
    settingsMonitoring: '監視中',
    settingsStopMonitor: '停止監視',
    settingsStartMonitor: '開始監視',
    settingsNoNodes: '暫無監視節點',
    settingsNodesHint: '節點來自「會話」頁的連接列表',
    settingsReadList: '讀取 SSH 會話列表',
    settingsNodesCountTemplate: '{n} 個節點 · 在線 {on}',
    settingsAddNode: '添加節點',
    settingsEditNode: '編輯節點',
    settingsNodeNameRequired: '主機不能為空',
    browserEmptyDir: '空目錄',
    browserBack: '返回上級',
    browserRetry: '重試',
    browserNewFolder: '新建文件夾',
    browserFolderName: '文件夾名',
    browserCreate: '創建',
    browserCancel: '取消',
    browserDelete: '刪除',
    browserDeleteConfirmTemplate: '確定刪除 {name}？',
    browserDeletedTemplate: '已刪除 {name}',
    browserDeleteFailedTemplate: '刪除失敗：{msg}',
    browserRenameFailedTemplate: '重命名失敗：{msg}',
    browserRenamedTemplate: '已重命名為 {name}',
    browserOpenFailedTemplate: '打開失敗：{msg}',
    browserDownloadFailedTemplate: '下載失敗：{msg}',
    browserUploadFailedTemplate: '上傳失敗：{msg}',
    browserUploadCancelled: '已取消上傳',
    browserDownloadCancelled: '已取消下載 {name}',
    browserDownloadedTemplate: '已下載 {name}',
    browserUploadedTemplate: '已上傳 {name}',
    browserCreateFailedTemplate: '創建失敗：{msg}',
    browserConnectFailedTemplate: '連接失敗：{msg}',
    browserReadDirFailedTemplate: '讀取目錄失敗：{msg}',
    browserUnsupportedProtoTemplate: '不支持的協議：{kind}',
    browserUpload: '上傳',
    browserDownloadLabel: '下載',
    browserExitHint: '再按一次以退出',
    browserFolder: '文件夾',
    trafficTitle: '流量',
    trafficTotal: '累計流量',
    trafficDown: '下行',
    trafficUp: '上行',
    trafficRxTemplate: '累計收 {v}',
    trafficTxTemplate: '累計送 {v}',
    trafficAppUsage: '應用程式用量（近 24 小時，含背景）',
    trafficNoAppData: '沒有讀到應用程式流量資料',
    trafficNeedUsage: '需要「使用情況存取」權限',
    trafficUsageDesc1: 'Android 10 起，讀取各應用程式流量必須在系統設定中手動授權。',
    trafficUsageDesc2: '授權後回到本頁即可看到清單。',
    trafficGoGrant: '前往授權',
    trafficReadFailedTemplate: '讀取應用程式流量失敗：{msg}',
    cellTitle: '行動網路訊號',
    cellNoSim: '沒有讀到 SIM 卡資訊（需要電話權限，且裝置需插卡）',
    cellCarrier: '電信業者',
    cellSimCarrier: 'SIM/電信業者',
    cellNetwork: '網路',
    cellServing: '服務細胞',
    cellDataNet: '資料網路',
    cellCellId: '細胞 ID',
    cellBand: '頻段',
    cellSignal: '訊號強度',
    cellSampling: '正在取樣…',
    cellMinute: '1 分鐘',
    cellNow: '現在',
    cellNeighborsTemplate: '鄰近細胞（{n}）',
    cellNoNeighbors: '沒有鄰近細胞資料（部分 ROM 不開放 allCellInfo）',
    cellLocation: '位置資訊',
    cellTypeTemplate: '類型 {type}',
    cellNetLocate: '網路定位',
    cellPassive: '被動（其他應用程式觸發）',
    cellViewLocation: '查看位置',
    cellShowReal: '已顯示真實座標',
    cellHideReal: '顯示真實座標',
    cellMasked: '預設遮蔽隱藏',
    cellNoLocation: '沒有可用的位置紀錄：請先到地圖 App 定位一次，或檢查位置權限。',
    cellHide: '隱藏',
    cellShow: '顯示',
    cellLatitude: '緯度',
    cellLongitude: '經度',
    cellAccuracy: '精確度',
    cellAltitude: '海拔',
    cellSpeed: '速度',
    cellSource: '來源',
    cellUpdatedAt: '更新時間',
    cellSlotTemplate: '卡槽 {n}',
    cellNoCarrier: '無電信業者',
    cellNoSignalTemplate: '{type} · 無訊號資料',
    cellRat: '制式',
    cellBandShort: '頻段',
    lanTitle: '區域網路裝置',
    lanRescan: '重新掃描',
    lanScanningSubnet: '正在取得網段…',
    lanSelfTemplate: '本機 {ip} · 掃描 {subnet}',
    lanProgressTemplate: '掃描中 {a} / {b} · 已發現 {n} 台',
    lanEmpty: '沒有偵測到其他裝置',
    lanEmptyDesc: '可能是路由器啟用了裝置隔離，或對方裝置不回應 ARP',
    lanCountTemplate: '共 {n} 台裝置',
    lanCooldownTemplate: '冷卻中：{n} 秒後可自動掃描',
    lanCooldownDesc: '兩次完整掃描間隔 30 秒；掃到一半離開不計入冷卻。想立刻掃請點右側按鈕',
    lanScanNow: '立即掃描',
    lanScanErrorTemplate: '掃描錯誤：{msg}',
    lanUnknownDevice: '未知裝置',
    nodeCopiedTemplate: '已複製 {ip}',
    nodeReverseDns: '反向 DNS',
    nodePtrEmpty: '沒有 PTR 記錄（裝置未提供主機名）',
    nodeTools: '診斷工具',
    nodePingDesc: 'ICMP / TCP 連通性與延遲',
    nodePortScanDesc: 'TCP connect 探測開放連接埠',
    nodeWhoisDesc: '查詢歸屬與註冊資訊',
    nodeUpnpDesc: '探索閘道對外服務',
    commonCopy: '複製',
    filesTitle: '檔案',
    filesRefresh: '重新整理',
    filesAddServerTemplate: '新增 {name}',
    filesEmptyHint: '暫無設定，可點右上角 + 新增',
    filesNoConnections: '暫無連線。請先於「會話」頁匯入設定或新增連線。',
    filesConnCountTemplate: '{n} 個連線',
    filesWebdav: 'WebDAV 伺服器',
    filesFtp: 'FTP 伺服器',
    filesSmb: 'SMB 伺服器',
    filesServerLabel: '伺服器',
    filesAddrRequired: '位址不能為空',
    filesWebdavUrlInvalid: 'WebDAV 位址需以 http:// 或 https:// 開頭',
    filesSmbShareRequired: 'SMB 需要填寫分享名稱',
    filesEditServerTemplate: '編輯 {name}',
    filesAddServerTitleTemplate: '新增 {name}',
    filesServerNameHint: '給這台伺服器取個好記的名稱',
    filesServerAddr: '位址',
    filesServerShare: '分享',
    filesServerShareHint: '例如 Music / 影視',
    filesDeleteServerTitle: '刪除伺服器',
    filesDeleteServerConfirmTemplate: '確定刪除「{name}」？',
    filesOpen: '開啟',
    filesDownload: '下載',
    filesRename: '重新命名',
    filesProperties: '屬性',
    filesType: '類型',
    filesFolder: '資料夾',
    filesFile: '檔案',
    filesSize: '大小',
    filesModified: '修改時間',
    filesPath: '路徑',
    filesExtra: '附加',
    filesClose: '關閉',
    filesNewName: '新名稱',
    commonConfirmBtn: '確定',
    commonQuery: '查詢',
    commonQuerying: '查詢中…',
    commonScanning: '掃描中…',
    commonStartScan: '開始掃描',
    commonStartDetect: '開始探測',
    commonDetecting: '探測中…',
    commonStartTest: '開始測試',
    commonTesting: '測試中…',
    commonStartSpeed: '開始測速',
    commonStartTraceroute: '開始追蹤',
    commonTracing: '追蹤中…',
    commonSendMagic: '傳送魔術封包',
    commonSending: '傳送中…',
    commonHostLabel: '主機',
    commonStartPing: '開始 Ping',
    groupDiagnostics: '診斷',
    groupPerformance: '效能',
    groupLan: '區域網路',
    groupCompute: '計算',
    toolsTitle: '工具',
    toolPingSub: 'TCP 探測 + 封包遺失統計',
    toolMultiPing: '多裝置 Ping',
    toolMultiPingSub: '同時探測多個目標',
    toolMonitor: '節點監視',
    toolMonitorSub: '定時監控上線狀態',
    toolGeoPingSub: '從多地節點探測',
    toolTracerouteSub: '逐跳路徑',
    toolPortScan: '連接埠掃描',
    toolPortScanSub: '常用 / 自訂 / 全部',
    toolWhoisSub: '網域與 IP 歸屬',
    toolDnsSub: 'A / AAAA / MX / TXT',
    toolIperfSub: '預設設定 + 結果解讀',
    toolSpeed: '網路測速',
    toolSpeedSub: '下載 / 上傳 / 延遲',
    toolSubnet: '子網掃描',
    toolSubnetSub: '區域網路裝置探索',
    toolUpnp: 'UPnP 掃描',
    toolUpnpSub: 'SSDP 探索閘道服務',
    toolWol: 'Wake On LAN',
    toolWolSub: 'UDP 魔術封包',
    toolIpCalc: 'IP 計算器',
    toolIpCalcSub: '遮罩 / 網段 / 可用位址',
    toolTodoTemplate: '{name}：暫未實作',
    terminalCopy: '複製選取',
    terminalPaste: '貼上',
    terminalSelectFirst: '請先長按選取要複製的內容',
    terminalSelectionEmpty: '選取範圍是空的',
    terminalClipboardEmpty: '剪貼簿是空的',
    terminalCopiedTemplate: '已複製 {n} 個字元',    homeNetworkType: '網路類型',
    homePublicIpv4: '公網 IPv4',
    homePublicIpv6: '公網 IPv6',
    homeGatewayIpv4: '閘道 IPv4',
    homeGatewayIpv6: '閘道 IPv6',
    homeLocalIp: '本機 IP',
    homeLocal: '本機',
    homeUpstream: '上層裝置',
    homePublic: '公網',
    homeDefaultGateway: '預設閘道',
    homeDirectExit: '直連出口',
    homeProxyExit: '代理出口',
    homeRegion: '歸屬地',
    homeNetworkStatus: '網路狀態',
    homeTopology: '鏈路拓撲',
    homeCell: '行動網路',
    homeWifi: 'Wi-Fi',
    homeTraffic: '流量',
    homeNotConnectedWifi: '未連線 Wi-Fi',
    homeSsidPermission: 'SSID 需要鄰近裝置/位置權限',
    homeWaitPermission: '等待權限 / 未插卡',
    homeExplanation: '說明',
    homeExplanationDesc: '不走代理時的真實出口，和公網出口不同表示正在走代理',
    homeDomesticLine: '國內線路',
    homeUpdatedTemplate: '{kind} · {time} 更新',
    homeSamplingTemplate: '每秒取樣中 · 已取樣 {n} 次',
    homeCopiedTemplate: '已複製 {title}：{value}',
    commonUnknown: '未知',
    commonNotObtained: '未取得',
    commonNone: '無',
    commonNotProbed: '未探測',    commonTodo: '暫未實作',
  );

  static AppStrings forLanguage(AppLanguage language) =>
      language == AppLanguage.zhHant ? zhHant : zhHans;

  static AppStrings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppStringsScope>();
    return scope?.strings ?? zhHans;
  }
}

/// 把文案注入组件树。
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings != strings;
}
