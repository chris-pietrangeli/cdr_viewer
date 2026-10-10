require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  test "uploading a CSV imports it and shows a report that can be revisited" do
    assert_difference -> { CallRecord.count }, 1 do
      post imports_path, params: { file: fixture_file_upload("calls.csv", "text/csv") }
    end

    import = Import.sole
    assert_redirected_to import_path(import)

    follow_redirect!
    assert_select "dd", text: "calls.csv"
    assert_select "dd code", text: Digest::SHA256.file(file_fixture("calls.csv")).hexdigest
    assert_select "tbody tr", 1
    assert_select "td", text: "duration is missing"
    assert_select "td code", text: "2026-03-09 09:00:00,+12025550101,+12025550142,,TWR-1"
  end

  test "uploading the same file again points back to the earlier import" do
    2.times { post imports_path, params: { file: fixture_file_upload("calls.csv", "text/csv") } }
    first, second = Import.order(:id).to_a

    get import_path(second)

    assert_select "dd a[href=?]", import_path(first)
  end

  test "a file that cannot be imported still gets a report" do
    post imports_path, params: { file: fixture_file_upload("not_cdr.csv", "text/csv") }
    follow_redirect!

    assert_select ".alert", text: /Unrecognised column layout: name, email/
    assert_equal 0, CallRecord.count
  end

  test "importing without a file redirects with a message" do
    post imports_path

    assert_redirected_to root_path
    assert_equal 0, Import.count
  end

  test "lists every import, newest first" do
    older = create_import(filename: "older.csv")
    newer = create_import(filename: "newer.csv")
    newer.update!(error: "Missing column(s): duration")

    get imports_path

    assert_select "tbody tr", 2
    assert_select "tbody tr:first-child td", text: "newer.csv"
    assert_select "tbody tr:first-child td", text: "Failed"
    assert_select "tbody tr:last-child a[href=?]", import_path(older)
  end
end
