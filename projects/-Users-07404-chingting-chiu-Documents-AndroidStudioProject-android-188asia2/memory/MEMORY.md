# Bet188 Asia Android App - Memory

## Project Summary
Betting/gambling platform app for Southeast Asia markets (ID, KH, etc.).
Working dir: `/Users/07404.chingting.chiu/Documents/AndroidStudioProject/android-188asia2/Bet188/application`
Main source: `app/src/main/java/com/xuenn/bet188/`

## Key Instruction
Focus on `/revamp` — this is the modern MVVM codebase. Directories `activity/`, `fragment/`, `model/` (outside revamp), `data/`, `util/` are **legacy** (old style, ignore unless necessary).

## Architecture (revamp/)
- **MVVM** with Repository pattern + UseCase layer
- **DI**: Koin (4 modules: viewModelModule, repositoryModule, useCaseModule, utilModule)
- **Layer flow**: View → ViewModel → Repository → Network (SPI) + Room DB + SharedPrefs
- **Base classes**: `BaseBindingActivity`, `BaseBindingFragment`, `BaseViewModel`
- **Reactive**: Mix of LiveData (legacy) and StateFlow/SharedFlow (modern, e.g. FindAccountViewModel)

## revamp/ Directory Structure
- `view/` — 34 feature dirs (login, register, account, statement, message, lobby, notification, livechat, drawer, forgotaccount, etc.)
- `viewmodel/` — 50+ ViewModels
- `model/data/repo/` — 16+ repositories
- `model/data/database/` — Room DAOs & entities
- `di/DiModules.kt` — All Koin modules
- `usecase/` — CheckDomainUseCase, AutoLoginUseCase, FetchVersionUseCase, CheckMaintenanceUseCase, etc.
- `utils/` — 50+ utilities (CommonUtils, DateUtils, FirebaseHelper, WebViewUtils, RegionUtil, etc.)
- `widget/` — 20+ custom views/dialogs
- `callback/`, `contract/` — Interfaces

## Network Layer
- **SPI pattern** from `comm/network/` — each API is an `Spi*` class
- Repos call: `spi.post(context, handler, callback)` or suspend `spi.get(...)`
- `ServerResponseHandler` handles maintenance/forbidden globally
- Token/region/language stored in `Bet188SharePreferences`

## Database (Room - "188asia_database" v17)
- `DraftDao` — Message drafts
- `StatementDao` — Cached statements
- `DashboardAlertDao` — Dashboard alerts
- `RegistrationRegionDao`, `RegistrationCurrencyDao` — Registration data
- `RoomDbHelper` — Singleton access, destructive migration allowed
- Safe wrappers: `StatementDaoChecked`, `DashboardAlertDaoChecked`

## Build
- Single module `:app`, Kotlin 1.9.24, SDK 34 / minSdk 28
- Flavors: dev, qat (default), red, uat, prod
- Key libs: OkHttp 3.8.0, Gson 2.5, Koin 3.5.6, Room 2.5.2, Coroutines 1.8.1, Firebase, JPush 5.8.0, Jumio 4.10.0, Glide 4.9.0

## Detailed Notes
See `revamp_architecture.md` for full details.
