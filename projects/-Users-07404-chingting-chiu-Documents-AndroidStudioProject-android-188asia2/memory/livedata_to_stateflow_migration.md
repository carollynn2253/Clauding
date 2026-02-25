# LiveData → StateFlow/SharedFlow Migration Plan

Derived from the Register feature refactoring. Apply this pattern to any ViewModel in `revamp/`.

---

## 0. Pre-flight checklist

Before touching any code, collect these facts:

| Item | Where to look |
|---|---|
| All Activities/Fragments using this ViewModel | `grep -rn "ViewModelName"` |
| All XML layouts bound to this ViewModel (`binding.vm = ...`) | Read each layout's `<data>` block |
| Every `android:onClick="@{vm::someMethod}"` in those XMLs | Search for `vm::` in the layout file |
| Every `android:visibility / android:text / ...` bound to VM fields | Search for `vm.` in the layout file |
| Every `mViewModel.xxx.observe(...)` in the Activity/Fragment | Read initData() |
| Every `mViewModel.xxx.value = ...` set from outside (result callbacks) | Read all `registerForActivityResult` blocks |

---

## 1. Classify existing LiveData fields

Split every `MutableLiveData` into one of three categories:

### A — Keep as LiveData (DataBinding / external mutation)
Used directly in XML expressions (`@{vm.field}`) **or** mutated from outside the VM
(e.g. `mViewModel.selectedRegion.value = ...` in an Activity result callback,
or `ListPopupWindow.setChooserAdapter(list, mViewModel.selectedCurrency)`).

→ **Leave untouched.** DataBinding observes LiveData natively.

### B → State (ongoing / renderable UI state)
Values that describe the *current* screen condition (loading, enabled/disabled, etc.)
that the View should re-render whenever they change.

→ Move into `data class XxxUiState(...)` + `MutableStateFlow<XxxUiState>`.

### C → Effect (one-time events)
Navigation, dialogs, error toasts — things that happen *once* and must not replay
on config change or lifecycle re-entry.

→ Move into `sealed interface XxxEffect` + `MutableSharedFlow<XxxEffect>`.

**Typical mapping:**

| Old field | Category | Notes |
|---|---|---|
| `progressDialogObservable` | B → `isLoading` | Replace all `progressDialogObservable.value = x` with `_state.update { it.copy(isLoading = x) }` |
| `registerResponseStatus` | C | One-time API result → individual Effect variants |
| `isRegisterLoginSuccess` | C | One-time login result → Effect |
| `selectedRegion / selectedCurrency` | A | Bound in XML + mutated by ListPopupWindow / result callbacks |

---

## 2. Create the Models file

Create `model/data/XxxModels.kt` alongside existing data files:

```kotlin
// Only fields NOT already covered by LiveData (category A)
data class XxxUiState(
    val isLoading: Boolean = false
    // add other B-category fields here
)

sealed interface XxxEffect {
    // Navigation (from click handlers that used to call context as Activity)
    data object NavigateToFoo : XxxEffect
    data class OpenSimpleWeb(val obj: SimpleWebObject) : XxxEffect

    // API response errors (from SpiResponse callbacks)
    data object ShowSomeError : XxxEffect

    // Post-action flows
    data object OpenNextScreen : XxxEffect
}
```

---

## 3. Refactor the ViewModel

### 3a. Store ApplicationContext, not Activity context
```kotlin
// Before
private lateinit var context: Context
fun init(context: Context) { this.context = context }

// After
private lateinit var appContext: Context
fun init(context: Context) { appContext = context.applicationContext }
```

### 3b. Add StateFlow + SharedFlow
```kotlin
private val _state = MutableStateFlow(XxxUiState())
val state: StateFlow<XxxUiState> = _state.asStateFlow()

private val _effects = MutableSharedFlow<XxxEffect>(extraBufferCapacity = 1)
val effects: SharedFlow<XxxEffect> = _effects.asSharedFlow()
```

### 3c. Replace loading LiveData
```kotlin
// Before
progressDialogObservable.value = true
// After
_state.update { it.copy(isLoading = true) }
```

### 3d. Replace IBaseXxx callback interface → emit Effects
```kotlin
// Before
(context as IBaseXxx).openFooScreen()
// After
viewModelScope.launch { _effects.emit(XxxEffect.OpenFooScreen) }
```

