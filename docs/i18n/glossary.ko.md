# 한국어 용어집

Fuery 문서를 한국어로 옮길 때 쓰는 용어와 문장 규칙이에요. 번역 절차는 [docs/AGENTS.md의 Translations](../AGENTS.md#translations)를 따르고, 문장은 [토스 테크니컬 라이팅 가이드](https://technical-writing.dev/)를 따라요.

## 기본 원칙

- 영어 페이지가 말하는 것만 옮겨요. 원문에 없는 주장, 비교, 설명을 더하지 않고, 원문에 있는 내용을 빼지 않아요.
- 용어는 이 파일에 적힌 대로 써요. 같은 개념을 페이지마다 다르게 옮기지 않아요.
- 이 파일에 없는 용어를 처음 옮기면, 그 번역을 추가하는 변경에서 이 파일에도 추가하세요.
- 사이드바 라벨(`astro.config.mjs`)과 페이지 제목 뒤에 붙는 문구(`src/routeData.ts`)도 이 파일의 표현을 써요.
- TanStack Query는 영어 원문이 언급하는 곳에서, 원문이 말하는 만큼만 언급해요. Fuery를 TanStack Query의 포팅, 클론, Flutter 버전이라고 부르지 않아요. "TanStack Query처럼 동작해요", "TanStack Query보다 가벼워요"처럼 비교하는 문장도 더하지 않아요.

## 영어 그대로 두는 것

- 코드 블록 전체. 코드 속 주석도 옮기지 않아요.
- API 이름과 식별자: `QueryClient`, `staleTime`, `mutate`, `fuery_core`. 영어 원문처럼 인라인 코드로 써요.
- 파일 이름, 경로, 명령어.
- Fuery, Flutter, Dart가 출력하는 메시지: `StateError: Query holds X, but was requested as Y`, `A Timer is still pending even after the widget tree was disposed`.
- 제품과 패키지 이름: Fuery, Flutter, Dart, pub.dev, GitHub, TanStack Query, React Query, React, `flutter_hooks`, `connectivity_plus`, `shared_preferences`, `fake_async`. 패키지 이름은 영어 원문처럼 인라인 코드로 써요.
- Bloc과 Cubit. 영어 원문이 소문자로 쓴 곳(cubits and blocs)도 "Cubit과 Bloc"처럼 대문자로 시작해요.
- 상태 값과 enum 값: `pending`, `success`, `error`, `idle`, `fetching`, `paused`. 문장에서는 "`pending` 상태"처럼 써요.
- 개발자 도구 화면에 보이는 문구: Queries 탭, Mutations 탭, Refetch, Invalidate, Reset, Remove 버튼, 상태 표시 `fetching`, `paused`, `inactive`, `disabled`, `stale`, `fresh`. 문서가 화면과 같은 말을 써야 독자가 화면에서 찾을 수 있어요.
- 앱 화면의 문자열: "Buy milk", *Adding…*.
- 용어로 쓰는 stale, fresh, zone, enum, getter, assert, tear-off.
- 레퍼런스 사이드바의 "fuery API", "fuery_core API", "fuery_hooks API".

## 고정된 표현

| 영어 | 한국어 | 쓰는 곳 |
|---|---|---|
| Concepts | 개념 | 사이드바 그룹 |
| Guides | 가이드 | 사이드바 그룹 |
| Reference | 레퍼런스 | 사이드바 그룹, "QueryClient reference"는 "QueryClient 레퍼런스" |
| Example app | 예제 앱 | 사이드바 링크 |
| Fuery for Flutter | Flutter용 Fuery | 페이지 제목 뒤(`src/routeData.ts`) |
| Built the Flutter way | Flutter 방식 그대로 | 홈 카드 제목 |
| Fuery is built the Flutter way. | Fuery는 Flutter 방식을 그대로 따라요. | 문장 |
| Nothing beyond Dart and Flutter | Dart와 Flutter만 있으면 돼요 | 홈 카드 제목 |
| Fuery depends on nothing beyond Dart and Flutter. | Fuery는 Dart와 Flutter에만 의존해요. | 문장. 주어가 패키지면 "`fuery`는 Dart와 Flutter에만 의존해요." |
| Fuery's caching and refetching model is inspired by TanStack Query. | Fuery의 캐싱과 다시 가져오기 모델은 TanStack Query에서 영감을 받았어요. | 홈, TanStack Query에서 넘어왔다면 |
| Why Fuery | Fuery를 쓰는 이유 | 홈 제목 |
| Get started | 시작하기 | 홈 버튼 |
| Try the demo | 데모 사용해보기 | 홈 버튼, 다음 단계 |
| View on GitHub | GitHub에서 보기 | 홈 버튼 |
| Next steps | 다음 단계 | 페이지 끝 제목 |
| In the example app | 예제 앱에서 | 페이지 끝 제목 |
| Its README maps each screen to what it shows. | 화면마다 보여주는 기능은 예제의 README에 있어요. | 예제 앱에서 |

## 용어

### 캐시의 구성 요소

[캐시가 동작하는 방식](../src/content/docs/how-the-cache-works.md)의 첫 표에 나오는 용어예요. 페이지마다 처음 나오는 곳에서 뜻을 밝혀요.

| 영어 | 한국어 | 메모 |
|---|---|---|
| query | 쿼리 | 서버 데이터의 정의(`Query`, `InfiniteQuery`). "요청"이나 "fetcher"로 옮기지 않아요. |
| definition | 정의 | 무엇을 가져오거나 바꿀지 담은 객체. "query definition"은 "쿼리 정의"예요. |
| mutation | 뮤테이션 | 서버 데이터를 바꾸는 정의(`Mutation`, `NoVariablesMutation`). "변경", "변이"로 옮기지 않아요. |
| client | 클라이언트 | `QueryClient`. "the default client"는 "기본 클라이언트"예요. |
| cache | 캐시 | "query cache"는 "쿼리 캐시", "mutation cache"는 "뮤테이션 캐시"예요. |
| cache entry | 캐시 항목 | 한 클라이언트에서 한 키의 데이터와 상태(`CachedQuery`). "항목"으로 줄이지 않고, "캐시 엔트리", "캐시된 쿼리"로 쓰지 않아요. |
| observer | 옵저버 | 정의와 클라이언트 하나를 잇는 객체. "관찰자"로 옮기지 않아요. |
| result | 결과 | 옵저버가 알리는 상태와 액션(`QueryResult`, `InfiniteQueryResult`, `MutationResult`). |
| run | 실행 | `mutate` 호출 한 번과 그 변수, 상태(`CachedMutation`). 페이지에서 처음 나올 때 "실행(`mutate` 호출 한 번)"처럼 뜻을 밝혀요. "런"으로 쓰지 않아요. |
| call | 호출 | "one call"은 "호출 한 번"이에요. |
| action | 액션 | 결과에 있는 메서드: `refetch()`, `fetchNextPage()`, `mutate`. |
| slot | 슬롯 | `ObserverSlot`, `QuerySlot`, `MutationStateSlot`. |
| adapter | 어댑터 | |

### 쿼리와 캐시

| 영어 | 한국어 | 메모 |
|---|---|---|
| query key, key | 쿼리 키, 키 | |
| query function | 쿼리 함수 | `queryFn` |
| query function context | 쿼리 함수 컨텍스트 | `QueryFunctionContext` |
| data | 데이터 | |
| state | 상태 | `QueryState`, `MutationState` |
| status | 상태 | 필드를 가리킬 때는 `status`, `fetchStatus`로 써요. |
| request | 요청 | 쿼리 함수가 서버에 보내는 요청. fetch(가져오기)와 구분해요. |
| response | 응답 | |
| stale | stale | "stale 상태", "stale 데이터"처럼 영어로 써요. `isStale`, `staleTime`, 필터 `stale`, 개발자 도구의 상태 표시와 같은 말이에요. "stale한", "오래된", "신선하지 않은"으로 쓰지 않아요. |
| fresh | fresh | "fresh 상태", "fresh 데이터"처럼 써요. "신선한", "최신"으로 쓰지 않아요. "a fresh client"처럼 '새로 만든'이라는 뜻이면 "새 클라이언트"로 옮겨요. |
| freshness | fresh 상태인지 | "judges freshness"는 "fresh 상태인지 판단해요"예요. |
| stale time | `staleTime` | 항상 코드로 써요. |
| garbage collection time | 가비지 컬렉션 시간 | `gcTime`. 페이지에서 처음 나올 때 "`gcTime`(가비지 컬렉션 시간)"으로 써요. |
| garbage collection | 가비지 컬렉션 | "쓰레기 수집"으로 쓰지 않아요. |
| query lifecycle | 쿼리 생명주기 | |
| stage | 단계 | |
| active, inactive | 활성, 비활성 | 켜진 옵저버가 하나 이상 있는 캐시 항목과 하나도 없는 캐시 항목. `QueryTypeFilter.active` |
| in use | 사용 중인 | |
| enabled, disabled | 켜진, 꺼진 | `enabled` 옵션. "turned off"도 "꺼진"이에요. "비활성"은 inactive에 쓰니 쓰지 않아요. 버튼은 "비활성화해요". |
| placeholder data | 플레이스홀더 데이터 | `placeholderData` |
| initial data | 초기 데이터 | `initialData` |
| structural sharing | 구조적 공유 | `structuralSharing` |
| default, defaults | 기본값 | "per-key defaults"는 "키별 기본값"이에요. |
| option | 옵션 | |
| filter | 필터 | "query filters"는 "쿼리 필터"예요. |
| prefix | 접두사 | "key prefix"는 "키 접두사"예요. |
| match | 조건에 맞는 캐시 항목 | "the matches"는 "조건에 맞는 캐시 항목", 뮤테이션이면 "조건에 맞는 실행"이에요. 동사는 "일치하다", "조건에 맞다"예요. |
| predicate | `predicate`, 조건 함수 | |
| retry | 재시도 | "retry policy"는 "재시도 정책"이에요. |
| attempt | 시도 | "failed attempt"는 "실패한 시도"예요. |
| failure | 실패 | |
| error | 에러 | "오류"로 쓰지 않아요. |
| cancellation | 취소 | |
| signal | `signal` | `AbortSignal`. 코드로 써요. |
| polling | 폴링 | `refetchInterval` |
| interval | 간격 | "on every refetchInterval tick"은 "`refetchInterval` 간격마다"예요. |
| trigger | 트리거 | 다시 가져오게 하는 일: 마운트, 포커스, 재연결. |
| infinite query | 무한 쿼리 | |
| page | 페이지 | |
| page param | 페이지 파라미터 | `pageParam`. 함수의 매개변수(parameter)와 구분해요. |
| cursor | 커서 | "cursor-based pages"는 "커서 기반 페이지"예요. |
| infinite scroll | 무한 스크롤 | |
| pagination | 페이지네이션 | |
| streamed query | 스트림 쿼리 | `streamedQuery` |
| stream | 스트림 | 타입을 가리키면 `Stream`으로 써요. |
| chunk | 청크 | |

### 뮤테이션

| 영어 | 한국어 | 메모 |
|---|---|---|
| mutation key | 뮤테이션 키 | `mutationKey` |
| mutation function | 뮤테이션 함수 | `mutationFn` |
| variables | 변수 | 뮤테이션에 넘기는 값(`TVariables`). |
| context | 컨텍스트 | `onMutate`가 반환한 값. 인수 이름은 `context`로 써요. |
| callback | 콜백 | |
| optimistic update | 낙관적 업데이트 | |
| rollback | 롤백 | 동사는 "롤백하다"예요. |
| scope | 스코프 | `MutationScope` |
| MutationState widgets | MutationState 위젯 | `MutationStateBuilder`, `MutationStateListener`, `MutationStateSelector` |
| cache work | 캐시 작업 | 무효화나 롤백처럼 캐시를 바꾸는 일. |

### 위젯, 훅, 어댑터

| 영어 | 한국어 | 메모 |
|---|---|---|
| widget | 위젯 | |
| builder | 빌더 | |
| branch | 분기 | `switch`나 `if`로 나눈 경우 하나. "error branch"는 "에러 분기", "data branch"는 "데이터 분기"예요. |
| listener | 리스너 | "listener widget"은 "리스너 위젯"이에요. |
| consumer | 컨슈머 | |
| selector | 셀렉터 | "선택자"로 쓰지 않아요. |
| flag | 플래그 | `isFetchingNextPage`처럼 결과에 있는 `bool` 필드. |
| hook | 훅 | |
| reading hook | 읽기 훅 | `useQuery`처럼 값을 읽는 훅. |
| change hook | 변화 훅 | `useOnQueryChange`, `useOnMutationChange`, `useOnMutationStateChange` |
| change | 변화 | 명사가 꼭 필요할 때만 써요. 그 밖에는 "바뀌다", "바꾸다"로 풀어요. |
| provider | 프로바이더 | `FueryProvider`. "the provided client"는 "`FueryProvider`가 제공하는 클라이언트"예요. |
| widget tree, subtree | 위젯 트리, 하위 트리 | |
| side effect | 사이드 이펙트 | "부수 효과"로 쓰지 않아요. "one-off effects"는 "한 번만 일어나는 사이드 이펙트"예요. |
| source | 소스 | `QuerySource`, 연결 상태 소스 |
| contract | 규칙 | "the slot contract"는 "슬롯의 규칙"이에요. |
| public API | 공개 API | |
| handle | 핸들 | |
| frame | 프레임 | "first frame"은 "첫 프레임"이에요. |
| build | 빌드 | "during a build"는 "빌드하는 동안"이에요. `build` 메서드는 코드로 써요. |
| screen | 화면 | "on screen"은 "화면에"예요. |
| snackbar | 스낵바 | |
| navigation | 화면 이동 | 동사 navigate는 "화면을 이동하다"예요. |
| dialog | 다이얼로그 | |
| pull to refresh | 당겨서 새로고침 | |
| loading indicator | 로딩 표시 | |
| refresh indicator | 새로고침 표시 | `RefreshIndicator`가 보여주는 표시. |
| spinner | 스피너 | |
| progress bar | 진행 표시줄 | |
| footer, header | 푸터, 헤더 | |
| button | 버튼 | 동사 tap은 "누르다"예요. "탭"은 화면의 탭(tab)에만 써요. |
| form | 폼 | |

### 앱 생명주기와 네트워크

| 영어 | 한국어 | 메모 |
|---|---|---|
| app lifecycle | 앱 생명주기 | |
| focus | 포커스 | 앱이 포그라운드에 있다는 뜻이에요. 키보드 포커스와 구분해요. |
| foreground, background | 포그라운드, 백그라운드 | "when the app resumes"는 "앱이 포그라운드로 돌아올 때"예요. |
| connectivity | 네트워크 연결 상태 | 뜻이 분명하면 "연결 상태"로 줄여요. |
| connectivity source | 연결 상태 소스 | |
| online, offline | 온라인, 오프라인 | |
| reconnect | 재연결 | 동사는 "네트워크가 다시 연결되다"예요. 명사는 목록에서만 써요. |
| network mode | 네트워크 모드 | `networkMode` |

### 기기에 저장하기

| 영어 | 한국어 | 메모 |
|---|---|---|
| persist | 기기에 저장하다 | 페이지에서 처음 나올 때는 "기기에 저장하다", 그다음부터는 "저장하다"로 써요. `persist` 옵션은 코드로 써요. "영속화"로 쓰지 않아요. |
| persistence | 캐시를 기기에 저장하기 | 기능과 페이지 이름. 본문에서는 동사로 풀어요. |
| persisted data | 저장된 데이터 | |
| persisted query | 저장하는 쿼리 | `persist`를 설정한 쿼리. |
| storage | 스토리지 | `QueryStorage`. "저장소"는 리포지토리와 헷갈리니 쓰지 않아요. |
| key-value storage | 키-값 스토리지 | |
| stored entry | 저장된 항목 | 스토리지 속 항목. 캐시 항목과 구분해요. |

### 테스트와 도구

| 영어 | 한국어 | 메모 |
|---|---|---|
| devtools | 개발자 도구 | `FueryDevtools`. 화면 문구는 영어 그대로 둬요. |
| panel | 패널 | |
| widget test | 위젯 테스트 | |
| fake | 가짜 | "fake API"는 "가짜 API", "fake clock"은 "가짜 시계", "fake time"은 "가짜 시간"이에요. |
| tear-down | 정리 함수 | `addTearDown`으로 등록한 함수. |
| timer | 타이머 | |
| microtask | 마이크로태스크 | |
| debug build, profile build, release build | 디버그 빌드, 프로파일 빌드, 릴리스 빌드 | |
| hot reload | 핫 리로드 | |
| warning | 경고 | "prints a warning"은 "경고를 출력해요"예요. |
| uncaught error | 잡히지 않은 에러 | |
| zone | zone | Dart의 zone. "the current zone"은 "현재 zone"이에요. |
| crash reporter | 크래시 리포터 | |
| line coverage | 라인 커버리지 | |
| regression suite | 회귀 테스트 | |
| edge case | 엣지 케이스 | |
| demo | 데모 | |

### Dart와 Flutter 일반 용어

| 영어 | 한국어 | 메모 |
|---|---|---|
| type | 타입 | "data type"은 "데이터 타입"이에요. |
| type argument, type parameter | 타입 인수, 타입 매개변수 | |
| type inference | 타입 추론 | 동사는 "추론하다"예요. |
| generic | 제네릭 | |
| parameter | 매개변수 | |
| argument | 인수 | "인자"로 쓰지 않아요. "named argument"는 "이름 있는 인수"예요. |
| field, member, method | 필드, 멤버, 메서드 | "메소드"로 쓰지 않아요. |
| constructor | 생성자 | |
| class, object, instance | 클래스, 객체, 인스턴스 | |
| function, closure | 함수, 클로저 | |
| value, return value | 값, 반환값 | |
| list | 리스트, 목록 | Dart의 `List` 값은 "리스트", 화면의 목록이나 늘어놓은 여러 항목은 "목록"이에요. |
| map, set | 맵, 세트 | |
| nullable, non-nullable | null이 될 수 있는, null이 될 수 없는 | |
| top-level | 최상위 | "top-level value"는 "최상위 값"이에요. |
| lifetime | 수명 | "long-lived object"는 "수명이 긴 객체"예요. |
| dependency | 의존성 | "dev dependency"는 "개발 의존성"이에요. |
| package | 패키지 | |
| code generation | 코드 생성 | |
| native code | 네이티브 코드 | |
| pure Dart | 순수 Dart | |
| core | 코어 | `fuery_core`를 가리킬 때. |
| state management | 상태 관리 | |
| app state, server state, server data | 앱 상태, 서버 상태, 서버 데이터 | |
| repository | 리포지토리 | |
| service | 서비스 | |
| hash | 해시 | |
| deprecated | 지원 중단된 | |
| alias | 별칭 | |
| milliseconds since epoch | epoch 이후 밀리초 | |
| batch | 묶음 | `notifyManager.batch`. "once per batch"는 "묶음마다 한 번"이에요. |
| user | 사용자 | 앱을 쓰는 사람. 문서를 읽는 개발자는 "사용자"라고 부르지 않고 주어를 생략해요. |

### 예제에 나오는 단어

| 영어 | 한국어 |
|---|---|
| todo | 할 일 |
| post | 게시물 |
| comment | 댓글 |
| like | 좋아요 |
| feed | 피드 |
| notification | 알림 |
| search term | 검색어 |
| list screen, detail screen | 목록 화면, 상세 화면 |
| the search screen, the compose screen, the post screen | 검색 화면, 글쓰기 화면, 게시물 화면 |
| draft | 초안 |
| cart, product, price | 장바구니, 상품, 가격 |
| job | 작업 |
| message, chat | 메시지, 채팅 |
| login, logout | 로그인, 로그아웃 |

## 동사

| 영어 | 한국어 | 메모 |
|---|---|---|
| fetch | 가져오다 | 명사가 꼭 필요할 때만 "가져오기"로 써요. "페치"로 쓰지 않아요. |
| refetch | 다시 가져오다 | 명사는 "다시 가져오기"예요. "리페치", "재요청"으로 쓰지 않아요. |
| prefetch | 미리 가져오다 | |
| load | 불러오다 | "load the next page"는 "다음 페이지를 불러오다"예요. 상태 이름 loading은 "로딩"이에요. |
| cache | 캐시하다 | 명사 caching은 "캐싱"이에요. |
| invalidate | 무효화하다 | |
| mark stale | stale 상태로 표시하다 | |
| subscribe | 구독하다 | 스트림을 listen하는 것도 "구독하다"예요. |
| unsubscribe | 구독을 해제하다 | |
| hear | 받다 | 리스너가 변화를 받는 것. "hears every run"은 "모든 실행의 변화를 받아요"예요. |
| mount, unmount | 마운트되다, 언마운트되다 | 위젯이 주어일 때. 클라이언트는 "마운트하다"(`mount()`)예요. |
| dispose | 해제하다 | Flutter의 `dispose` 메서드는 코드로 써요. |
| destroy | 없애다 | `destroy()` |
| emit | 내보내다 | |
| notify | 알리다 | |
| report | 알리다, 전달하다 | 결과와 상태는 "알리다", 에러를 콜백이나 서비스로 넘기는 것은 "전달하다"예요. "reports its error to `onUncaughtError`"는 "그 에러를 `onUncaughtError`로 전달해요"예요. |
| throw | 에러를 일으키다, 에러가 발생하다 | "던지다"로 쓰지 않아요. "throws a `StateError`"는 "`StateError`가 발생해요"예요. |
| catch | 잡다 | "에러를 잡으세요." |
| settle | 끝나다 | 성공이든 실패든 끝나는 것. "settled run"은 "끝난 실행"이에요. |
| complete | 완료되다 | `Future`가 끝나는 것. |
| succeed, fail | 성공하다, 실패하다 | |
| cancel, abort | 취소하다, 중단하다 | |
| pause | 멈추다 | "paused mutation"은 "멈춘 뮤테이션"이에요. `FetchStatus.paused`는 코드로 써요. |
| resume | 이어서 실행하다 | 멈춘 뮤테이션에 써요(`resumePausedMutations`). 앱이 resume하는 것은 "포그라운드로 돌아오다"예요. |
| join | 합류하다 | "joins that fetch"는 "이미 시작된 가져오기에 합류해요"예요. |
| wait, await | 기다리다, `await`로 기다리다 | |
| render | 렌더링하다 | |
| show | 보여주다 | |
| rebuild | 다시 빌드하다 | "리빌드"로 쓰지 않아요. |
| build, create | 만들다 | 객체를 만드는 것. "builds two objects"는 "객체 두 개를 만들어요"예요. "생성하다"로 쓰지 않아요. |
| define | 정의하다 | |
| observe | 관찰하다 | `observe()` |
| watch | 지켜보다 | `client.watch` |
| select | 선택하다 | |
| read, write | 읽다, 쓰다 | 캐시를 읽고 쓰는 일. |
| use | 사용하다 | 위젯이 클라이언트를 사용하는 것처럼 쿼리, 클라이언트, 옵저버를 사용하는 일. 캐시에 쓰는(write) 일과 헷갈리지 않게 "쓰다"로 옮기지 않아요. |
| share | 공유하다 | |
| update | 업데이트하다 | "갱신하다"로 쓰지 않아요. |
| change | 바꾸다, 바뀌다 | |
| set, configure | 설정하다 | |
| hold | 담다 | "A `Query` holds no data"는 "`Query`에는 데이터가 담기지 않아요"보다 "`Query`는 데이터를 담지 않아요"로 써요. |
| keep | 유지하다, 두다 | "keeps the data"는 "데이터를 유지해요", "keep the client in a `State` field"는 "클라이언트를 `State` 필드에 두세요"예요. |
| remove | 제거하다 | 캐시에서 없애는 것. |
| delete | 삭제하다 | 스토리지에서 지우는 것. |
| clear, empty | 비우다 | `clear()` |
| reset | 초기 상태로 되돌리다 | `reset()`, `resetQueries`. "returns the result to idle"은 "결과를 `idle` 상태로 되돌려요"예요. |
| store | 저장하다 | |
| restore | 복원하다 | |
| discard | 버리다 | |
| expire | 만료되다 | |
| seed | 미리 채우다 | `initialData` |
| register | 등록하다 | |
| merge, combine | 합치다 | |
| fold | 쌓다 | `Stream.fold`, `combine`. "folds new chunks onto the existing data"는 "새 청크를 기존 데이터에 쌓아요"예요. |
| compare | 비교하다 | "by value"는 "값으로", "by identity"는 "같은 객체인지로"예요. |
| encode, decode | 인코딩하다, 디코딩하다 | |
| overwrite | 덮어쓰다 | |
| capture | 캡처하다 | |
| assign | 할당하다 | |
| import | 임포트하다 | "가져오다"는 fetch에만 써요. |
| export, re-export | 내보내다, 다시 내보내다 | |
| install | 설치하다 | |
| inspect | 살펴보다 | |
| debounce | 디바운스하다 | |
| poll | 폴링하다 | |
| print | 출력하다 | |

## 그 밖의 표현

| 영어 | 한국어 | 메모 |
|---|---|---|
| by default | 기본으로 | "기본적으로"는 '대체로'로 읽히니 쓰지 않아요. |
| at once | 바로, 한 번에 | '곧바로'면 "바로", '한꺼번에'면 "한 번에"예요. |
| once | 한 번, ~하면 | 횟수면 "한 번", '~하고 나면'이면 "~하면", "~한 뒤"예요. |
| in flight | 이미 가져오는 중인 | "cancels the fetch in flight"는 "이미 가져오는 중이면 취소해요"처럼 동사로 풀어요. |
| meanwhile | 그동안 | |
| for good | 계속 | |
| wherever it started | 어디서 시작했든 | |

## 페이지 제목

페이지 제목은 사이드바 라벨이자 다른 페이지가 링크할 때 쓰는 이름이에요. 링크 글자에도 이 제목을 써요.

| 페이지 | 영어 제목 | 한국어 제목 |
|---|---|---|
| `index.mdx` | Server state for Flutter | Flutter용 서버 상태 |
| `getting-started.md` | Getting started | 시작하기 |
| `coming-from-tanstack-query.md` | Coming from TanStack Query | TanStack Query에서 넘어왔다면 |
| `server-state.md` | Server state in Flutter | Flutter의 서버 상태 |
| `how-the-cache-works.md` | How the cache works | 캐시가 동작하는 방식 |
| `guides/queries.md` | Queries | 쿼리 |
| `guides/widgets.md` | Widgets | 위젯 |
| `guides/mutations.md` | Mutations | 뮤테이션 |
| `guides/infinite-queries.md` | Infinite queries | 무한 쿼리 |
| `guides/streaming.md` | Streamed queries | 스트림 쿼리 |
| `guides/organizing-queries.md` | Organizing queries | 쿼리 정리하기 |
| `guides/query-client.md` | Reading and updating the cache | 캐시 읽고 업데이트하기 |
| `guides/client-setup.md` | Setting up the client | 클라이언트 설정하기 |
| `guides/lifecycle.md` | Refetching and going offline | 다시 가져오기와 오프라인 |
| `guides/persistence.md` | Persistence | 캐시를 기기에 저장하기 |
| `guides/hooks.md` | Hooks | 훅 |
| `guides/bloc.md` | Bloc and cubits | Bloc과 Cubit |
| `guides/testing.md` | Testing | 테스트 |
| `guides/devtools.md` | Devtools | 개발자 도구 |
| `guides/adapters.md` | Building an adapter | 어댑터 만들기 |
| `reference/query-options.md` | Query options | 쿼리 옵션 |
| `reference/query-results.md` | Query results | 쿼리 결과 |
| `reference/mutation-options.md` | Mutation options | 뮤테이션 옵션 |
| `reference/mutation-results.md` | Mutation results | 뮤테이션 결과 |
| `reference/query-client.md` | QueryClient | QueryClient |
| `troubleshooting.md` | Troubleshooting | 문제 해결 |

## 다른 페이지에서 링크하는 제목

다른 페이지가 `#앵커`로 링크하는 제목이에요. 번역한 제목의 글자로 앵커가 만들어지므로, 이 표와 다르게 옮기면 그 제목으로 향하는 한국어 링크가 깨져요. 같은 영어 제목이 여러 페이지에 있으면 모두 같은 한국어로 옮겨요. 이 표의 제목을 바꾸면 그 앵커로 링크하는 한국어 페이지도 같은 변경에서 고치세요.

| 영어 제목 | 한국어 제목 | 앵커 | 페이지 |
|---|---|---|---|
| Observers | 옵저버 | `#옵저버` | `how-the-cache-works` |
| Query lifecycle | 쿼리 생명주기 | `#쿼리-생명주기` | `how-the-cache-works` |
| Mutation runs | 뮤테이션 실행 | `#뮤테이션-실행` | `how-the-cache-works` |
| Query keys | 쿼리 키 | `#쿼리-키` | `guides/queries` |
| Using a query | 쿼리 사용하기 | `#쿼리-사용하기` | `guides/queries` |
| Query data can't be null | null이 될 수 없는 쿼리 데이터 | `#null이-될-수-없는-쿼리-데이터` | `guides/queries` |
| Which errors to retry | 재시도할 에러 고르기 | `#재시도할-에러-고르기` | `guides/queries` |
| Keeping the previous page on screen | 이전 페이지를 화면에 유지하기 | `#이전-페이지를-화면에-유지하기` | `guides/queries` |
| Rebuilding only what changed | 바뀐 부분만 다시 빌드하기 | `#바뀐-부분만-다시-빌드하기` | `guides/queries`, `guides/widgets` |
| Cancelling a request | 요청 취소하기 | `#요청-취소하기` | `guides/queries` |
| Reacting to changes | 변화에 반응하기 | `#변화에-반응하기` | `guides/widgets`, `guides/hooks` |
| Selecting part of the state | 상태의 일부 선택하기 | `#상태의-일부-선택하기` | `guides/widgets` |
| Showing several queries together | 여러 쿼리 함께 보여주기 | `#여러-쿼리-함께-보여주기` | `guides/widgets` |
| Running a mutation | 뮤테이션 실행하기 | `#뮤테이션-실행하기` | `guides/mutations` |
| Showing every run of a mutation | 뮤테이션의 모든 실행 보여주기 | `#뮤테이션의-모든-실행-보여주기` | `guides/mutations`, `guides/hooks` |
| Telling the user a mutation failed | 뮤테이션이 실패했다고 사용자에게 알리기 | `#뮤테이션이-실패했다고-사용자에게-알리기` | `guides/mutations` |
| Acting after one call succeeds | 호출 한 번이 성공한 뒤 처리하기 | `#호출-한-번이-성공한-뒤-처리하기` | `guides/mutations` |
| Showing only the runs a widget starts | 위젯이 시작한 실행만 보여주기 | `#위젯이-시작한-실행만-보여주기` | `guides/mutations`, `guides/hooks` |
| Callbacks | 콜백 | `#콜백` | `guides/mutations`, `reference/mutation-options` |
| Optimistic updates | 낙관적 업데이트 | `#낙관적-업데이트` | `guides/mutations` |
| Mutations without variables | 변수 없는 뮤테이션 | `#변수-없는-뮤테이션` | `guides/mutations` |
| Sharing one observer | 옵저버 하나 공유하기 | `#옵저버-하나-공유하기` | `guides/mutations` |
| Updating items in cached pages | 캐시된 페이지의 항목 업데이트하기 | `#캐시된-페이지의-항목-업데이트하기` | `guides/infinite-queries` |
| Cursor-based pages | 커서 기반 페이지 | `#커서-기반-페이지` | `guides/infinite-queries` |
| Refetching every loaded page | 불러온 페이지 모두 다시 가져오기 | `#불러온-페이지-모두-다시-가져오기` | `guides/infinite-queries` |
| Reporting failures from a repository | 리포지토리의 실패를 쿼리에 전달하기 | `#리포지토리의-실패를-쿼리에-전달하기` | `guides/organizing-queries` |
| Reading and writing the cache | 캐시 읽고 쓰기 | `#캐시-읽고-쓰기` | `guides/query-client` |
| Invalidating | 무효화하기 | `#무효화하기` | `guides/query-client` |
| Watching the cache | 캐시 지켜보기 | `#캐시-지켜보기` | `guides/query-client`, `guides/hooks` |
| Fetching outside widgets | 위젯 밖에서 가져오기 | `#위젯-밖에서-가져오기` | `guides/query-client` |
| Clearing everything at logout | 로그아웃할 때 모두 비우기 | `#로그아웃할-때-모두-비우기` | `guides/query-client` |
| Reporting every failure in one place | 모든 실패를 한곳에서 보고하기 | `#모든-실패를-한곳에서-보고하기` | `guides/client-setup` |
| Catching errors that callbacks throw | 콜백에서 발생한 에러 잡기 | `#콜백에서-발생한-에러-잡기` | `guides/client-setup` |
| Which client a query uses | 쿼리가 사용하는 클라이언트 | `#쿼리가-사용하는-클라이언트` | `guides/client-setup` |
| When the app resumes | 앱이 포그라운드로 돌아올 때 | `#앱이-포그라운드로-돌아올-때` | `guides/lifecycle` |
| When the network reconnects | 네트워크가 다시 연결될 때 | `#네트워크가-다시-연결될-때` | `guides/lifecycle` |
| Persisting infinite queries | 무한 쿼리 저장하기 | `#무한-쿼리-저장하기` | `guides/persistence` |
| When stored data is discarded | 저장된 데이터를 버릴 때 | `#저장된-데이터를-버릴-때` | `guides/persistence` |
| Restoring ahead of time | 미리 복원하기 | `#미리-복원하기` | `guides/persistence` |
| Deleting stored data | 저장된 데이터 삭제하기 | `#저장된-데이터-삭제하기` | `guides/persistence` |
| Persisting mutations | 뮤테이션 저장하기 | `#뮤테이션-저장하기` | `guides/persistence` |
| Snackbars and navigation in useEffect | useEffect에서 스낵바와 화면 이동 | `#useeffect에서-스낵바와-화면-이동` | `guides/hooks` |
| In a cubit | Cubit에서 | `#cubit에서` | `guides/bloc` |
| Mutations from a cubit or bloc | Cubit이나 Bloc에서 뮤테이션 실행하기 | `#cubit이나-bloc에서-뮤테이션-실행하기` | `guides/bloc` |
| Testing cubits and blocs | Cubit과 Bloc 테스트하기 | `#cubit과-bloc-테스트하기` | `guides/testing` |
| Every run of a mutation | 뮤테이션의 모든 실행 | `#뮤테이션의-모든-실행` | `guides/adapters` |
| InfiniteQuery options | InfiniteQuery 옵션 | `#infinitequery-옵션` | `reference/query-options` |
| Query function context | 쿼리 함수 컨텍스트 | `#쿼리-함수-컨텍스트` | `reference/query-options` |
| QueryResult fields | QueryResult 필드 | `#queryresult-필드` | `reference/query-results` |
| InfiniteQueryResult fields | InfiniteQueryResult 필드 | `#infinitequeryresult-필드` | `reference/query-results` |
| InfiniteQueryResult actions | InfiniteQueryResult 액션 | `#infinitequeryresult-액션` | `reference/query-results` |
| Options | 옵션 | `#옵션` | `reference/mutation-options` |
| Running the mutation | 뮤테이션 실행하기 | `#뮤테이션-실행하기` | `reference/mutation-options` |
| NoVariablesMutation | NoVariablesMutation | `#novariablesmutation` | `reference/mutation-options` |
| MutateOptions | MutateOptions | `#mutateoptions` | `reference/mutation-options` |
| MutationPersist | MutationPersist | `#mutationpersist` | `reference/mutation-options` |
| MutationResult | MutationResult | `#mutationresult` | `reference/mutation-results` |
| MutationState fields | MutationState 필드 | `#mutationstate-필드` | `reference/mutation-results` |
| Constructor options | 생성자 옵션 | `#생성자-옵션` | `reference/query-client` |
| Operations on matching queries | 조건에 맞는 쿼리를 다루는 메서드 | `#조건에-맞는-쿼리를-다루는-메서드` | `reference/query-client` |
| Query filters | 쿼리 필터 | `#쿼리-필터` | `reference/query-client` |
| Refetch and cancel arguments | 다시 가져오기와 취소 인수 | `#다시-가져오기와-취소-인수` | `reference/query-client` |
| Defaults | 기본값 | `#기본값` | `reference/query-client` |
| Cache callbacks | 캐시 콜백 | `#캐시-콜백` | `reference/query-client` |
| Caches | 캐시 | `#캐시` | `reference/query-client` |
| QueryState fields | QueryState 필드 | `#querystate-필드` | `reference/query-client` |
| StateError: Query holds X, but was requested as Y | 영어 그대로 | `#stateerror-query-holds-x-but-was-requested-as-y` | `troubleshooting` |
| A Timer is still pending even after the widget tree was disposed | 영어 그대로 | `#a-timer-is-still-pending-even-after-the-widget-tree-was-disposed` | `troubleshooting` |
| A test passes only when it runs first | 테스트가 맨 처음 실행될 때만 통과해요 | `#테스트가-맨-처음-실행될-때만-통과해요` | `troubleshooting` |
| A MutationListener never runs | MutationListener가 한 번도 실행되지 않아요 | `#mutationlistener가-한-번도-실행되지-않아요` | `troubleshooting` |
| A screen reads another client's cache | 화면이 다른 클라이언트의 캐시를 읽어요 | `#화면이-다른-클라이언트의-캐시를-읽어요` | `troubleshooting` |

## 문장 규칙

### 해요체로 써요

- 본문, 목록, 표 칸의 문장은 모두 해요체예요: "~해요", "~예요", "~돼요". 합쇼체(~합니다)와 반말(~한다)은 쓰지 않아요.
- 할 일은 "~하세요", 금지는 "~하지 마세요"로 써요. "~하는 것은 피해야 합니다"로 쓰지 않아요.
- 현재형으로 써요. "~할 거예요", "~하게 될 거예요"처럼 미래형으로 쓰지 않아요.
- frontmatter의 `description`도 영어가 문장이면 해요체 문장으로, 명사구면 명사구로 옮겨요.

### 주어를 분명하게 써요

- 문서를 읽는 개발자가 할 일은 주어 없이 써요. "여러분", "당신", "사용자는"을 주어로 쓰지 않아요.
- Fuery, 위젯, 옵저버, 클라이언트가 하는 일을 설명할 때는 그 대상을 주어로 써요: "Fuery가 데이터를 다시 가져와요", "옵저버가 구독을 해제해요".
- 누가 하는지가 중요한 수동문은 능동문으로 바꿔요: "저장된 데이터가 삭제돼요"보다 "Fuery가 저장된 데이터를 삭제해요".
- 영어의 it, they는 가리키는 대상을 다시 쓰거나 생략해요. "그것", "그들"로 옮기지 않아요.

### 명사 대신 동사를 써요

- 명사에 "수행하다", "진행하다", "실시하다", "작업을 하다"를 붙이지 않아요: "캐시 무효화를 수행해요"가 아니라 "캐시를 무효화해요".
- 영어의 동작 명사(a fetch, a refetch, a change)는 동사로 풀어요: "A refetch that fails keeps the data"는 "다시 가져오다가 실패해도 데이터는 남아요".
- 한 문장에는 생각 하나만 담아요. 쉼표로 두 생각을 이은 영어 문장은 두 문장으로 나눠요.

### 번역체를 고쳐요

| 피할 표현 | 쓸 표현 | 예 |
|---|---|---|
| ~을 통해 | ~로 | "이 API를 통해 가져와요" → "이 API로 가져와요" |
| ~에 의해 ~되다 | 능동문 | "옵저버에 의해 구독돼요" → "옵저버가 구독해요" |
| ~을 가지고 있다 | ~이 있다 | "결과는 `refetch()`를 가지고 있어요" → "결과에는 `refetch()`가 있어요" |
| ~하는 것이 가능하다 | ~할 수 있다 | "취소하는 것이 가능해요" → "취소할 수 있어요" |
| ~에 대해(서) | 목적격 조사 | "옵션에 대해 설명해요" → "옵션을 설명해요" |
| ~로부터 | ~에서 | "서버로부터 가져와요" → "서버에서 가져와요" |
| ~하기 위해(서) | ~하려면 | "무효화하기 위해서는" → "무효화하려면" |
| ~되어지다, ~하게 되다 | ~되다, ~하다 | "저장되어져요" → "저장돼요" |
| 만약 ~라면 | ~하면 | "만약 데이터가 없다면" → "데이터가 없으면" |
| 각각의 | ~마다 | "각각의 옵저버는" → "옵저버마다" |
| ~들 | 생략 | "화면들이 공유해요" → "화면이 모두 공유해요" |
| ~할 필요가 있다 | ~해야 하다 | "해제할 필요가 있어요" → "해제해야 해요" |
| ~와 함께 | ~로, ~하고 | "기본값과 함께 만들어요" → "기본값으로 만들어요" |

### 쉬운 말을 쓰고 군더더기를 빼요

- 쉬운 말이 있으면 한자어를 쓰지 않아요: "생성하다"는 "만들다", "기재하다"는 "적다", "해당 옵저버"는 "그 옵저버", "이용하다"는 "사용하다", "~시"는 "~할 때"로 써요.
- 영어 규칙처럼 "간단히", "그냥", "쉽게", "매우"를 쓰지 않아요. 영어에 can이 없으면 "~할 수 있어요"를 더하지 않아요.
- 메타 담화를 쓰지 않아요: "이 페이지에서는 ~을 알아봐요", "다음과 같이", "아래와 같이", "앞서 설명했듯이", "참고로", "결론적으로". 첫 문장은 영어처럼 답부터 말해요.

### 조사

- 코드와 영어 이름 뒤에는 조사를 붙여 써요: "`staleTime`은".
- 이름을 한국어로 읽었을 때 마지막 글자의 받침으로 조사를 골라요.

| 받침 | 예 | 조사 |
|---|---|---|
| 없음 | Fuery, Flutter, Dart, `Query`, `QueryClient`, `FueryProvider`, `mutate`, `refetch()`, `observe()`, `true`, `false` | 는, 가, 를, 와, 로 |
| ㄹ | `null`, `signal`, `AbortSignal` | 은, 이, 을, 과, 로 |
| 그 밖의 받침 | `staleTime`, `gcTime`, `Mutation`, `Duration`, `String`, `Stream`, `reset()`, `QuerySlot`, `StatelessWidget`, JSON, Bloc, Cubit | 은, 이, 을, 과, 으로 |

- 읽는 법이 애매하면 뒤에 명사를 붙여요: "`meta` 옵션은", "`find` 메서드를".

### 띄어쓰기

- 의존 명사는 띄어 써요: "할 수 있어요", "할 때", "하는 동안", "한 뒤".
- 보조 용언 "주다", "보다"는 붙여 써요: "보여줘요", "알려줘요", "사용해보세요".
- 부정 부사 "안"은 띄어 쓰고, "않다"는 앞말과 띄어 써요: "안 돼요", "가져오지 않아요".
- 용어 표에서 띄어 쓴 복합 명사는 그대로 띄어 써요: "캐시 항목", "쿼리 키", "쿼리 함수", "위젯 트리". "기본값", "반환값", "접두사", "생명주기", "새로고침", "한곳"은 붙여 써요.
- 영어나 코드 뒤에 오는 한국어 명사는 띄어 써요: "`Query` 정의", "Flutter 앱". 접미사는 붙여 써요: "Flutter용".

### 숫자와 단위

- 기간, 횟수, 기본값은 아라비아 숫자에 단위를 붙여 써요: "5분", "1초, 2초, 4초", "3번", "1일", "0".
- 작은 개수는 고유어로 써요: "캐시 항목 하나", "요청 한 번", "화면 두 개".
- "(default: 5 minutes)"는 "(기본값: 5분)"으로 옮겨요.

### 문장 부호

- 문장은 마침표로 끝내요. 제목에는 마침표, 물음표, 느낌표를 쓰지 않아요.
- 코드 블록이나 목록 앞 문장을 콜론으로 끝내지 않아요. 마침표로 끝낸 뒤 코드 블록이나 목록을 이어요.
- 문장 가운데 있는 영어의 콜론은 되도록 두 문장으로 나눠 풀어요. 목록 항목의 머리말, 표 칸, "(기본값: 5분)" 같은 괄호 안에서는 콜론을 그대로 써요.
- 괄호는 앞말에 붙여 써요: "캐시 항목(`CachedQuery`)".
- 따옴표와 강조(굵게, 기울임)는 영어 원문과 같은 곳에 써요.
- 가운뎃점(·) 대신 "와/과"나 쉼표를 써요.

### 제목

- 할 일을 말하는 제목은 "~하기"로 써요: "Keeping the previous page on screen"은 "이전 페이지를 화면에 유지하기".
- 개념이나 API 이름을 말하는 제목은 명사로 써요: "Query keys"는 "쿼리 키", "QueryResult fields"는 "QueryResult 필드".
- "When ~" 제목은 "~할 때"로 써요: "When the app resumes"는 "앱이 포그라운드로 돌아올 때".
- 문제 해결 페이지에서 증상을 말하는 제목은 해요체 평서문으로 써요: "A query refetches too often"은 "쿼리가 데이터를 너무 자주 다시 가져와요". 에러 메시지인 제목은 영어 그대로 둬요.
- 30자 안으로 써요.
- 같은 영어 제목은 모든 페이지에서 같은 한국어로 옮겨요. 다른 페이지가 링크하는 제목은 [다른 페이지에서 링크하는 제목](#다른-페이지에서-링크하는-제목)의 표대로 써요.

### 표와 목록

- 표 머리글도 옮겨요.

  | 영어 | 한국어 |
  |---|---|
  | Option, Type, Default | 옵션, 타입, 기본값 |
  | What it does, Description, Meaning | 하는 일, 설명, 의미 |
  | Returns, Arguments | 반환 타입, 인수 |
  | Field, Member, Method, Callback | 필드, 멤버, 메서드, 콜백 |
  | Runs | 실행 시점 |
  | Filter, Selects | 필터, 선택 대상 |
  | Status, Value, Mode, Behavior, Stage | 상태, 값, 모드, 동작, 단계 |
  | Widget, Hook | 위젯, 훅 |

- 표 칸의 "required"는 "필수", "none"은 "없음", "now"는 "현재 시각"으로 옮겨요.
- 영어 칸이 문장이면 해요체 문장으로, 명사구면 명사구로 옮겨요. 목록 항목도 같아요.

### 약어와 외래어

- 약어는 페이지에서 처음 나올 때 풀어 써요: "CI(Continuous Integration)", "CLI(Command-Line Interface)". API, JSON, UI, HTTP, URL, SDK처럼 개발자가 모두 아는 약어는 그대로 써요.
- 외래어는 개발자가 흔히 쓰는 표기를 따라요: 메시지, 메서드, 컨텍스트, 캐시, 릴리스, 파라미터, 플레이스홀더, 셀렉터, 리포지토리. "메세지", "메소드", "콘텍스트", "캐쉬"로 쓰지 않아요.

## 예문

### 1. 문장을 나누고 용어를 맞춰요

영어:

> Fuery refetches stale data when the app returns to the foreground and when the network reconnects, so screens catch up without a pull to refresh.

피할 번역:

> Fuery는 앱이 포그라운드로 돌아올 때와 네트워크가 재연결될 때 stale한 데이터를 리페치하며, 이를 통해 화면들은 당겨서 새로고침 없이도 따라잡게 됩니다.

옮긴 문장:

> 앱이 포그라운드로 돌아오거나 네트워크가 다시 연결되면 Fuery가 stale 데이터를 다시 가져와요. 그래서 당겨서 새로고침하지 않아도 화면이 바뀐 데이터를 보여줘요.

- 두 생각을 두 문장에 나눠 담았어요.
- "stale한", "리페치" 대신 용어집의 "stale 데이터", "다시 가져와요"를 썼어요.
- "이를 통해", "화면들", "~하게 됩니다"를 뺐어요.

### 2. 명사 대신 동사로 풀어요

영어:

> Each `mutate` call adds a run to the mutation cache, with its own variables and state. The run belongs to the client's cache, not to the definition or a widget.

피할 번역:

> 각각의 `mutate` 호출은 자신만의 변수들과 상태를 가지고 뮤테이션 캐시에 런을 추가합니다. 그 런은 정의나 위젯이 아닌 클라이언트의 캐시에 속하게 됩니다.

옮긴 문장:

> `mutate`를 호출할 때마다 뮤테이션 캐시에 실행이 하나 생겨요. 실행마다 변수와 상태가 따로 있어요. 실행은 정의나 위젯이 아니라 클라이언트의 캐시에 속해요.

- "호출은" 대신 "호출할 때마다"로 동사를 살렸어요.
- "런" 대신 용어집의 "실행"을 썼어요.
- "각각의", "~들", "가지고", "~하게 됩니다"를 뺐어요.

### 3. 금지는 "~하지 마세요"로 써요

영어:

> Don't call `observe()` in `build`. Each call creates an observer that subscribes and fetches again.

피할 번역:

> `build` 안에서 `observe()`를 호출하는 것은 피해야 합니다. 각각의 호출은 구독하고 다시 페치하는 옵저버를 생성하게 됩니다.

옮긴 문장:

> `build`에서 `observe()`를 호출하지 마세요. 호출할 때마다 옵저버가 새로 생겨요. 새 옵저버는 구독하고 데이터를 다시 가져와요.

- 금지를 "~하지 마세요"로 바로 말했어요.
- 긴 관형절을 풀어서 옵저버를 주어로 세웠어요.
- "생성하다", "페치"를 "생기다", "가져오다"로 바꿨어요.
