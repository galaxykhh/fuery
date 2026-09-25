## 1.5.1
- Released with `fuery_core` 1.5.1. `useQuery`, `useInfiniteQuery`, `useQueries`, and `useMutation` rebuild faster: they no longer hash a key built again with the same content. `useMutationState` and `useOnMutationStateChange` stay fast with many runs in the cache.

## 1.5.0
- Add `useMutationState(mutation)`, which returns the state of every run of a mutation, oldest first, wherever the run was started. It finds the runs by the `mutationKey` or by `MutationFilters`.
- Add `useOnQueryChange`, `useOnMutationChange`, and `useOnMutationStateChange` for side effects, such as a snackbar or navigation. They follow the rules of the listener widgets. `useOnQueryChange` takes the result of `useQuery` or `useInfiniteQuery`, and `useOnMutationChange` that of `useMutation`. `useOnMutationStateChange` hears every run of a mutation, as `MutationStateListener` does. The listener runs after a change, with the widget's own `context`, never during a build or for the result at mount.
- Export `FueryFocusManager`. `FocusManager` still means Flutter's class.

## 1.4.4
- First release: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useQueryClient` render Fuery's queries and mutations in a `HookWidget`. Released and versioned together with `fuery` and `fuery_core`.
- In debug builds, a hook warns once when it gets an observer created in `build`, which subscribes again on every rebuild, or an observer of another client than the one it uses.
- `fuery_hooks.dart` re-exports `fuery` without Fuery's `FocusManager` class, whose name Flutter uses too; the `focusManager` singleton is exported.