### 3e. Replace navigation calls that used Activity context → emit Effects
```kotlin
// Before
FooActivity.launch(context as Activity, data)
// After
viewModelScope.launch { _effects.emit(XxxEffect.NavigateToFoo(data)) }
```

### 3f. Replace one-time LiveData results → emit Effects (inside SpiResponse callbacks)
```kotlin
// Before
someResultLiveData.value = Result.ERROR
// After
viewModelScope.launch { _effects.emit(XxxEffect.ShowSomeError) }
```

---

## 4. Refactor each View (Activity / Fragment)

### 4a. Remove IBaseXxx from class declaration
```kotlin
// Before
class FooActivity : BaseBindingHeaderActivity<...>(), IBaseXxx { ... }
// After
class FooActivity : BaseBindingHeaderActivity<...>() { ... }
```

### 4b. Replace progressDialogObservable observer with state collector
```kotlin
// REMOVE
mViewModel.progressDialogObservable.observe(this) { isShow ->
    if (isShow) showLoadingDialog() else dismissLoadingDialog()
}

// ADD inside initData()
lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        launch { mViewModel.state.collect { render(it) } }
        launch { mViewModel.effects.collect { handleEffect(it) } }
    }
}

private fun render(state: XxxUiState) {
    if (state.isLoading) showLoadingDialog() else dismissLoadingDialog()
    // bind other state fields
}
```

### 4c. Remove one-time LiveData observers; handle in handleEffect()
```kotlin
// REMOVE
mViewModel.someResultLiveData.observe(this) { result -> ... }

// ADD to handleEffect()
is XxxEffect.ShowSomeError -> { /* show dialog / set field error */ }
```

### 4d. Keep category-A LiveData observers unchanged
```kotlin
// KEEP — these are still MutableLiveData
mViewModel.selectedRegion.observe(this) { region -> checkRegion(region) }
```

### 4e. Keep category-A external mutations unchanged
```kotlin
// KEEP — still MutableLiveData set from result callback
mViewModel.selectedRegion.value = parsedRegion
```

---

## 5. Check EVERY other screen that uses this ViewModel

This is the most common mistake. A ViewModel is often reused across multiple screens.

For each screen using the ViewModel:
1. List all ViewModel methods it calls
2. Determine which effects those methods can emit
3. Add a `repeatOnLifecycle(STARTED) { effects.collect { ... } }` block
4. Handle only the effects relevant to that screen; use `else -> {}` for the rest

**Key lesson from Register refactoring:**
`RegisterTypeSelectActivity` reused `RegisterViewModel` but only got `LaunchOAuthRegister` fixed initially.
A second pass found `NavigateToLogin` was also missing because `btn_login` in the XML was
bound via `android:onClick="@{vm::onLoginClick}"` — always scan the XML.

---

## 6. Delete unused callback interfaces

If the `IBaseXxx` interface was only used for ViewModel→View callbacks, delete it.
Verify with `grep -rn "IBaseXxx"` before deleting.

---

## 7. Verification checklist

- [ ] `grep -rn "InterfaceName"` returns no references (deleted interface gone)
- [ ] `grep -rn "removedLiveData"` returns no references
- [ ] Every screen using the ViewModel has `effects.collect { ... }` with all relevant effects handled
- [ ] Every XML `android:onClick="@{vm::someMethod}"` that emits an effect has a handler in every screen using that layout
- [ ] Loading dialog shows/hides correctly (state.isLoading path works)
- [ ] No Activity context stored in ViewModel (only ApplicationContext)

---

## Pitfalls

| Pitfall | Fix |
|---|---|
| Effect emitted but no subscriber → silent no-op | Ensure EVERY screen using the VM collects effects |
| XML DataBinding calls VM method that emits effect | Scan XML for `vm::` and `vm.` expressions |
| `ListPopupWindow.setChooserAdapter(list, liveData)` needs MutableLiveData | Keep those fields as LiveData (category A) |
| `finish()` called before `OpenSuccessPage` effect is consumed | Remove `finish()` from result handler; call it inside the effect handler after launching the next screen |
| `openSuccessPage()` uses `context as Activity` | Convert to effect; Activity handles `startActivity + finish()` in effect handler |
