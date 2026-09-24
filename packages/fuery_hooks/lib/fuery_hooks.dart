/// Hooks for Fuery: `useQuery`, `useInfiniteQuery`, `useMutation`,
/// `useQueries`, and `useMutationState` for `flutter_hooks`.
library;

// Flutter has a FocusManager class too, so a file that imports material and
// this library could not name either. The focusManager singleton stays.
export 'package:fuery/fuery.dart' hide FocusManager;

export 'src/hooks.dart' hide debugResetHookWarnings;
