/// The Supabase project that holds scontrino photos. Everything else lives in
/// Firebase.
///
/// The publishable key is meant to ship inside the app, like the Firebase
/// options. What it may do is decided by the storage policies on the bucket,
/// not by keeping it secret. Never put the secret (service role) key here.
abstract final class SupabaseConfig {
  static const url = 'https://rqxqpvlejismjmxgakcj.supabase.co';
  static const publishableKey =
      'sb_publishable_Ood9rcOrj2DSr4jGxJm3RQ_baYRtRr5';
  static const receiptsBucket = 'Grocery Accounting';
}
