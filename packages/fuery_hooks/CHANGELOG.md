## 1.5.0
- Add `useMutationState(mutation, listener:, listenWhen:)`. It returns the state of every run of a mutation, found by its `mutationKey` or by `MutationFilters`, oldest first, wherever the run was started. Its listener is called once for each run that changes, as `MutationStateListener`'s is.
- `useQuery`, `useInfiniteQuery`, and `useMutation` take `listener` and `listenWhen`, with the rules of the listener widgets, and share the hook's observer. The listener runs after a change, never during a build and not for the result at mount, with the widget's own `context`. For a mutation definition, it hears the runs started from the hook's own result. A listener that throws is reported to the client's `onUncaughtError`.
- Exports `FueryFocusManager`. `FocusManager` still means Flutter's class.

## 1.4.4
- First release: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useQueryClient` render Fuery's queries and mutations in a `HookWidget`. Released and versioned together with `fuery` and `fuery_core`.
- In debug builds, a hook warns once when it gets an observer created in `build`, which subscribes again on every rebuild, or an observer of another client than the one it uses.
- `fuery_hooks.dart` re-exports `fuery` without Fuery's `FocusManager` class, whose name Flutter uses too; the `focusManager` singleton is exported.
