# ActionMailer delivery method for Brevo's transactional email API.
#
# Brevo's SMTP relay requires a separate, manual activation from their support
# team on new accounts (confirmed 2026-09: it silently accepts and drops mail
# instead of raising, so testing via SMTP looked successful but nothing sent).
# The API has no such gate, so this wraps Brevo::TransactionalEmailsApi
# directly rather than waiting on that activation. See LOCAL_DEV_NOTES.md.
#
# Registered via ActionMailer::Base.add_delivery_method in
# config/environments/production.rb, selected via MAIL_PROVIDER=brevo.
class BrevoDeliveryMethod
  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    Brevo.configure { |config| config.api_key["api-key"] = settings.fetch(:api_key) }

    api_instance = Brevo::TransactionalEmailsApi.new
    send_smtp_email = Brevo::SendSmtpEmail.new(
      sender: sender_for(mail),
      to: recipients_for(mail),
      subject: mail.subject,
      html_content: part_body(mail, :html),
      text_content: part_body(mail, :text)
    )

    api_instance.send_transac_email(send_smtp_email)
  end

  private

  def sender_for(mail)
    address = Mail::Address.new(mail[:from].to_s)
    { email: address.address, name: address.display_name }.compact
  end

  def recipients_for(mail)
    Array(mail.to).map do |email|
      address = mail[:to].addrs.find { |a| a.address == email } || Mail::Address.new(email)
      { email: address.address, name: address.display_name }.compact
    end
  end

  def part_body(mail, kind)
    content_type_fragment = kind == :html ? "html" : "plain"
    part = mail.multipart? ? mail.parts.find { |p| p.content_type.to_s.include?(content_type_fragment) } : mail
    part&.body&.decoded
  end
end
