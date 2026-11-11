import 'dart:io';
import 'api.dart';
import '../../models/user.dart';

class AuthService {
  /// POST /login → { token, user }
  static Future<({String token, User user, Map<String, dynamic> rawUser})> login(String email, String password) async {
    final d = await Api.post('/login', body: {'email': email, 'password': password}, auth: false)
        as Map<String, dynamic>;
    final raw = (d['user'] as Map).cast<String, dynamic>();
    return (token: d['token'] as String, user: User.fromJson(raw), rawUser: raw);
  }

  /// POST /auth/google { id_token } → { token, user }. An email with no account (or an
  /// unverified one) answers 404 'not_found'.
  static Future<({String token, User user, Map<String, dynamic> rawUser})> googleSignIn(String idToken) async {
    final d = await Api.post('/auth/google', body: {'id_token': idToken}, auth: false) as Map<String, dynamic>;
    final raw = (d['user'] as Map).cast<String, dynamic>();
    return (token: d['token'] as String, user: User.fromJson(raw), rawUser: raw);
  }

  /// POST /logout
  static Future<void> logout() async {
    try { await Api.post('/logout'); } catch (_) {}
    await Api.deleteToken();
  }

  // ── Register Buyer ──────────────────────────────────────────────────────
  static Future<void> registerBuyer({
    required String firstName, required String lastName,
    String? middleInitial, String? sex, String? birthday, int? age,
    required String email, String? contactNo,
    String? province, String? municipality, String? barangay,
    String? street, String? houseNo,
    required String password, required String passwordConfirmation,
    File? validId,
  }) async {
    final fields = <String, String>{
      'first_name': firstName, 'last_name': lastName,
      if (middleInitial != null) 'middle_initial': middleInitial,
      if (sex       != null) 'sex': sex,
      if (birthday  != null) 'birthday': birthday,
      if (age       != null) 'age': '$age',
      'email': email,
      if (contactNo   != null) 'contact_no': contactNo,
      if (province    != null) 'province': province,
      if (municipality!= null) 'municipality': municipality,
      if (barangay    != null) 'barangay': barangay,
      if (street      != null) 'street': street,
      if (houseNo     != null) 'house_no': houseNo,
      'password': password, 'password_confirmation': passwordConfirmation,
    };
    if (validId != null) {
      await Api.postMultipart('/register/buyer', fields: fields, files: {'valid_id': validId});
    } else {
      await Api.post('/register/buyer', body: fields, auth: false);
    }
  }

  // ── Register Seller ─────────────────────────────────────────────────────
  static Future<void> registerSeller({
    required String firstName, required String lastName,
    String? middleInitial, required String businessName,
    String? lineOfBusiness,
    String? sex, String? birthday, int? age,
    required String email, String? contactNo,
    String? province, String? municipality, String? barangay,
    String? street, String? houseNo,
    required String password, required String passwordConfirmation,
    File? validId, File? businessPermit,
  }) async {
    final fields = <String, String>{
      'first_name': firstName, 'last_name': lastName,
      if (middleInitial != null) 'middle_initial': middleInitial,
      'business_name': businessName,
      if (lineOfBusiness != null) 'line_of_business': lineOfBusiness,
      if (sex != null) 'sex': sex,
      if (birthday != null) 'birthday': birthday,
      if (age != null) 'age': '$age',
      'email': email,
      if (contactNo != null) 'contact_no': contactNo,
      if (province != null) 'province': province,
      if (municipality != null) 'municipality': municipality,
      if (barangay != null) 'barangay': barangay,
      if (street != null) 'street': street,
      if (houseNo != null) 'house_no': houseNo,
      'password': password, 'password_confirmation': passwordConfirmation,
    };
    if (validId != null || businessPermit != null) {
      await Api.postMultipart('/register/seller', fields: fields, files: {
        if (validId != null) 'valid_id': validId,
        if (businessPermit != null) 'business_permit': businessPermit,
      });
    } else {
      await Api.post('/register/seller', body: fields, auth: false);
    }
  }

  // ── Register Courier ────────────────────────────────────────────────────
  static Future<void> registerCourier({
    required String firstName, required String lastName,
    String? middleInitial, String? sex, String? birthday, int? age,
    required String email,
    required String mobileNumber,
    required String driverLicenseNumber,
    required String licenseExpiryDate,
    required String dateOfBirth,
    String? contactNo,
    String? province, String? municipality, String? barangay,
    String? street, String? houseNo,
    required String vehicleType, required String plateNumber,
    required String password, required String passwordConfirmation,
    File? validId, File? orCr,
  }) async {
    final fields = <String, String>{
      'first_name': firstName, 'last_name': lastName,
      if (middleInitial != null) 'middle_initial': middleInitial,
      if (sex != null) 'sex': sex,
      if (birthday != null) 'birthday': birthday,
      if (age != null) 'age': '$age',
      'email': email,
      'mobile_number': mobileNumber,
      'driver_license_number': driverLicenseNumber,
      'license_expiry_date': licenseExpiryDate,
      'date_of_birth': dateOfBirth,
      if (contactNo != null) 'contact_no': contactNo,
      if (province != null) 'province': province,
      if (municipality != null) 'municipality': municipality,
      if (barangay != null) 'barangay': barangay,
      if (street != null) 'street': street,
      if (houseNo != null) 'house_no': houseNo,
      'vehicle_type': vehicleType,
      'plate_number': plateNumber,
      'password': password, 'password_confirmation': passwordConfirmation,
    };
    if (validId != null || orCr != null) {
      await Api.postMultipart('/register/courier', fields: fields, files: {
        if (validId != null) 'valid_id': validId,
        if (orCr != null) 'or_cr': orCr,
      });
    } else {
      await Api.post('/register/courier', body: fields, auth: false);
    }
  }

  // ── Forgot Password ─────────────────────────────────────────────────────
  /// POST /forgot-password → sends a reset link to the given email.
  static Future<void> forgotPassword(String email) async {
    await Api.post('/forgot-password', body: {'email': email}, auth: false);
  }
}
