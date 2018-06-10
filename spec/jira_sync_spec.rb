# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

RSpec.describe Danger::DangerJiraSync do
  it "should be a plugin" do
    expect(described_class.new(nil)).to be_a Danger::Plugin
  end

  describe "with Dangerfile" do
    let(:dangerfile) { testing_dangerfile }
    let(:plugin) { dangerfile.jira_sync }
    let(:jira_settings) do 
      {
        jira_url: 'http://example.atlassian.net/',
        jira_username: 'some_user',
        jira_api_key: 'some_api_key',
      }
    end

    def stub_pull_request
      VCR.use_cassette(:pull_request) do
        plugin.env.request_source.fetch_details
      end
    end

    before do
      stub_pull_request
    end

    describe "configure" do
      it "should return the JIRA::Client instance" do
        value = plugin.configure(jira_settings)
        expect(value).to be_a(JIRA::Client)
      end
    end

    describe "autolabel_pull_request" do
      let(:issue_prefixes) { %w(DEV ABC) }

      it "raises a NotConfiguredError when #configure has not been called" do
        expect { plugin.autolabel_pull_request(issue_prefixes) }.to(
          raise_error(Danger::DangerJiraSync::NotConfiguredError)
        )
      end

      context "after calling #configure" do
        before do 
          plugin.configure(jira_settings)
        end

        it "returns a list of labels that contains Jira component names" do
          skip
        end

        it "returns a list of labels that contains Jira issue project keys" do
          skip
        end

        it "creates a warrning when a related Jira ticket cannot be fetched" do
          skip
        end

        it "adds a label to the github issue for each related jira issue component name" do
          skip
        end

        it "adds a label to the github issue for each related jira issue project key" do
          skip
        end

        it "ignores duplicate issue keys" do
          skip
        end

        it "ignores component and project key name overlap" do
          skip
        end

        it "adds missing github labels" do
          skip
        end

        it "does not attempt to add new github labels when they already exist" do
          skip
        end

        it "returns nil if no issue keys are found in the pr name or body" do
          expect(plugin.autolabel_pull_request(["NOPE"])).to be_nil
        end

        it "falls back to issue keys in the pr body if none are found in the pr title" do
          skip
        end

        it "ignores issue keys in the pr body if any are found in the pr title" do
          skip
        end

        it "raises an ArgumentError if no issue_prefixes are specified" do
          expect { plugin.autolabel_pull_request([]) }.to raise_error(ArgumentError)
        end

        it "returns nil if no labels can be fetched from Jira" do
          skip
        end
      end
    end

    # Some examples for writing tests
    # You should replace these with your own.

    # it "Warns on a monday" do
    #   monday_date = Date.parse("2016-07-11")
    #   allow(Date).to receive(:today).and_return monday_date

    #   @my_plugin.warn_on_mondays

    #   expect(@dangerfile.status_report[:warnings]).to eq(["Trying to merge code on a Monday"])
    # end

    # it "Does nothing on a tuesday" do
    #   monday_date = Date.parse("2016-07-12")
    #   allow(Date).to receive(:today).and_return monday_date

    #   @my_plugin.warn_on_mondays

    #   expect(@dangerfile.status_report[:warnings]).to eq([])
    # end
  end
end
