-- Optional interface configuration. Keep outside lua/plugins so it is not
-- installed or activated on machines that do not use Jira.
return {
  {
    "letieu/jira.nvim",
    cmd = { "Jira" },
    opts = {
      jira = {
        api_version = "3",
        limit = 200,
        logging = false,
      },
      active_sprint_query = "project = '%s' AND sprint in openSprints() ORDER BY Rank ASC",
      queries = {
        ["Next sprint"] = "project = '%s' AND sprint in futureSprints() ORDER BY Rank ASC",
        ["Backlog"] = "project = '%s' AND (issuetype IN standardIssueTypes() OR issuetype = Sub-task) AND (sprint IS EMPTY OR sprint NOT IN openSprints()) AND statusCategory != Done ORDER BY Rank ASC",
        ["My Tasks"] = "assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC",
      },
    },
  },
}
