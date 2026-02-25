# LiveData → StateFlow/SharedFlow Migration

Migrate the ViewModel for the feature: **$ARGUMENTS**

Follow these steps exactly. Read the full migration plan at:
`/Users/07404.chingting.chiu/.claude/projects/-Users-07404-chingting-chiu-Documents-AndroidStudioProject-android-188asia2/memory/livedata_to_stateflow_migration.md`

---

## Step 0 — Pre-flight: collect all facts

1. `grep -rn "<ViewModelName>"` to find every Activity/Fragment using this ViewModel.
2. Read each layout XML bound to this ViewModel (`binding.vm = ...`):
   - Find every `android:onClick="@{vm::someMethod}"` — these emit effects that ALL screens must handle.
   - Find every `android:visibility / android:text / ...` bound to VM fields — these must stay as LiveData (Category A).
3. Read every Activity/Fragment using the ViewModel:
   - List all `mViewModel.xxx.observe(...)` calls.
   - List all `mViewModel.xxx.value = ...` mutations from outside the VM (result callbacks, adapter clicks, etc.).
4. Read the ViewModel itself fully.
5. Check if the ViewModel already has a nested sealed class (e.g., `XxxResult`) — if so, it will be **converted** into `XxxEffect` (not kept alongside it).

## Step 1 — Classify all MutableLiveData fields

| Category | Rule | Action |
|---|---|---|
| A | Used in XML `@{vm.field}` OR mutated from outside the VM | **Keep as MutableLiveData** |
| B | Ongoing UI state (loading, enabled/disabled) | Move to `XxxUiState` data class |
| C | One-time events (navigation, errors, dialogs) | Move to `XxxEffect` sealed interface |

**Special case**: if `ListPopupWindow.setChooserAdapter(list, liveData)` uses the field → must stay Category A.

**`progressDialogObservable` (from BaseViewModel)**: even though it lives in BaseViewModel and is shared, override `setProgressStatus` in the target ViewModel to drive `_state.isLoading` instead. Remove `progressDialogObservable.observe(...)` from every view that uses this ViewModel; replace with `state.collect`.

## Step 2 — Add `XxxUiState` and `XxxEffect` to the ViewModel file

**Do NOT create a separate `XxxModels.kt` file.** Place both declarations as **top-level** in the same `.kt` file as the ViewModel, at the bottom.

If the ViewModel already has a nested sealed class (e.g., `sealed class XxxResult { ... }`):
- **Remove** it entirely.
- Replace all its usages with the new `XxxEffect` entries.

```kotlin
// bottom of XxxViewModel.kt, outside the class body:

data class XxxUiState(
    val isLoading: Boolean = false
    // add other B-category fields
)

sealed interface XxxEffect {
    // Navigation
    data object NavigateToFoo : XxxEffect
    data class NavigateToBar(val token: String) : XxxEffect

    // Results / one-time events
    data object SomeSuccess : XxxEffect

    // Dialogs (replaces DialogUtil calls that needed Activity context)
    data class ShowErrorDialog(
        val title: CharSequence,
        val message: CharSequence,
        val buttonText: CharSequence? = null,  // null = use default OK string in the view
        val requestCode: Int = 0
    ) : XxxEffect
    data object ShowNetworkErrorDialog : XxxEffect
}
```

## Step 3 — Refactor the ViewModel

