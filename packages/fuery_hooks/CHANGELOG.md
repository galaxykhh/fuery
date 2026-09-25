## 1.5.1
- Released with the performance improvements of `fuery_core` 1.5.1: `useQuery`, `useInfiniteQuery`, `useQueries`, and `useMutation` no longer hash a key built again with the same content on every build, and `useMutationState` and `useOnMutationStateChange` stay fast with many runs in the cache.

## 1.5.0
- Add `useMutationState(mutation)`. It returns the state of every run of a mutation, found by its `mutationKey` or by `MutationFilters`, oldest first, wherever the run was started.
- Add `useOnQueryChange`, `useOnMutationChange`, and `useOnMutationStateChange` for side effects, such as a snackbar or navigation, with the rules of the listener widgets. The first two take the result of `useQuery`, `useInfiniteQuery`, or `useMutation`; `useOnMutationStateChange` hears every run of a mutation, as `MutationStateListener` does. The listener runs after a change, never during a build and not for the result at mount, with the widget's own `context`.
- Exports `FueryFocusManager`. `FocusManager` still means Flutter's class.

## 1.4.4
- First release: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useQueryClient` render Fuery's queries and mutations in a `HookWidget`. Released and versioned together with `fuery` and `fuery_core`.
- In debug builds, a hook warns once when it gets an observer created in `build`, which subscribes again on every rebuild, or an observer of another client than the one it uses.
- `fuery_hooks.dart` re-exports `fuery` without Fuery's `FocusManager` class, whose name Flutter uses too; the `focusManager` singleton is exported.
