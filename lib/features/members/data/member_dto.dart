import '../logic/household_member.dart';

/// The `users` fields a sign in refreshes.
///
/// `createdAt` is deliberately absent: it belongs to [newMemberToFirestore]
/// and must survive every later mirror write.
Map<String, Object?> memberToFirestore(HouseholdMember member) => {
  'displayName': member.displayName,
  'email': member.email,
};

/// The full body of a `users` document that does not exist yet.
///
/// [createdAt] is passed in rather than read here so this stays a pure map
/// conversion: the repository supplies `FieldValue.serverTimestamp()`, a test
/// supplies a `Timestamp`.
Map<String, Object?> newMemberToFirestore(
  HouseholdMember member, {
  required Object createdAt,
}) => {...memberToFirestore(member), 'createdAt': createdAt};

/// Reads a document body into a [HouseholdMember]. [id] is the document id,
/// which is never part of the body.
///
/// Read defensively, like items: a member whose document was written by hand
/// must render rather than break the payer picker.
HouseholdMember memberFromFirestore(String id, Map<String, Object?> data) {
  final email = _string(data['email']);
  final displayName = _string(data['displayName']);

  return HouseholdMember(
    id: id,
    displayName: displayName.isEmpty
        ? displayNameFromEmail(email)
        : displayName,
    email: email,
  );
}

String _string(Object? value) => value is String ? value : '';
