# frozen_string_literal: true

require "securerandom"
require "jira-ruby"

module Danger
  # Jira and GitHub should be friends, and Danger brings them closer together
  # with jira_sync
  #
  # @example You must always configure jira_sync before it can access the Jira
  #   REST API
  #
  #         jira_sync.configure(
  #           jira_url: "https://myjirainstance.atlassian.net",
  #           jira_username: "test@example.com",
  #           jira_api_token: "ABC123",
  #         )
  #
  # @example Automatically label Pull Requests with the associated Jira issue's
  #   component names and project key
  #
  #         jira_sync.autolabel_pull_request(%w(DEV))
  #
  # @see  roverdotcom/danger-jira_sync
  # @tags jira, github, labels, autolabel, danger, plugin
  #
  class DangerJiraSync < Plugin
    class NotConfiguredError < StandardError
      def initialize(msg = "You must call jira_sync.configure before jira_sync can be used")
        super
      end
    end

    # Configures the Jira REST Client with your credentials
    #
    # @param jira_url [String]  The full url to your Jira instance, e.g.,
    #   "https://myjirainstance.atlassian.net"
    # @param jira_username [String] The username to use for accessing the Jira
    #   instance. Commonly, this is an email address.
    # @param jira_api_token [String] The API key to use to access the Jira
    #   instance. Generate one here: https://id.atlassian.com/manage/api-tokens
    #
    # @return [JIRA::Client] The underlying jira-ruby JIRA::Client instance
    #
    def configure(jira_url:, jira_username:, jira_api_token:)
      warn "danger-jira_sync plugin configuration is missing jira_url" if jira_url.blank?
      warn "danger-jira_sync plugin configuration is missing jira_username" if jira_username.blank?
      warn "danger-jira_sync plugin configuration is missing jira_api_token" if jira_api_token.blank?

      @jira_client = JIRA::Client.new(
        site: jira_url,
        username: jira_username,
        password: jira_api_token,
        context_path: "",
        auth_type: :basic
      )
    end

    # Labels the Pull Request with Jira Project Keys and Component Names
    #
    # @param issue_prefixes [Array<String>] An array of issue key prefixes;
    #   this is often the project key. These must be present in the title or
    #   body of the Pull Request
    #
    # @return [Array<String>, nil] The list of project & component labels
    #   that were applied or nil if no issue or labels were found
    #
    def autolabel_pull_request(issue_prefixes, project: true, components: true, labels: false)
      raise NotConfiguredError unless @jira_client
      raise(ArgumentError, "issue_prefixes cannot be empty") if issue_prefixes.empty?

      issue_keys = extract_issue_keys_from_pull_request(issue_prefixes)
      return if issue_keys.empty?

      labels = fetch_labels_from_issues(
        issue_keys,
        project: project,
        components: components,
        labels: labels
      )
      return if labels.empty?

      create_missing_github_labels(labels)
      add_labels_to_issue(labels)

      labels
    end

    private

    def repo
      @repo ||= github.pr_json[:base][:repo][:full_name]
    end

    def issue_number
      @issue_number ||= github.pr_json["number"]
    end

    def github_labels
      @github_labels ||= github.api.labels(repo).map { |github_label| github_label[:name] }
    rescue Octokit::Error => e
      warn "#{e.response_status} Error while retrieving GitHub labels: #{e.message}"
    end

    def extract_issue_keys_from_pull_request(key_prefixes)
      # Match all key_prefixes followed by a dash then numbers, e.g. "DEV-12345"
      re = Regexp.new(/((#{key_prefixes.join("|")})-\d+)/)

      # Extract keys from the PR title and fallback to the body if none are found
      keys = []
      github.pr_title.gsub(re) { |match| keys << match }
      github.pr_body.gsub(re) { |match| keys << match } if keys.empty?
      keys.compact.uniq
    end

    def fetch_labels_from_issues(issue_keys, project: true, components: true, labels: false)
      issue_labels = []
      issue_keys.each do |key|
        begin
          issue = @jira_client.Issue.find(key)
          issue_labels << issue.project.key if project
          issue_labels += issue.components.map(&:name) if components
          issue_labels += issue.fields["labels"] if labels
        rescue JIRA::HTTPError => e
          warn "#{e.code} Error while retrieving JIRA issue \"#{key}\": #{e.message}"
          # No reason to continue if Unauthorized
          break if e.code == 503
        end
      end
      issue_labels.compact.uniq
    end

    def create_missing_github_labels(labels)
      missing_labels = labels - github_labels
      missing_labels.each do |label|
        color = SecureRandom.hex(3)
        begin
          github.api.add_label(repo, label, color)
        rescue Octokit::Error => e
          warn "#{e.response_status} Error while creating GitHub label \"#{label}\" with color \"#{color}\": #{e.message}"
        end
      end
      missing_labels
    end

    def add_labels_to_issue(labels)
      existing_labels = github.api.labels_for_issue(repo, issue_number).map { |label| label[:name] }
      new_labels = labels - existing_labels
      github.api.add_labels_to_an_issue(repo, issue_number, new_labels) unless new_labels.empty?
    rescue Octokit::Error => e
      warn "#{e.response_status} Error while adding labels [#{labels}] to GitHub issue: #{e.message}"
    end
  end
end
