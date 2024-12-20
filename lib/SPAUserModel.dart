class SPAUserModel {
  String? deviceid;
  String? email;
  String? mobile;
  bool? active;
  String? finyearstartdate;
  String? finyearenddate;
  String? paymentId;
  String? orderId;
  String? signature;
  SPAUserModel(
      {this.deviceid,
      this.email,
      this.mobile,
      this.active,
      this.finyearstartdate,
      this.finyearenddate,
      this.paymentId,
      this.orderId,
      this.signature});

  SPAUserModel.fromJson(Map<String, dynamic> json) {
    deviceid = json['deviceid'];
    email = json['email'];
    mobile = json['mobile'];
    active = json['active'];
    finyearstartdate = json['finyearstartdate'];
    finyearenddate = json['finyearenddate'];
    paymentId = json['paymentId'];
    orderId = json['orderId'];
    signature = json['signature'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['deviceid'] = deviceid;
    data['email'] = email;
    data['mobile'] = mobile;
    data['active'] = active;
    data['finyearstartdate'] = finyearstartdate;
    data['finyearenddate'] = finyearenddate;
    data['paymentId'] = paymentId;
    data['orderId'] = orderId;
    data['signature'] = signature;
    return data;
  }
}
