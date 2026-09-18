require "test_helper"

class TitoSyncJobTest < ActiveJob::TestCase
  FakeTicket = Struct.new(:slug, :email, :first_name, :last_name)

  class FakeTicketsScope
    def initialize(tickets)
      @tickets = tickets
    end

    def where(**)
      @tickets
    end
  end

  class FakeTitoClient
    def initialize(tickets)
      @tickets = tickets
    end

    def tickets
      FakeTicketsScope.new(@tickets)
    end
  end

  def with_fake_tito_client(tickets)
    fake_client = FakeTitoClient.new(tickets)
    User.define_singleton_method(:tito_client) { fake_client }
    yield
  ensure
    User.singleton_class.send(:remove_method, :tito_client)
  end

  test "counts already-linked, connects by email, and creates new users" do
    already_linked = users(:attendee_one).tap { |u| u.update!(tito_ticket_slug: "existing-slug") }
    to_connect = User.create!(email: "connectme@example.com", first_name: "Con", last_name: "Nect")

    tickets = [
      FakeTicket.new(already_linked.tito_ticket_slug, already_linked.email, "Alice", "Attendee"),
      FakeTicket.new("connect-slug", to_connect.email, "Con", "Nect"),
      FakeTicket.new("new-slug", "brandnew@example.com", "Brand", "New")
    ]

    with_fake_tito_client(tickets) { TitoSyncJob.perform_now }

    status = TitoSyncJob.status
    assert_equal :finished, status[:state]
    assert_equal 1, status[:already]
    assert_equal 1, status[:connected]
    assert_equal 1, status[:added]
    assert_equal 0, status[:failed]

    assert_equal "connect-slug", to_connect.reload.tito_ticket_slug
    assert User.exists?(email: "brandnew@example.com")
  end

  test "a bad ticket is skipped and counted as failed, without aborting the rest" do
    good_ticket = FakeTicket.new("good-slug", "good@example.com", "Good", "One")
    bad_ticket = FakeTicket.new("bad-slug", nil, "Bad", "One") # nil email breaks .downcase

    with_fake_tito_client([ bad_ticket, good_ticket ]) { TitoSyncJob.perform_now }

    status = TitoSyncJob.status
    assert_equal :finished, status[:state]
    assert_equal 1, status[:added]
    assert_equal 1, status[:failed]
    assert User.exists?(email: "good@example.com")
  end

  test "never modifies role on an existing user, even when re-synced" do
    volunteer = users(:volunteer_one)
    volunteer.update!(tito_ticket_slug: "vol-slug")
    ticket = FakeTicket.new("vol-slug", volunteer.email, volunteer.first_name, volunteer.last_name)

    with_fake_tito_client([ ticket ]) { TitoSyncJob.perform_now }

    assert volunteer.reload.volunteer?
  end

  test "a fatal error writes a failed status" do
    User.define_singleton_method(:tito_client) { raise "boom: unreachable" }

    TitoSyncJob.perform_now

    status = TitoSyncJob.status
    assert_equal :failed, status[:state]
    assert_match "boom: unreachable", status[:error]
  ensure
    User.singleton_class.send(:remove_method, :tito_client)
  end
end
