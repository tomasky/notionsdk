///|
test "path_param reads required parameters" {
  assert_eq(
    @api-endpoints.path_param({ "user_id": "u1" }, "user_id") catch {
      _ => ""
    },
    "u1",
  )
  let missing = try {
    let _ = @api-endpoints.path_param({ "user_id": "u1" }, "page_id")
    "no error"
  } catch {
    @api-endpoints.EndpointParameterError(message) => message
    _ => "other"
  }
  assert_eq(missing, "Missing required path parameter: page_id")
}

///|
test "number_to_string renders integers without a decimal point" {
  assert_eq(@api-endpoints.number_to_string(10.0), "10")
  assert_eq(@api-endpoints.number_to_string(1.5), "1.5")
}

///|
test "endpoint definitions build their paths" {
  assert_eq(
    (@api-endpoints.getUser.path)({ "user_id": "u1" }) catch {
      _ => ""
    },
    "users/u1",
  )
  assert_eq(
    (@api-endpoints.listBlockChildren.path)({ "block_id": "b1" }) catch {
      _ => ""
    },
    "blocks/b1/children",
  )
  assert_eq(
    (@api-endpoints.getPageProperty.path)({
      "page_id": "p1",
      "property_id": "t",
    }) catch {
      _ => ""
    },
    "pages/p1/properties/t",
  )
  assert_eq(
    (@api-endpoints.oauthToken.path)(Json::null()) catch {
      _ => ""
    },
    "oauth/token",
  )
  assert_eq(@api-endpoints.getUser.http_method, "get")
  assert_eq(@api-endpoints.movePage.http_method, "post")
}
