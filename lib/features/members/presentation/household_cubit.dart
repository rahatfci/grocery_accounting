import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../auth/logic/app_user.dart';
import '../data/member_repository.dart';
import '../logic/household.dart';
import '../logic/household_member.dart';
import 'household_state.dart';

/// The household for as long as someone is signed in: names and avatars for
/// Home, the list, the pantry history, spending and Account.
class HouseholdCubit extends Cubit<HouseholdState> {
  HouseholdCubit(this._members, {required AppUser currentUser})
    : _currentUser = currentUser,
      super(HouseholdLoading(Household.of(const [], currentUser))) {
    _subscribe();
  }

  final MemberRepository _members;
  final AppUser _currentUser;
  StreamSubscription<List<HouseholdMember>>? _subscription;

  /// Subscribes again after a failure. A snapshot stream is finished once it
  /// has errored, so recovering takes a new subscription.
  void retry() {
    emit(HouseholdLoading(state.household));
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _members.watchMembers().listen(
      (members) => emit(HouseholdLoaded(Household.of(members, _currentUser))),
      onError: _onStreamError,
    );
  }

  /// Reported, and shown as the members already known: a name that cannot be
  /// refreshed is still better than no name at all.
  void _onStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      HouseholdFailure(
        state.household,
        error is DataFailure ? error : const UnexpectedDataFailure(),
      ),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
