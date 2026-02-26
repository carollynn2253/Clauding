# Android MVVM Refactor Agent Memory

## Project: android-188asia2 (Bet188)
- DI framework: **Koin** (`org.koin.androidx.viewmodel.ext.android.viewModel`)
- Base classes: `BaseViewModel` (extends ViewModel, implements IOAuthBaseListener, KoinComponent), `BaseBindingHeaderActivity`, `BaseBindingActivity`
- Navigation: Manual Intent-based (no Navigation Component)
- Naming: ViewModels named `XxxViewModel`, Repos named `XxxRepository`

## Key Pattern: ListPopupWindow requires MutableLiveData
- `ListPopupWindow.setChooserAdapter(dataList, MutableLiveData<T>)` forces the selected item field to stay as MutableLiveData (Category A).
- Cannot migrate to StateFlow if the popup widget writes directly to the LiveData.

## Category A Classification Gotcha
- Fields used in XML data binding (`@{vm.field}`) MUST remain as MutableLiveData.
- Fields mutated from outside the VM (e.g., Activity sets `mViewModel.selectedRegion.value = ...`) must also stay as MutableLiveData.
- These are easy to miss -- always check XML layouts and Activity code for external mutations.

## Context Storage
- Always store `context.applicationContext` in the ViewModel, never the Activity reference.
- For `hideKeyboard` in onClick methods, use `view.context` transiently instead of stored context.

## Callback Interface Removal Pattern
- When an interface like `IBaseRegister` is used only for VM-to-View callbacks via `context as IBaseRegister`, it can be fully replaced by Effect emissions.
- Verify no other files reference the interface before deleting.
- After refactoring RegisterActivity/OAuthRegisterActivity, `IBaseRegister.kt` became dead code.

## Event Wrapper Location
- Created `Event<T>` wrapper at `revamp/model/data/Event.kt`.
- All Effect sealed classes live in `revamp/viewmodel/` (e.g., `RegisterEffect.kt`, `RegionSearchEffect` inside `RegionSearchViewModel.kt`).

## Register Flow Architecture (Post-Refactor)
- `RegisterViewModel` uses `_effect: MutableLiveData<Event<RegisterEffect>>` for one-time navigation/dialog events.
- Activities observe `effect` LiveData and handle navigation, dialogs, finish, etc.
- XML `android:onClick="@{vm::onXxxClick}"` handlers emit Effects instead of casting context.
- `performGoogleSignIn` still needs Activity parameter (Google OAuth SDK requirement).
- Facebook OAuth callback stays in Activity (SDK callback interface pattern).

## SPI Callback Pattern
- API calls use `SpiResponse<T>` callback pattern (not coroutines/suspend).
- Repository methods accept Context + callback, return via `onResponse`.
- `progressDialogObservable` in BaseViewModel controls loading dialog show/dismiss.
