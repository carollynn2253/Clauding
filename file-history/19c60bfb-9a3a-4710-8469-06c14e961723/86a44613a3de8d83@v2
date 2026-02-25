# revamp/ Architecture Deep Dive

## DI Modules (di/DiModules.kt)

### viewModelModule — 50+ VMs including:
- Auth: LoginViewModel, RegisterViewModel, ContinueLoginViewModel, OTPViewModel, SecurityCodeViewModel
- Account: MyAccountViewModel, SettingViewModel, DrawerViewModel, ChangePwdViewModel, TrustDeviceViewModel, AccountSecurityNotifyViewModel, ProvideEmailViewModel
- Statement: StatementAllViewModel, StatementSummaryViewModel, StatementBetHistoryViewModel, StatementTransHistoryViewModel, StatementSbkHistoryViewModel, StatementPromotionHistoryDetailViewModel
- Messaging: MessageViewModel, MessageComposeViewModel, MessageComposeSelectorViewModel
- Notification: NotificationViewModel, NotificationListViewModel
- Web: WebViewModel, SimpleWebViewModel, GuideWebViewModel, TnCWebViewModel, OverlayAdsWebViewModel, PdfViewerViewModel
- Utility: LobbyViewModel, MarqueeViewModel, BottomNavigationViewModel, BottomChooserViewModel
- Special: SplashViewModel, MaintenanceViewModel, CheckVersionViewModel, LiveChatViewModel, CallBackViewModel, IdentityVerificationViewModel

### repositoryModule — singletons:
BaseRepository, ChangePwdRepository, DrawerRepository, MessageRepository, StatementRepository, SettingRepository, MyAccountRepository, NotificationRepository, RegisterRepository, LobbyRepository, LoginRepository, WebViewRepository, OTPRepository, RegionRepository, ForgotAccountRepository

### useCaseModule:
CheckDomainUseCase, DownloadApkUseCase, FetchVersionUseCase, CheckMaintenanceUseCase, AutoLoginUseCase, CheckDraftAvailableUseCase

### utilModule:
CrashReportUtils, AdaChatBotManager, FirebaseHelper

## Base Classes

### BaseViewModel
- Extends ViewModel, implements IOAuthBaseListener
- Manages: OAuth init (Google/Facebook), progress dialog, VIP tier checks, login status, Firebase analytics
- Key: `isMemberLogin()`, `isMemberVip()`, `setProgressStatus()`, `initOAuthRecord()`

### BaseBindingActivity
- Extends AppCompatActivity with DataBinding
- Handles: fragment transactions (with animations), email verify dialogs, high-risk account security checks, loading dialogs, maintenance/forbidden checks
- Checks login prerequisites before showing content

### BaseBindingFragment
- Extends Fragment with DataBinding
- Lifecycle hooks: `initArgs()`, `initData()`, `initView()`, `getLayoutId()`
- Loading dialog management

### BaseActivityOptions (Builder pattern)
- Configures activity UI: logo, title, member info, menu, notification, marquee, header, bottom nav

## Repository Details

### BaseRepository
- Access to `Bet188SharePreferences` (login status, VIP, region, language)
- `handler: ServerResponseHandler?` — set per ViewModel for maintenance/forbidden handling

### StatementRepository
APIs: SpiSummary, SpiDepositHistory, SpiWithdrawalHistory, SpiAdjustmentHistory, SpiPromotionHistory, SpiFlexiblePromotionDetailHistory, SpiSettleBets, SpiSettleBetDetails, SpiUnsettleBets, SpiGameLaunchToken, SpiStatementHistoryLongDays
Caching: StatementDaoChecked

### LoginRepository (extends RegisterRepository)
APIs: SpiSponsorSetting, SpiGetRegionTheme, SpiOAuthRebinding
Manages: OAuth rebinding, sponsor list, theme, lock pattern, biometric auth

### MessageRepository
APIs: SpiGetMessageList, SpiDeleteMessage, SpiSetMessageStatus, SpiGetInboxUnreadCount, SpiGetMessageDetail, SpiReplyMessage, SpiSendMessage, SpiForwardMessage, SpiMemberinfo, SpiGetComposeCategories, SpiGetComposeSubjects, SpiGetMemberTransactions, SpiGetMemberPromotions
DB: RoomDbHelper for drafts
Supports both callback and suspend patterns