- Store `context.applicationContext`, not Activity context.
- Add `_state`, `state`, `_effects`, `effects`, and a `protected fun emitEffect(...)` helper.
- Override `setProgressStatus` to update `_state` (keeps BaseViewModel's `progressDialogObservable` untouched for other VMs).
- Replace every `progressDialogObservable.value = x` (inside the VM) → `_state.update { it.copy(isLoading = x) }`.
- Replace every `context as Activity` navigation call → `emitEffect(XxxEffect.NavigateTo...)`.
- Replace every `DialogUtil.showSimpleDialog(context, ...)` → `emitEffect(XxxEffect.ShowErrorDialog(...))`.
- Replace every `DialogUtil.showNetworkErrorDialog(context, ...)` → `emitEffect(XxxEffect.ShowNetworkErrorDialog)`.
- Replace every one-time LiveData result → `emitEffect(...)`.
- Remove any `IBaseXxx` interface from the ViewModel.
- For XML `android:onClick` handlers: use `view.context` **transiently** for `hideKeyboard`; emit an effect for the navigation.

```kotlin
private val _state = MutableStateFlow(XxxUiState())
val state = _state.asStateFlow()

private val _effects = MutableSharedFlow<XxxEffect>(extraBufferCapacity = 1)
val effects = _effects.asSharedFlow()

protected fun emitEffect(effect: XxxEffect) {
    viewModelScope.launch { _effects.emit(effect) }
}

override fun setProgressStatus(isInProgress: Boolean) {
    _state.update { it.copy(isLoading = isInProgress) }
}

open fun init(context: Context) {
    this.context = context.applicationContext
    // ...
}

// onClick bound in XML — use view.context transiently, emit for navigation:
fun onForgetClick(view: View) {
    view.context.hideKeyboard(view)
    emitEffect(XxxEffect.NavigateToForgotAccount)
}
```

## Step 4 — Refactor each View (Activity / Fragment)

For **every** screen using this ViewModel:

1. Remove `IBaseXxx` from the class declaration.
2. Remove observers for Category B/C LiveData (including `progressDialogObservable.observe`).
3. **Keep** observers for Category A LiveData.
4. If an external callback previously did `mViewModel.progressDialogObservable.value = x`, change it to `mViewModel.setProgressStatus(x)`.
5. Add inside `initData()`:

```kotlin
lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        launch { mViewModel.state.collect { render(it) } }
        launch { mViewModel.effects.collect { handleEffect(it) } }
    }
}

private fun render(state: XxxUiState) {
    if (state.isLoading) showLoadingDialog() else dismissLoadingDialog()
}

private fun handleEffect(effect: XxxEffect) {
    when (effect) {
        // Navigation effects: launch the target screen here
        // Dialog effects: call DialogUtil with `this` (Activity context)
        is XxxEffect.ShowErrorDialog -> {
            val btnText = effect.buttonText ?: getString(UiStr.TXTBTNCOMOK)
            DialogUtil.showSimpleDialog(this, effect.title, effect.message, btnText, effect.requestCode)
        }
        XxxEffect.ShowNetworkErrorDialog -> DialogUtil.showNetworkErrorDialog(this, DialogUtil.API_RETURN_FAIL)
        // handle only effects relevant to this screen; use else -> {} for the rest
        else -> {}
    }
}
```

6. **Timing rule**: if a result callback calls `openSuccessPage()` then `finish()`, remove `finish()` from the callback — call it inside the effect handler after launching the next screen.
7. **`requestCode` dialogs**: if a `ShowErrorDialog` carries a `requestCode` (e.g., `FAIL_TOO_MANY`), keep the existing `onPositiveButtonClicked(requestCode)` override — `DialogUtil` will still call it correctly.

## Step 5 — Audit every other screen using this ViewModel

- For each screen, list which effects its flows can trigger.
- Ensure `effects.collect` is present and handles those effects.
- Use `else -> {}` for effects that can never be emitted from that screen's context.
- Check every XML `android:onClick="@{vm::method}"` — the emitted effect must be handled in every screen that uses that layout.

## Step 6 — Delete unused callback interfaces

`grep -rn "IBaseXxx"` — if zero references remain, delete the file.

## Step 7 — Verification checklist

- [ ] No separate `XxxModels.kt` created — `XxxUiState` and `XxxEffect` are at the bottom of the ViewModel file.
- [ ] Old nested sealed class (e.g., `XxxResult`) fully removed; zero references remain.
- [ ] Every screen using the ViewModel collects `effects`.
- [ ] `progressDialogObservable.observe(...)` removed from every screen; replaced by `state.collect`.
- [ ] Every external `mViewModel.progressDialogObservable.value = x` changed to `mViewModel.setProgressStatus(x)`.
- [ ] Every `android:onClick="@{vm::method}"` has a handler in every screen using that layout.
- [ ] Loading dialog shows/hides correctly via `state.isLoading`.
- [ ] No Activity context stored in ViewModel (only `applicationContext`).
- [ ] `finish()` timing is correct — not called before effect is consumed.
- [ ] Dialog `requestCode` flows still reach `onPositiveButtonClicked` correctly.
