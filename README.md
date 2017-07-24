# Overview

**Starred Search** is a tool to search the readme files in GitHub users' starred repositories. It lives at [starredsearch.com](http://starredsearch.com).

The app is written in Swift using the [Vapor](https://github.com/qutheory/vapor) web framework.

# Prerequisites

* Swift 3 / Xcode 8.

* A [GitHub OAuth application](https://github.com/settings/developers) with the callback URL set to `/oauth/github` on your server.

# Debug Environment

Create the file `debug.json` in your checkout directory:

```
{
  "GITHUB_CLIENT_ID": "<your app client>",
  "GITHUB_CLIENT_SECRET": "<your app secret>",
  "APP_ADMIN_PASSWORD": "<your choice>"
}
```

# Release Environment

Define environment variables for `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` and `APP_ADMIN_PASSWORD`.

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
