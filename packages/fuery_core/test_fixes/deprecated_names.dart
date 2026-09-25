// `dart fix --compare-to-golden`, run in this directory, checks that the
// transforms in lib/fix_data.yaml turn this file into
// deprecated_names.dart.expect.
import 'package:fuery_core/fuery_core.dart';

// FocusManager
final FocusManager focus = FocusManager();

class AppFocus extends FocusManager {}

bool isFocus(Object value) => value is FocusManager;
