## What does this PR do?
<!-- Brief description -->

## Checklist

### Security
- [ ] No API keys, secrets, or credentials in code or comments
- [ ] Firestore queries are scoped to the authenticated user (`userId` filter — never query all users)
- [ ] No user-controlled input passed directly to Firestore queries without validation
- [ ] Firebase security rules updated if data model changed (check `firestore.rules`)
- [ ] HTTP requests use HTTPS only; no hardcoded URLs with credentials

### Clean Code
- [ ] No dead code, commented-out blocks, or unused imports
- [ ] No magic numbers — use constants from `app_constants.dart`
- [ ] Widget/function does one thing; split if it exceeds ~80 lines
- [ ] Provider state is not mutated directly — only via notifier methods
- [ ] No logic inside `build()` — extracted to providers or helpers

### Data & Finance Logic
- [ ] Monetary values use `double` consistently; no int/string mixing
- [ ] Price refresh calls go through `PriceRefreshService`, not ad-hoc HTTP
- [ ] New asset types registered in `known_assets.dart` if applicable
- [ ] Date formatting uses `DateFormatter` utility, not raw `DateTime.toString()`

### Flutter / Performance
- [ ] No `setState` in screens that use Riverpod
- [ ] `const` constructors used where possible
- [ ] No `print()` calls — use proper logging or remove
- [ ] Images use `CachedNetworkImage`, not `Image.network`

### Testing
- [ ] New business logic has at least one unit test
- [ ] Widget tests updated if UI structure changed
