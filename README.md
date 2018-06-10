# danger-jira_sync

Jira and GitHub should be friends, and Danger brings them closer together
with jira_sync

## Installation

Add `danger-jira_sync` to your Gemfile

    gem "danger-jira_sync"

Or, without bundler

    $ gem install danger-jira_sync

## Usage

You must always configure jira_sync before it can access the Jira REST API

    jira_sync.configure(
      jira_url: "https://myjirainstance.atlassian.net",
      jira_username: "test@example.com",
      jira_api_key: "ABC123",
    )

Automatically label Pull Requests with the associated Jira issue's component names and project key

    jira_sync.autolabel_pull_request(%w(DEV))

### Methods

#### `configure(jira_url:, jira_username:, jira_api_key:)` 
Configures the Jira Client with your credentials

##### Params
  - `jira_url [String]` - The full url to your Jira instance, e.g., "https://myjirainstance.atlassian.net" 
  - `jira_username [String]` - The username to use for accessing the Jira instance. Commonly, this is an email address.
  - `jira_api_key [String]` - The API key to use to access the Jira instance. Generate one here: https://id.atlassian.com/manage/api-tokens

##### Returns
 - `[JIRA::Client]` - The underlying `JIRA::Client` instance

#### `autolabel_pull_request(issue_prefixes)` 
Labels the Pull Request with Jira Project Keys and Component Names

##### Params
  - `issue_prefixes [Array<String>]` - An array of issue key prefixes; this is often the project key. These must be present in the title or body of the Pull Request

##### Returns
  - `[Array<String>, nil]` - The list of project & component labels that were applied or nil if no issue or labels were found


## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies
3. Run `bundle exec rake spec` to run the tests
4. Use `bundle exec guard` to automatically have tests run as you make changes
5. Make your changes
