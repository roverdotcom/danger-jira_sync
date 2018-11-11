# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

# In order to regenerate the fixtures in ./fixtures/vcr_cassettes,
# you must ensure that your Jira Cloud development environment contains
# projects matching all of the key prefixes in ISSUE_KEYS_IN_PR_TITLE and
# ISSUE_KEYS_IN_PR_BODY. Similarly, there must be an issue in each project
# with a matching key. Look at JIRA_ENVIRONMENT for hints on how  to
# configure the development environment for VCR.
#
# On the GitHub side, if ./fixtures/vcr_cassettes/pull_request.yml changes, you
# must ensure the title in the response contains the keys found in
# ISSUE_KEYS_IN_PR_TITLE, and that the body contains the strings found in
# ISSUE_KEYS_IN_PR_BODY. These constants reflect assumptions in the test suite.
#
ISSUE_KEYS_IN_PR_TITLE = ["DEV-1", "ABC-1"].freeze
ISSUE_KEYS_IN_PR_BODY = ["XYZ-1"].freeze
JIRA_ENVIRONMENT = {
  projects: [
    {
      key: "DEV",
      issues: [
        {
          key: "DEV-1",
          components: %w(ComponentA ComponentB),
          labels: %w(label1 label2)
        }
      ]
    },
    {
      key: "XYZ",
      issues: [
        {
          key: "XYZ-1",
          components: %w(ComponentC),
          labels: %w(label1)
        }
      ]
    },
    {
      key: "ABC",
      issues: [
        {
          key: "ABC-1",
          components: %w(ComponentB),
          laels: %(label2)
        }
      ]
    }
  ]
}.freeze

