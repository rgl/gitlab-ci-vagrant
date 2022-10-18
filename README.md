GitLab-CI runner nodes

This is to be used after [rgl/gitlab-vagrant](https://github.com/rgl/gitlab-vagrant) is running.

This is analogous to Jenkins slave nodes of the [rgl/jenkins-vagrant](https://github.com/rgl/jenkins-vagrant) environment, but using GitLab-CI instead of Jenkins.

# Usage

From the `../gitlab-vagrant` directory, start GitLab as described at [rgl/gitlab-vagrant](https://github.com/rgl/gitlab-vagrant).

At this repository directory, start the runner nodes:

```bash
vagrant up --no-destroy-on-error ubuntu
vagrant up --no-destroy-on-error windows
```

# Reference

* [.gitlab-ci.yml documentation](https://docs.gitlab.com/ee/ci/yaml/index.html)
* [GitLab Continuous Integration (GitLab CI/CD)](https://docs.gitlab.com/ee/ci/)
