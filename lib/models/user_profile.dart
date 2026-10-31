class UserProfile {
  final int id;
  final int userId;
  final String? firstName;
  final String? lastName;
  final String? middleInitial;
  final String? sex;
  final String? birthday;
  final int? age;
  final String? contactNo;
  final String? province;
  final String? municipality;
  final String? barangay;
  final String? street;
  final String? houseNo;
  final String? validId;
  final String? businessName;
  final String? lineOfBusiness;
  final String? businessPermit;
  final String? vehicleType;
  final String? plateNumber;
  final String? orCr;
  final bool adminAcknowledged;

  const UserProfile({
    required this.id, required this.userId,
    this.firstName, this.lastName, this.middleInitial,
    this.sex, this.birthday, this.age, this.contactNo,
    this.province, this.municipality, this.barangay,
    this.street, this.houseNo, this.validId,
    this.businessName, this.lineOfBusiness, this.businessPermit,
    this.vehicleType, this.plateNumber, this.orCr,
    this.adminAcknowledged = false,
  });

  String get displayName {
    final parts = [firstName, lastName].where((p) => p != null && p.isNotEmpty);
    return parts.join(' ');
  }

  String get fullAddress {
    final parts = [houseNo, street, barangay, municipality, province]
        .where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id:               j['id'] ?? 0,
    userId:           j['user_id'] ?? 0,
    firstName:        j['first_name'],
    lastName:         j['last_name'],
    middleInitial:    j['middle_initial'],
    sex:              j['sex'],
    birthday:         j['birthday'],
    age:              j['age'],
    contactNo:        j['contact_no'],
    province:         j['province'],
    municipality:     j['municipality'],
    barangay:         j['barangay'],
    street:           j['street'],
    houseNo:          j['house_no'],
    validId:          j['valid_id'],
    businessName:     j['business_name'],
    lineOfBusiness:   j['line_of_business'],
    businessPermit:   j['business_permit'],
    vehicleType:      j['vehicle_type'],
    plateNumber:      j['plate_number'],
    orCr:             j['or_cr'],
    adminAcknowledged: j['admin_acknowledged'] ?? false,
  );
}
