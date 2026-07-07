# Source

URL: https://claude.com/blog/enterprise-managed-auth
Published: June 18, 2026

## Centrally Manage Authorization for MCP Connectors

Anthropic has launched enterprise-managed authorization for MCP (Model Context Protocol) connectors, enabling administrators to provision connector access across their entire organization through identity providers like Okta. This eliminates the need for individual user authorization, streamlining deployment and security.

**Zero-Touch Setup:** When employees log in, their connectors are already configured based on their IdP groups and roles. Access remains consistent across Claude chat, Claude Code, and Cowork.

**Centralized Administration:** Admins manage MCP access within existing identity provider workflows—provision once, scope by group, manage revocation through the IdP. Organizations can shorten access token lifetimes without impacting productivity.

**Security Control:** Admins can require connectors to only connect through the IdP, keeping work and personal use separated while preventing accidental linking of personal accounts to work tools.

**Identity Providers:** Okta supported at launch; additional providers coming soon.

**MCP Providers at Launch:** Asana, Atlassian, Canva, Figma, Granola, Linear, Supabase (Slack coming soon).

**Early Adopters:** HubSpot, Ramp, and Webflow rolling out enterprise-managed auth across teams.

Available in beta for Claude Team and Enterprise plan customers.
