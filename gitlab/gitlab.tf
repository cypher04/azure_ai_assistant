data "gitlab_project" "project" {
  path_with_namespace = "${var.gitlab_namespace}/${var.gitlab_project_name}"
}


// gitlab project

resource "gitlab_project_environment" "default_branch" {
  project = data.gitlab_project.project.id
  name    = "gitlab_project"
  external_url = "https://gitlab.com/${var.gitlab_namespace}/${var.gitlab_project_name}/-/environments/${var.default_branch}"
}

// gitlab branch protection

resource "gitlab_branch_protection" "example" {
  project = data.gitlab_project.project.id
  branch  = "main"
  allowed_to_push = [ 
    {
    access_level = "maintainer"
  }
   ]

   allowed_to_merge = [ {
     access_level = "developer"
   } ]
}