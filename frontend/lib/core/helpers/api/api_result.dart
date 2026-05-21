class ApiResult <T> {
  final T? data;
  final String? error;
  final bool isSuccess;


  ApiResult.success(this.data)
  //! initialize list: initialize the error value(eg. error = null, isSuccess = true) before passing to constructor
      : error = null,
        isSuccess = true;
//! initialize list: initialize the data value(eg. data  = null, isSuccess = false) before passing to constructor
  ApiResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

 typedef ApiResultType = ApiResult<Map<String, dynamic>>;