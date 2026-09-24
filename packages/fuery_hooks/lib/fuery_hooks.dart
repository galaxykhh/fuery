/// Hooks for Fuery: `useQuery`, `useInfiniteQuery`, `useMutation`, and
/// `useQueries` for `flutter_hooks`.
library;

// Flutter has a FocusManager class too, and FocusManager is also the deprecated
// former name of FueryFocusManager, so this library leaves it out: FocusManager
// means Flutter's class. FueryFocusManager and the focusManager singleton stay.
export 'package:fuery/fuery.dart' hide FocusManager;

export 'src/hooks.dart' hide debugResetHookWarnings;
