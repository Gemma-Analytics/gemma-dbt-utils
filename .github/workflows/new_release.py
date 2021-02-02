#!/usr/bin/env python3
"""Create a new GitHub release, if appropriate.

Steps:
- check if version in dbt_profiles.yml matches an existing release
- if not, create a new release
"""

import requests
import os
import yaml
import json


def main():
    github_token = os.environ["GITHUB_TOKEN"]
    github_repository = os.environ["GITHUB_REPOSITORY"]
    with open("dbt_project.yml", "r") as dbt_project:
        release_version = (
            "v" + yaml.load(dbt_project, Loader=yaml.FullLoader)["version"]
        )

    url = "https://api.github.com/repos/{0}/releases".format(github_repository)
    params = {"per_page": 100, "page": 0}

    create_new_release = True
    print(
        "\n\nChecking if GitHub tag {0} already exists...\n\n".format(release_version)
    )
    while create_new_release:
        page_of_tags = requests.get(url, params=params)
        assert page_of_tags.status_code == 200, page_of_tags.text
        if not page_of_tags.json():
            break  # iterated through all tags - nothing found!

        # iterate:
        for tag in page_of_tags.json():
            if release_version == tag["name"]:
                print(
                    "\n\nGitHub tag {0} already exists - not creating new release!\n\n".format(
                        release_version
                    )
                )
                create_new_release = False
                continue
        params["page"] = 1 + params["page"]

    if create_new_release:
        data = {
            "tag_name": release_version,
            "name": release_version,
            "body": "This release was automatically created by a GitHub action after a PR merger. Check the PR for changes.",
        }
        print("\n\nCreating new release {0}...\n\n".format(release_version))
        new_release = requests.post(
            url,
            headers={
                "Accept": "application/vnd.github.v3+json",
                "Authorization": "token {0}".format(github_token),
            },
            data=json.dumps(data),
        )
        assert new_release.status_code == 201, new_release.text
        print("\n\nNew release created:\n", new_release.json())


if __name__ == "__main__":
    # execute only if run as a script
    main()
