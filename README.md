# Overview

**Starred Search** is a tool to search the readme files in GitHub users' starred repositories. It lives at [starredsearch.com](http://starredsearch.com).

The app is written in Swift using the [Vapor](https://github.com/qutheory/vapor) web framework.

# Prerequisites

* Swift 3 / Xcode 8.

* The [Vapor CLI](https://github.com/vapor/toolbox).

* A [GitHub OAuth application](https://github.com/settings/developers) with the callback URL set to `/oauth/github` on your server.

# Build

Run `vapor build` to install package dependencies and build the project.

# Debug Environment

Run `vapor xcode` to create the Xcode project. Edit the App scheme and add an argument to the Run action:

```
  --workdir=$(SRCROOT)
``` 

Create the file `debug.json` in your checkout directory:

```
{
  "GITHUB_CLIENT_ID": "<your app client>",
  "GITHUB_CLIENT_SECRET": "<your app secret>",
  "APP_ADMIN_PASSWORD": "<your choice>"
}
```

# Release Environment

Run `vapor build --release` to build the app and copy `.build/release/App` to the server.

Copy the `Resource` and `Public` directories to the same directory on the server.

Define environment variables for `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` and `APP_ADMIN_PASSWORD`.

Run `./App --workdir=<your directory> --port=<your port>`.

# Sample launchctl File

Replace `???` as appropriate.

```
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
    <key>GITHUB_CLIENT_ID</key>
    <string>???</string>
    <key>GITHUB_CLIENT_SECRET</key>
    <string>???</string>
    <key>APP_ADMIN_PASSWORD</key>
    <string>???</string>
	</dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>???</string>
	<key>ProgramArguments</key>
	<array>
		<string>???/App</string>
		<string>--workdir=???</string>
		<string>--port=???</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>???</string>
	<key>StandardOutPath</key>
	<string>???</string>
	<key>WorkingDirectory</key>
	<string>???</string>
</dict>
</plist>
```
