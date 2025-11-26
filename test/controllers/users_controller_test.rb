require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get users_index_url
    assert_response :success
  end
  
  test "should have new user button" do
    get users_index_url
    assert_response :success
    assert_select "button.btn-add", "新增用户"
  end
  
  test "should have user creation modal" do
    get users_index_url
    assert_response :success
    assert_select "div#addModal.modal-overlay"
    assert_select "form#addForm"
  end
  
  test "should have all required form fields" do
    get users_index_url
    assert_response :success
    assert_select "input#addUsername[required]"
    assert_select "input#addEmail[required]"
    assert_select "input#addPhone[required]"
    assert_select "input#addPassword[required]"
    assert_select "select#addRole"
    assert_select "select#addMembership"
    assert_select "select#addStatus"
  end
end
