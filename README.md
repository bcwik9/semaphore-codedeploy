### Setup
* Clone repo
* Run `bundle install` and `rake db:migrate`
* Setup AWS credentials. http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
* Go to your AWS, and create a CodeDeploy project with the same name as your project in GitHub
* Go to your AWS, and create a CodeDeploy deployment group with the same name as your branch in GitHub
* Go to your GitHub account settings, and create a Personal access token. Write it down
  * `export GITHUB_CODEDEPLOY_TOKEN=[key you copied]`
* Go to your Semaphore project, and create a new webhook that has the URL for this server
* Push code to GitHub, and it should automatically create a CodeDeploy deployment for the project!
