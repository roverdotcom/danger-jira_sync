# danger-jira_sync

Jira and GitHub should be friends, and Danger brings them closer together
with jira_sync

## Installation

Add `danger-jira_sync` to your Gemfile

    gem "danger-jira_sync", git: "https://github.com/roverdotcom/danger-jira_sync"

Or, without bundler

    $ gem install danger-jira_sync -s https://github.com/roverdotcom/danger-jira_sync

## Usage

You must always configure jira_sync before it can access the Jira REST API

    jira_sync.configure(
      jira_url: "https://myjirainstance.atlassian.net",
      jira_username: "test@example.com",
      jira_api_token: "ABC123",
    )

Automatically label Pull Requests with the associated Jira issue's component names and project key

    jira_sync.autolabel_pull_request(%w(DEV))

## Methods

### `configure(jira_url:, jira_username:, jira_api_token:)` 
Configures the Jira Client with your credentials

**Params**
  - `jira_url [String]` - The full url to your Jira instance, e.g., "https://myjirainstance.atlassian.net" 
  - `jira_username [String]` - The username to use for accessing the Jira instance. Commonly, this is an email address
  - `jira_api_token [String]` - The API key to use to access the Jira instance. Generate one here: https://id.atlassian.com/manage/api-tokens

**Returns**
 - `[JIRA::Client]` - The underlying `JIRA::Client` instance

### `autolabel_pull_request(issue_prefixes)` 
Labels the Pull Request with Jira Project Keys and Component Names

**Params**
  - `issue_prefixes [Array<String>]` - An array of issue key prefixes; this is often the project key. These must be present in the title or body of the Pull Request

**Returns**
  - `[Array<String>, nil]` - The list of project & component labels that were applied or nil if no issue or labels were found


## Development

1. Create a [Jira Cloud developmnet environment](http://go.atlassian.com/cloud-dev)
2. Clone this repo
3. Run `bundle install` to setup dependencies
4. Copy `.env.sample` to `.env` and fill in settings for GitHub and your Jira Cloud development environment
5. Run `bundle exec rake spec` to run the tests
6. Use `bundle exec guard` to automatically have tests run as you make changes
7. Make your changes

# **:warning: Do not commit fixtures with your credentials in them :warning:**

Before committing, check to see if you have created or changed any fixtures in `/spec/fixtures/vcr_cassettes`. If you have, it is likely that the changed file contains your credentials. Manually remove your credentials from these fixture files

When a new HTTP request is made that [VCR](https://github.com/vcr/vcr) hasn't seen before, it will record the response from the server and play it back in subsequent HTTP requests to the same URL with the same headers. This means that if a new request is made in the tests, it will actually make a request to the server in order to record the response. For this reason, development should be done within testing environments in GitHub and Jira Cloud