RSpec.describe Danger::DangerJiraSync do
  it "should be a plugin" do
    expect(described_class.new(nil)).to be_a Danger::Plugin
  end

  describe "with Dangerfile" do
    let(:dangerfile) { testing_dangerfile }
    let(:plugin) { dangerfile.jira_sync }
    let(:jira_settings) do
      {
        jira_url: testing_env["DANGER_JIRA_URL"],
        jira_username: testing_env["DANGER_JIRA_USERNAME"],
        jira_api_token: testing_env["DANGER_JIRA_API_TOKEN"]
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

      it "should render a warning when the jira_url is blank" do
        jira_settings[:jira_url] = ""

        plugin.configure(jira_settings)

        has_jira_url_warning = dangerfile.status_report[:warnings].any? do |warning|
          warning == "danger-jira_sync plugin configuration is missing jira_url"
        end
        expect(has_jira_url_warning).to be(true)
      end

      it "should render a warning when the jira_username is blank" do
        jira_settings[:jira_username] = ""

        plugin.configure(jira_settings)

        has_jira_url_warning = dangerfile.status_report[:warnings].any? do |warning|
          warning == "danger-jira_sync plugin configuration is missing jira_username"
        end
        expect(has_jira_url_warning).to be(true)
      end

      it "should render a warning when the jira_api_token is blank" do
        jira_settings[:jira_api_token] = ""

        plugin.configure(jira_settings)

        has_jira_url_warning = dangerfile.status_report[:warnings].any? do |warning|
          warning == "danger-jira_sync plugin configuration is missing jira_api_token"
        end
        expect(has_jira_url_warning).to be(true)
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
        let(:github_api_mock) { Object.new }

        before do
          plugin.configure(jira_settings)
        end

        def github_labels_response(labels)
          labels.map do |label|
            {
              id: SecureRandom.random_number(100_000),
              node_id: SecureRandom.base64,
              url: "https://api.github.com/repos/<someorg>/<somerepo>/labels/#{label}",
              name: label,
              color: SecureRandom.hex(3),
              default: false
            }
          end
        end

        def stub_github_api_labelling(labels: [])
          allow(github_api_mock).to receive(:labels).and_return(github_labels_response(labels))
          allow(github_api_mock).to receive(:add_label).and_return(nil)
          allow(github_api_mock).to receive(:labels_for_issue).and_return([])
          allow(github_api_mock).to receive(:add_labels_to_an_issue).and_return(nil)

          allow(plugin.github).to receive(:api).and_return(github_api_mock)
        end

        def extract_project_keys(prefixes)
          return prefixes.map { |key| key.gsub(/-\d+/, "") }
        end

        def pr_title_project_keys
          extract_project_keys(ISSUE_KEYS_IN_PR_TITLE)
        end

        def pr_body_project_keys
          extract_project_keys(ISSUE_KEYS_IN_PR_BODY)
        end

        def pr_title_related_component_names
          component_names = []

          JIRA_ENVIRONMENT[:projects].map do |project|
            next unless pr_title_project_keys.include? project[:key]
            component_names += project[:issues].map { |issue| issue[:components] }
          end

          component_names.flatten.uniq
        end

        def pr_title_related_project_keys
          project_keys = []

          JIRA_ENVIRONMENT[:projects].map do |project|
            project_keys << project[:key] if pr_title_project_keys.include? project[:key]
          end

          project_keys.compact.uniq
        end

        def expected_jira_ticket_labels
          JIRA_ENVIRONMENT[:projects].map { |p| p[:issues].map { |i| i[:labels] } }.flatten.compact.uniq
        end

        def stub_jira_find_issue_response(code:, message:)
          client = plugin.configure(jira_settings)

          response_mock = Object.new
          allow(response_mock).to receive(:code).and_return(code)
          allow(response_mock).to receive(:message).and_return(message)

          issue_mock = Object.new
          allow(issue_mock).to receive(:find).and_raise(JIRA::HTTPError.new(response_mock))

          allow(client).to receive(:Issue).and_return(issue_mock)
        end

        def stub_jira_find_issue_404
          stub_jira_find_issue_response(code: 404, message: "Not found")
        end

        def stub_jira_find_issue_unauthorized
          stub_jira_find_issue_response(code: 503, message: "Unauthorized")
        end

        it "returns a list of labels that contains Jira component names by default" do
          stub_github_api_labelling

          labels = []
          VCR.use_cassette(:default_success, record: :new_episodes) do
            labels = plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(labels).to include(*pr_title_related_component_names)
        end

        it "returns a list of labels that contains Jira issue project keys by default" do
          stub_github_api_labelling

          labels = []
          VCR.use_cassette(:default_success, record: :new_episodes) do
            labels = plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(labels).to include(*pr_title_related_project_keys)
        end

        it "does not return labels by default" do
          stub_github_api_labelling

          labels = []
          VCR.use_cassette(:default_success, record: :new_episodes) do
            labels = plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(labels).not_to include(*expected_jira_ticket_labels)
        end

        it "returns a list of labels that contains JIRA issue labels" do
          stub_github_api_labelling

          labels = []
          VCR.use_cassette(:default_success, record: :new_episodes) do
            labels = plugin.autolabel_pull_request(issue_prefixes, labels: true)
          end

          expect(labels).to include(*expected_jira_ticket_labels)
        end

        it "creates no warnings in the default case" do
          stub_github_api_labelling

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(dangerfile.status_report[:warnings].count).to eq(0)
        end

        it "creates a warning when a related Jira ticket cannot be fetched" do
          stub_jira_find_issue_404

          VCR.use_cassette(:default_success, record: :new_episodes) do
            expect(plugin.autolabel_pull_request(issue_prefixes)).to be_nil
          end

          issue_warning_count = dangerfile.status_report[:warnings].count do |warning|
            warning.start_with?("404 Error while retrieving JIRA issue")
          end

          expect(issue_warning_count).to eq(issue_prefixes.length)
        end

        it "creates only one warning when the Jira credentials are invalid" do
          stub_jira_find_issue_unauthorized

          VCR.use_cassette(:default_success, record: :new_episodes) do
            expect(plugin.autolabel_pull_request(issue_prefixes)).to be_nil
          end

          issue_warning_count = dangerfile.status_report[:warnings].count do |warning|
            warning.start_with?("503 Error while retrieving JIRA issue")
          end

          expect(issue_warning_count).to eq(1)
        end

        it "creates a warning when it cannot create a github label" do
          stub_github_api_labelling

          error = Octokit::Error.from_response({
            method: "POST",
            url: "https://www.example.com/",
            status: 422,
            documentation_url: "https://developer.github.com/v3/issues/labels/#create-a-label",
            message: <<~HEREDOC
              resource: Label
              code: already_exists
              field: name
            HEREDOC
          })

          expect(github_api_mock).to receive(:add_label).and_raise(error)
          expect(dangerfile.status_report[:warnings].count).to eq(0), "preconditions"

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end

          expected_missing_label_count = 1
          expect(dangerfile.status_report[:warnings].count).to eq(expected_missing_label_count)
        end

        it "creates a warning when it cannot add a label to an existing github issue" do
          stub_github_api_labelling

          error = Octokit::Error.from_response({
            method: "GET",
            url: "https://www.example.com/",
            status: 503,
            documentation_url: "https://developer.github.com/v3/issues/labels/#create-a-label",
            message: "Forbidden"
          })

          expect(github_api_mock).to receive(:add_labels_to_an_issue).and_raise(error)
          expect(dangerfile.status_report[:warnings].count).to eq(0), "preconditions"

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(dangerfile.status_report[:warnings].count).to eq(1)
        end

        it "creates a warning when it cannot fetch labels for the related pr" do
          stub_github_api_labelling

          error = Octokit::Error.from_response({
            method: "GET",
            url: "https://www.example.com/",
            status: 503,
            documentation_url: "https://developer.github.com/v3/issues/labels/#create-a-label",
            message: "Forbidden"
          })

          expect(github_api_mock).to receive(:labels_for_issue).and_raise(error)
          expect(dangerfile.status_report[:warnings].count).to eq(0), "preconditions"

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(dangerfile.status_report[:warnings].count).to eq(1)
        end

        it "creates a warning when it cannot fetch existing github labels" do
          stub_github_api_labelling

          error = Octokit::Error.from_response({
            method: "POST",
            url: "https://www.example.com/",
            status: 422,
            documentation_url: "https://developer.github.com/v3/issues/labels/#create-a-label",
            message: <<~HEREDOC
              resource: Label
              code: already_exists
              field: name
            HEREDOC
          })

          expect(github_api_mock).to receive(:labels).and_raise(error)
          expect(dangerfile.status_report[:warnings].count).to eq(0), "preconditions"

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end

          expect(dangerfile.status_report[:warnings].count).to eq(1)
        end

        it "adds a label to the github issue for each related jira issue component name" do
          pr_title_related_component_names.each do |component_name|
            expect(github_api_mock).to receive(:add_label).with(anything, component_name, anything).once.and_return(nil)
          end
          stub_github_api_labelling

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end
        end

        it "adds a label to the github issue for each related jira issue project key" do
          pr_title_related_project_keys.each do |project_key|
            expect(github_api_mock).to receive(:add_label).with(anything, project_key, anything).once.and_return(nil)
          end
          stub_github_api_labelling

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end
        end

        it "does not add existing labels to the github pr" do
          expect(github_api_mock).to receive(:labels_for_issue).once.and_return github_labels_response(%w(DEV))
          expect(github_api_mock).to receive(:add_labels_to_an_issue).with(anything, anything, %w(ComponentA ComponentC ABC ComponentB)).once

          stub_github_api_labelling

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end
        end

        it "adds missing github labels" do
          labels = pr_title_project_keys + pr_title_related_component_names
          labels.each do |label|
            expect(github_api_mock).to receive(:add_label).with(anything, label, anything)
          end
          stub_github_api_labelling

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(issue_prefixes)
          end
        end

        it "does not attempt to add new github labels when they already exist" do
          existing_labels = %w(ComponentA)
          existing_labels.each do |existing_label|
            expect(github_api_mock).not_to receive(:add_label).with(anything, existing_label, anything)
          end
          stub_github_api_labelling(labels: existing_labels)

          VCR.use_cassette(:default_success) do
            plugin.autolabel_pull_request(issue_prefixes)
          end
        end

        it "returns nil if no issue keys are found in the pr name or body" do
          expect(plugin.autolabel_pull_request(["NOPE"])).to be_nil
        end

        it "falls back to issue keys in the pr body if none are found in the pr title" do
          stub_github_api_labelling

          VCR.use_cassette(:default_success, record: :new_episodes) do
            plugin.autolabel_pull_request(pr_body_project_keys)
          end
        end

        it "ignores issue keys in the pr body if any are found in the pr title" do
          stub_github_api_labelling

          labels = []
          VCR.use_cassette(:default_success, record: :new_episodes) do
            labels = plugin.autolabel_pull_request(pr_body_project_keys + pr_title_project_keys)
          end

          expect(labels).to include(*pr_title_project_keys)
          expect(labels).not_to include(*pr_body_project_keys)
        end

        it "raises an ArgumentError if no issue_prefixes are specified" do
          expect { plugin.autolabel_pull_request([]) }.to raise_error(ArgumentError)
        end

        it "returns nil if no labels can be fetched from Jira" do
          stub_jira_find_issue_404

          VCR.use_cassette(:default_success, record: :new_episodes) do
            expect(plugin.autolabel_pull_request(issue_prefixes)).to be_nil
          end
        end
      end
    end
  end
end