### DrawerRepository
Provides: user code, language, region, currency, gender from prefs
APIs: SpiGetAccountSummary, SpiSportsLaunchToken, version check

### MyAccountRepository
APIs: SpiGetDashboardAlerts, SpiGetLeftMenuInfo, SpiGetMobileAndScheduleCallStatus, SpiScheduleCall
Region-based banking menu filtering (CN, VN, KH, ID, KR, TH, JP, MY, IN)

### NotificationRepository
APIs: SpiGetByCategories, SpiGetByGroupID, SpiGetImportantNotifications, SpiGetAnnouncement, SpiMarkAsRead, SpiMarkAllAsRead, SpiGetCategoriesInfo, SpiHideImportantWidget

### LobbyRepository
APIs: SpiGetLobbyInfo, SpiGetRegionTheme, SpiSponsorSetting, SpiSportsLaunchToken
Theme caching, product list management

## View Layer — Feature Directories
- `account/dashboard/` — MyAccountDashboardActivity
- `account/drawer/` — MyAccountDrawerActivity
- `account/security/` — AccountSecurityNotifyActivity, TrustDeviceActivity
- `drawer/` — DrawerActivity, ChatDrawerActivity, MainDrawerFragment, ProductDrawerFragment
- `login/` — LoginActivity, ContinueLoginActivity
- `register/` — RegisterTypeSelectActivity, OAuthRegisterActivity
- `forgotaccount/` — ForgotAccountActivity, SecurityCodeActivity, ProvideEmailActivity, SetNewPasswordActivity, IdentityVerificationActivity
- `lobby/` — HomeLobbyActivity, HomeLobbyFragment
- `statement/` — StatementAllActivity + bethistory/, transhistory/, promotionhistorydetail/, all/, PdfViewerActivity
- `message/` — MessageActivity, MessageDetailActivity, ComposeMessageActivity, MessageComposeSelectorActivity
- `notification/` — NotificationActivity, NotificationListActivity, NotificationThreadActivity, NotificationFragment
- `lockpattern/` — LockPatternActivity
- `maintenance/` — MaintenanceActivity
- `livechat/` — LiveChatActivity
- `callback/` — CallBackActivity
- `bottomchooser/` — BottomChooserActivity
- `imageview/` — Custom ImageView components

## Key Patterns

### Sealed Classes for Results
```kotlin
sealed class CheckDomainResult {
    data object Complete : CheckDomainResult()
    data object DomainEmpty : CheckDomainResult()
}
```

### Modern StateFlow/Effect pattern (FindAccountViewModel)
```kotlin
private val _state = MutableStateFlow(FindAccountUiState())
val state: StateFlow<FindAccountUiState> = _state.asStateFlow()
private val _effects = MutableSharedFlow<FindAccountEffect>(...)
val effects: SharedFlow<FindAccountEffect> = _effects.asSharedFlow()
```

### Legacy LiveData pattern (most VMs)
```kotlin
val progressDialogObservable = MutableLiveData<Boolean>()
val loginReturnStatus = MutableLiveData<LoginResult>()
```

### Activity Result Contracts
```kotlin
class MessageDetailContract : ActivityResultContract<MessageDetailInputBundles, MessageDetailOutputBundles>
```

## Constants & Enums (Constants.kt)
Key enums: VerifyChannel, ThemeSetting, LobbyPopUp, EmailVerifyAction, AccountHighRiskType, UserVIPTier, AccountDashboardMenuItem, MessageStatus

## Notable Widgets
- BaseDialogFragment + BaseDialogFragmentBuilder
- PopUpDialogFragment, IconNotifyDialogFragment
- MarqueeTextView, EmailAutoCompleteTextView, CustomTextInputLayout
- LockPatternView, StatementMultiDateSelector, TabLayoutWithArrow
- BottomNavigationView (custom), CaptchaView
- RecyclerViewItemDecoration, PagerViewItemDecoration

## SharedPreferences
`Bet188SharePreferences` singleton — stores: user188token, region, language, VIP tier, balance, unread counts, fingerprint data, OAuth keys
`clearOldUserData()` — atomic Room transaction on logout
