## 1.4.4
- First release: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useQueryClient` render Fuery's queries and mutations in a `HookWidget`. Released and versioned together with `fuery` and `fuery_core`.
- In debug builds, a hook warns once when it gets an observer created in `build`, which subscribes again on every rebuild, or an observer of another client than the one it uses.
- `fuery_hooks.dart` re-exports `fuery` without Fuery's `FocusManager` class, whose name Flutter uses too; the `focusManager` singleton is exported.
