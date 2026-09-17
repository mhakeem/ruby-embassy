require "test_helper"

class BrevoDeliveryMethodTest < ActiveSupport::TestCase
  test "maps a Mail::Message to a Brevo send_transac_email call" do
    mail = Mail.new do
      from    "noreply@rockymtnruby.dev"
      to      "attendee@example.com"
      subject "Your Ruby Embassy login link"

      text_part { body "Sign in here: https://example.com/session/callback" }
      html_part { content_type "text/html; charset=UTF-8"; body "<p>Sign in <a href=\"https://example.com/session/callback\">here</a></p>" }
    end

    api_instance = Minitest::Mock.new
    sent_email = nil
    api_instance.expect(:send_transac_email, true) { |email| sent_email = email; true }

    Brevo::TransactionalEmailsApi.stub :new, api_instance do
      BrevoDeliveryMethod.new(api_key: "test-key").deliver!(mail)
    end

    api_instance.verify
    assert_equal({ email: "noreply@rockymtnruby.dev" }, sent_email.sender)
    assert_equal [ { email: "attendee@example.com" } ], sent_email.to
    assert_equal "Your Ruby Embassy login link", sent_email.subject
    assert_includes sent_email.html_content, "Sign in"
    assert_includes sent_email.text_content, "Sign in here"
  end
end
