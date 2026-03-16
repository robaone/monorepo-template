# practice-monorepo

Repo to be shared across teams for storing all code.

## Getting Started

### Environment Dependencies

The monorepo uses [mise](https://mise.jdx.dev) to manage environment dependencies and centralize common tasks.

1. Install Mise (`brew install mise` or see their [installation guide](https://mise.jdx.dev/getting-started.html)).
2. `mise install` to install tools (node/python)
3. Set your AWS Profile to the production account
4. `mise run monorepo-init`

Then for whichever domain you are working on, `cd` into that directory and run `mise run init` to install the dependencies.

### Tunnel9

The monorepo uses [tunnel9](https://github.com/sio2boss/tunnel9) to manage SSH tunnels to the database.

1. `mise run tunnel9-init` to install the tunnel9 binary and all relevant dependencies
2. `mise run tunnel9` to start the tunnel9 services. From it, you can toggle tunnels on and off. If you ctrl-c or press `q` to quit the "UI", the tunnels will be closed.

### Tooling

The package.json has commands that aid in workflow management. They require the creation of configuration files.
Run the following command to setup the configuration files.

```
./tooling/scripts/setup.sh
```

It will create `~/.tooling/config.json` and `~/jira-cli/config.json`.

## Running Locally

### Build the Code

Regardless of running one lambda or all lambdas, you'll need to build the code first.

```sh
# Navigate to the directory
cd domains/delivery-ts
# Build the code
npm run build
```

### Run One Lambda
 
_Better docs should be written for this._

To run the lambdas in a **TypeScript** domain:

```sh
# Navigate to the directory
cd domains/delivery-ts
# Build the code
npm run build
# Ensure you have an active session, since this will likely require pulling secrets from SecretsManager
aws_dev_mfa 123456
# Replace the <lambda-name> with the name based on what is in the package.json
npm run local:<lambda-name>
```

### Run All Lambdas in a Domain

When running the lambdas for a domain, first consider which database you intend to use. If using the dev environment database, you will need to have an active tunnel9 connection. To use the testbed database, you'll need to run it locally.

> WARNING: Not all domains currently support this.

```sh
cd domains/product-ts
mise run lambdas-local-[local|dev]
```

## Folder structure

```txt
.
├── docs/
│   ├── adr/
|   |   └── ${adr name: snake case}.md
│   └── README.md
├── domains/
│   ├── project1/
│   |   ├── ${project source code}
│   |   ├── .depends
│   |   └── README.md
│   ├── project2/
│   |   ├── ${project source code}
│   |   ├── .depends
│   |   └── README.md
├── tooling/
│   └── ${category}/
|       └── ${executable files}.ext
├── package.json
└── README.md
```


## Usage

### Start a feature

1. Create a new branch from `develop` by running the following command

```
npm run start:feature
```

### Creating a new project

1. Navigate to the repository root
1. Type the following command and follow the instructions

```
npm run create:project
```

### Interproject dependency

If project1 depends on project2 (i.e. a change in project2 should cause a build and deployment of project1), edit the `domains/project1/.depends` file by adding the following

```
domains/project2/*
```

### Create a pull request

1. Run the following command to push your changes to GitHub and create your pull request

```
npm run create:pr
```

### Deploy feature to the develop environment

1. All checks must pass in the pull request
2. The pull request must have at least 1 approval
3. The pull request must target the `develop` branch
4. Squash and merge the pull request
5. The workflow will run and deploy all changed projects to the develop environment
6. A release will be created or updated with a description of the contents of the next release
7. The deployment will be recorded and associated with tickets

### Cut a release and deploy to UAT

1. Create a release branch from the `develop` branch and pull requests by running the following command
2. The workflow will create two pull requests in this order:
   - First, a draft PR targeting `develop`
   - Then, a PR targeting `main`
3. The workflow will run and deploy all changed projects to the staging / uat environment

```
npm run start:release
```

### Create a hotfix

1. Create a hotfix branch from the `main` branch
2. Update the package.json version to the next patch version
3. Commit your changes with a message with a `fix:` semantic prefix
4. Push your changes to GitHub. The workflow will create two pull requests in this order:
   - First, a draft PR targeting `develop`
   - Then, a PR targeting `main`
5. The workflow will run and deploy all changed projects to the staging / uat environment
6. A release will be created and tickets will be tagged

```
npm run start:hotfix
```

### Deploy release / hotfix to production

1. All checks must pass in the pull request
2. The pull request must have at least 1 approval
3. The pull request must target the `main` branch
4. Merge the pull request (🚨 DO NOT SQUASH AND MERGE!)
5. The workflow will run and deploy all changed projects to the production environment
6. A GitHub release will be generated and the repository will be tagged with the next version
7. Confirm that the deployment to production is successful

```
git checkout ${release or hotfix branch}
npm run merge
```

### Navigating the Github Actions Workflow

1. Builds and deployments are done via GitHub actions.
2. You can view each project's build in the GitHub actions page.

