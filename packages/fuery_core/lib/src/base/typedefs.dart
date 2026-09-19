import 'dart:async';

import 'package:fuery_core/src/infinite_data.dart';

typedef ValueGetter<T> = T? Function();

typedef FueryKey = List<dynamic>;

typedef QueryKey = FueryKey;

typedef QueryFn<Data> = Future<Data> Function();

typedef InfiniteQueryFn<Params, Data> = Future<Data> Function(Params params);

typedef InfiniteQueryNextParamGetter<Param, Data> = Param? Function(
  InfiniteData<Param, Data> lastPage,
  List<InfiniteData<Param, Data>> allPages,
);

typedef InfiniteQueryPreviousParamGetter<Param, Data> = Param? Function(
  InfiniteData<Param, Data> firstPage,
  List<InfiniteData<Param, Data>> allPages,
);

typedef MutationKey = FueryKey;

typedef MutationAsyncFn<Param, Data, Err> = Future<Data> Function(Param param);

typedef MutationSyncFn<Param, Data, Err> = void Function(Param param);

typedef MutationNoParamAsyncFn<Data, Err> = Future<Data> Function();

typedef MutationNoParamSyncFn<Data, Err> = void Function();

typedef Store<T> = Map<String, T>;

typedef MutationMutateCallback<Param> = void Function(Param param);

typedef MutationNoParamMutateCallback = void Function();

typedef MutationSuccessCallback<Param, Data> = void Function(
  Param param,
  Data data,
);

typedef MutationNoParamSuccessCallback<Data> = void Function(Data data);

typedef MutationErrorCallback<Param, Err> = void Function(
  Param params,
  Err error,
);

typedef MutationNoParamErrorCallback<Err> = void Function(Err error);
