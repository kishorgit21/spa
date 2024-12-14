class SPAUserModel {
  String? deviceid;
  String? email;
  String? mobile;
  bool? active;
  String? finyearstartdate;
  String? finyearenddate;

  SPAUserModel(
      {this.deviceid,
      this.email,
      this.mobile,
      this.active,
      this.finyearstartdate,
      this.finyearenddate});

  SPAUserModel.fromJson(Map<String, dynamic> json) {
    deviceid = json['deviceid'];
    email = json['email'];
    mobile = json['mobile'];
    active = json['active'];
    finyearstartdate = json['finyearstartdate'];
    finyearenddate = json['finyearenddate'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['deviceid'] = deviceid;
    data['email'] = email;
    data['mobile'] = mobile;
    data['active'] = active;
    data['finyearstartdate'] = finyearstartdate;
    data['finyearenddate'] = finyearenddate;
    return data;
  }
}
