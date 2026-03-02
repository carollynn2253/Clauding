---
name: refactor
description: Refactor an Android Activity or Fragment to MVVM architecture with StateFlow/SharedFlow, UiState, and Effect patterns
argument-hint: [ActivityName or FragmentName]
---

Refactor **$ARGUMENTS** to MVVM architecture.

## Steps

1. Read the target Activity/Fragment and its XML layouts fully.
2. `grep -rn "<ClassName>"` to find every screen using the same ViewModel (if one exists).
3. Classify all `MutableLiveData` fields and interface callbacks:

| Category | Rule | Action |
|---|---|---|
| A | Used in XML `@{vm.field}` OR mutated from outside the VM | **Keep as MutableLiveData** |
| B | Ongoing UI state: loading, form state, state machine state, button visibility, error counts | Move to `XxxUiState` data class → `StateFlow` |
| C | One-time events: LiveData observed for navigation/errors/dialogs, or interface callbacks (`IBaseXxx`) cast from context | Move to `XxxEffect` sealed interface → `SharedFlow` |

4. Create or update the ViewModel:

   **StateFlow (Category B):**
   - `private val _state = MutableStateFlow(XxxUiState())` + `val state = _state.asStateFlow()`
   - UiState always includes `isLoading: Boolean` (replaces `progressDialogObservable`)
   - UiState may include more fields depending on the screen — use judgement:
     - Simple screens: just `isLoading`
     - Complex screens: form values, validation errors, button state, state machine enum, error counts, visibility flags
   - Replace `progressDialogObservable.value = true/false` with `_state.update { it.copy(isLoading = true/false) }`
   - If BaseViewModel has `setProgressStatus`, override it: `override fun setProgressStatus(isInProgress: Boolean) { _state.update { it.copy(isLoading = isInProgress) } }`
   - For complex UiState, add a private helper: `private fun update(newState: XxxUiState) { _state.value = newState }`

   **State machine pattern (for screens with distinct states):**
   - Define `enum class XxxState { STATE_A, STATE_B, ... }` in the ViewModel file
   - Include in UiState: `val state: XxxState = XxxState.INITIAL`
   - ViewModel action handlers use `when(s.state)` to determine behavior per state
   - Activity `render(state)` uses `when(state.state)` to update UI per state

   **SharedFlow (Category C):**
   - `private val _effects = MutableSharedFlow<XxxEffect>(extraBufferCapacity = 1)` + `val effects = _effects.asSharedFlow()`
   - Add helper: `protected fun emitEffect(effect: XxxEffect) { viewModelScope.launch { _effects.emit(effect) } }`
   - Each Effect should be a **specific named event** (`data object ShowUsernameExistsError`), NOT a wrapper around an enum/status (`data class RegisterResponseError(val status: ...)`)

   **Replace interface callbacks with Effects:**
   - `(context as IBaseXxx).openXxx()` → `emitEffect(XxxEffect.OpenXxx)`
   - `(context as IBaseXxx).checkIsEnableBtn()` → `emitEffect(XxxEffect.RefreshButtonState)`

   **Replace Activity references with Effects:**
   - `LoginActivity.launchClearTop(context as Activity)` → `emitEffect(XxxEffect.NavigateToLogin)`
   - `OAuthRegisterActivity.launch(context as Activity, data)` → `emitEffect(XxxEffect.LaunchOAuthRegister(data))`
   - `SimpleWebActivity.launch(context as Activity, obj)` → `emitEffect(XxxEffect.OpenSimpleWeb(obj))`
   - `RegisterSuccessWebActivity.launchClearTop(context as Activity, obj)` → `emitEffect(XxxEffect.OpenSuccessPage(obj))`

   **Replace one-time LiveData with Effects:**
   - `registerResponseStatus.value = status` → emit individual Effects per status (`ShowUsernameExistsError`, `ShowEmailExistsError`, etc.)
   - `isRegisterLoginSuccess.value = true/false` → `emitEffect(XxxEffect.OpenLockPatternSetting)` / `emitEffect(XxxEffect.ShowLoginFailed)`
   - `loginReturnStatus.value = LoginResult.Success` → `emitEffect(LoginEffect.LoginSuccess)`

   **Context handling:**
   - Rename `context` to `appContext`, assign from `context.applicationContext` in `init()`
   - For XML `android:onClick` handlers: use `view.context.hideKeyboard(view)` or `appContext.hideKeyboard(view)` transiently
   - Remove all `context as Activity` casts — use Effects for navigation instead

   **If multiple Activities share the same ViewModel:** do NOT create separate ViewModels. Only create a new ViewModel when the Activity has no existing ViewModel or is functionally independent.

5. Refactor each Activity/Fragment:

   **Add StateFlow + SharedFlow collection:**
   ```kotlin
   lifecycleScope.launch {
       repeatOnLifecycle(Lifecycle.State.STARTED) {
           launch { mViewModel.state.collect { state -> render(state) } }
           launch { mViewModel.effects.collect { effect -> handleEffect(effect) } }
       }
   }
   ```

   **Add `render(state)` method:**
   ```kotlin
   private fun render(state: XxxUiState) {
       if (state.isLoading) showLoadingDialog() else dismissLoadingDialog()
   }
   ```

   **Add `handleEffect(effect)` method** with exhaustive `when`:
   - Navigation effects → call Activity launch methods directly
   - Error effects → set errors on views, show dialogs, call `checkIsEnableRegisterBtn()`
   - Each error effect handler should also refresh captcha if applicable

   **Remove old observers:**
   - Remove `progressDialogObservable.observe(this) { ... }` — replaced by `render(state)`
   - Remove `registerResponseStatus.observe(this) { ... }` — replaced by Effect handling
   - Remove `isRegisterLoginSuccess.observe(this) { ... }` — replaced by Effect handling
   - Keep `observe()` for Category A LiveData (selectedRegion, selectedCurrency, legalAge, etc.)

   **Remove interface implementations:**
   - Remove `IBaseXxx` from class declaration
   - Change `override fun` to `open fun` or `private fun` for methods that were in the interface

   **Form logic — decide per screen:**
   - If form validation reads directly from views (e.g., `binding.email.text`, `binding.emailLayout.error`) and works fine, keep it in Activity
   - If form validation involves business rules or complex logic, move to ViewModel with UiState fields
   - Use judgement — simple view-level validation stays in Activity, complex screens may need UiState

6. **File placement:**
   - `XxxUiState` and `XxxEffect` together in a separate file under `model/data/` (e.g., `RegisterModels.kt`, `LoginModels.kt`)
   - Related enums (e.g., state machine states) can go in the same models file or the ViewModel file

7. Verify against the mandatory checklist before completing.
