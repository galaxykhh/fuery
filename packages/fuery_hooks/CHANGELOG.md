## Unreleased
- Fix: `fuery_hooks.dart` no longer exports Fuery's `FocusManager` class, whose name clashed with Flutter's; the `focusManager` singleton is still exported.
- Debug warnings: the warning about observers created on every rebuild also covers `useQueries` and explains the effect for `useMutation`, and a hook given an observer of another client than the one it uses warns, once per hook and key. A new observer made for a replaced client, such as `useMemoized(() => todosQuery.observe(client: client), [client])`, doesn't count as recreated.
- Released together with `fuery_core`'s fixes, among them: a listener that throws no longer freezes `useQueries` or other hooks notified in the same batch.

## 1.4.3
- First release: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useQueryClient` render Fuery's queries and mutations in a `HookWidget`. Released and versioned together with `fuery` and `fuery_core`.
