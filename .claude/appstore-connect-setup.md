# App Store Connect MCP Setup Guide

## Overview
The App Store Connect MCP server enables Claude to directly interact with your App Store Connect account for managing app metadata, beta testers, analytics, and more.

## Step 1: Generate API Credentials

1. Go to [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/api)
2. Click the **+** button to create a new API key
3. Name it something like "Claude Code MCP"
4. Choose **Admin** or **App Manager** role (Admin recommended for full access)
5. Click **Generate**
6. **Download the .p8 file** immediately (you can only download it once!)
7. Note down the **Key ID** (shown in the keys list)
8. Note down the **Issuer ID** (shown at the top of the page)

## Step 2: Store the .p8 File Securely

Save your `.p8` file in a secure location, e.g.:
```bash
mkdir -p ~/.appstore-connect
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstore-connect/
chmod 600 ~/.appstore-connect/AuthKey_*.p8
```

## Step 3: Add MCP Server to Claude

Run this command (replacing placeholders with your values):

```bash
claude mcp add appstore-connect \
  --command "npx" \
  --args "-y,appstore-connect-mcp-server" \
  --env "APP_STORE_CONNECT_KEY_ID=YOUR_KEY_ID" \
  --env "APP_STORE_CONNECT_ISSUER_ID=YOUR_ISSUER_ID" \
  --env "APP_STORE_CONNECT_P8_PATH=/Users/YOUR_USERNAME/.appstore-connect/AuthKey_YOUR_KEY_ID.p8"
```

### Example with actual values:
```bash
claude mcp add appstore-connect \
  --command "npx" \
  --args "-y,appstore-connect-mcp-server" \
  --env "APP_STORE_CONNECT_KEY_ID=ABC123XYZ" \
  --env "APP_STORE_CONNECT_ISSUER_ID=12345678-1234-1234-1234-123456789012" \
  --env "APP_STORE_CONNECT_P8_PATH=/Users/jamesfarmer/.appstore-connect/AuthKey_ABC123XYZ.p8"
```

## Step 4: Restart Claude Code

After adding the MCP server, restart Claude Code for changes to take effect.

## Step 5: Verify Connection

Run `claude mcp list` to verify the server is connected.

## Available Features

Once connected, you can ask Claude to:
- List and manage your apps
- Create and manage beta test groups
- Add/remove beta testers
- View beta feedback and screenshots
- Create app versions
- Manage localizations
- View analytics reports
- Manage bundle IDs and capabilities

## Security Notes

- Keep your `.p8` file secure and never commit it to git
- The API key has access to your App Store Connect account
- Consider using a key with limited permissions if possible
- Rotate keys periodically

## Troubleshooting

If the MCP server fails to connect:
1. Verify the `.p8` file path is correct and accessible
2. Check that Key ID and Issuer ID are correct
3. Ensure the API key hasn't been revoked
4. Check Claude Code logs for specific error messages
